import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  final DateTime? scheduledAt;
  final Map<String, dynamic>? webhookPayload;

  const Broadcast({
    required this.id,
    this.clientId,
    this.campaignName,
    this.messageContent,
    this.photo,
    required this.sentAt,
    required this.totalRecipients,
    this.status,
    this.scheduledAt,
    this.webhookPayload,
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
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      webhookPayload: json['webhook_payload'] is Map
          ? Map<String, dynamic>.from(json['webhook_payload'] as Map)
          : null,
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
    DateTime? scheduledAt,
    Map<String, dynamic>? webhookPayload,
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
      scheduledAt: scheduledAt ?? this.scheduledAt,
      webhookPayload: webhookPayload ?? this.webhookPayload,
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
  final String? wamid;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const BroadcastRecipient({
    required this.id,
    this.broadcastId,
    this.customerPhone,
    this.customerName,
    this.messageSent,
    this.status,
    this.wamid,
    this.deliveredAt,
    this.readAt,
  });

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) {
    return BroadcastRecipient(
      id: json['id']?.toString() ?? '',
      broadcastId: json['broadcast_id']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      customerName: json['customer_name'] as String?,
      messageSent: json['message_sent'] as String?,
      status: json['status'] as String?,
      wamid: json['wamid'] as String?,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
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
  int _recipientSentCount = 0;
  bool _isSending = false;
  String? _error;
  String? _sendError;
  int _monthlySentCount = 0;

  RealtimeChannel? _broadcastsChannel;
  RealtimeChannel? _recipientsChannel;
  Timer? _sendingPollTimer;

  List<Broadcast> get broadcasts => _broadcasts;
  List<BroadcastRecipient> get recipients => _recipients;
  Broadcast? get selectedBroadcast => _selectedBroadcast;
  bool get isLoading => _isLoading;
  bool get isLoadingRecipients => _isLoadingRecipients;
  int get recipientSentCount => _recipientSentCount;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get sendError => _sendError;
  int get monthlySentCount => _monthlySentCount;
  int get monthlyLimit => ClientConfig.currentClient?.broadcastLimit ?? 0;
  int get remainingBroadcasts => (monthlyLimit - _monthlySentCount).clamp(0, monthlyLimit);
  bool get hasLimit => monthlyLimit > 0;
  bool get isAtLimit => hasLimit && _monthlySentCount >= monthlyLimit;

  // Status breakdown from loaded recipients
  int get recipientsSent => _recipients.where((r) {
        final s = r.status?.toLowerCase() ?? '';
        return s == 'sent' || s == 'accepted';
      }).length;
  int get recipientsDelivered => _recipients.where((r) => r.status?.toLowerCase() == 'delivered').length;
  int get recipientsRead => _recipients.where((r) => r.status?.toLowerCase() == 'read').length;
  int get recipientsFailed => _recipients.where((r) => r.status?.toLowerCase() == 'failed').length;

  /// Get dynamic table names from ClientConfig
  String get _broadcastsTable {
    final table = ClientConfig.broadcastsTable;
    if (table != null && table.isNotEmpty) return table;
    final slug = ClientConfig.currentClient?.slug;
    if (slug != null && slug.isNotEmpty) return '${slug}_broadcasts';
    throw StateError('No broadcasts table configured — client not fully loaded');
  }

  String get _recipientsTable {
    // Prefer the explicit broadcast_recipients_table column from the clients row
    final explicit = ClientConfig.broadcastRecipientsTableName;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    // Fallback: derive from the broadcasts table name (supports older rows)
    final slug = ClientConfig.currentClient?.slug;
    if (slug != null && slug.isNotEmpty) return '${slug}_broadcast_recipients';
    throw StateError('No broadcast_recipients table configured — client not fully loaded');
  }

  void initialize() {
    _subscribeToBroadcasts();
  }

  void _startSendingPoller() {
    _sendingPollTimer?.cancel();
    _sendingPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final sendingIds = _broadcasts
          .where((b) => b.status == 'sending')
          .map((b) => b.id)
          .toList();
      if (sendingIds.isEmpty) {
        _stopSendingPoller();
        return;
      }
      try {
        final rows = await SupabaseService.adminClient
            .from(_broadcastsTable)
            .select('id, status, total_recipients, campaign_name')
            .inFilter('id', sendingIds);
        bool changed = false;
        for (final row in (rows as List)) {
          final id = row['id']?.toString();
          final newStatus = row['status'] as String?;
          final idx = _broadcasts.indexWhere((b) => b.id == id);
          if (idx != -1 && _broadcasts[idx].status != newStatus) {
            _broadcasts[idx] = _broadcasts[idx].copyWith(
              status: newStatus,
              totalRecipients: row['total_recipients'] is int
                  ? row['total_recipients'] as int
                  : int.tryParse(row['total_recipients']?.toString() ?? '') ?? _broadcasts[idx].totalRecipients,
            );
            if (_selectedBroadcast?.id == id) {
              _selectedBroadcast = _broadcasts[idx];
            }
            changed = true;
          }
        }
        if (changed) notifyListeners();
        // Stop once no more sending broadcasts
        if (_broadcasts.every((b) => b.status != 'sending')) {
          _stopSendingPoller();
        }
      } catch (e) {
        debugPrint('Sending poller error: $e');
      }
    });
  }

  void _stopSendingPoller() {
    _sendingPollTimer?.cancel();
    _sendingPollTimer = null;
  }

  void _subscribeToBroadcasts() {
    _broadcastsChannel?.unsubscribe();
    
    _broadcastsChannel = SupabaseService.client
        .channel('broadcasts_$_broadcastsTable')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _broadcastsTable,
          callback: (payload) {
            debugPrint('📢 New broadcast received');
            _handleNewBroadcast(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _broadcastsTable,
          callback: (payload) {
            debugPrint('📢 Broadcast updated');
            _handleBroadcastUpdate(payload.newRecord);
          },
        )
        .subscribe();

    debugPrint('📢 Subscribed to $_broadcastsTable realtime updates');
  }

  void _handleNewBroadcast(Map<String, dynamic> data) {
    try {
      final broadcast = Broadcast.fromJson(data);
      _broadcasts.removeWhere((b) => b.id == broadcast.id);
      _broadcasts.insert(0, broadcast);
      notifyListeners();
      if (broadcast.status == 'sending') _startSendingPoller();
    } catch (e) {
      debugPrint('Error handling new broadcast: $e');
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
        if (broadcast.status == 'sending') _startSendingPoller();
      }
    } catch (e) {
      debugPrint('Error handling broadcast update: $e');
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
            debugPrint('📢 New recipient received');
            _handleNewRecipient(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _recipientsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'broadcast_id',
            value: broadcastId,
          ),
          callback: (payload) {
            debugPrint('📢 Recipient status updated');
            _handleRecipientUpdate(payload.newRecord);
          },
        )
        .subscribe();

    debugPrint('📢 Subscribed to $_recipientsTable realtime updates');
  }

  void _handleNewRecipient(Map<String, dynamic> data) {
    try {
      final recipient = BroadcastRecipient.fromJson(data);
      if (!_recipients.any((r) => r.id == recipient.id)) {
        _recipients.insert(0, recipient);
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
      debugPrint('Error handling new recipient: $e');
    }
  }

  void _handleRecipientUpdate(Map<String, dynamic> data) {
    try {
      final updated = BroadcastRecipient.fromJson(data);
      final idx = _recipients.indexWhere((r) => r.id == updated.id);
      if (idx != -1) {
        _recipients[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling recipient update: $e');
    }
  }

  Future<void> fetchBroadcasts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📢 Fetching from table: $_broadcastsTable');
      
      // Use adminClient to bypass RLS on per-client tables
      final response = await SupabaseService.adminClient
          .from(_broadcastsTable)
          .select()
          .order('sent_at', ascending: false);

      _broadcasts = (response as List).map((json) {
        return Broadcast.fromJson(json);
      }).toList();

      debugPrint('📢 Fetched ${_broadcasts.length} broadcasts from $_broadcastsTable');

      // Enrich with actual recipient counts from the recipients table
      await _enrichRecipientCounts();

      await fetchMonthlySentCount();

      _isLoading = false;
      notifyListeners();

      _subscribeToBroadcasts();

      if (_broadcasts.any((b) => b.status == 'sending')) {
        _startSendingPoller();
      }
    } catch (e) {
      debugPrint('Fetch broadcasts error: $e');
      _error = 'Failed to load broadcasts';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Enrich broadcasts list with actual recipient counts from the recipients table.
  Future<void> _enrichRecipientCounts() async {
    if (_broadcasts.isEmpty) return;
    try {
      // Use per-broadcast COUNT queries in parallel — avoids Supabase's 1000-row
      // default limit that would truncate a single all-rows fetch.
      bool changed = false;
      await Future.wait(_broadcasts.map((broadcast) async {
        final result = await SupabaseService.adminClient
            .from(_recipientsTable)
            .select()
            .eq('broadcast_id', broadcast.id)
            .count(CountOption.exact);
        final actual = result.count;
        final idx = _broadcasts.indexWhere((b) => b.id == broadcast.id);
        if (idx != -1 && actual != _broadcasts[idx].totalRecipients) {
          _broadcasts[idx] = _broadcasts[idx].copyWith(totalRecipients: actual);
          if (_selectedBroadcast?.id == broadcast.id) {
            _selectedBroadcast = _broadcasts[idx];
          }
          changed = true;
        }
      }));
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('📢 _enrichRecipientCounts error: $e');
    }
  }

  Future<void> selectBroadcast(Broadcast broadcast) async {
    _selectedBroadcast = broadcast;
    _recipients = [];
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
      // Use adminClient to bypass RLS on per-client tables
      final result = await SupabaseService.adminClient
          .from(_recipientsTable)
          .select()
          .eq('broadcast_id', broadcastId)
          .count(CountOption.exact);
      return result.count;
    } catch (e) {
      debugPrint('Error fetching recipient count: $e');
      return -1;
    }
  }

  Future<void> fetchRecipients(String broadcastId) async {
    try {
      // Supabase default row limit is 1000 — fetch in batches of 1000 until exhausted.
      const batchSize = 1000;
      final allRows = <Map<String, dynamic>>[];
      int offset = 0;
      while (true) {
        final response = await SupabaseService.adminClient
            .from(_recipientsTable)
            .select('id, customer_name, customer_phone, status, wamid, delivered_at, read_at')
            .eq('broadcast_id', broadcastId)
            .range(offset, offset + batchSize - 1);
        final batch = List<Map<String, dynamic>>.from(response as List);
        allRows.addAll(batch);
        if (batch.length < batchSize) break;
        offset += batchSize;
      }
      _recipients = allRows.map((json) => BroadcastRecipient.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch recipients error: $e');
    }
  }

  Future<void> _fetchRecipientStats(String broadcastId) async {
    try {
      // Use adminClient to bypass RLS on per-client tables
      final result = await SupabaseService.adminClient
          .from(_recipientsTable)
          .select()
          .eq('broadcast_id', broadcastId)
          .inFilter('status', ['accepted', 'sent', 'delivered'])
          .count(CountOption.exact);
      _recipientSentCount = result.count;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching recipient stats: $e');
    }
  }

  Future<void> fetchMonthlySentCount() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      // Use adminClient to bypass RLS on per-client tables
      final broadcastsResponse = await SupabaseService.adminClient
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

      // Count actual recipients for those broadcasts (adminClient bypasses RLS)
      final countResult = await SupabaseService.adminClient
          .from(_recipientsTable)
          .select()
          .inFilter('broadcast_id', ids)
          .count(CountOption.exact);
      _monthlySentCount = countResult.count;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching monthly broadcast count: $e');
    }
  }

  /// Rename a broadcast campaign
  Future<void> renameBroadcast(String broadcastId, String newName) async {
    try {
      // Use adminClient to bypass RLS on per-client tables
      await SupabaseService.adminClient
          .from(_broadcastsTable)
          .update({'campaign_name': newName})
          .eq('id', broadcastId);

      // Verify the update actually persisted
      final verify = await SupabaseService.adminClient
          .from(_broadcastsTable)
          .select('campaign_name')
          .eq('id', broadcastId)
          .maybeSingle();

      final persistedName = verify?['campaign_name']?.toString();
      if (persistedName != newName) {
        debugPrint('⚠️ Rename did not persist! DB has: $persistedName, expected: $newName');
        debugPrint('⚠️ This is likely an RLS policy issue — check UPDATE policy on $_broadcastsTable');
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
      debugPrint('Error renaming broadcast: $e');
      rethrow;
    }
  }

  void clearSelection() {
    _selectedBroadcast = null;
    _recipients = [];
    _recipientsChannel?.unsubscribe();
    notifyListeners();
  }

  Future<bool> sendBroadcast(String instruction, {String? templateName, String? templateImageUrl}) async {
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
      final client = ClientConfig.currentClient;
      debugPrint('[sendBroadcast] Initiating broadcast for client: ${client?.name}');

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
        if (templateName != null && templateName.isNotEmpty)
          'template_name': templateName,
        if (templateImageUrl != null && templateImageUrl.isNotEmpty)
          'offer_image_url': templateImageUrl,
      };

      final response = await SupabaseService.postWebhook(
        webhookUrl,
        payload,
        secret: SupabaseService.webhookSecret.isNotEmpty ? SupabaseService.webhookSecret : null,
      );

      debugPrint('[sendBroadcast] Response: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('📢 [sendBroadcast] Success!');

        // Log the broadcast action
        await SupabaseService.instance.log(
          actionType: ActionType.broadcastSent,
          description: 'Sent broadcast: ${instruction.length > 50 ? '${instruction.substring(0, 50)}...' : instruction}',
          metadata: {
            'instruction': instruction,
            'client_name': client?.name,
          },
        );

        // Insert a confirmation message into the manager chat so it appears immediately
        final managerChatsTable = ClientConfig.managerChatsTable;
        if (managerChatsTable != null && managerChatsTable.isNotEmpty) {
          try {
            final confirmText = templateName != null && templateName.isNotEmpty
                ? '📢 Broadcast queued! Template "$templateName" is being sent. You\'ll see delivery results shortly.'
                : '📢 Broadcast queued and being processed. You\'ll see delivery results shortly.';
            await SupabaseService.adminClient
                .from(managerChatsTable)
                .insert({
                  'client_id': client?.id,
                  'user_id': ClientConfig.currentUser?.id,
                  'user_name': ClientConfig.currentUserName,
                  'user_message': instruction,
                  'ai_response': confirmText,
                });
          } catch (e) {
            debugPrint('[sendBroadcast] Chat confirmation insert failed: $e');
          }
        }

        Future.delayed(const Duration(seconds: 2), () {
          fetchBroadcasts();
          fetchMonthlySentCount();
        });

        _isSending = false;
        notifyListeners();
        return true;
      } else {
        _sendError = 'Server error (${response.statusCode}). Please try again.';
        debugPrint('📢 [sendBroadcast] Server error: ${response.statusCode} ${response.body}');
        _isSending = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('📢 [sendBroadcast] Error: $e');
      _sendError = e.toString().contains('XMLHttpRequest')
          ? 'Network error — could not reach the broadcast server. Check webhook URL.'
          : 'Failed to send: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> scheduleBroadcast(
    String instruction,
    DateTime scheduledAtBht, {
    String? editBroadcastId,
    String? templateName,
    String? templateImageUrl,
  }) async {
    if (instruction.trim().isEmpty) {
      _sendError = 'Please enter a broadcast instruction';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final client = ClientConfig.currentClient;

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

      // scheduledAtBht is treated as Bahrain time (UTC+3) — convert to UTC for storage
      final scheduledAtUtc = scheduledAtBht.subtract(const Duration(hours: 3));

      final payload = {
        'source': 'dashboard',
        'type': 'broadcast',
        'instruction': instruction.trim(),
        'ai_phone': broadcastPhone,
        'phone': broadcastPhone,
        'client_id': client?.id,
        'client_name': client?.name,
        'user_name': ClientConfig.currentUserName,
        'timestamp': scheduledAtUtc.toIso8601String(),
        if (templateName != null && templateName.isNotEmpty)
          'template_name': templateName,
        if (templateImageUrl != null && templateImageUrl.isNotEmpty)
          'offer_image_url': templateImageUrl,
      };

      final campaignName = instruction.trim().length > 60
          ? '${instruction.trim().substring(0, 60)}...'
          : instruction.trim();

      if (editBroadcastId != null) {
        await SupabaseService.adminClient
            .from(_broadcastsTable)
            .update({
              'scheduled_at': scheduledAtUtc.toIso8601String(),
              'webhook_payload': payload,
              'campaign_name': campaignName,
            })
            .eq('id', editBroadcastId);
      } else {
        await SupabaseService.adminClient
            .from(_broadcastsTable)
            .insert({
              'client_id': client?.id,
              'campaign_name': campaignName,
              'status': 'scheduled',
              'scheduled_at': scheduledAtUtc.toIso8601String(),
              'webhook_payload': payload,
              'total_recipients': 0,
              'sent_at': DateTime.now().toUtc().toIso8601String(),
              'created_by': ClientConfig.currentUserName,
              if (templateImageUrl != null && templateImageUrl.isNotEmpty)
                'photo': templateImageUrl,
            });
      }

      await SupabaseService.instance.log(
        actionType: ActionType.broadcastSent,
        description: 'Scheduled broadcast: $campaignName',
        metadata: {
          'instruction': instruction,
          'scheduled_at': scheduledAtUtc.toIso8601String(),
          'client_name': client?.name,
        },
      );

      // Insert a confirmation message into the manager chat
      final managerChatsTable = ClientConfig.managerChatsTable;
      if (managerChatsTable != null && managerChatsTable.isNotEmpty) {
        try {
          final bhtFormatted =
              '${scheduledAtBht.day}/${scheduledAtBht.month}/${scheduledAtBht.year} '
              '${scheduledAtBht.hour.toString().padLeft(2, '0')}:${scheduledAtBht.minute.toString().padLeft(2, '0')}';
          final confirmText = templateName != null && templateName.isNotEmpty
              ? '⏰ Broadcast scheduled! Template "$templateName" will be sent on $bhtFormatted (Bahrain time).'
              : '⏰ Broadcast scheduled for $bhtFormatted (Bahrain time).';
          await SupabaseService.adminClient
              .from(managerChatsTable)
              .insert({
                'client_id': client?.id,
                'user_id': ClientConfig.currentUser?.id,
                'user_name': ClientConfig.currentUserName,
                'user_message': instruction,
                'ai_response': confirmText,
              });
        } catch (e) {
          debugPrint('[scheduleBroadcast] Chat confirmation insert failed: $e');
        }
      }

      Future.delayed(const Duration(milliseconds: 500), fetchBroadcasts);

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('📢 [scheduleBroadcast] Error: $e');
      _sendError = 'Failed to schedule: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelScheduledBroadcast(String broadcastId) async {
    try {
      await SupabaseService.adminClient
          .from(_broadcastsTable)
          .update({'status': 'cancelled'})
          .eq('id', broadcastId);

      final index = _broadcasts.indexWhere((b) => b.id == broadcastId);
      if (index != -1) {
        _broadcasts[index] = _broadcasts[index].copyWith(status: 'cancelled');
        if (_selectedBroadcast?.id == broadcastId) {
          _selectedBroadcast = _selectedBroadcast!.copyWith(status: 'cancelled');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cancelling scheduled broadcast: $e');
      rethrow;
    }
  }

  void clearSendError() {
    _sendError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopSendingPoller();
    _broadcastsChannel?.unsubscribe();
    _recipientsChannel?.unsubscribe();
    super.dispose();
  }
}