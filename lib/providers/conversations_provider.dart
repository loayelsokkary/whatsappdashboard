import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for managing conversations state
class ConversationsProvider extends ChangeNotifier {
  // ============================================
  // STATE
  // ============================================

  List<RawExchange> _allExchanges = [];
  List<Conversation> _conversations = [];
  List<Message> _pendingMessages = []; // For optimistic updates
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;
  String _searchQuery = '';
  ConversationStatus? _statusFilter;
  String? _labelFilter;
  bool _isSending = false;
  bool _soundEnabled = true;
  bool _browserNotificationsEnabled = false;
  Set<String> _knownExchangeIds = {};
  bool _initialLoadDone = false;

  StreamSubscription<List<RawExchange>>? _exchangesSubscription;

  // ============================================
  // GETTERS
  // ============================================

  List<Conversation> get conversations {
    var filtered = _conversations;

    if (_statusFilter != null) {
      filtered = filtered.where((c) => c.status == _statusFilter).toList();
    }

    if (_labelFilter != null) {
      filtered = filtered.where((c) => c.label == _labelFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) =>
          c.displayName.toLowerCase().contains(query) ||
          c.customerPhone.contains(query)).toList();
    }

    return filtered;
  }

  /// All unique labels across conversations (for filter UI)
  List<String> get availableLabels {
    final labels = _conversations
        .where((c) => c.label != null && c.label!.isNotEmpty)
        .map((c) => c.label!)
        .toSet()
        .toList();
    labels.sort();
    return labels;
  }

  Conversation? get selectedConversation {
    if (_selectedCustomerPhone == null) return null;
    try {
      return _conversations.firstWhere(
        (c) => c.customerPhone == _selectedCustomerPhone,
      );
    } catch (e) {
      return null;
    }
  }

  /// Messages with pending (optimistic) messages included
  List<Message> get messages {
    if (_selectedCustomerPhone == null) return [];

    final customerExchanges = _allExchanges
        .where((ex) => ex.customerPhone == _selectedCustomerPhone)
        .toList();

    customerExchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final List<Message> result = [];
    for (final ex in customerExchanges) {
      // Determine if this is a manager-initiated exchange (no customer input)
      // Media attribution relies on null vs empty string for managerResponse:
      //   - null: no manager involved → media is from the customer
      //   - '' (empty string): manager responded with no text (e.g. photo only) → media is from manager
      final bool hasManagerResponse = ex.managerResponse != null;
      final bool isManagerInitiated = ex.customerMessage.trim().isEmpty && !ex.isVoiceMessage && hasManagerResponse;
      final bool mediaIsFromManager = ex.hasMedia && isManagerInitiated;

      // Customer message - check for voice, text, or media
      if (ex.isVoiceMessage) {
        // Voice message (transcribed) - media always from customer
        result.add(Message(
          id: '${ex.id}_customer',
          content: ex.voiceResponse!,
          senderType: SenderType.customer,
          isOutbound: false,
          senderName: ex.customerName,
          createdAt: ex.createdAt,
          isVoiceMessage: true,
          label: ex.label,
          mediaUrl: ex.mediaUrl,
          mediaType: ex.mediaType,
          mediaFilename: ex.mediaFilename,
        ));
      } else if (ex.customerMessage.trim().isNotEmpty || (ex.hasMedia && !mediaIsFromManager)) {
        // Regular text message or customer media message
        result.add(Message(
          id: '${ex.id}_customer',
          content: ex.customerMessage,
          senderType: SenderType.customer,
          isOutbound: false,
          senderName: ex.customerName,
          createdAt: ex.createdAt,
          isVoiceMessage: false,
          label: ex.label,
          mediaUrl: mediaIsFromManager ? null : ex.mediaUrl,
          mediaType: mediaIsFromManager ? null : ex.mediaType,
          mediaFilename: mediaIsFromManager ? null : ex.mediaFilename,
        ));
      }

      // AI response (skip empty)
      if (ex.aiResponse.trim().isNotEmpty) {
        result.add(Message(
          id: '${ex.id}_ai',
          content: ex.aiResponse,
          senderType: SenderType.ai,
          isOutbound: true,
          senderName: null,
          createdAt: ex.createdAt.add(const Duration(seconds: 1)),
        ));
      }

      // Manager response (show if has text OR if has manager-sent media)
      if ((ex.managerResponse != null && ex.managerResponse!.trim().isNotEmpty) || mediaIsFromManager) {
        result.add(Message(
          id: '${ex.id}_manager',
          content: ex.managerResponse?.trim().isNotEmpty == true ? ex.managerResponse! : '',
          senderType: SenderType.manager,
          isOutbound: true,
          senderName: null,
          createdAt: ex.createdAt.add(const Duration(seconds: 2)),
          mediaUrl: mediaIsFromManager ? ex.mediaUrl : null,
          mediaType: mediaIsFromManager ? ex.mediaType : null,
          mediaFilename: mediaIsFromManager ? ex.mediaFilename : null,
        ));
      }
    }

    // Add pending messages for this conversation (only if no matching real message exists)
    final pending = _pendingMessages
        .where((m) => m.id.startsWith('pending_$_selectedCustomerPhone'))
        .where((pending) {
          // Check if this pending message already has a matching real message
          for (final ex in customerExchanges) {
            if (ex.managerResponse != null && 
                ex.managerResponse!.trim() == pending.content.trim()) {
              return false; // Real message exists, don't show pending
            }
          }
          return true; // No matching real message, show pending
        })
        .toList();
    result.addAll(pending);

    return result;
  }

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  ConversationStatus? get statusFilter => _statusFilter;
  String? get labelFilter => _labelFilter;
  bool get isLoadingMessages => _isLoading;
  bool get isSending => _isSending;

  int get totalCount => _conversations.length;
  int get needsReplyCount => _conversations.where((c) => c.status == ConversationStatus.needsReply).length;
  int get repliedCount => _conversations.where((c) => c.status == ConversationStatus.replied).length;
  int get totalUnreadCount => _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  bool get soundEnabled => _soundEnabled;

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Request browser notification permission
    _requestNotificationPermission();

    try {
      final service = SupabaseService.instance;
      _allExchanges = await service.fetchAllExchanges();
      _isConnected = true;
      _knownExchangeIds = _allExchanges.map((e) => e.id).toSet();
      _initialLoadDone = true;
      _buildConversations();

      service.subscribeToExchanges();
      _exchangesSubscription = service.exchangesStream.listen((exchanges) {
        final previousIds = _knownExchangeIds;
        _allExchanges = exchanges;
        _knownExchangeIds = exchanges.map((e) => e.id).toSet();

        // Detect new customer messages (only after initial load)
        if (_initialLoadDone) {
          final newIds = _knownExchangeIds.difference(previousIds);
          for (final newId in newIds) {
            try {
              final exchange = exchanges.firstWhere((e) => e.id == newId);
              final hasCustomerMsg = exchange.customerMessage.trim().isNotEmpty || exchange.isVoiceMessage;
              final isSelected = exchange.customerPhone == _selectedCustomerPhone;
              if (hasCustomerMsg && !isSelected) {
                _triggerNewMessageNotification(exchange);
              }
            } catch (_) {}
          }
        }

        _buildConversations();
        _clearOldPendingMessages();
        notifyListeners();
      });

    } catch (e) {
      _error = 'Failed to connect: $e';
      _isConnected = false;
      print('Initialize error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = SupabaseService.instance;
      _allExchanges = await service.fetchAllExchanges();
      _isConnected = true;
      _buildConversations();
      _clearOldPendingMessages();
    } catch (e) {
      _error = 'Failed to fetch: $e';
      _isConnected = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================
  // BUILD CONVERSATIONS
  // ============================================

  void _buildConversations() {
    final Map<String, List<RawExchange>> grouped = {};

    for (final ex in _allExchanges) {
      grouped.putIfAbsent(ex.customerPhone, () => []);
      grouped[ex.customerPhone]!.add(ex);
    }

    _conversations = grouped.entries.map((entry) {
      final customerPhone = entry.key;
      final exchanges = entry.value;

      exchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final firstEx = exchanges.first;
      final lastEx = exchanges.last;

      String? customerName;
      for (final ex in exchanges) {
        if (ex.customerName != null && ex.customerName!.isNotEmpty) {
          customerName = ex.customerName;
          break;
        }
      }

      // Determine status based on last exchange
      // "Needs Reply" if customer sent message but no AI or manager response
      final hasCustomerMessage = lastEx.customerMessage.trim().isNotEmpty || lastEx.isVoiceMessage;
      final hasAiResponse = lastEx.aiResponse.trim().isNotEmpty;
      final hasManagerResponse = lastEx.managerResponse != null && 
                                  lastEx.managerResponse!.trim().isNotEmpty;
      
      // Check if AI response is just a handoff message (doesn't count as real reply)
      final isHandoffMessage = hasAiResponse && _isHandoffMessage(lastEx.aiResponse);
      final hasRealAiResponse = hasAiResponse && !isHandoffMessage;
      
      final status = (hasCustomerMessage && !hasRealAiResponse && !hasManagerResponse)
          ? ConversationStatus.needsReply
          : ConversationStatus.replied;

      // Determine last message to show (use customerInput to handle voice messages)
      String lastMessage = lastEx.customerInput;
      if (hasManagerResponse) {
        lastMessage = lastEx.managerResponse!;
      } else if (hasAiResponse) {
        lastMessage = lastEx.aiResponse;
      }

      // Get the most recent label (from latest exchange with a label)
      String? label;
      for (int i = exchanges.length - 1; i >= 0; i--) {
        if (exchanges[i].label != null && exchanges[i].label!.isNotEmpty) {
          label = exchanges[i].label;
          break;
        }
      }

      // Count consecutive unread exchanges from the end
      int unread = 0;
      if (status == ConversationStatus.needsReply) {
        for (int i = exchanges.length - 1; i >= 0; i--) {
          final ex = exchanges[i];
          final hasCust = ex.customerMessage.trim().isNotEmpty || ex.isVoiceMessage;
          final hasAi = ex.aiResponse.trim().isNotEmpty && !_isHandoffMessage(ex.aiResponse);
          final hasMgr = ex.managerResponse != null && ex.managerResponse!.trim().isNotEmpty;
          if (hasCust && !hasAi && !hasMgr) {
            unread++;
          } else {
            break;
          }
        }
      }

      return Conversation(
        customerPhone: customerPhone,
        customerName: customerName,
        lastMessage: lastMessage,
        lastMessageAt: lastEx.createdAt,
        status: status,
        unreadCount: unread,
        startedAt: firstEx.createdAt,
        label: label,
      );
    }).toList();

    // Reset unread count for the currently selected conversation
    if (_selectedCustomerPhone != null) {
      final idx = _conversations.indexWhere(
          (c) => c.customerPhone == _selectedCustomerPhone);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      }
    }

    _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    print('Built ${_conversations.length} conversations');
  }

  void _clearOldPendingMessages() {
    final now = DateTime.now();
    
    // Remove pending messages that are older than 30 seconds (timeout)
    _pendingMessages.removeWhere((msg) => 
        now.difference(msg.createdAt).inSeconds > 30);
    
    // Remove pending messages that now have matching real messages
    // (real message arrived via real-time subscription)
    _pendingMessages.removeWhere((pending) {
      final phone = pending.id.split('_')[1]; // Extract phone from pending_PHONE_timestamp
      
      // Find exchanges for this customer
      final customerExchanges = _allExchanges.where((ex) => ex.customerPhone == phone);
      
      // Check if any exchange has a manager_response matching our pending content
      for (final ex in customerExchanges) {
        if (ex.managerResponse != null && 
            ex.managerResponse!.trim() == pending.content.trim()) {
          // Real message exists, remove pending
          return true;
        }
      }
      return false;
    });
  }

  // ============================================
  // SELECTION
  // ============================================

  Future<void> selectConversation(Conversation conversation) async {
    _selectedCustomerPhone = conversation.customerPhone;
    _selectedCustomerName = conversation.customerName;

    final index = _conversations.indexWhere(
        (c) => c.customerPhone == conversation.customerPhone);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    }

    notifyListeners();
  }

  void clearSelection() {
    _selectedCustomerPhone = null;
    _selectedCustomerName = null;
    notifyListeners();
  }

  // ============================================
  // FILTERS
  // ============================================

  void setStatusFilter(ConversationStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setLabelFilter(String? label) {
    _labelFilter = label;
    notifyListeners();
  }

  // ============================================
  // MEDIA UPLOAD
  // ============================================

  Future<String?> uploadMedia(Uint8List bytes, String filename) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final slug = ClientConfig.currentClient?.slug ?? 'uploads';
      final path = '$slug/${timestamp}_$filename';

      // Determine content type from extension to avoid dart:io Platform detection on web
      final ext = filename.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

      await SupabaseService.client.storage
          .from('media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      final url = SupabaseService.client.storage
          .from('media')
          .getPublicUrl(path);

      debugPrint('Uploaded media: $url');
      return url;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // ============================================
  // SEND MESSAGE - OPTIMISTIC UPDATE
  // ============================================

  Future<bool> sendMessage(
    String conversationId,
    String text, {
    String? mediaUrl,
    String? mediaType,
    String? mediaFilename,
  }) async {
    if (_isSending) return false;
    if (text.trim().isEmpty && mediaUrl == null) return false;

    final customerPhone = conversationId;
    final trimmedText = text.trim();

    // Create pending message (shows immediately)
    final pendingId = 'pending_${customerPhone}_${DateTime.now().millisecondsSinceEpoch}';
    final pendingContent = mediaUrl != null && trimmedText.isEmpty
        ? (mediaFilename ?? 'Media')
        : trimmedText;
    final pendingMessage = Message(
      id: pendingId,
      content: pendingContent,
      senderType: SenderType.manager,
      isOutbound: true,
      senderName: null,
      createdAt: DateTime.now(),
    );

    _pendingMessages.add(pendingMessage);
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final service = SupabaseService.instance;

      final success = await service.sendMessageViaWebhook(
        customerPhone: customerPhone,
        message: trimmedText,
        customerName: _selectedCustomerName,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        mediaFilename: mediaFilename,
      );

      // DON'T remove pending message here!
      // Real-time subscription will bring the actual message
      // and _removePendingIfExists() will handle the swap

      if (!success) {
        // Only remove on failure
        _pendingMessages.removeWhere((m) => m.id == pendingId);
        _error = 'Failed to send message';
      }

      _isSending = false;
      notifyListeners();
      return success;

    } catch (e) {
      _pendingMessages.removeWhere((m) => m.id == pendingId);
      _error = 'Failed to send: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // NOTIFICATIONS
  // ============================================

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  void _requestNotificationPermission() {
    try {
      final permission = web.Notification.permission;
      if (permission == 'granted') {
        _browserNotificationsEnabled = true;
      } else if (permission != 'denied') {
        web.Notification.requestPermission().toDart.then((result) {
          _browserNotificationsEnabled = result.toDart == 'granted';
          print('Browser notification permission: $_browserNotificationsEnabled');
        });
      }
    } catch (e) {
      print('Notification permission error: $e');
    }
  }

  void _triggerNewMessageNotification(RawExchange exchange) {
    final name = exchange.customerName ?? exchange.customerPhone;
    final message = exchange.isVoiceMessage
        ? (exchange.voiceResponse ?? 'Voice message')
        : exchange.customerMessage;

    // Play notification sound
    if (_soundEnabled) {
      _playNotificationSound();
    }

    // Show browser notification
    if (_browserNotificationsEnabled) {
      _showBrowserNotification(name, message);
    }
  }

  void _playNotificationSound() {
    try {
      final context = web.AudioContext();
      final oscillator = context.createOscillator();
      final gainNode = context.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(context.destination);

      oscillator.type = 'sine';
      oscillator.frequency.value = 880;
      gainNode.gain.value = 0.2;

      oscillator.start();
      oscillator.stop(context.currentTime + 0.15);

      // Second tone after short pause
      final osc2 = context.createOscillator();
      final gain2 = context.createGain();
      osc2.connect(gain2);
      gain2.connect(context.destination);
      osc2.type = 'sine';
      osc2.frequency.value = 1100;
      gain2.gain.value = 0.2;
      osc2.start(context.currentTime + 0.2);
      osc2.stop(context.currentTime + 0.35);
    } catch (e) {
      print('Sound error: $e');
    }
  }

  void _showBrowserNotification(String name, String message) {
    try {
      final truncated = message.length > 100 ? '${message.substring(0, 100)}...' : message;
      web.Notification(
        'New message from $name',
        web.NotificationOptions(body: truncated),
      );
    } catch (e) {
      print('Browser notification error: $e');
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Check if a message is an automated handoff message (manager takeover)
  bool _isHandoffMessage(String message) {
    final lowerMessage = message.toLowerCase().trim();
    
    // English handoff phrases
    if (lowerMessage.contains('manager will be with you shortly')) return true;
    if (lowerMessage.contains('the manager will be with you')) return true;
    
    // Arabic handoff phrases
    if (message.contains('المدير سيكون معك')) return true;
    
    return false;
  }

  // ============================================
  // DISPOSE
  // ============================================

  @override
  void dispose() {
    _exchangesSubscription?.cancel();
    super.dispose();
  }
}
