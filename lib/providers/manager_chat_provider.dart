import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

/// Manager chat message model - matches new schema
class ManagerChatMessage {
  final String id;
  final String? clientId;
  final String? userId;
  final String? userName;
  final String? userMessage;
  final String? aiResponse;
  final DateTime createdAt;

  const ManagerChatMessage({
    required this.id,
    this.clientId,
    this.userId,
    this.userName,
    this.userMessage,
    this.aiResponse,
    required this.createdAt,
  });

  factory ManagerChatMessage.fromJson(Map<String, dynamic> json) {
    return ManagerChatMessage(
      id: json['id'] as String,
      clientId: json['client_id'] as String?,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      userMessage: json['user_message'] as String?,
      aiResponse: json['ai_response'] as String?,
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
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Provider for manager chat with AI
class ManagerChatProvider extends ChangeNotifier {
  List<ManagerChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isWaitingForResponse = false;
  String? _error;
  
  String _agentId = '';
  String _managerPhoneNumber = '';
  String? _currentUserId;

  RealtimeChannel? _chatChannel;
  Timer? _pollTimer;

  List<ManagerChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isWaitingForResponse => _isWaitingForResponse;
  String? get error => _error;

  /// Get dynamic table name from ClientConfig
  String get _managerChatsTable {
    final slug = ClientConfig.currentClient?.slug;
    if (slug != null && slug.isNotEmpty) {
      return '${slug}_manager_chats';
    }
    return 'manager_chats';
  }

  /// Initialize the chat
  void initialize({
    required String agentId,
    required String managerPhoneNumber,
  }) {
    _agentId = agentId;
    _managerPhoneNumber = managerPhoneNumber;
    _currentUserId = ClientConfig.currentUser?.id;
    
    print('💬 Initializing chat for user: $_currentUserId');
    
    _loadMessages();
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
            print('💬 New manager chat message received for user');
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

  /// Handle new message from realtime
  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final message = ManagerChatMessage.fromJson(data);

      // Only add if it's for the current user
      if (message.userId != _currentUserId) return;

      // Check if message already exists (or is temp message)
      final existingIndex = _messages.indexWhere((m) =>
        m.id == message.id ||
        (m.id.startsWith('temp_') && m.userMessage == message.userMessage)
      );

      if (existingIndex != -1) {
        // Replace temp message with real one
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }

      // Only clear waiting when AI has actually responded
      if (message.aiResponse != null && message.aiResponse!.isNotEmpty) {
        _isWaitingForResponse = false;
        _stopPolling();
      }
      notifyListeners();
    } catch (e) {
      print('Error handling new message: $e');
    }
  }

  /// Handle message update from realtime
  void _handleMessageUpdate(Map<String, dynamic> data) {
    try {
      final message = ManagerChatMessage.fromJson(data);

      // Only update if it's for the current user
      if (message.userId != _currentUserId) return;

      // Try to find by actual ID first
      var index = _messages.indexWhere((m) => m.id == message.id);

      // If not found, try matching temp message by content
      if (index == -1) {
        index = _messages.indexWhere((m) =>
          m.id.startsWith('temp_') && m.userMessage == message.userMessage
        );
      }

      if (index != -1) {
        _messages[index] = message;
      } else {
        // INSERT was missed — add the message so it still appears
        _messages.add(message);
      }

      // Clear waiting when AI has responded
      if (message.aiResponse != null && message.aiResponse!.isNotEmpty) {
        _isWaitingForResponse = false;
        _stopPolling();
      }
      notifyListeners();
    } catch (e) {
      print('Error handling message update: $e');
    }
  }

  /// Load existing messages for current user only
  Future<void> _loadMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _currentUserId;
      if (userId == null) {
        print('💬 No user ID, cannot load messages');
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      print('💬 Loading messages from: $_managerChatsTable for user: $userId');
      
      final response = await SupabaseService.client
          .from(_managerChatsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(100);

      _messages = (response as List)
          .map((json) => ManagerChatMessage.fromJson(json))
          .toList();

      print('💬 Loaded ${_messages.length} chat messages for user: $userId');
    } catch (e) {
      print('Load messages error: $e');
      _error = 'Failed to load messages';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Send a message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _isWaitingForResponse = true;
    notifyListeners();

    try {
      final webhookUrl = ClientConfig.managerChatWebhookUrl;
      if (webhookUrl == null || webhookUrl.isEmpty) {
        throw Exception('Manager chat webhook URL not configured');
      }

      final userId = _currentUserId ?? ClientConfig.currentUser?.id;
      final userName = ClientConfig.currentUser?.name ?? 'Unknown';

      // Create optimistic message
      final optimisticMessage = ManagerChatMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        clientId: ClientConfig.currentClient?.id,
        userId: userId,
        userName: userName,
        userMessage: text,
        aiResponse: null,
        createdAt: DateTime.now(),
      );
      _messages.add(optimisticMessage);
      notifyListeners();

      // Send to webhook with user info
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
          }
        },
        'timestamp': DateTime.now().toIso8601String(),
        'webhookUrl': webhookUrl,
        'executionMode': 'production',
      };

      print('💬 Calling webhook: $webhookUrl');
      print('💬 Payload: $payload');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('💬 Webhook response: ${response.statusCode}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Log the AI chat message
        await SupabaseService.instance.log(
          actionType: ActionType.messageSent,
          description: 'AI Chat: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}',
          metadata: {
            'message': text,
            'type': 'ai_chat',
          },
        );
      } else {
        throw Exception('Webhook failed: ${response.body}');
      }

      // Response will come via realtime subscription
      // Start polling as fallback in case realtime misses the update
      _startPolling();

    } catch (e) {
      print('Send message error: $e');
      _error = 'Failed to send message';
      _isWaitingForResponse = false;
      notifyListeners();
    }
  }

  // ============================================
  // POLLING FALLBACK
  // ============================================

  /// Start polling as fallback for when realtime misses events
  void _startPolling() {
    _stopPolling();
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      attempts++;
      if (!_isWaitingForResponse || attempts > 10) {
        _stopPolling();
        if (_isWaitingForResponse) {
          // Timed out after ~30s
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

  /// Fetch latest messages and check if AI has responded
  Future<void> _pollForResponse() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await SupabaseService.client
          .from(_managerChatsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(100);

      final freshMessages = (response as List)
          .map((json) => ManagerChatMessage.fromJson(json))
          .toList();

      // Check if any new message has an AI response we don't have yet
      bool hasNewResponse = false;
      for (final fresh in freshMessages) {
        if (fresh.aiResponse != null && fresh.aiResponse!.isNotEmpty) {
          final existing = _messages.where((m) =>
            m.id == fresh.id &&
            m.aiResponse != null &&
            m.aiResponse!.isNotEmpty
          );
          if (existing.isEmpty) {
            hasNewResponse = true;
            break;
          }
        }
      }

      if (hasNewResponse) {
        _messages = freshMessages;
        _isWaitingForResponse = false;
        _stopPolling();
        notifyListeners();
      }
    } catch (e) {
      print('Poll for response error: $e');
    }
  }

  /// Clear chat history (local only)
  void clearChat() {
    _messages = [];
    notifyListeners();
  }

  /// Reload messages (useful when switching back to chat)
  Future<void> refresh() async {
    await _loadMessages();
  }

  @override
  void dispose() {
    _stopPolling();
    _chatChannel?.unsubscribe();
    super.dispose();
  }
}