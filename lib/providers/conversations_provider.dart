import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for managing conversations state
/// Exchanges from Supabase are expanded into messages for display
class ConversationsProvider extends ChangeNotifier {
  // ============================================
  // STATE
  // ============================================

  List<RawExchange> _allExchanges = [];
  List<Conversation> _conversations = [];
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;
  String _searchQuery = '';
  ConversationStatus? _statusFilter;
  bool _isSending = false;

  // Subscriptions
  StreamSubscription<List<RawExchange>>? _exchangesSubscription;

  // ============================================
  // GETTERS
  // ============================================

  /// All conversations (filtered)
  List<Conversation> get conversations {
    var filtered = _conversations;

    // Apply status filter
    if (_statusFilter != null) {
      filtered = filtered.where((c) => c.status == _statusFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) =>
          c.displayName.toLowerCase().contains(query) ||
          c.customerPhone.contains(query)).toList();
    }

    return filtered;
  }

  /// Currently selected conversation
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

  /// Messages for selected conversation
  /// Each exchange becomes 2 messages: customer then AI
  List<Message> get messages {
    if (_selectedCustomerPhone == null) return [];

    final customerExchanges = _allExchanges
        .where((ex) => ex.customerPhone == _selectedCustomerPhone)
        .toList();

    // Sort by time
    customerExchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Expand each exchange into 2 messages
    final List<Message> result = [];
    for (final ex in customerExchanges) {
      // Customer message
      result.add(Message(
        id: '${ex.id}_customer',
        content: ex.customerMessage,
        senderType: SenderType.customer,
        isOutbound: false,
        senderName: ex.customerName,
        createdAt: ex.createdAt,
      ));

      // AI/Agent response (slightly after customer message)
      result.add(Message(
        id: '${ex.id}_ai',
        content: ex.aiResponse,
        senderType: SenderType.ai,
        isOutbound: true,
        senderName: null,
        createdAt: ex.createdAt.add(const Duration(seconds: 1)),
      ));
    }

    return result;
  }

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  ConversationStatus? get statusFilter => _statusFilter;
  bool get isLoadingMessages => _isLoading;
  bool get isSending => _isSending;

  // Count getters
  int get totalCount => _conversations.length;
  int get needsReplyCount => _conversations.where((c) => c.status == ConversationStatus.needsReply).length;
  int get repliedCount => _conversations.where((c) => c.status == ConversationStatus.replied).length;

  // For compatibility with existing UI
  int get aiActiveCount => repliedCount;
  int get humanActiveCount => 0;
  int get awaitingHandoffCount => needsReplyCount;
  int get resolvedCount => 0;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Initialize and connect to Supabase
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final service = SupabaseService.instance;

      // Fetch all exchanges
      _allExchanges = await service.fetchAllExchanges();
      _isConnected = true;

      // Build conversations from exchanges
      _buildConversations();

      // Subscribe to real-time updates
      service.subscribeToExchanges();
      _exchangesSubscription = service.exchangesStream.listen((exchanges) {
        _allExchanges = exchanges;
        _buildConversations();
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

  /// Refresh exchanges
  Future<void> fetchConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = SupabaseService.instance;
      _allExchanges = await service.fetchAllExchanges();
      _isConnected = true;
      _buildConversations();
    } catch (e) {
      _error = 'Failed to fetch: $e';
      _isConnected = false;
      print('Fetch error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================
  // CONVERSATION BUILDING LOGIC
  // ============================================

  /// Build conversations from raw exchanges
  void _buildConversations() {
    // Group exchanges by customer phone
    final Map<String, List<RawExchange>> grouped = {};

    for (final ex in _allExchanges) {
      grouped.putIfAbsent(ex.customerPhone, () => []);
      grouped[ex.customerPhone]!.add(ex);
    }

    // Convert to conversations
    _conversations = grouped.entries.map((entry) {
      final customerPhone = entry.key;
      final exchanges = entry.value;

      // Sort by time
      exchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final firstEx = exchanges.first;
      final lastEx = exchanges.last;

      // Get customer name from any exchange
      String? customerName;
      for (final ex in exchanges) {
        if (ex.customerName != null) {
          customerName = ex.customerName;
          break;
        }
      }

      // Status: All exchanges have AI responses, so always "replied"
      const status = ConversationStatus.replied;

      return Conversation(
        customerPhone: customerPhone,
        customerName: customerName,
        lastMessage: lastEx.aiResponse,
        lastMessageAt: lastEx.createdAt,
        status: status,
        unreadCount: 0,
        startedAt: firstEx.createdAt,
      );
    }).toList();

    // Sort by last message time (newest first)
    _conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    print('Built ${_conversations.length} conversations from ${_allExchanges.length} exchanges');
  }

  // ============================================
  // SELECTION
  // ============================================

  /// Select a conversation
  Future<void> selectConversation(Conversation conversation) async {
    _selectedCustomerPhone = conversation.customerPhone;
    _selectedCustomerName = conversation.customerName;

    // Mark as read (reset unread count locally)
    final index = _conversations.indexWhere((c) => c.customerPhone == conversation.customerPhone);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    }

    notifyListeners();
  }

  /// Clear selection
  void clearSelection() {
    _selectedCustomerPhone = null;
    _selectedCustomerName = null;
    notifyListeners();
  }

  // ============================================
  // FILTERS
  // ============================================

  /// Set status filter
  void setStatusFilter(ConversationStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ============================================
  // SEND MESSAGE (HUMAN HANDOVER)
  // ============================================

  /// Send a message from the dashboard to the customer
  /// This calls n8n webhook which sends WhatsApp AND saves to Supabase
  Future<bool> sendMessage(String conversationId, String text) async {
    if (_isSending) return false;
    
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final service = SupabaseService.instance;

      // conversationId is the customer phone
      final customerPhone = conversationId;

      // Send via n8n webhook (sends WhatsApp + saves to Supabase)
      final success = await service.sendMessageViaWebhook(
        customerPhone: customerPhone,
        message: text,
        customerName: _selectedCustomerName,
      );

      if (success) {
        print('Message sent to $customerPhone: $text');
        
        // The real-time subscription will pick up the new message
        // But we can also force a refresh
        await Future.delayed(const Duration(milliseconds: 500));
        await fetchConversations();
      } else {
        _error = 'Failed to send message';
      }

      _isSending = false;
      notifyListeners();
      return success;

    } catch (e) {
      _error = 'Failed to send message: $e';
      print('Send message error: $e');
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // TAKEOVER (for UI compatibility)
  // ============================================

  Future<bool> takeOverConversation(String conversationId) async {
    print('Manager taking over conversation: $conversationId');
    // In this simplified model, manager just starts typing
    // The webhook handles sending to WhatsApp
    return true;
  }

  Future<bool> releaseConversation(String conversationId, {String? notes}) async {
    print('Releasing conversation: $conversationId');
    // AI will automatically respond to next customer message
    return true;
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