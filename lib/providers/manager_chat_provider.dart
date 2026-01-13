import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/supabase_service.dart';
import '../models/models.dart';

/// Message model for manager chat
class ManagerChatMessage {
  final String id;
  final String agentId;
  final String managerPhoneNumber;
  final String message;
  final String role; // 'manager' or 'assistant'
  final String status; // 'pending' or 'processed'
  final DateTime createdAt;

  ManagerChatMessage({
    required this.id,
    required this.agentId,
    required this.managerPhoneNumber,
    required this.message,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory ManagerChatMessage.fromJson(Map<String, dynamic> json) {
    return ManagerChatMessage(
      id: json['id'] as String,
      agentId: json['agent_id'] as String,
      managerPhoneNumber: json['manager_phone_number'] as String,
      message: json['message'] as String,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isUser => role == 'manager';
  bool get isAssistant => role == 'assistant';
  bool get isPending => status == 'pending';
}

/// Provider for manager AI chat functionality
class ManagerChatProvider extends ChangeNotifier {
  List<ManagerChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isWaitingForResponse = false;
  String? _error;
  RealtimeChannel? _channel;
  
  // Configuration
  String? _agentId;
  String? _managerPhoneNumber;

  List<ManagerChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isWaitingForResponse => _isWaitingForResponse;
  String? get error => _error;

  /// Initialize the chat for a specific agent/manager
  Future<void> initialize({
    required String agentId,
    required String managerPhoneNumber,
  }) async {
    _agentId = agentId;
    _managerPhoneNumber = managerPhoneNumber;
    
    await _loadChatHistory();
    _subscribeToResponses();
  }

  /// Load existing chat history from Supabase
  Future<void> _loadChatHistory() async {
    if (_agentId == null || _managerPhoneNumber == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      
      final response = await supabase
          .from('manager_chats')
          .select()
          .eq('agent_id', _agentId!)
          .eq('manager_phone_number', _managerPhoneNumber!)
          .order('created_at', ascending: true);

      _messages = (response as List)
          .map((json) => ManagerChatMessage.fromJson(json))
          .toList();

      print('📱 Loaded ${_messages.length} chat messages');
    } catch (e) {
      _error = 'Failed to load chat history: $e';
      print('Error loading chat history: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Subscribe to real-time updates for assistant responses
  void _subscribeToResponses() {
    if (_agentId == null || _managerPhoneNumber == null) return;

    _channel?.unsubscribe();

    final supabase = SupabaseService.client;

    _channel = supabase
        .channel('manager_chat_${_agentId}_$_managerPhoneNumber')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'manager_chats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'manager_phone_number',
            value: _managerPhoneNumber!,
          ),
          callback: (payload) {
            print('📱 Real-time chat update received');
            _handleNewMessage(payload.newRecord);
          },
        )
        .subscribe();

    print('📱 Subscribed to manager chat updates');
  }

  /// Handle incoming real-time message
  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final message = ManagerChatMessage.fromJson(data);
      
      // Only add if not already in list (avoid duplicates)
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
        
        // If it's an assistant response, stop waiting and cancel timeout
        if (message.isAssistant) {
          _isWaitingForResponse = false;
          _responseTimeoutTimer?.cancel();
          _responseTimeoutTimer = null;
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error handling new message: $e');
    }
  }

  // Timeout timer for AI response
  Timer? _responseTimeoutTimer;

  /// Send a message from the manager
  Future<bool> sendMessage(String text) async {
    if (_agentId == null || _managerPhoneNumber == null) {
      _error = 'Chat not initialized';
      notifyListeners();
      return false;
    }

    if (text.trim().isEmpty) return false;

    _isWaitingForResponse = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = SupabaseService.client;

      // Insert the manager's message
      final response = await supabase
          .from('manager_chats')
          .insert({
            'agent_id': _agentId,
            'manager_phone_number': _managerPhoneNumber,
            'message': text.trim(),
            'role': 'manager',
            'status': 'pending',
          })
          .select()
          .single();

      // Add to local list immediately for instant UI feedback
      final message = ManagerChatMessage.fromJson(response);
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
        notifyListeners();
      }

      // Call the webhook to trigger AI processing
      final webhookUrl = ClientConfig.webhookUrl;
      if (webhookUrl.isNotEmpty) {
        final payload = {
          'source': 'dashboard',
          'type': 'query',
          'body': {
            'record': {
              'id': message.id,
              'agent_id': _agentId,
              'manager_phone_number': _managerPhoneNumber,
              'message': text.trim(),
              'role': 'manager',
              'status': 'pending',
            }
          },
          'timestamp': DateTime.now().toIso8601String(),
        };

        print('📱 Calling webhook: $webhookUrl');
        
        // Fire and forget - don't wait for response
        http.post(
          Uri.parse(webhookUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).then((res) {
          print('📱 Webhook response: ${res.statusCode}');
        }).catchError((e) {
          print('📱 Webhook error: $e');
        });
      }

      // Start timeout timer - if no response in 30 seconds, show error
      _responseTimeoutTimer?.cancel();
      _responseTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_isWaitingForResponse) {
          _isWaitingForResponse = false;
          _error = 'Response timed out. Please try again.';
          notifyListeners();
        }
      });

      print('📱 Sent message, waiting for AI response...');
      return true;
    } catch (e) {
      _error = 'Failed to send message: $e';
      _isWaitingForResponse = false;
      print('Error sending message: $e');
      notifyListeners();
      return false;
    }
  }

  /// Clear chat history (local only, doesn't delete from DB)
  void clearLocalHistory() {
    _messages.clear();
    notifyListeners();
  }

  /// Refresh chat history from database
  Future<void> refresh() async {
    await _loadChatHistory();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _responseTimeoutTimer?.cancel();
    super.dispose();
  }
}