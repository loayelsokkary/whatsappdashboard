import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Analytics data models
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
  });
}

class DailyActivity {
  final DateTime date;
  final int count;

  DailyActivity({required this.date, required this.count});
}

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

/// Provider for analytics data
class AnalyticsProvider extends ChangeNotifier {
  AnalyticsData? _analytics;
  bool _isLoading = false;
  String? _error;

  AnalyticsData? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> fetchAnalytics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final businessPhone = ClientConfig.businessPhone;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Fetch all messages for this business
      final response = await _client
          .from('messages')
          .select()
          .eq('ai_phone', businessPhone)
          .order('created_at', ascending: false);

      final messages = response as List;

      // Calculate stats
      final totalMessages = messages.length;
      
      // Count AI responses (non-empty ai_response)
      final aiResponses = messages.where((m) => 
          m['ai_response'] != null && 
          m['ai_response'].toString().trim().isNotEmpty).length;
      
      // Count manager responses (non-empty manager_response)
      final managerResponses = messages.where((m) => 
          m['manager_response'] != null && 
          m['manager_response'].toString().trim().isNotEmpty).length;

      // Unique customers
      final uniquePhones = messages
          .map((m) => m['customer_phone'] as String)
          .toSet();
      final uniqueCustomers = uniquePhones.length;

      // Today's messages
      final todayMessages = messages.where((m) {
        final createdAt = DateTime.parse(m['created_at']);
        return createdAt.isAfter(todayStart);
      }).length;

      // This week's messages
      final thisWeekMessages = messages.where((m) {
        final createdAt = DateTime.parse(m['created_at']);
        return createdAt.isAfter(weekStart);
      }).length;

      // This month's messages
      final thisMonthMessages = messages.where((m) {
        final createdAt = DateTime.parse(m['created_at']);
        return createdAt.isAfter(monthStart);
      }).length;

      // Last 7 days activity
      final last7Days = List.generate(7, (i) {
        final date = todayStart.subtract(Duration(days: 6 - i));
        final nextDate = date.add(const Duration(days: 1));
        final count = messages.where((m) {
          final createdAt = DateTime.parse(m['created_at']);
          return createdAt.isAfter(date) && createdAt.isBefore(nextDate);
        }).length;
        return DailyActivity(date: date, count: count);
      });

      // Top customers
      final customerCounts = <String, Map<String, dynamic>>{};
      for (final m in messages) {
        final phone = m['customer_phone'] as String;
        final name = m['customer_name'] as String?;
        if (!customerCounts.containsKey(phone)) {
          customerCounts[phone] = {'name': name, 'count': 0};
        }
        customerCounts[phone]!['count'] = (customerCounts[phone]!['count'] as int) + 1;
        // Update name if we have one
        if (name != null && name.isNotEmpty) {
          customerCounts[phone]!['name'] = name;
        }
      }

      final topCustomers = customerCounts.entries
          .map((e) => TopCustomer(
                phone: e.key,
                name: e.value['name'] as String?,
                messageCount: e.value['count'] as int,
              ))
          .toList()
        ..sort((a, b) => b.messageCount.compareTo(a.messageCount));

      _analytics = AnalyticsData(
        totalMessages: totalMessages,
        aiResponses: aiResponses,
        managerResponses: managerResponses,
        uniqueCustomers: uniqueCustomers,
        todayMessages: todayMessages,
        thisWeekMessages: thisWeekMessages,
        thisMonthMessages: thisMonthMessages,
        last7Days: last7Days,
        topCustomers: topCustomers.take(5).toList(),
      );

    } catch (e) {
      _error = 'Failed to load analytics: $e';
      print('Analytics error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}