import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Broadcast Analytics data
class BroadcastAnalyticsData {
  final int totalCampaigns;
  final int totalRecipients;
  final int totalDelivered;
  final int totalRead;
  final int totalFailed;
  final double deliveryRate;
  final double readRate;
  final List<CampaignPerformance> recentCampaigns;
  final List<DailyBroadcastActivity> last7Days;

  BroadcastAnalyticsData({
    required this.totalCampaigns,
    required this.totalRecipients,
    required this.totalDelivered,
    required this.totalRead,
    required this.totalFailed,
    required this.deliveryRate,
    required this.readRate,
    required this.recentCampaigns,
    required this.last7Days,
  });
}

class CampaignPerformance {
  final String id;
  final String name;
  final int recipients;
  final int delivered;
  final int read;
  final int failed;
  final DateTime sentAt;

  CampaignPerformance({
    required this.id,
    required this.name,
    required this.recipients,
    required this.delivered,
    required this.read,
    required this.failed,
    required this.sentAt,
  });

  double get deliveryRate => recipients > 0 ? (delivered + read) / recipients * 100 : 0;
  double get readRate => recipients > 0 ? read / recipients * 100 : 0;
}

class DailyBroadcastActivity {
  final DateTime date;
  final int campaigns;
  final int recipients;

  DailyBroadcastActivity({
    required this.date,
    required this.campaigns,
    required this.recipients,
  });
}

/// Provider for broadcast analytics
class BroadcastAnalyticsProvider extends ChangeNotifier {
  BroadcastAnalyticsData? _analytics;
  bool _isLoading = false;
  String? _error;

  BroadcastAnalyticsData? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> fetchAnalytics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final clientId = ClientConfig.client.id;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Fetch all broadcasts for this client
      final broadcastsResponse = await _client
          .from('broadcasts')
          .select()
          .eq('client_id', clientId)
          .order('sent_at', ascending: false);

      final broadcasts = broadcastsResponse as List;
      final totalCampaigns = broadcasts.length;

      // Fetch all recipients
      final recipientsResponse = await _client
          .from('broadcast_recipients')
          .select('*, broadcasts!inner(client_id)')
          .eq('broadcasts.client_id', clientId);

      final recipients = recipientsResponse as List;

      // Calculate totals
      int totalRecipients = recipients.length;
      int totalDelivered = 0;
      int totalRead = 0;
      int totalFailed = 0;
      int totalSent = 0;

      for (final r in recipients) {
        switch (r['status']) {
          case 'delivered':
            totalDelivered++;
            break;
          case 'read':
            totalRead++;
            break;
          case 'failed':
            totalFailed++;
            break;
          case 'sent':
            totalSent++;
            break;
        }
      }

      // Calculate rates
      final deliveryRate = totalRecipients > 0
          ? (totalDelivered + totalRead) / totalRecipients * 100
          : 0.0;
      final readRate = totalRecipients > 0
          ? totalRead / totalRecipients * 100
          : 0.0;

      // Get campaign performance
      final recentCampaigns = <CampaignPerformance>[];
      for (final broadcast in broadcasts.take(5)) {
        final campaignRecipients = recipients
            .where((r) => r['broadcast_id'] == broadcast['id'])
            .toList();

        int delivered = 0;
        int read = 0;
        int failed = 0;

        for (final r in campaignRecipients) {
          switch (r['status']) {
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

        recentCampaigns.add(CampaignPerformance(
          id: broadcast['id'],
          name: broadcast['campaign_name'] ?? 'Unnamed',
          recipients: campaignRecipients.length,
          delivered: delivered,
          read: read,
          failed: failed,
          sentAt: DateTime.parse(broadcast['sent_at']),
        ));
      }

      // Last 7 days activity
      final last7Days = List.generate(7, (i) {
        final date = todayStart.subtract(Duration(days: 6 - i));
        final nextDate = date.add(const Duration(days: 1));

        final dayCampaigns = broadcasts.where((b) {
          final sentAt = DateTime.parse(b['sent_at']);
          return sentAt.isAfter(date) && sentAt.isBefore(nextDate);
        }).length;

        int dayRecipients = 0;
        for (final b in broadcasts) {
          final sentAt = DateTime.parse(b['sent_at']);
          if (sentAt.isAfter(date) && sentAt.isBefore(nextDate)) {
            dayRecipients += (b['total_recipients'] as int?) ?? 0;
          }
        }

        return DailyBroadcastActivity(
          date: date,
          campaigns: dayCampaigns,
          recipients: dayRecipients,
        );
      });

      _analytics = BroadcastAnalyticsData(
        totalCampaigns: totalCampaigns,
        totalRecipients: totalRecipients,
        totalDelivered: totalDelivered,
        totalRead: totalRead,
        totalFailed: totalFailed,
        deliveryRate: deliveryRate,
        readRate: readRate,
        recentCampaigns: recentCampaigns,
        last7Days: last7Days,
      );

    } catch (e) {
      _error = 'Failed to load analytics: $e';
      print('Broadcast analytics error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}