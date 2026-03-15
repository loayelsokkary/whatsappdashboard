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
  final String? photo;
  final DateTime sentAt;
  final int totalRecipients;
  final String? status;

  const Broadcast({
    required this.id,
    this.clientId,
    this.campaignName,
    this.messageContent,
    this.photo,
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
      photo: json['photo'] as String?,
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
    String? photo,
    DateTime? sentAt,
    int? totalRecipients,
    String? status,
  }) {
    return Broadcast(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      campaignName: campaignName ?? this.campaignName,
      messageContent: messageContent ?? this.messageContent,
      photo: photo ?? this.photo,
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
  bool _isLoadingRecipients = false;
  bool _isLoadingMoreRecipients = false;
  bool _hasMoreRecipients = false;
  int _recipientOffset = 0;
  int _recipientSentCount = 0;
  bool _isSending = false;
  String? _error;
  String? _sendError;
  int _monthlySentCount = 0;

  static const int _recipientsPageSize = 100;
  
  RealtimeChannel? _broadcastsChannel;
  RealtimeChannel? _recipientsChannel;

  List<Broadcast> get broadcasts => _broadcasts;
  List<BroadcastRecipient> get recipients => _recipients;
  Broadcast? get selectedBroadcast => _selectedBroadcast;
  bool get isLoading => _isLoading;
  bool get isLoadingRecipients => _isLoadingRecipients;
  bool get isLoadingMoreRecipients => _isLoadingMoreRecipients;
  bool get hasMoreRecipients => _hasMoreRecipients;
  int get recipientSentCount => _recipientSentCount;
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
        _recipientOffset += 1;
        // Increment total count in selected broadcast
        if (_selectedBroadcast != null) {
          final updated = _selectedBroadcast!.copyWith(
            totalRecipients: _selectedBroadcast!.totalRecipients + 1,
          );
          _selectedBroadcast = updated;
          final idx = _broadcasts.indexWhere((b) => b.id == updated.id);
          if (idx != -1) _broadcasts[idx] = updated;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error handling new recipient: $e');
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
    _recipients = [];
    _recipientOffset = 0;
    _hasMoreRecipients = false;
    _recipientSentCount = 0;
    _isLoadingRecipients = true;
    notifyListeners();

    // Fast COUNT query — updates totalRecipients before list fetch completes
    final exactCount = await _fetchRecipientCount(broadcast.id);
    if (exactCount >= 0 && _selectedBroadcast?.id == broadcast.id) {
      _selectedBroadcast = _selectedBroadcast!.copyWith(totalRecipients: exactCount);
      final idx = _broadcasts.indexWhere((b) => b.id == broadcast.id);
      if (idx != -1) _broadcasts[idx] = _selectedBroadcast!;
      notifyListeners();
    }

    // First page of recipients + delivery stats in parallel
    await Future.wait([
      fetchRecipients(broadcast.id),
      _fetchRecipientStats(broadcast.id),
    ]);

    _isLoadingRecipients = false;
    notifyListeners();

    _subscribeToRecipients(broadcast.id);
  }

  Future<int> _fetchRecipientCount(String broadcastId) async {
    try {
      final result = await SupabaseService.client
          .from(_recipientsTable)
          .select()
          .eq('broadcast_id', broadcastId)
          .count(CountOption.exact);
      return result.count;
    } catch (e) {
      print('Error fetching recipient count: $e');
      return -1;
    }
  }

  Future<void> fetchRecipients(String broadcastId) async {
    try {
      final response = await SupabaseService.client
          .from(_recipientsTable)
          .select('id, customer_name, customer_phone, status')
          .eq('broadcast_id', broadcastId)
          .range(0, _recipientsPageSize - 1);
      final rows = List<Map<String, dynamic>>.from(response as List);
      _recipients = rows.map((json) => BroadcastRecipient.fromJson(json)).toList();
      _recipientOffset = rows.length;
      _hasMoreRecipients = rows.length >= _recipientsPageSize;
      notifyListeners();
    } catch (e) {
      print('Fetch recipients error: $e');
    }
  }

  Future<void> loadMoreRecipients() async {
    if (!_hasMoreRecipients || _isLoadingMoreRecipients || _selectedBroadcast == null) return;
    _isLoadingMoreRecipients = true;
    notifyListeners();
    try {
      final broadcastId = _selectedBroadcast!.id;
      final response = await SupabaseService.client
          .from(_recipientsTable)
          .select('id, customer_name, customer_phone, status')
          .eq('broadcast_id', broadcastId)
          .range(_recipientOffset, _recipientOffset + _recipientsPageSize - 1);
      final rows = List<Map<String, dynamic>>.from(response as List);
      _recipients = [
        ..._recipients,
        ...rows.map((json) => BroadcastRecipient.fromJson(json)),
      ];
      _recipientOffset += rows.length;
      _hasMoreRecipients = rows.length >= _recipientsPageSize;
    } catch (e) {
      print('Load more recipients error: $e');
    }
    _isLoadingMoreRecipients = false;
    notifyListeners();
  }

  Future<void> _fetchRecipientStats(String broadcastId) async {
    try {
      final result = await SupabaseService.client
          .from(_recipientsTable)
          .select()
          .eq('broadcast_id', broadcastId)
          .inFilter('status', ['accepted', 'sent', 'delivered'])
          .count(CountOption.exact);
      _recipientSentCount = result.count;
      notifyListeners();
    } catch (e) {
      print('Error fetching recipient stats: $e');
    }
  }

  Future<void> fetchMonthlySentCount() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      // Get IDs of broadcasts sent this month
      final broadcastsResponse = await SupabaseService.client
          .from(_broadcastsTable)
          .select('id')
          .gte('sent_at', startOfMonth);
      final ids = (broadcastsResponse as List)
          .map((b) => b['id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (ids.isEmpty) {
        _monthlySentCount = 0;
        notifyListeners();
        return;
      }

      // Count actual recipients for those broadcasts
      final countResult = await SupabaseService.client
          .from(_recipientsTable)
          .select()
          .inFilter('broadcast_id', ids)
          .count(CountOption.exact);
      _monthlySentCount = countResult.count;
      notifyListeners();
    } catch (e) {
      print('Error fetching monthly broadcast count: $e');
    }
  }

  /// Rename a broadcast campaign
  Future<void> renameBroadcast(String broadcastId, String newName) async {
    try {
      await SupabaseService.client
          .from(_broadcastsTable)
          .update({'campaign_name': newName})
          .eq('id', broadcastId);

      // Verify the update actually persisted (RLS may silently block)
      final verify = await SupabaseService.client
          .from(_broadcastsTable)
          .select('campaign_name')
          .eq('id', broadcastId)
          .maybeSingle();

      final persistedName = verify?['campaign_name']?.toString();
      if (persistedName != newName) {
        print('⚠️ Rename did not persist! DB has: $persistedName, expected: $newName');
        print('⚠️ This is likely an RLS policy issue — check UPDATE policy on $_broadcastsTable');
        throw Exception('Rename failed — check Supabase RLS policies on $_broadcastsTable');
      }

      // Update local state
      final index = _broadcasts.indexWhere((b) => b.id == broadcastId);
      if (index != -1) {
        _broadcasts[index] = _broadcasts[index].copyWith(campaignName: newName);
      }
      if (_selectedBroadcast?.id == broadcastId) {
        _selectedBroadcast = _selectedBroadcast!.copyWith(campaignName: newName);
      }
      notifyListeners();
    } catch (e) {
      print('Error renaming broadcast: $e');
      rethrow;
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
      // Debug: log config state
      final client = ClientConfig.currentClient;
      print('📢 [sendBroadcast] Client: ${client?.name} (${client?.id})');
      print('📢 [sendBroadcast] broadcastsPhone: ${ClientConfig.broadcastsPhone}');
      print('📢 [sendBroadcast] broadcastsWebhookUrl: ${ClientConfig.broadcastsWebhookUrl}');
      print('📢 [sendBroadcast] businessPhone fallback: ${client?.businessPhone}');
      print('📢 [sendBroadcast] webhookUrl fallback: ${client?.webhookUrl}');

      final webhookUrl = ClientConfig.broadcastsWebhookUrl;
      if (webhookUrl == null || webhookUrl.isEmpty) {
        _sendError = 'Broadcasts webhook URL not configured. Ask your admin to set it in client settings.';
        _isSending = false;
        notifyListeners();
        return false;
      }

      final broadcastPhone = ClientConfig.broadcastsPhone;
      if (broadcastPhone == null || broadcastPhone.isEmpty) {
        _sendError = 'Broadcasts phone number not configured. Ask your admin to set it in client settings.';
        _isSending = false;
        notifyListeners();
        return false;
      }

      final payload = {
        'source': 'dashboard',
        'type': 'broadcast',
        'instruction': instruction.trim(),
        'ai_phone': broadcastPhone,
        'phone': broadcastPhone,
        'client_id': client?.id,
        'client_name': client?.name,
        'user_name': ClientConfig.currentUserName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📢 [sendBroadcast] Sending to: $webhookUrl');
      print('📢 [sendBroadcast] Payload: $payload');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('📢 [sendBroadcast] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('📢 [sendBroadcast] Success!');

        // Log the broadcast action
        await SupabaseService.instance.log(
          actionType: ActionType.broadcastSent,
          description: 'Sent broadcast: ${instruction.length > 50 ? '${instruction.substring(0, 50)}...' : instruction}',
          metadata: {
            'instruction': instruction,
            'client_name': client?.name,
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
        _sendError = 'Server error (${response.statusCode}). Please try again.';
        print('📢 [sendBroadcast] Server error: ${response.statusCode} ${response.body}');
        _isSending = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('📢 [sendBroadcast] Error: $e');
      _sendError = e.toString().contains('XMLHttpRequest')
          ? 'Network error — could not reach the broadcast server. Check webhook URL.'
          : 'Failed to send: $e';
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