import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

/// A single chat session (grouped from messages by session_id)
class ChatSession {
  final String? id; // null = legacy messages without a session_id
  final String preview; // first user message preview (truncated)
  final DateTime lastMessageAt;
  final int messageCount;

  const ChatSession({
    required this.id,
    required this.preview,
    required this.lastMessageAt,
    required this.messageCount,
  });

  bool get isLegacy => id == null;
}

/// Manager chat message model - matches DB schema
class ManagerChatMessage {
  final String id;
  final String? clientId;
  final String? userId;
  final String? userName;
  final String? userMessage;
  final String? aiResponse;
  final DateTime createdAt;
  final String? sessionId; // Groups messages into chat sessions

  const ManagerChatMessage({
    required this.id,
    this.clientId,
    this.userId,
    this.userName,
    this.userMessage,
    this.aiResponse,
    required this.createdAt,
    this.sessionId,
  });

  factory ManagerChatMessage.fromJson(Map<String, dynamic> json) {
    return ManagerChatMessage(
      id: json['id'] as String,
      clientId: json['client_id'] as String?,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      userMessage: json['user_message'] as String?,
      aiResponse: json['ai_response'] as String?,
      sessionId: json['session_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'user_name': userName,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'session_id': sessionId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Provider for manager chat with AI
class ManagerChatProvider extends ChangeNotifier {
  // All messages for this user across all sessions
  List<ManagerChatMessage> _allMessages = [];

  bool _isLoading = false;
  bool _isWaitingForResponse = false;
  String? _error;

  String _agentId = '';
  String _managerPhoneNumber = '';
  String? _currentUserId;
  bool _initialized = false;

  // Current session ID (null = legacy / unassigned)
  String? _currentSessionId;

  // In-memory cache: message ID → session_id
  // Survives DB refreshes when _patchSessionId hasn't committed yet.
  final Map<String, String> _messageSessionMap = {};

  RealtimeChannel? _chatChannel;
  Timer? _pollTimer;

  // ─── Getters ───────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isWaitingForResponse => _isWaitingForResponse;
  String? get error => _error;
  String? get currentSessionId => _currentSessionId;

  /// Messages for the current session only
  List<ManagerChatMessage> get messages {
    if (_currentSessionId == null) {
      // Legacy: show messages without a session_id
      return _allMessages
          .where((m) => m.sessionId == null)
          .toList();
    }
    return _allMessages
        .where((m) => m.sessionId == _currentSessionId)
        .toList();
  }

  /// All sessions, sorted by most recent first
  List<ChatSession> get sessions {
    final Map<String?, List<ManagerChatMessage>> grouped = {};
    for (final msg in _allMessages) {
      grouped.putIfAbsent(msg.sessionId, () => []).add(msg);
    }

    final result = grouped.entries.map((entry) {
      final msgs = entry.value
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      // First non-empty user message as preview
      final firstUserMsg = msgs.firstWhere(
        (m) => m.userMessage != null && m.userMessage!.isNotEmpty,
        orElse: () => msgs.first,
      );
      final raw = firstUserMsg.userMessage ?? 'Chat session';
      final preview = raw.length > 60 ? '${raw.substring(0, 60)}...' : raw;

      return ChatSession(
        id: entry.key,
        preview: preview,
        lastMessageAt: msgs.last.createdAt,
        messageCount: msgs.length,
      );
    }).toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    return result;
  }

  /// Dynamic table name from ClientConfig
  String get _managerChatsTable {
    final slug = ClientConfig.currentClient?.slug;
    if (slug != null && slug.isNotEmpty) {
      return '${slug}_manager_chats';
    }
    return 'manager_chats';
  }

  // ─── Initialization ────────────────────────────────────────

  /// Initialize the chat. Only does full setup once; subsequent calls reload messages.
  void initialize({
    required String agentId,
    required String managerPhoneNumber,
  }) {
    _agentId = agentId;
    _managerPhoneNumber = managerPhoneNumber;
    final userId = ClientConfig.currentUser?.id;

    if (_initialized && userId == _currentUserId) {
      // Already initialized — just refresh messages silently
      _refreshMessages();
      return;
    }

    _currentUserId = userId;
    _initialized = true;

    print('💬 Initializing chat for user: $_currentUserId');
    _loadAllMessages();
    _subscribeToMessages();
  }

  /// Subscribe to realtime messages for current user only
  void _subscribeToMessages() {
    _chatChannel?.unsubscribe();

    final userId = _currentUserId;
    if (userId == null) {
      print('💬 No user ID, skipping realtime subscription');
      return;
    }

    _chatChannel = SupabaseService.client
        .channel('manager_chat_${_managerChatsTable}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _managerChatsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('💬 New manager chat message received');
            _handleNewMessage(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _managerChatsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('💬 Manager chat message updated');
            _handleMessageUpdate(payload.newRecord);
          },
        )
        .subscribe();

    print('💬 Subscribed to $_managerChatsTable for user: $userId');
  }

  // ─── Message handlers ──────────────────────────────────────

  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final message = ManagerChatMessage.fromJson(data);
      if (message.userId != _currentUserId) return;

      // Match by ID first, then by content — do NOT match by session_id because
      // n8n may save the DB record without session_id, so the incoming record
      // will have sessionId=null even though the temp message has a real UUID.
      final existingIndex = _allMessages.indexWhere((m) =>
          m.id == message.id ||
          (m.id.startsWith('temp_') &&
              m.userMessage == message.userMessage));

      if (existingIndex != -1) {
        final existing = _allMessages[existingIndex];
        // Prefer the temp message's session_id if the DB record has none
        final resolvedSessionId = message.sessionId ?? existing.sessionId;
        final resolved = _withSessionId(message, resolvedSessionId);
        _allMessages[existingIndex] = resolved;
        // Cache so future DB refreshes can restore the session_id
        if (resolvedSessionId != null) {
          _messageSessionMap[message.id] = resolvedSessionId;
        }
        // Patch the DB record so future refreshes preserve the session_id
        if (message.sessionId == null && resolvedSessionId != null) {
          _patchSessionId(message.id, resolvedSessionId);
        }
      } else {
        // No temp match — assign to the active session if record has no session_id
        final resolvedSessionId = message.sessionId ?? _currentSessionId;
        final resolved = _withSessionId(message, resolvedSessionId);
        _allMessages.add(resolved);
        if (resolvedSessionId != null) {
          _messageSessionMap[message.id] = resolvedSessionId;
        }
        if (message.sessionId == null && _currentSessionId != null) {
          _patchSessionId(message.id, _currentSessionId!);
        }
      }

      if (message.aiResponse != null && message.aiResponse!.isNotEmpty) {
        _isWaitingForResponse = false;
        _stopPolling();
      }
      notifyListeners();
    } catch (e) {
      print('Error handling new message: $e');
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> data) {
    try {
      final message = ManagerChatMessage.fromJson(data);
      if (message.userId != _currentUserId) return;

      // Match by real ID first
      var index = _allMessages.indexWhere((m) => m.id == message.id);

      // Fall back to matching temp message by content only (no session_id check)
      if (index == -1) {
        index = _allMessages.indexWhere((m) =>
            m.id.startsWith('temp_') &&
            m.userMessage == message.userMessage);
      }

      if (index != -1) {
        final existing = _allMessages[index];
        final resolvedSessionId = message.sessionId ?? existing.sessionId;
        final resolved = _withSessionId(message, resolvedSessionId);
        _allMessages[index] = resolved;
        if (resolvedSessionId != null) {
          _messageSessionMap[message.id] = resolvedSessionId;
        }
        if (message.sessionId == null && resolvedSessionId != null) {
          _patchSessionId(message.id, resolvedSessionId);
        }
      } else {
        final resolvedSessionId = message.sessionId ?? _currentSessionId;
        final resolved = _withSessionId(message, resolvedSessionId);
        _allMessages.add(resolved);
        if (resolvedSessionId != null) {
          _messageSessionMap[message.id] = resolvedSessionId;
        }
        if (message.sessionId == null && _currentSessionId != null) {
          _patchSessionId(message.id, _currentSessionId!);
        }
      }

      if (message.aiResponse != null && message.aiResponse!.isNotEmpty) {
        _isWaitingForResponse = false;
        _stopPolling();
      }
      notifyListeners();
    } catch (e) {
      print('Error handling message update: $e');
    }
  }

  /// Return a copy of [msg] with [sessionId] applied (only if different).
  ManagerChatMessage _withSessionId(
      ManagerChatMessage msg, String? sessionId) {
    if (msg.sessionId == sessionId) return msg;
    return ManagerChatMessage(
      id: msg.id,
      clientId: msg.clientId,
      userId: msg.userId,
      userName: msg.userName,
      userMessage: msg.userMessage,
      aiResponse: msg.aiResponse,
      createdAt: msg.createdAt,
      sessionId: sessionId,
    );
  }

  /// Patch the DB record so the session_id survives future full refreshes.
  Future<void> _patchSessionId(String messageId, String sessionId) async {
    try {
      // Skip patching temp IDs — they're not in the DB yet
      if (messageId.startsWith('temp_')) return;
      await SupabaseService.client
          .from(_managerChatsTable)
          .update({'session_id': sessionId})
          .eq('id', messageId);
      print('💬 Patched session_id=$sessionId on message $messageId');
    } catch (e) {
      print('Failed to patch session_id: $e');
    }
  }

  // ─── Loading ───────────────────────────────────────────────

  /// Full load — replaces all messages, sets current session to most recent
  Future<void> _loadAllMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _currentUserId;
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      print('💬 Loading all messages from: $_managerChatsTable for user: $userId');

      final response = await SupabaseService.client
          .from(_managerChatsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(500);

      _allMessages = (response as List).map((json) {
        final msg = ManagerChatMessage.fromJson(json);
        if (msg.sessionId != null) return msg;
        final cached = _messageSessionMap[msg.id];
        return cached != null ? _withSessionId(msg, cached) : msg;
      }).toList();

      print('💬 Loaded ${_allMessages.length} messages');

      // Auto-select most recent session
      if (_currentSessionId == null) {
        final allSessions = sessions;
        if (allSessions.isNotEmpty && !allSessions.first.isLegacy) {
          _currentSessionId = allSessions.first.id;
        } else if (allSessions.isNotEmpty) {
          // Only legacy messages — start a new session so user can continue fresh
          _currentSessionId = _generateSessionId();
        }
        // If no messages at all, _currentSessionId stays null until user sends first message
      }
    } catch (e) {
      print('Load messages error: $e');
      _error = 'Failed to load messages';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Silent refresh — fetches latest without showing loading spinner
  Future<void> _refreshMessages() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from(_managerChatsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(500);

      _allMessages = (response as List).map((json) {
        final msg = ManagerChatMessage.fromJson(json);
        if (msg.sessionId != null) return msg;
        final cached = _messageSessionMap[msg.id];
        return cached != null ? _withSessionId(msg, cached) : msg;
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Refresh messages error: $e');
    }
  }

  // ─── Sessions ──────────────────────────────────────────────

  /// Start a brand-new chat session
  void startNewSession() {
    _currentSessionId = _generateSessionId();
    _isWaitingForResponse = false;
    notifyListeners();
  }

  /// Switch to an existing session (or null for legacy)
  void switchToSession(String? sessionId) {
    _currentSessionId = sessionId;
    _isWaitingForResponse = false;
    notifyListeners();
  }

  // ─── Send Message ──────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Ensure we have a session ID before sending
    _currentSessionId ??= _generateSessionId();

    _isWaitingForResponse = true;
    notifyListeners();

    try {
      final webhookUrl = ClientConfig.managerChatWebhookUrl;
      if (webhookUrl == null || webhookUrl.isEmpty) {
        throw Exception('Manager chat webhook URL not configured');
      }

      final userId = _currentUserId ?? ClientConfig.currentUser?.id;
      final userName = ClientConfig.currentUser?.name ?? 'Unknown';

      // Optimistic message for instant UI feedback
      final optimisticMessage = ManagerChatMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        clientId: ClientConfig.currentClient?.id,
        userId: userId,
        userName: userName,
        userMessage: text,
        aiResponse: null,
        sessionId: _currentSessionId,
        createdAt: DateTime.now(),
      );
      _allMessages.add(optimisticMessage);
      notifyListeners();

      final payload = {
        'source': 'dashboard',
        'type': 'query',
        'body': {
          'record': {
            'id': optimisticMessage.id,
            'agent_id': _agentId,
            'manager_phone_number': _managerPhoneNumber,
            'message': text,
            'role': 'manager',
            'status': 'pending',
            'user_id': userId,
            'user_name': userName,
            'client_id': ClientConfig.currentClient?.id,
            'session_id': _currentSessionId,
          }
        },
        'timestamp': DateTime.now().toIso8601String(),
        'webhookUrl': webhookUrl,
        'executionMode': 'production',
      };

      print('💬 Calling webhook: $webhookUrl');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('💬 Webhook response: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await SupabaseService.instance.log(
          actionType: ActionType.messageSent,
          description: 'AI Chat: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}',
          metadata: {
            'message': text,
            'type': 'ai_chat',
            'session_id': _currentSessionId,
          },
        );
      } else {
        throw Exception('Webhook failed: ${response.body}');
      }

      _startPolling();
    } catch (e) {
      print('Send message error: $e');
      _error = 'Failed to send message';
      _isWaitingForResponse = false;
      notifyListeners();
    }
  }

  // ─── Polling fallback ──────────────────────────────────────

  void _startPolling() {
    _stopPolling();
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      attempts++;
      if (!_isWaitingForResponse || attempts > 10) {
        _stopPolling();
        if (_isWaitingForResponse) {
          _isWaitingForResponse = false;
          notifyListeners();
        }
        return;
      }
      await _pollForResponse();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollForResponse() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from(_managerChatsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(500);

      final freshMessages = (response as List)
          .map((json) => ManagerChatMessage.fromJson(json))
          .toList();

      // Check if AI has responded to any message we're waiting on
      bool hasNewResponse = false;
      for (final fresh in freshMessages) {
        if (fresh.aiResponse != null && fresh.aiResponse!.isNotEmpty) {
          final existing = _allMessages.where((m) =>
              m.id == fresh.id &&
              m.aiResponse != null &&
              m.aiResponse!.isNotEmpty);
          if (existing.isEmpty) {
            hasNewResponse = true;
            break;
          }
        }
      }

      if (hasNewResponse) {
        // Merge fresh DB records, preserving any in-memory session_id corrections
        for (final fresh in freshMessages) {
          final idx = _allMessages.indexWhere((m) =>
              m.id == fresh.id ||
              (m.id.startsWith('temp_') &&
                  m.userMessage == fresh.userMessage));
          if (idx != -1) {
            final existing = _allMessages[idx];
            final resolvedSessionId =
                fresh.sessionId ?? existing.sessionId ?? _messageSessionMap[fresh.id];
            _allMessages[idx] = _withSessionId(fresh, resolvedSessionId);
          } else {
            final resolvedSessionId =
                fresh.sessionId ?? _messageSessionMap[fresh.id] ?? _currentSessionId;
            _allMessages.add(_withSessionId(fresh, resolvedSessionId));
          }
        }
        _isWaitingForResponse = false;
        _stopPolling();
        notifyListeners();
      }
    } catch (e) {
      print('Poll for response error: $e');
    }
  }

  // ─── Utilities ─────────────────────────────────────────────

  /// Generate a UUID v4
  static String _generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Manual refresh (can be called from UI)
  Future<void> refresh() async {
    await _refreshMessages();
  }

  @override
  void dispose() {
    _stopPolling();
    _chatChannel?.unsubscribe();
    super.dispose();
  }
}
