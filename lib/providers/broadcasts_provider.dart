import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  String? _error;

  // Getters
  List<Broadcast> get broadcasts => _broadcasts;
  List<BroadcastRecipient> get recipients => _recipients;
  Broadcast? get selectedBroadcast => _selectedBroadcast;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
}