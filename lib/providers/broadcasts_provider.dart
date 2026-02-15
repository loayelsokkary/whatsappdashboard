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
  final String? clientId;
  final String? campaignName;
  final String? messageContent;
  final DateTime sentAt;
  final int totalRecipients;
  final String? status;

  const Broadcast({
    required this.id,
    this.clientId,
    this.campaignName,
    this.messageContent,
    required this.sentAt,
    required this.totalRecipients,
    this.status,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString(),
      campaignName: json['campaign_name'] as String?,
      messageContent: json['message_content'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
      totalRecipients: json['total_recipients'] is int
          ? json['total_recipients'] as int
          : int.tryParse(json['total_recipients']?.toString() ?? '') ?? 0,
      status: json['status'] as String?,
    );
  }

  Broadcast copyWith({
    String? id,
    String? clientId,
    String? campaignName,
    String? messageContent,
    DateTime? sentAt,
    int? totalRecipients,
    String? status,
  }) {
    return Broadcast(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      campaignName: campaignName ?? this.campaignName,
      messageContent: messageContent ?? this.messageContent,
      sentAt: sentAt ?? this.sentAt,
      totalRecipients: totalRecipients ?? this.totalRecipients,
      status: status ?? this.status,
    );
  }
}

/// Broadcast recipient model
class BroadcastRecipient {
  final String id;
  final String? broadcastId;
  final String? customerPhone;
  final String? customerName;
  final String? messageSent;
  final String? status;

  const BroadcastRecipient({
    required this.id,
    this.broadcastId,
    this.customerPhone,
    this.customerName,
    this.messageSent,
    this.status,
  });

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) {
    return BroadcastRecipient(
      id: json['id']?.toString() ?? '',
      broadcastId: json['broadcast_id']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      customerName: json['customer_name'] as String?,
      messageSent: json['message_sent'] as String?,
      status: json['status'] as String?,
    );
  }

  String get displayName => customerName ?? customerPhone ?? 'Unknown';
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
  int _monthlySentCount = 0;
  
  RealtimeChannel? _broadcastsChannel;
  RealtimeChannel? _recipientsChannel;

  List<Broadcast> get broadcasts => _broadcasts;
  List<BroadcastRecipient> get recipients => _recipients;
  Broadcast? get selectedBroadcast => _selectedBroadcast;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get sendError => _sendError;
  int get monthlySentCount => _monthlySentCount;
  int get monthlyLimit => ClientConfig.currentClient?.broadcastLimit ?? 0;
  int get remainingBroadcasts => (monthlyLimit - _monthlySentCount).clamp(0, monthlyLimit);
  bool get hasLimit => monthlyLimit > 0;
  bool get isAtLimit => hasLimit && _monthlySentCount >= monthlyLimit;

  /// Get dynamic table names from ClientConfig
  String get _broadcastsTable {
    final table = ClientConfig.broadcastsTable;
    if (table != null && table.isNotEmpty) {
      return table;
    }
    final slug = ClientConfig.currentClient?.slug;
    if (slug != null && slug.isNotEmpty) {
      return '${slug}_broadcasts';
    }
    return 'broadcasts';
  }

  String get _recipientsTable {
    final broadcastsTable = _broadcastsTable;
    if (broadcastsTable != 'broadcasts') {
      final prefix = broadcastsTable.replaceAll('_broadcasts', '');
      return '${prefix}_broadcast_recipients';
    }
    return 'broadcast_recipients';
  }

  void initialize() {
    _subscribeToBroadcasts();
  }

  void _subscribeToBroadcasts() {
    _broadcastsChannel?.unsubscribe();
    
    _broadcastsChannel = SupabaseService.client
        .channel('broadcasts_${_broadcastsTable}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _broadcastsTable,
          callback: (payload) {
            print('📢 New broadcast received');
            _handleNewBroadcast(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _broadcastsTable,
          callback: (payload) {
            print('📢 Broadcast updated');
            _handleBroadcastUpdate(payload.newRecord);
          },
        )
        .subscribe();

    print('📢 Subscribed to $_broadcastsTable realtime updates');
  }

  void _handleNewBroadcast(Map<String, dynamic> data) {
    try {
      final broadcast = Broadcast.fromJson(data);
      
      // Remove duplicate if exists, then add
      _broadcasts.removeWhere((b) => b.id == broadcast.id);
      _broadcasts.insert(0, broadcast);
      notifyListeners();
    } catch (e) {
      print('Error handling new broadcast: $e');
    }
  }

  void _handleBroadcastUpdate(Map<String, dynamic> data) {
    try {
      final broadcast = Broadcast.fromJson(data);
      
      final index = _broadcasts.indexWhere((b) => b.id == broadcast.id);
      if (index != -1) {
        _broadcasts[index] = broadcast;
        
        if (_selectedBroadcast?.id == broadcast.id) {
          _selectedBroadcast = broadcast;
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error handling broadcast update: $e');
    }
  }

  void _subscribeToRecipients(String broadcastId) {
    _recipientsChannel?.unsubscribe();
    
    _recipientsChannel = SupabaseService.client
        .channel('recipients_$broadcastId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _recipientsTable,
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
        .subscribe();

    print('📢 Subscribed to $_recipientsTable realtime updates');
  }

  void _handleNewRecipient(Map<String, dynamic> data) {
    try {
      final recipient = BroadcastRecipient.fromJson(data);
      
      if (!_recipients.any((r) => r.id == recipient.id)) {
        _recipients.insert(0, recipient);
        _syncBroadcastRecipientCount();
        notifyListeners();
      }
    } catch (e) {
      print('Error handling new recipient: $e');
    }
  }

  void _syncBroadcastRecipientCount() {
    if (_selectedBroadcast == null) return;
    
    final actualCount = _recipients.length;
    if (_selectedBroadcast!.totalRecipients != actualCount) {
      final updatedBroadcast = _selectedBroadcast!.copyWith(
        totalRecipients: actualCount,
      );
      
      _selectedBroadcast = updatedBroadcast;
      
      final index = _broadcasts.indexWhere((b) => b.id == updatedBroadcast.id);
      if (index != -1) {
        _broadcasts[index] = updatedBroadcast;
      }
    }
  }

  Future<void> fetchBroadcasts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📢 Fetching from table: $_broadcastsTable');
      
      final response = await SupabaseService.client
          .from(_broadcastsTable)
          .select()
          .order('sent_at', ascending: false);

      _broadcasts = (response as List).map((json) {
        return Broadcast.fromJson(json);
      }).toList();

      print('📢 Fetched ${_broadcasts.length} broadcasts from $_broadcastsTable');

      await fetchMonthlySentCount();

      _isLoading = false;
      notifyListeners();

      _subscribeToBroadcasts();
    } catch (e) {
      print('Fetch broadcasts error: $e');
      _error = 'Failed to load broadcasts';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectBroadcast(Broadcast broadcast) async {
    _selectedBroadcast = broadcast;
    notifyListeners();

    await fetchRecipients(broadcast.id);
    _syncBroadcastRecipientCount();
    notifyListeners();
    
    _subscribeToRecipients(broadcast.id);
  }

  Future<void> fetchRecipients(String broadcastId) async {
    try {
      print('📢 Fetching recipients from: $_recipientsTable');
      
      final response = await SupabaseService.client
          .from(_recipientsTable)
          .select()
          .eq('broadcast_id', broadcastId);

      _recipients = (response as List)
          .map((json) => BroadcastRecipient.fromJson(json))
          .toList();

      print('📢 Fetched ${_recipients.length} recipients from $_recipientsTable');
      notifyListeners();
    } catch (e) {
      print('Fetch recipients error: $e');
    }
  }

  Future<void> fetchMonthlySentCount() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      final response = await SupabaseService.client
          .from(_broadcastsTable)
          .select('total_recipients')
          .gte('sent_at', startOfMonth);

      _monthlySentCount = (response as List)
          .fold<int>(0, (sum, b) => sum + ((b['total_recipients'] ?? 0) as int));
      notifyListeners();
    } catch (e) {
      print('Error fetching monthly broadcast count: $e');
    }
  }

  void clearSelection() {
    _selectedBroadcast = null;
    _recipients = [];
    _recipientsChannel?.unsubscribe();
    notifyListeners();
  }

  Future<bool> sendBroadcast(String instruction) async {
    if (instruction.trim().isEmpty) {
      _sendError = 'Please enter a broadcast instruction';
      notifyListeners();
      return false;
    }

    if (isAtLimit) {
      _sendError = 'Monthly broadcast limit reached ($monthlyLimit/$monthlyLimit)';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final webhookUrl = ClientConfig.broadcastsWebhookUrl;
      if (webhookUrl == null || webhookUrl.isEmpty) {
        throw Exception('Broadcasts webhook URL not configured');
      }

      final broadcastPhone = ClientConfig.broadcastsPhone;
      if (broadcastPhone == null || broadcastPhone.isEmpty) {
        throw Exception('Broadcasts phone number not configured');
      }

      final payload = {
        'source': 'dashboard',
        'type': 'broadcast',
        'instruction': instruction.trim(),
        'ai_phone': broadcastPhone,
        'phone': broadcastPhone,
        'client_id': ClientConfig.currentClient?.id,
        'client_name': ClientConfig.currentClient?.name,
        'user_name': ClientConfig.currentUserName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📢 Sending broadcast to $webhookUrl');
      print('📢 Payload: $payload');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('📢 Webhook response: ${response.statusCode} ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('📢 Broadcast sent successfully');

        // Log the broadcast action
        await SupabaseService.instance.log(
          actionType: ActionType.broadcastSent,
          description: 'Sent broadcast: ${instruction.length > 50 ? '${instruction.substring(0, 50)}...' : instruction}',
          metadata: {
            'instruction': instruction,
            'client_name': ClientConfig.currentClient?.name,
          },
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          fetchBroadcasts();
          fetchMonthlySentCount();
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