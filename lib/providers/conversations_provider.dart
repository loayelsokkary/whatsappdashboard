import 'dart:async';
import 'package:flutter/foundation.dart';
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
  bool _isSending = false;

  StreamSubscription<List<RawExchange>>? _exchangesSubscription;

  // ============================================
  // GETTERS
  // ============================================

  List<Conversation> get conversations {
    var filtered = _conversations;

    if (_statusFilter != null) {
      filtered = filtered.where((c) => c.status == _statusFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) =>
          c.displayName.toLowerCase().contains(query) ||
          c.customerPhone.contains(query)).toList();
    }

    return filtered;
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
      // Customer message (skip empty)
      if (ex.customerMessage.trim().isNotEmpty) {
        result.add(Message(
          id: '${ex.id}_customer',
          content: ex.customerMessage,
          senderType: SenderType.customer,
          isOutbound: false,
          senderName: ex.customerName,
          createdAt: ex.createdAt,
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

      // Manager response (skip empty)
      if (ex.managerResponse != null && ex.managerResponse!.trim().isNotEmpty) {
        result.add(Message(
          id: '${ex.id}_manager',
          content: ex.managerResponse!,
          senderType: SenderType.manager,
          isOutbound: true,
          senderName: null,
          createdAt: ex.createdAt.add(const Duration(seconds: 2)),
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
  bool get isLoadingMessages => _isLoading;
  bool get isSending => _isSending;

  int get totalCount => _conversations.length;
  int get needsReplyCount => _conversations.where((c) => c.status == ConversationStatus.needsReply).length;
  int get repliedCount => _conversations.where((c) => c.status == ConversationStatus.replied).length;

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final service = SupabaseService.instance;
      _allExchanges = await service.fetchAllExchanges();
      _isConnected = true;
      _buildConversations();

      service.subscribeToExchanges();
      _exchangesSubscription = service.exchangesStream.listen((exchanges) {
        _allExchanges = exchanges;
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
      final hasCustomerMessage = lastEx.customerMessage.trim().isNotEmpty;
      final hasAiResponse = lastEx.aiResponse.trim().isNotEmpty;
      final hasManagerResponse = lastEx.managerResponse != null && 
                                  lastEx.managerResponse!.trim().isNotEmpty;
      
      final status = (hasCustomerMessage && !hasAiResponse && !hasManagerResponse)
          ? ConversationStatus.needsReply
          : ConversationStatus.replied;

      // Determine last message to show
      String lastMessage = lastEx.customerMessage;
      if (hasManagerResponse) {
        lastMessage = lastEx.managerResponse!;
      } else if (hasAiResponse) {
        lastMessage = lastEx.aiResponse;
      }

      return Conversation(
        customerPhone: customerPhone,
        customerName: customerName,
        lastMessage: lastMessage,
        lastMessageAt: lastEx.createdAt,
        status: status,
        unreadCount: status == ConversationStatus.needsReply ? 1 : 0,
        startedAt: firstEx.createdAt,
      );
    }).toList();

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

  // ============================================
  // SEND MESSAGE - OPTIMISTIC UPDATE
  // ============================================

  Future<bool> sendMessage(String conversationId, String text) async {
    if (_isSending || text.trim().isEmpty) return false;

    final customerPhone = conversationId;
    final trimmedText = text.trim();

    // Create pending message (shows immediately)
    final pendingId = 'pending_${customerPhone}_${DateTime.now().millisecondsSinceEpoch}';
    final pendingMessage = Message(
      id: pendingId,
      content: trimmedText,
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
  // DISPOSE
  // ============================================

  @override
  void dispose() {
    _exchangesSubscription?.cancel();
    super.dispose();
  }
}