import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'roi_analytics_provider.dart' show OpenConversation;

// ================================================================
// DATA MODELS
// ================================================================

class ChatbotDailyBreakdown {
  final String date; // YYYY-MM-DD (Bahrain timezone)
  final int conversations; // distinct phones with any activity
  final int aiReplies;
  final int humanReplies;

  const ChatbotDailyBreakdown({
    required this.date,
    required this.conversations,
    required this.aiReplies,
    required this.humanReplies,
  });
}

class ChatbotConversationEntry {
  final String phone;
  final String? name;
  final DateTime firstMessageAt;
  final int messageCount;
  final bool isAiHandled;
  final bool isHumanTakeover;
  final double? avgResponseSeconds;
  final String? agentName;
  final bool hasUnreplied;

  const ChatbotConversationEntry({
    required this.phone,
    this.name,
    required this.firstMessageAt,
    required this.messageCount,
    required this.isAiHandled,
    required this.isHumanTakeover,
    this.avgResponseSeconds,
    this.agentName,
    required this.hasUnreplied,
  });
}

class ChatbotAnalyticsData {
  final int totalConversations;
  final int aiHandled;
  final int humanTakeover;
  final double avgResponseTimeSeconds;
  final List<ChatbotDailyBreakdown> daily;
  final List<OpenConversation> openConversations;
  final List<OpenConversation> overdueConversations;
  final List<ChatbotConversationEntry> allConversations;

  const ChatbotAnalyticsData({
    required this.totalConversations,
    required this.aiHandled,
    required this.humanTakeover,
    required this.avgResponseTimeSeconds,
    required this.daily,
    required this.openConversations,
    required this.overdueConversations,
    required this.allConversations,
  });

  double get aiResolutionRate =>
      totalConversations > 0 ? (aiHandled / totalConversations) * 100 : 0;

  double get handoffRate =>
      totalConversations > 0 ? (humanTakeover / totalConversations) * 100 : 0;
}

// ================================================================
// PROVIDER
// ================================================================

class ChatbotAnalyticsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseService.adminClient;

  bool _isLoading = false;
  String? _error;
  ChatbotAnalyticsData? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  ChatbotAnalyticsData? get data => _data;

  Future<void> fetchAnalytics({
    required String? messagesTable,
    DateTime? startDate,
    DateTime? endDate,
    Duration overdueThreshold = const Duration(minutes: 30),
  }) async {
    if (messagesTable == null || messagesTable.isEmpty) {
      _error = 'Messages table not configured';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ---- Fetch all rows (paginated) ----
      // Schema: each row is ONE EXCHANGE — customer_message (inbound) +
      // ai_response and/or manager_response (outbound) in the SAME row.
      // Timestamps: customer_sent_at, ai_responded_at, created_at.
      List<Map<String, dynamic>> messages = [];
      const pageSize = 1000;
      int from = 0;
      while (true) {
        var q = _supabase.from(messagesTable).select();
        if (startDate != null) q = q.gte('created_at', startDate.toIso8601String());
        if (endDate != null) q = q.lte('created_at', endDate.toIso8601String());
        final raw = await q
            .order('created_at', ascending: true)
            .range(from, from + pageSize - 1);
        final rows = List<Map<String, dynamic>>.from(raw);
        messages.addAll(rows);
        if (rows.length < pageSize) break;
        from += pageSize;
      }

      // ---- Group by customer phone ----
      final Map<String, List<Map<String, dynamic>>> byPhone = {};
      for (final m in messages) {
        final phone = m['customer_phone']?.toString() ?? '';
        if (phone.isEmpty) continue;
        byPhone.putIfAbsent(phone, () => []).add(m);
      }

      final now = DateTime.now();
      final int totalConversations = byPhone.length;
      int aiHandled = 0;
      int humanTakeover = 0;
      final List<double> responseTimes = []; // global avg
      final List<OpenConversation> openConvs = [];
      final List<ChatbotConversationEntry> allConvEntries = [];

      for (final entry in byPhone.entries) {
        final phone = entry.key;
        final msgs = entry.value; // sorted ascending by created_at

        // ---- Classify conversation ----
        // Human Takeover: any row has manager_response filled
        // AI Handled: no manager_response anywhere AND at least one ai_response
        //             AND every row that has a customer_message was replied to
        bool anyHumanReply = false;
        bool anyAiReply = false;
        bool allCustomerMsgsAnswered = true;

        for (final m in msgs) {
          final hasCustomer = _hasCustomerMessage(m);
          final hasAi = _hasAiResponse(m);
          final hasManager = _hasManagerResponse(m);
          if (hasManager) anyHumanReply = true;
          if (hasAi) anyAiReply = true;
          if (hasCustomer && !hasAi && !hasManager) allCustomerMsgsAnswered = false;
        }

        final bool isHumanTakeover = anyHumanReply;
        final bool isAiHandled = !anyHumanReply && anyAiReply && allCustomerMsgsAnswered;

        if (isHumanTakeover) {
          humanTakeover++;
        } else if (isAiHandled) {
          aiHandled++;
        }

        // ---- Response time: ai_responded_at − customer_sent_at per row ----
        final List<double> convRespTimes = [];
        for (final m in msgs) {
          final sentAt = _parseDateField(m, 'customer_sent_at');
          final respondedAt = _parseDateField(m, 'ai_responded_at');
          if (sentAt == null || respondedAt == null) continue;
          final diffSec = respondedAt.difference(sentAt).inSeconds.toDouble();
          if (diffSec > 0 && diffSec <= 86400) {
            responseTimes.add(diffSec);
            convRespTimes.add(diffSec);
          }
        }
        final double? convAvgResp = convRespTimes.isNotEmpty
            ? convRespTimes.reduce((a, b) => a + b) / convRespTimes.length
            : null;

        // ---- Awaiting reply: latest customer_message row with no response ----
        Map<String, dynamic>? lastUnansweredRow;
        DateTime? lastUnansweredTime;
        for (final m in msgs) {
          if (!_hasCustomerMessage(m)) continue;
          if (_hasAiResponse(m) || _hasManagerResponse(m)) continue;
          final t = _parseDateField(m, 'created_at');
          if (t == null) continue;
          if (lastUnansweredTime == null || t.isAfter(lastUnansweredTime)) {
            lastUnansweredTime = t;
            lastUnansweredRow = m;
          }
        }
        final bool hasUnreplied = lastUnansweredRow != null;

        if (hasUnreplied && lastUnansweredTime != null) {
          openConvs.add(OpenConversation(
            customerPhone: phone,
            customerName: lastUnansweredRow['customer_name']?.toString(),
            lastMessage: lastUnansweredRow['customer_message']?.toString() ?? '',
            lastMessageAt: lastUnansweredTime,
            waitingTime: now.difference(lastUnansweredTime),
          ));
        }

        // ---- Customer name (first non-empty) ----
        String? convName;
        for (final m in msgs) {
          final n = m['customer_name']?.toString() ?? '';
          if (n.isNotEmpty) {
            convName = n;
            break;
          }
        }

        allConvEntries.add(ChatbotConversationEntry(
          phone: phone,
          name: convName,
          firstMessageAt: _parseDateField(msgs.first, 'created_at') ?? now,
          messageCount: msgs.length,
          isAiHandled: isAiHandled,
          isHumanTakeover: isHumanTakeover,
          avgResponseSeconds: convAvgResp,
          agentName: null,
          hasUnreplied: hasUnreplied,
        ));
      }

      final overdueConvs =
          openConvs.where((c) => c.waitingTime >= overdueThreshold).toList();
      final double avgResponseTime = responseTimes.isNotEmpty
          ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
          : 0.0;

      // ---- Daily breakdown ----
      final Map<String, _DayAcc> dailyAcc = {};
      for (final m in messages) {
        final createdAt = _parseDateField(m, 'created_at');
        if (createdAt == null) continue;
        final bt = createdAt.toUtc().add(const Duration(hours: 3));
        final day =
            '${bt.year}-${bt.month.toString().padLeft(2, '0')}-${bt.day.toString().padLeft(2, '0')}';
        dailyAcc.putIfAbsent(day, () => _DayAcc());
        final acc = dailyAcc[day]!;
        final phone = m['customer_phone']?.toString() ?? '';
        if (phone.isNotEmpty) acc.phones.add(phone);
        // Count AI vs human replies
        if (_hasAiResponse(m) && !_hasManagerResponse(m)) {
          acc.aiReplies++;
        } else if (_hasManagerResponse(m)) {
          acc.humanReplies++;
        }
      }

      // Fill missing days between startDate and endDate
      final List<ChatbotDailyBreakdown> daily = [];
      if (startDate != null && endDate != null) {
        var cursor = startDate;
        while (!cursor.isAfter(endDate)) {
          final key =
              '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
          final acc = dailyAcc[key];
          daily.add(ChatbotDailyBreakdown(
            date: key,
            conversations: acc?.phones.length ?? 0,
            aiReplies: acc?.aiReplies ?? 0,
            humanReplies: acc?.humanReplies ?? 0,
          ));
          cursor = cursor.add(const Duration(days: 1));
        }
      } else {
        final sortedKeys = dailyAcc.keys.toList()..sort();
        for (final key in sortedKeys) {
          final acc = dailyAcc[key]!;
          daily.add(ChatbotDailyBreakdown(
            date: key,
            conversations: acc.phones.length,
            aiReplies: acc.aiReplies,
            humanReplies: acc.humanReplies,
          ));
        }
      }

      debugPrint('=== CHATBOT ANALYTICS ===');
      debugPrint('Total: $totalConversations | AI: $aiHandled | Human: $humanTakeover');
      debugPrint('Open: ${openConvs.length} | Overdue: ${overdueConvs.length}');
      debugPrint('Avg response: ${avgResponseTime.toStringAsFixed(1)}s');
      debugPrint('=========================');

      _data = ChatbotAnalyticsData(
        totalConversations: totalConversations,
        aiHandled: aiHandled,
        humanTakeover: humanTakeover,
        avgResponseTimeSeconds: avgResponseTime,
        daily: daily,
        openConversations: openConvs,
        overdueConversations: overdueConvs,
        allConversations: allConvEntries,
      );
    } catch (e, st) {
      _error = 'Failed to load chatbot analytics: $e';
      debugPrint('ChatbotAnalytics error: $e\n$st');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---- Helpers ----

  bool _hasCustomerMessage(Map<String, dynamic> m) =>
      (m['customer_message']?.toString() ?? '').trim().isNotEmpty;

  bool _hasAiResponse(Map<String, dynamic> m) =>
      (m['ai_response']?.toString() ?? '').trim().isNotEmpty;

  bool _hasManagerResponse(Map<String, dynamic> m) =>
      (m['manager_response']?.toString() ?? '').trim().isNotEmpty;

  DateTime? _parseDateField(Map<String, dynamic> m, String field) =>
      DateTime.tryParse(m[field]?.toString() ?? '');
}

class _DayAcc {
  final Set<String> phones = {};
  int aiReplies = 0;
  int humanReplies = 0;
}
