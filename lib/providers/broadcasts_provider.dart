import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

/// Broadcast campaign model
class Broadcast {
  final String id;
  final String clientId;
  final String? campaignName;
  final String? messageContent;
  final DateTime sentAt;
  final int totalRecipients;

  const Broadcast({
    required this.id,
    required this.clientId,
    this.campaignName,
    this.messageContent,
    required this.sentAt,
    required this.totalRecipients,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      campaignName: json['campaign_name'] as String?,
      messageContent: json['message_content'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
      totalRecipients: json['total_recipients'] as int? ?? 0,
    );
  }
}

/// Broadcast recipient model
class BroadcastRecipient {
  final String id;
  final String broadcastId;
  final String? customerPhone;
  final String? customerName;
  final String status;
  final DateTime sentAt;

  const BroadcastRecipient({
    required this.id,
    required this.broadcastId,
    this.customerPhone,
    this.customerName,
    required this.status,
    required this.sentAt,
  });

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) {
    return BroadcastRecipient(
      id: json['id'] as String,
      broadcastId: json['broadcast_id'] as String,
      customerPhone: json['customer_phone'] as String?,
      customerName: json['customer_name'] as String?,
      status: json['status'] as String? ?? 'sent',
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }

  String get displayName => customerName ?? customerPhone ?? 'Unknown';

  Color get statusColor {
    switch (status) {
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'read':
        return const Color(0xFF2196F3);
      case 'failed':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFF9800);
    }
  }
}

/// Provider for managing broadcast campaigns
class BroadcastsProvider extends ChangeNotifier {
  List<Broadcast> _broadcasts = [];
  List<BroadcastRecipient> _recipients = [];
  Broadcast? _selectedBroadcast;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  String? _sendError;
  
  // Realtime subscriptions
  RealtimeChannel? _broadcastsChannel;
  RealtimeChannel? _recipientsChannel;

  // Getters
  List<Broadcast> get broadcasts => _broadcasts;
  List<BroadcastRecipient> get recipients => _recipients;
  Broadcast? get selectedBroadcast => _selectedBroadcast;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get sendError => _sendError;

  /// Initialize realtime subscriptions
  void initialize() {
    _subscribeToBroadcasts();
  }

  /// Subscribe to realtime broadcasts updates
  void _subscribeToBroadcasts() {
    final clientId = ClientConfig.client.id;
    
    _broadcastsChannel?.unsubscribe();
    
    _broadcastsChannel = SupabaseService.client
        .channel('broadcasts_$clientId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'broadcasts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'client_id',
            value: clientId,
          ),
          callback: (payload) {
            print('📢 New broadcast received');
            _handleNewBroadcast(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'broadcasts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'client_id',
            value: clientId,
          ),
          callback: (payload) {
            print('📢 Broadcast updated');
            _handleBroadcastUpdate(payload.newRecord);
          },
        )
        .subscribe();

    print('📢 Subscribed to broadcasts realtime updates');
  }

  /// Handle new broadcast from realtime
  void _handleNewBroadcast(Map<String, dynamic> data) {
    try {
      final broadcast = Broadcast.fromJson(data);
      
      // Add to beginning of list if not already present
      if (!_broadcasts.any((b) => b.id == broadcast.id)) {
        _broadcasts.insert(0, broadcast);
        notifyListeners();
      }
    } catch (e) {
      print('Error handling new broadcast: $e');
    }
  }

  /// Handle broadcast update from realtime
  void _handleBroadcastUpdate(Map<String, dynamic> data) {
    try {
      final broadcast = Broadcast.fromJson(data);
      
      final index = _broadcasts.indexWhere((b) => b.id == broadcast.id);
      if (index != -1) {
        _broadcasts[index] = broadcast;
        
        // Update selected broadcast if it's the same one
        if (_selectedBroadcast?.id == broadcast.id) {
          _selectedBroadcast = broadcast;
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error handling broadcast update: $e');
    }
  }

  /// Subscribe to recipients for a specific broadcast
  void _subscribeToRecipients(String broadcastId) {
    _recipientsChannel?.unsubscribe();
    
    _recipientsChannel = SupabaseService.client
        .channel('recipients_$broadcastId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'broadcast_recipients',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'broadcast_id',
            value: broadcastId,
          ),
          callback: (payload) {
            print('📢 New recipient received');
            _handleNewRecipient(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'broadcast_recipients',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'broadcast_id',
            value: broadcastId,
          ),
          callback: (payload) {
            print('📢 Recipient status updated');
            _handleRecipientUpdate(payload.newRecord);
          },
        )
        .subscribe();

    print('📢 Subscribed to recipients realtime updates');
  }

  /// Handle new recipient from realtime
  void _handleNewRecipient(Map<String, dynamic> data) {
    try {
      final recipient = BroadcastRecipient.fromJson(data);
      
      if (!_recipients.any((r) => r.id == recipient.id)) {
        _recipients.insert(0, recipient);
        notifyListeners();
      }
    } catch (e) {
      print('Error handling new recipient: $e');
    }
  }

  /// Handle recipient update from realtime
  void _handleRecipientUpdate(Map<String, dynamic> data) {
    try {
      final recipient = BroadcastRecipient.fromJson(data);
      
      final index = _recipients.indexWhere((r) => r.id == recipient.id);
      if (index != -1) {
        _recipients[index] = recipient;
        notifyListeners();
      }
    } catch (e) {
      print('Error handling recipient update: $e');
    }
  }

  /// Fetch all broadcasts for current client
  Future<void> fetchBroadcasts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final clientId = ClientConfig.client.id;
      final response = await SupabaseService.client
          .from('broadcasts')
          .select()
          .eq('client_id', clientId)
          .order('sent_at', ascending: false);

      _broadcasts = (response as List)
          .map((json) => Broadcast.fromJson(json))
          .toList();

      print('Fetched ${_broadcasts.length} broadcasts');

      _isLoading = false;
      notifyListeners();
      
      // Initialize realtime subscription after first fetch
      _subscribeToBroadcasts();
    } catch (e) {
      print('Fetch broadcasts error: $e');
      _error = 'Failed to load broadcasts';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a broadcast and load its recipients
  Future<void> selectBroadcast(Broadcast broadcast) async {
    _selectedBroadcast = broadcast;
    notifyListeners();

    await fetchRecipients(broadcast.id);
    
    // Subscribe to realtime updates for this broadcast's recipients
    _subscribeToRecipients(broadcast.id);
  }

  /// Fetch recipients for a broadcast
  Future<void> fetchRecipients(String broadcastId) async {
    try {
      final response = await SupabaseService.client
          .from('broadcast_recipients')
          .select()
          .eq('broadcast_id', broadcastId)
          .order('sent_at', ascending: false);

      _recipients = (response as List)
          .map((json) => BroadcastRecipient.fromJson(json))
          .toList();

      print('Fetched ${_recipients.length} recipients');
      notifyListeners();
    } catch (e) {
      print('Fetch recipients error: $e');
    }
  }

  /// Clear selection
  void clearSelection() {
    _selectedBroadcast = null;
    _recipients = [];
    _recipientsChannel?.unsubscribe();
    notifyListeners();
  }

  /// Get stats for current broadcast
  Map<String, int> get recipientStats {
    int sent = 0;
    int delivered = 0;
    int read = 0;
    int failed = 0;

    for (final r in _recipients) {
      switch (r.status) {
        case 'sent':
          sent++;
          break;
        case 'delivered':
          delivered++;
          break;
        case 'read':
          read++;
          break;
        case 'failed':
          failed++;
          break;
      }
    }

    return {
      'sent': sent,
      'delivered': delivered,
      'read': read,
      'failed': failed,
      'total': _recipients.length,
    };
  }

  /// Send a broadcast via n8n webhook
  /// The AI will parse the instruction and determine recipients
  Future<bool> sendBroadcast(String instruction) async {
    if (instruction.trim().isEmpty) {
      _sendError = 'Please enter a broadcast instruction';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final webhookUrl = ClientConfig.webhookUrl;
      if (webhookUrl.isEmpty) {
        throw Exception('Webhook URL not configured');
      }

      final payload = {
        'source': 'dashboard',
        'type': 'broadcast',
        'instruction': instruction.trim(),
        'ai_phone': ClientConfig.businessPhone,
        'client_id': ClientConfig.client.id,
        'client_name': ClientConfig.client.name,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('Sending broadcast: $payload');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Broadcast sent successfully');
        
        // Realtime will handle the update, but also refresh after delay as backup
        Future.delayed(const Duration(seconds: 2), () {
          fetchBroadcasts();
        });

        _isSending = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Send broadcast error: $e');
      _sendError = 'Failed to send broadcast: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear send error
  void clearSendError() {
    _sendError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _broadcastsChannel?.unsubscribe();
    _recipientsChannel?.unsubscribe();
    super.dispose();
  }
}