import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// ROI ANALYTICS PROVIDER v4 — Full Rewrite
// ============================================================

class RoiAnalyticsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  AnalyticsData? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  AnalyticsData? get data => _data;

  Future<void> fetchAnalytics({
    required String clientId,
    required String? messagesTable,
    required String? broadcastsTable,
    DateTime? startDate,
    DateTime? endDate,
    String? campaignId,
    DateTime? compareStartDate,
    DateTime? compareEndDate,
    Duration overdueThreshold = const Duration(minutes: 30),
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ------- Fetch messages (paginated — Supabase default limit is 1000) -------
      List<Map<String, dynamic>> messages = [];
      if (messagesTable != null) {
        const pageSize = 1000;
        int from = 0;
        while (true) {
          var q = _supabase.from(messagesTable).select();
          if (startDate != null) {
            q = q.gte('created_at', startDate.toIso8601String());
          }
          if (endDate != null) {
            q = q.lte('created_at', endDate.toIso8601String());
          }
          final raw = await q
              .order('created_at', ascending: true)
              .range(from, from + pageSize - 1);
          final rows = List<Map<String, dynamic>>.from(raw);
          messages.addAll(rows);
          if (rows.length < pageSize) break;
          from += pageSize;
        }
      }

      // ------- Fetch campaigns + recipients -------
      List<Map<String, dynamic>> campaigns = [];
      List<Map<String, dynamic>> recipients = [];
      if (broadcastsTable != null) {
        campaigns = List<Map<String, dynamic>>.from(
          await _supabase
              .from(broadcastsTable)
              .select()
              .eq('client_id', clientId)
              .order('sent_at', ascending: false),
        );

        if (campaigns.isNotEmpty) {
          final recipientsTable =
              broadcastsTable.replaceAll('broadcasts', 'broadcast_recipients');
          final cIds = campaigns.map((c) => c['id']).toList();
          // Paginate recipients (can exceed 1000)
          const rPageSize = 1000;
          int rFrom = 0;
          while (true) {
            final rRaw = await _supabase
                .from(recipientsTable)
                .select()
                .inFilter('broadcast_id', cIds)
                .range(rFrom, rFrom + rPageSize - 1);
            final rows = List<Map<String, dynamic>>.from(rRaw);
            recipients.addAll(rows);
            if (rows.length < rPageSize) break;
            rFrom += rPageSize;
          }
        }
      }

      // ------- Filter out broadcast copies -------
      int broadcastsSkipped = 0;
      final filtered = <Map<String, dynamic>>[];
      for (final m in messages) {
        final sb = (m['sent_by']?.toString() ?? '').toLowerCase().trim();
        if (sb == 'broadcast') {
          broadcastsSkipped++;
          continue;
        }
        filtered.add(m);
      }

      // ------- Build campaign lookups -------
      final Map<String, Set<String>> campaignPhones = {};
      final Map<String, List<String>> phoneCampaigns = {};
      final Map<String, Map<String, dynamic>> campaignById = {};
      final Map<String, DateTime> campaignSentAt = {};

      for (final c in campaigns) {
        final cId = c['id']?.toString() ?? '';
        campaignById[cId] = c;
        final sentAt = c['sent_at'] != null
            ? DateTime.tryParse(c['sent_at'].toString())
            : null;
        if (sentAt != null) campaignSentAt[cId] = sentAt;
        campaignPhones[cId] = {};
      }
      for (final r in recipients) {
        final cId = r['broadcast_id']?.toString() ?? '';
        final phone = r['customer_phone']?.toString() ?? '';
        if (phone.isEmpty) continue;
        campaignPhones[cId]?.add(phone);
        phoneCampaigns.putIfAbsent(phone, () => []).add(cId);
      }

      // ------- Determine which messages to use -------
      List<Map<String, dynamic>> workingMessages = filtered;

      // If campaignId filter, only include messages from attributed customers
      if (campaignId != null) {
        final attributedPhones = campaignPhones[campaignId] ?? {};
        final cSentAt = campaignSentAt[campaignId];
        workingMessages = filtered.where((m) {
          final phone = m['customer_phone']?.toString() ?? '';
          if (!attributedPhones.contains(phone)) return false;
          if (cSentAt != null) {
            final createdAt = _parseDate(m);
            if (createdAt != null && createdAt.isBefore(cSentAt)) return false;
          }
          return true;
        }).toList();
      }

      // ------- Compute current period -------
      final now = DateTime.now();
      final current = _computeMetrics(
        messages: workingMessages,
        campaignById: campaignById,
        campaignPhones: campaignPhones,
        phoneCampaigns: phoneCampaigns,
        campaignSentAt: campaignSentAt,
        overdueThreshold: overdueThreshold,
        now: now,
      );

      // ------- Compute comparison period (paginated) -------
      _ComputedMetrics? comparison;
      if (compareStartDate != null &&
          compareEndDate != null &&
          messagesTable != null) {
        List<Map<String, dynamic>> compMessages = [];
        const compPageSize = 1000;
        int compFrom = 0;
        while (true) {
          var cq = _supabase.from(messagesTable).select();
          cq = cq.gte('created_at', compareStartDate.toIso8601String());
          cq = cq.lte('created_at', compareEndDate.toIso8601String());
          final compRaw = await cq
              .order('created_at', ascending: true)
              .range(compFrom, compFrom + compPageSize - 1);
          final rows = List<Map<String, dynamic>>.from(compRaw);
          compMessages.addAll(rows);
          if (rows.length < compPageSize) break;
          compFrom += compPageSize;
        }

        int compSkipped = 0;
        final compFiltered = <Map<String, dynamic>>[];
        for (final m in compMessages) {
          final sb = (m['sent_by']?.toString() ?? '').toLowerCase().trim();
          if (sb == 'broadcast') {
            compSkipped++;
            continue;
          }
          compFiltered.add(m);
        }
        debugPrint(
            'Comparison period: ${compFiltered.length} msgs (skipped $compSkipped broadcasts)');

        List<Map<String, dynamic>> compWorking = compFiltered;
        if (campaignId != null) {
          final attributedPhones = campaignPhones[campaignId] ?? {};
          final cSentAt = campaignSentAt[campaignId];
          compWorking = compFiltered.where((m) {
            final phone = m['customer_phone']?.toString() ?? '';
            if (!attributedPhones.contains(phone)) return false;
            if (cSentAt != null) {
              final createdAt = _parseDate(m);
              if (createdAt != null && createdAt.isBefore(cSentAt)) return false;
            }
            return true;
          }).toList();
        }

        comparison = _computeMetrics(
          messages: compWorking,
          campaignById: campaignById,
          campaignPhones: campaignPhones,
          phoneCampaigns: phoneCampaigns,
          campaignSentAt: campaignSentAt,
          overdueThreshold: overdueThreshold,
          now: now,
        );
      }

      // ------- Campaign performance -------
      final campaignPerformance = _buildCampaignPerformance(
        campaigns: campaigns,
        recipients: recipients,
        messages: filtered,
        campaignById: campaignById,
        campaignPhones: campaignPhones,
        campaignSentAt: campaignSentAt,
      );

      // ------- Debug output -------
      final ov = current.overview;
      final leadCount = ov.leads;
      final totalRevenue = ov.revenue;
      final engagementRate = ov.engagementRate;
      final avgResponseTime = ov.avgResponseTimeSeconds;
      final openCount = ov.openConversationCount;
      final overdueCount = ov.overdueConversationCount;
      final messagesSent = ov.messagesSent;
      final messagesReceived = ov.messagesReceived;

      debugPrint('=== ANALYTICS PROVIDER v4 ===');
      debugPrint(
          'Table: $messagesTable | Total rows: ${messages.length} | Skipped broadcasts: $broadcastsSkipped');
      debugPrint('Leads: $leadCount | Revenue: $totalRevenue BHD');
      debugPrint(
          'Engagement: ${engagementRate.toStringAsFixed(1)}% (${current.inboundCustomerCount} inbound / ${current.outboundCount} broadcasts sent)');
      debugPrint(
          'Avg Response: ${avgResponseTime.toStringAsFixed(0)}s | Open: $openCount | Overdue: $overdueCount');
      debugPrint('Messages Sent: $messagesSent | Received: $messagesReceived');
      debugPrint('Campaigns: ${campaignPerformance.length}');
      debugPrint('=============================');

      // ------- Assemble data -------
      _data = AnalyticsData(
        current: ov,
        comparison: comparison?.overview,
        dailyBreakdown:
            _fillMissingDays(current.daily, startDate, endDate),
        comparisonDailyBreakdown: comparison != null
            ? _fillMissingDays(
                comparison.daily, compareStartDate, compareEndDate)
            : null,
        campaigns: campaignPerformance,
        openConversations: current.open,
        overdueConversations: current.overdue,
        labeledCustomers: current.labeledCustomers,
      );
    } catch (e, st) {
      _error = 'Failed to load analytics: $e';
      debugPrint('ROI Analytics error: $e\n$st');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // CORE METRIC COMPUTATION
  // ============================================================

  _ComputedMetrics _computeMetrics({
    required List<Map<String, dynamic>> messages,
    required Map<String, Map<String, dynamic>> campaignById,
    required Map<String, Set<String>> campaignPhones,
    required Map<String, List<String>> phoneCampaigns,
    required Map<String, DateTime> campaignSentAt,
    required Duration overdueThreshold,
    required DateTime now,
  }) {
    // --- Group by customer_phone (already sorted by created_at asc) ---
    final Map<String, List<Map<String, dynamic>>> byPhone = {};
    for (final m in messages) {
      final phone = m['customer_phone']?.toString() ?? '';
      if (phone.isEmpty) continue;
      byPhone.putIfAbsent(phone, () => []).add(m);
    }

    // ---- LEADS: 24h gap rule ----
    int totalLeads = 0;
    int organicLeads = 0;
    for (final entry in byPhone.entries) {
      final phone = entry.key;
      final msgs = entry.value;
      final isFromBroadcast = phoneCampaigns.containsKey(phone);
      DateTime? lastCM;
      for (final m in msgs) {
        if (!_hasCustomerMessage(m)) continue;
        final createdAt = _parseDate(m);
        if (createdAt == null) continue;
        if (lastCM == null || createdAt.difference(lastCM).inHours >= 24) {
          totalLeads++;
          if (!isFromBroadcast) organicLeads++;
        }
        lastCM = createdAt;
      }
    }

    // ---- REVENUE: label-based × offer_amount ----
    double totalRevenue = 0;
    int appointmentsBooked = 0;
    int paymentsDone = 0;
    final revenueLabels = {'appointment booked', 'payment done'};
    // First customer_message per phone (for campaign attribution)
    final Map<String, DateTime> phoneFirstMsg = {};
    for (final entry in byPhone.entries) {
      for (final m in entry.value) {
        if (!_hasCustomerMessage(m)) continue;
        final t = _parseDate(m);
        if (t == null) continue;
        phoneFirstMsg.putIfAbsent(entry.key, () => t);
        break;
      }
    }

    // Collect all label events with their attribution date (label_set_at or created_at)
    final List<Map<String, dynamic>> labelEvents = [];
    for (final entry in byPhone.entries) {
      final phone = entry.key;
      for (final m in entry.value) {
        final label = (m['label']?.toString() ?? '').toLowerCase().trim();
        if (!revenueLabels.contains(label)) continue;
        // Use label_set_at as the attribution date; fall back to created_at
        final labelSetAt = m['label_set_at'] != null
            ? DateTime.tryParse(m['label_set_at'].toString())
            : null;
        final attributionDate = labelSetAt ?? _parseDate(m);
        labelEvents.add({'phone': phone, 'label': label, 'attribution_date': attributionDate, 'message': m});
      }
    }

    final List<LabeledCustomer> labeledCustomers = [];
    for (final evt in labelEvents) {
      final label = evt['label'] as String;
      final phone = evt['phone'] as String;
      final msg = evt['message'] as Map<String, dynamic>;
      final attrDate = evt['attribution_date'] as DateTime?;
      if (label == 'appointment booked') appointmentsBooked++;
      if (label == 'payment done') paymentsDone++;

      labeledCustomers.add(LabeledCustomer(
        phone: phone,
        name: msg['customer_name']?.toString(),
        label: label,
        date: attrDate ?? DateTime.now(),
      ));

      final cIds = phoneCampaigns[phone] ?? [];
      double offer = 0;
      for (final cId in cIds) {
        final sentAt = campaignSentAt[cId];
        final firstMsg = phoneFirstMsg[phone];
        if (sentAt != null &&
            firstMsg != null &&
            firstMsg.isAfter(sentAt)) {
          offer = double.tryParse(
                  campaignById[cId]?['offer_amount']?.toString() ?? '0') ??
              0;
          break;
        }
      }
      totalRevenue += offer;
    }

    // ---- ENGAGEMENT RATE (inbound messages / total broadcasts sent) ----
    int inboundMessageCount = 0;
    int totalBroadcastsSent = 0;
    for (final phones in campaignPhones.values) {
      totalBroadcastsSent += phones.length;
    }
    for (final m in messages) {
      if (_hasCustomerMessage(m)) inboundMessageCount++;
    }
    final engagementRate = totalBroadcastsSent > 0
        ? (inboundMessageCount / totalBroadcastsSent) * 100
        : 0.0;

    // ---- AVG RESPONSE TIME (capped at 24h / 86400s) ----
    final List<double> responseTimes = [];
    final Map<String, List<double>> responseTimesByEmployee = {};
    for (final entry in byPhone.entries) {
      final msgs = entry.value;
      for (int i = 0; i < msgs.length; i++) {
        if (!_hasCustomerMessage(msgs[i])) continue;
        final cmTime = _parseDate(msgs[i]);
        if (cmTime == null) continue;
        for (int j = i + 1; j < msgs.length; j++) {
          if (!_isHumanOutbound(msgs[j])) continue;
          final mrTime = _parseDate(msgs[j]);
          if (mrTime == null) continue;
          final diffSec = mrTime.difference(cmTime).inSeconds.toDouble();
          if (diffSec > 0 && diffSec <= 86400) {
            responseTimes.add(diffSec);
            final employee = (msgs[j]['sent_by']?.toString() ?? '').trim();
            if (employee.isNotEmpty) {
              responseTimesByEmployee.putIfAbsent(employee, () => []).add(diffSec);
            }
          }
          break;
        }
      }
    }
    final avgResponseTime = responseTimes.isNotEmpty
        ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
        : 0.0;

    // ---- PER-EMPLOYEE AVG RESPONSE TIME ----
    final Map<String, double> employeeAvgResponseTime = {};
    for (final entry in responseTimesByEmployee.entries) {
      final times = entry.value;
      employeeAvgResponseTime[entry.key] =
          times.reduce((a, b) => a + b) / times.length;
    }

    // ---- OPEN & OVERDUE CONVERSATIONS ----
    final List<OpenConversation> openConvs = [];
    for (final entry in byPhone.entries) {
      final msgs = entry.value;
      if (msgs.isEmpty) continue;
      final last = msgs.last;
      final hasCM = _hasCustomerMessage(last);
      final hasMR = last['manager_response'] != null &&
          last['manager_response'].toString().trim().isNotEmpty;
      if (hasCM && !hasMR) {
        final t = _parseDate(last);
        if (t != null) {
          openConvs.add(OpenConversation(
            customerPhone: entry.key,
            customerName: last['customer_name']?.toString(),
            lastMessage: last['customer_message']?.toString() ?? '',
            lastMessageAt: t,
            waitingTime: now.difference(t),
          ));
        }
      }
    }
    final overdueConvs =
        openConvs.where((c) => c.waitingTime >= overdueThreshold).toList();

    // ---- MESSAGES SENT / RECEIVED ----
    int messagesSent = 0;
    int messagesReceived = 0;
    for (final m in messages) {
      if (_isHumanOutbound(m)) messagesSent++;
      if (_hasCustomerMessage(m)) messagesReceived++;
    }

    // ---- DAILY BREAKDOWN (UTC+3 Bahrain) ----
    final Map<String, _DayAccumulator> dailyAcc = {};
    final Map<String, DateTime?> phoneDailyLastCM = {};

    for (final m in messages) {
      final createdAt = _parseDate(m);
      if (createdAt == null) continue;
      // Convert to Bahrain timezone (UTC+3)
      final bahrainTime = createdAt.toUtc().add(const Duration(hours: 3));
      final dayKey =
          '${bahrainTime.year}-${bahrainTime.month.toString().padLeft(2, '0')}-${bahrainTime.day.toString().padLeft(2, '0')}';
      dailyAcc.putIfAbsent(dayKey, () => _DayAccumulator());
      final acc = dailyAcc[dayKey]!;
      final phone = m['customer_phone']?.toString() ?? '';
      final hasCM = _hasCustomerMessage(m);

      if (hasCM && phone.isNotEmpty) {
        acc.received++;
        acc.repliedPhones.add(phone);

        // Daily leads (24h gap)
        final lastCM = phoneDailyLastCM[phone];
        if (lastCM == null || createdAt.difference(lastCM).inHours >= 24) {
          acc.leads++;
        }
        phoneDailyLastCM[phone] = createdAt;
      }

      if (_isHumanOutbound(m)) {
        acc.sent++;
        if (phone.isNotEmpty) acc.engagedPhones.add(phone);
      }

      // Daily revenue is attributed separately below using label_set_at

      // Daily response time
      if (hasCM && phone.isNotEmpty) {
        final phoneMsgs = byPhone[phone];
        if (phoneMsgs != null) {
          final idx = phoneMsgs.indexOf(m);
          if (idx >= 0) {
            for (int j = idx + 1; j < phoneMsgs.length; j++) {
              if (!_isHumanOutbound(phoneMsgs[j])) continue;
              final nextAt = _parseDate(phoneMsgs[j]);
              if (nextAt != null) {
                final diffSec =
                    nextAt.difference(createdAt).inSeconds.toDouble();
                if (diffSec > 0 && diffSec <= 86400) {
                  acc.responseTimes.add(diffSec);
                }
              }
              break;
            }
          }
        }
      }
    }

    // Attribute daily revenue using label_set_at (not message created_at)
    for (final evt in labelEvents) {
      final attributionDate = evt['attribution_date'] as DateTime?;
      if (attributionDate == null) continue;
      final phone = evt['phone'] as String;
      final bahrainTime = attributionDate.toUtc().add(const Duration(hours: 3));
      final dayKey =
          '${bahrainTime.year}-${bahrainTime.month.toString().padLeft(2, '0')}-${bahrainTime.day.toString().padLeft(2, '0')}';
      dailyAcc.putIfAbsent(dayKey, () => _DayAccumulator());
      final acc = dailyAcc[dayKey]!;
      final cIds = phoneCampaigns[phone] ?? [];
      double offer = 0;
      for (final cId in cIds) {
        final sentAt = campaignSentAt[cId];
        final firstMsg = phoneFirstMsg[phone];
        if (sentAt != null && firstMsg != null && firstMsg.isAfter(sentAt)) {
          offer = double.tryParse(
                  campaignById[cId]?['offer_amount']?.toString() ?? '0') ??
              0;
          break;
        }
      }
      acc.revenue += offer;
    }

    final dailyBreakdown = dailyAcc.entries.map((e) {
      final a = e.value;
      final avgRT = a.responseTimes.isNotEmpty
          ? a.responseTimes.reduce((x, y) => x + y) / a.responseTimes.length
          : 0.0;
      final er = totalBroadcastsSent > 0
          ? (a.received / totalBroadcastsSent) * 100
          : 0.0;
      return DailyBreakdown(
        date: e.key,
        leads: a.leads,
        revenue: a.revenue,
        engagementRate: er,
        avgResponseTimeSeconds: avgRT,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return _ComputedMetrics(
      overview: OverviewMetrics(
        leads: totalLeads,
        organicLeads: organicLeads,
        revenue: totalRevenue,
        appointmentsBooked: appointmentsBooked,
        paymentsDone: paymentsDone,
        engagementRate: engagementRate,
        avgResponseTimeSeconds: avgResponseTime,
        employeeAvgResponseTime: employeeAvgResponseTime,
        openConversationCount: openConvs.length,
        overdueConversationCount: overdueConvs.length,
        messagesSent: messagesSent,
        messagesReceived: messagesReceived,
      ),
      daily: dailyBreakdown,
      open: openConvs,
      overdue: overdueConvs,
      uniqueRepliers: inboundMessageCount,
      outboundCount: totalBroadcastsSent,
      inboundCustomerCount: inboundMessageCount,
      labeledCustomers: labeledCustomers,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _hasCustomerMessage(Map<String, dynamic> m) {
    return m['customer_message'] != null &&
        m['customer_message'].toString().trim().isNotEmpty;
  }

  bool _isHumanOutbound(Map<String, dynamic> m) {
    final hasMR = m['manager_response'] != null &&
        m['manager_response'].toString().trim().isNotEmpty;
    final sb = m['sent_by']?.toString();
    final sbL = (sb ?? '').toLowerCase().trim();
    return hasMR &&
        sb != null &&
        sb.trim().isNotEmpty &&
        sbL != 'broadcast';
  }

  DateTime? _parseDate(Map<String, dynamic> m) {
    return DateTime.tryParse(m['created_at']?.toString() ?? '');
  }

  // ============================================================
  // FILL MISSING DAYS
  // ============================================================

  List<DailyBreakdown> _fillMissingDays(
    List<DailyBreakdown> source,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null || end == null) return source;

    final map = <String, DailyBreakdown>{};
    for (final d in source) {
      map[d.date] = d;
    }

    final result = <DailyBreakdown>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(last)) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      result.add(map[key] ??
          DailyBreakdown(
            date: key,
            leads: 0,
            revenue: 0,
            engagementRate: 0,
            avgResponseTimeSeconds: 0,
          ));
      cursor = cursor.add(const Duration(days: 1));
    }

    return result;
  }

  // ============================================================
  // CAMPAIGN PERFORMANCE
  // ============================================================

  List<CampaignPerformance> _buildCampaignPerformance({
    required List<Map<String, dynamic>> campaigns,
    required List<Map<String, dynamic>> recipients,
    required List<Map<String, dynamic>> messages,
    required Map<String, Map<String, dynamic>> campaignById,
    required Map<String, Set<String>> campaignPhones,
    required Map<String, DateTime> campaignSentAt,
  }) {
    final Map<String, List<Map<String, dynamic>>> msgByPhone = {};
    for (final m in messages) {
      final phone = m['customer_phone']?.toString() ?? '';
      if (phone.isEmpty) continue;
      msgByPhone.putIfAbsent(phone, () => []).add(m);
    }

    final revenueLabels = {'appointment booked', 'payment done'};
    final List<CampaignPerformance> result = [];

    for (final c in campaigns) {
      final cId = c['id']?.toString() ?? '';
      final sentAt = campaignSentAt[cId];
      final phones = campaignPhones[cId] ?? {};
      final offerAmount =
          double.tryParse(c['offer_amount']?.toString() ?? '0') ?? 0;
      final name = c['campaign_name']?.toString() ?? 'Untitled';

      int responded = 0;
      int leads = 0;
      double revenue = 0;

      for (final phone in phones) {
        final phoneMsgs = msgByPhone[phone];
        if (phoneMsgs == null) continue;

        bool hasReplied = false;
        DateTime? lastCM;
        int phoneLeads = 0;

        for (final m in phoneMsgs) {
          if (!_hasCustomerMessage(m)) continue;
          final createdAt = _parseDate(m);
          if (createdAt == null) continue;
          if (sentAt != null && createdAt.isBefore(sentAt)) continue;

          hasReplied = true;
          if (lastCM == null ||
              createdAt.difference(lastCM).inHours >= 24) {
            phoneLeads++;
          }
          lastCM = createdAt;
        }

        if (hasReplied) responded++;
        leads += phoneLeads;

        for (final m in phoneMsgs) {
          final label =
              (m['label']?.toString() ?? '').toLowerCase().trim();
          if (!revenueLabels.contains(label)) continue;
          final createdAt = _parseDate(m);
          if (createdAt == null) continue;
          if (sentAt != null && createdAt.isBefore(sentAt)) continue;
          revenue += offerAmount;
        }
      }

      final engRate =
          phones.isNotEmpty ? (responded / phones.length) * 100 : 0.0;

      result.add(CampaignPerformance(
        id: cId,
        name: name,
        sentAt: sentAt,
        offerAmount: offerAmount,
        sent: phones.length,
        responded: responded,
        leads: leads,
        revenue: revenue,
        engagementRate: engRate,
      ));
    }

    return result;
  }
}

// ============================================================
// INTERNAL HELPERS
// ============================================================

class _DayAccumulator {
  int leads = 0;
  double revenue = 0;
  int sent = 0;
  int received = 0;
  Set<String> repliedPhones = {};
  Set<String> engagedPhones = {};
  List<double> responseTimes = [];
}

class _ComputedMetrics {
  final OverviewMetrics overview;
  final List<DailyBreakdown> daily;
  final List<OpenConversation> open;
  final List<OpenConversation> overdue;
  final int uniqueRepliers;
  final int outboundCount;
  final int inboundCustomerCount;
  final List<LabeledCustomer> labeledCustomers;

  _ComputedMetrics({
    required this.overview,
    required this.daily,
    required this.open,
    required this.overdue,
    required this.uniqueRepliers,
    required this.outboundCount,
    required this.inboundCustomerCount,
    this.labeledCustomers = const [],
  });
}

// ============================================================
// DATA MODELS
// ============================================================

class LabeledCustomer {
  final String phone;
  final String? name;
  final String label; // 'appointment booked' or 'payment done'
  final DateTime date;

  LabeledCustomer({
    required this.phone,
    this.name,
    required this.label,
    required this.date,
  });

  String get displayName => name ?? phone;
}

class AnalyticsData {
  final OverviewMetrics current;
  final OverviewMetrics? comparison;
  final List<DailyBreakdown> dailyBreakdown;
  final List<DailyBreakdown>? comparisonDailyBreakdown;
  final List<CampaignPerformance> campaigns;
  final List<OpenConversation> openConversations;
  final List<OpenConversation> overdueConversations;
  final List<LabeledCustomer> labeledCustomers;

  AnalyticsData({
    required this.current,
    this.comparison,
    required this.dailyBreakdown,
    this.comparisonDailyBreakdown,
    required this.campaigns,
    required this.openConversations,
    required this.overdueConversations,
    this.labeledCustomers = const [],
  });
}

class OverviewMetrics {
  final int leads;
  final int organicLeads;
  final double revenue;
  final int appointmentsBooked;
  final int paymentsDone;
  final double engagementRate; // 0-100
  final double avgResponseTimeSeconds;
  final Map<String, double> employeeAvgResponseTime; // employee name -> avg seconds
  final int openConversationCount;
  final int overdueConversationCount;
  final int messagesSent;
  final int messagesReceived;

  OverviewMetrics({
    required this.leads,
    this.organicLeads = 0,
    required this.revenue,
    this.appointmentsBooked = 0,
    this.paymentsDone = 0,
    required this.engagementRate,
    required this.avgResponseTimeSeconds,
    this.employeeAvgResponseTime = const {},
    required this.openConversationCount,
    required this.overdueConversationCount,
    required this.messagesSent,
    required this.messagesReceived,
  });
}

class DailyBreakdown {
  final String date; // YYYY-MM-DD
  final int leads;
  final double revenue;
  final double engagementRate;
  final double avgResponseTimeSeconds;

  DailyBreakdown({
    required this.date,
    required this.leads,
    required this.revenue,
    required this.engagementRate,
    required this.avgResponseTimeSeconds,
  });
}

class CampaignPerformance {
  final String id;
  final String name;
  final DateTime? sentAt;
  final double offerAmount;
  final int sent;
  final int responded;
  final int leads;
  final double revenue;
  final double engagementRate;

  CampaignPerformance({
    required this.id,
    required this.name,
    this.sentAt,
    required this.offerAmount,
    required this.sent,
    required this.responded,
    required this.leads,
    required this.revenue,
    required this.engagementRate,
  });
}

class OpenConversation {
  final String customerPhone;
  final String? customerName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final Duration waitingTime;

  OpenConversation({
    required this.customerPhone,
    this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.waitingTime,
  });
}
