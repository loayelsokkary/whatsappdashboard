import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for analytics data - supports both Conversations and Broadcasts analytics
class AnalyticsProvider extends ChangeNotifier {
  AnalyticsData? _analytics;
  bool _isLoading = false;
  String? _error;
  String _currentType = 'conversations';

  // Getters
  AnalyticsData? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentType => _currentType;

  /// Fetch analytics data for the specified type
  Future<void> fetchAnalytics({String type = 'conversations'}) async {
    _currentType = type;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (type == 'conversations') {
        await _fetchConversationsAnalytics();
      } else {
        await _fetchBroadcastsAnalytics();
      }
    } catch (e) {
      print('Error fetching $type analytics: $e');
      _error = 'Failed to load analytics';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch conversations analytics
  Future<void> _fetchConversationsAnalytics() async {
    // Check if conversations is configured
    if (!ClientConfig.isConversationsConfigured) {
      _error = 'Conversations not configured';
      return;
    }

    final tableName = ClientConfig.messagesTableName;
    final businessPhone = ClientConfig.conversationsPhone!;

    // Fetch all messages from dynamic table
    final messagesResponse = await SupabaseService.client
        .from(tableName)
        .select('id, ai_phone, customer_phone, customer_name, customer_message, ai_response, manager_response, created_at')
        .eq('ai_phone', businessPhone)
        .order('created_at', ascending: false);

    final messages = messagesResponse as List;

    // Calculate statistics
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final hasAi = ClientConfig.currentClient?.hasAiConversations ?? false;

    int totalMessages = messages.length;
    int aiResponses = 0;
    int managerResponses = 0;
    int todayMessages = 0;
    int thisWeekMessages = 0;
    int thisMonthMessages = 0;
    Set<String> uniqueCustomers = {};
    Map<String, int> customerMessageCounts = {};
    Map<String, String?> customerNames = {};
    Map<String, int> dailyCounts = {};

    for (final msg in messages) {
      final createdAt = DateTime.parse(msg['created_at']);
      final customerPhone = msg['customer_phone'] as String?;

      // Count responses based on actual content
      final aiResponse = msg['ai_response'] as String?;
      final managerResponse = msg['manager_response'] as String?;

      // Only count AI responses if client has AI
      if (hasAi && aiResponse != null && aiResponse.trim().isNotEmpty) {
        aiResponses++;
      }
      if (managerResponse != null && managerResponse.trim().isNotEmpty) {
        managerResponses++;
      }

      // Time-based counts
      if (createdAt.isAfter(todayStart)) {
        todayMessages++;
      }
      if (createdAt.isAfter(weekStart)) {
        thisWeekMessages++;
      }
      if (createdAt.isAfter(monthStart)) {
        thisMonthMessages++;
      }

      // Unique customers
      if (customerPhone != null && customerPhone.isNotEmpty) {
        uniqueCustomers.add(customerPhone);
        customerMessageCounts[customerPhone] = (customerMessageCounts[customerPhone] ?? 0) + 1;
        if (msg['customer_name'] != null) {
          customerNames[customerPhone] = msg['customer_name'];
        }
      }

      // Daily activity
      final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
    }

    // Build last 7 days activity
    List<DailyActivity> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      final date = todayStart.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      last7Days.add(DailyActivity(date: date, count: dailyCounts[dateKey] ?? 0));
    }

    // Build top customers
    final sortedCustomers = customerMessageCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<TopCustomer> topCustomers = sortedCustomers.take(5).map((entry) {
      return TopCustomer(
        phone: entry.key,
        name: customerNames[entry.key],
        messageCount: entry.value,
      );
    }).toList();

    _analytics = AnalyticsData(
      totalMessages: totalMessages,
      aiResponses: aiResponses,
      managerResponses: managerResponses,
      uniqueCustomers: uniqueCustomers.length,
      todayMessages: todayMessages,
      thisWeekMessages: thisWeekMessages,
      thisMonthMessages: thisMonthMessages,
      last7Days: last7Days,
      topCustomers: topCustomers,
    );
  }

  /// Fetch broadcasts analytics
  Future<void> _fetchBroadcastsAnalytics() async {
    // Check if broadcasts is configured
    if (!ClientConfig.isBroadcastsConfigured) {
      _error = 'Broadcasts not configured';
      return;
    }

    final tableName = ClientConfig.broadcastsTableName;

    // Fetch broadcasts from dynamic table
    final broadcastsResponse = await SupabaseService.client
        .from(tableName)
        .select('id, campaign_name, message_content, total_recipients, sent_at')
        .order('sent_at', ascending: false);

    final broadcasts = broadcastsResponse as List;

    // Calculate statistics
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int totalRecipients = 0;
    int totalCampaigns = broadcasts.length;
    int todayRecipients = 0;
    int thisWeekRecipients = 0;
    int thisMonthRecipients = 0;
    Map<String, int> dailyCounts = {};

    for (final b in broadcasts) {
      final recipients = (b['total_recipients'] ?? 0) as int;
      final sentAt = b['sent_at'] != null ? DateTime.parse(b['sent_at']) : now;

      totalRecipients += recipients;

      // Time-based counts
      if (sentAt.isAfter(todayStart)) {
        todayRecipients += recipients;
      }
      if (sentAt.isAfter(weekStart)) {
        thisWeekRecipients += recipients;
      }
      if (sentAt.isAfter(monthStart)) {
        thisMonthRecipients += recipients;
      }

      // Daily activity
      final dateKey = '${sentAt.year}-${sentAt.month.toString().padLeft(2, '0')}-${sentAt.day.toString().padLeft(2, '0')}';
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + recipients;
    }

    // Build last 7 days activity
    List<DailyActivity> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      final date = todayStart.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      last7Days.add(DailyActivity(date: date, count: dailyCounts[dateKey] ?? 0));
    }

    // Top broadcasts by recipient count
    final sortedBroadcasts = broadcasts
        .where((b) => (b['total_recipients'] ?? 0) > 0)
        .toList()
      ..sort((a, b) => ((b['total_recipients'] ?? 0) as int).compareTo((a['total_recipients'] ?? 0) as int));

    List<TopCustomer> topBroadcasts = sortedBroadcasts.take(5).map((b) {
      return TopCustomer(
        phone: b['id'].toString(),
        name: b['campaign_name'] as String?,
        messageCount: (b['total_recipients'] ?? 0) as int,
      );
    }).toList();

    // Fetch recipients for delivery stats
    int totalSent = 0;
    int totalFailed = 0;
    try {
      final recipientsTable = tableName != 'broadcasts'
          ? '${tableName.replaceAll('_broadcasts', '')}_broadcast_recipients'
          : 'broadcast_recipients';

      final recipientsResponse = await SupabaseService.client
          .from(recipientsTable)
          .select('status');

      final allRecipients = recipientsResponse as List;
      for (final r in allRecipients) {
        if (r['status']?.toString() == 'accepted') {
          totalSent++;
        } else {
          totalFailed++;
        }
      }
    } catch (e) {
      print('Error fetching broadcast recipients for delivery stats: $e');
    }

    final totalRecipientsCount = totalSent + totalFailed;
    final deliveryRate = totalRecipientsCount > 0
        ? totalSent / totalRecipientsCount * 100
        : 0.0;

    _analytics = AnalyticsData(
      totalMessages: totalRecipients,     // Total recipients reached
      aiResponses: totalCampaigns,        // Total campaigns
      managerResponses: 0,                // Not tracked
      uniqueCustomers: totalCampaigns,    // Number of campaigns
      todayMessages: todayRecipients,
      thisWeekMessages: thisWeekRecipients,
      thisMonthMessages: thisMonthRecipients,
      last7Days: last7Days,
      topCustomers: topBroadcasts,        // Top broadcasts by recipients
      totalSent: totalSent,
      totalFailed: totalFailed,
      deliveryRate: deliveryRate,
    );
  }

  /// Clear analytics data
  void clear() {
    _analytics = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

/// Analytics data model
class AnalyticsData {
  final int totalMessages;
  final int aiResponses;
  final int managerResponses;
  final int uniqueCustomers;
  final int todayMessages;
  final int thisWeekMessages;
  final int thisMonthMessages;
  final List<DailyActivity> last7Days;
  final List<TopCustomer> topCustomers;
  // Broadcast delivery stats
  final int totalSent;
  final int totalFailed;
  final double deliveryRate;

  AnalyticsData({
    required this.totalMessages,
    required this.aiResponses,
    required this.managerResponses,
    required this.uniqueCustomers,
    required this.todayMessages,
    required this.thisWeekMessages,
    required this.thisMonthMessages,
    required this.last7Days,
    required this.topCustomers,
    this.totalSent = 0,
    this.totalFailed = 0,
    this.deliveryRate = 0.0,
  });
}

/// Daily activity data point
class DailyActivity {
  final DateTime date;
  final int count;

  DailyActivity({required this.date, required this.count});
}

/// Top customer data
class TopCustomer {
  final String phone;
  final String? name;
  final int messageCount;

  TopCustomer({
    required this.phone,
    this.name,
    required this.messageCount,
  });

  String get displayName => name ?? phone;
}