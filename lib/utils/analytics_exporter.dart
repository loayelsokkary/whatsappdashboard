import 'dart:convert';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../providers/admin_analytics_provider.dart';
import '../providers/roi_analytics_provider.dart';
import 'health_scorer.dart';
import 'initials_helper.dart';

/// Returns [numerator] / [denominator], or [fallback] if [denominator] is zero,
/// or the result is infinite / NaN.
double safeDiv(num numerator, num denominator, {double fallback = 0.0}) {
  if (denominator == 0) return fallback;
  final result = numerator / denominator;
  if (result.isInfinite || result.isNaN) return fallback;
  return result.toDouble();
}

/// Sanitises any value that will be used as a numeric quantity in the PDF.
/// Returns 0.0 for null, NaN, infinity, or negative-infinity.
double _n(dynamic v) {
  if (v == null) return 0.0;
  final d = (v is num) ? v.toDouble() : 0.0;
  if (d.isInfinite || d.isNaN) return 0.0;
  return d;
}

/// Sanitises a double to be safe for PDF. Alias for _n.
double _sfPdf(double v) => (v.isInfinite || v.isNaN) ? 0.0 : v;

/// Utility class for exporting analytics data to PDF, Excel, and CSV.
class AnalyticsExporter {
  static final _pdf = _PdfBrandColors();

  // ─────────────────────────────────────────────────────────────────
  // ARABIC FONT LOADING
  // ─────────────────────────────────────────────────────────────────

  static pw.Font? _arabicFont;
  static pw.MemoryImage? _logoImage;

  static Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _arabicFont = pw.Font.ttf(data);
    } catch (_) {
      // Font unavailable  -  Arabic text falls back to default font
    }
  }

  static Future<void> _loadLogoImage() async {
    if (_logoImage != null) return;
    try {
      final data = await rootBundle.load('assets/images/vivid_logo.png');
      _logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Logo unavailable  -  fall back to text
    }
  }

  /// Returns a TextStyle with the Arabic font applied when text is Arabic.
  static pw.TextStyle _arStyle(pw.TextStyle base, String text) {
    if (_arabicFont == null || !isArabicText(text)) return base;
    return base.copyWith(font: _arabicFont);
  }

  /// Strips Arabic Unicode characters from a name that will be rendered
  /// with the Latin font. Purely-Arabic names are returned unchanged
  /// (they will be rendered with the Arabic font via [_arStyle]).
  static String _sanitizePdfName(String name) {
    if (name.isEmpty) return name;
    if (isArabicText(name)) return name; // fully Arabic → keep for Arabic font
    // Strip isolated Arabic glyphs embedded in Latin names (e.g. "fatima ع")
    return name
        .replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]'), '')
        .trim();
  }

  // ─────────────────────────────────────────────────────────────────
  // CSV EXPORT (unchanged)
  // ─────────────────────────────────────────────────────────────────

  static void exportAnalyticsCsv({
    required AnalyticsData data,
    required String clientName,
    required String dateRange,
  }) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());
    final m = data.current;

    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('# ANALYTICS REPORT');
    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('Business,${_escapeCsv(clientName)}');
    buffer.writeln('Date Range,$dateRange');
    buffer.writeln('');

    buffer.writeln('# ─── OVERVIEW METRICS ───');
    buffer.writeln('Metric,Value');
    buffer.writeln('Leads,${m.leads}');
    buffer.writeln('Revenue,"${_fmtNumber(m.revenue)} BHD"');
    buffer.writeln('Engagement Rate,${m.engagementRate.toStringAsFixed(1)}%');
    buffer.writeln('Avg Response Time,${_fmtDurationCsv(m.avgResponseTimeSeconds)}');
    buffer.writeln('Open Conversations,${m.openConversationCount}');
    buffer.writeln('Overdue Conversations,${m.overdueConversationCount}');
    buffer.writeln('Messages Sent,"${_fmtInt(m.messagesSent)}"');
    buffer.writeln('Messages Received,"${_fmtInt(m.messagesReceived)}"');
    buffer.writeln('');

    if (data.comparison != null) {
      final c = data.comparison!;
      buffer.writeln('# ─── COMPARISON PERIOD ───');
      buffer.writeln('Metric,Value');
      buffer.writeln('Leads,${c.leads}');
      buffer.writeln('Revenue,"${_fmtNumber(c.revenue)} BHD"');
      buffer.writeln('Engagement Rate,${c.engagementRate.toStringAsFixed(1)}%');
      buffer.writeln('Avg Response Time,${_fmtDurationCsv(c.avgResponseTimeSeconds)}');
      buffer.writeln('Messages Sent,"${_fmtInt(c.messagesSent)}"');
      buffer.writeln('Messages Received,"${_fmtInt(c.messagesReceived)}"');
      buffer.writeln('');
    }

    if (data.campaigns.isNotEmpty) {
      buffer.writeln('# ─── CAMPAIGN PERFORMANCE ───');
      buffer.writeln('Campaign,Date,Sent,Responded,Leads,Revenue,Engagement Rate');
      for (final c in data.campaigns) {
        final date = c.sentAt != null ? _formatDateIso(c.sentAt!) : 'N/A';
        buffer.writeln(
          '${_escapeCsv(c.name)},$date,${c.sent},${c.responded},${c.leads},"${_fmtNumber(c.revenue)} BHD",${c.engagementRate.toStringAsFixed(1)}%',
        );
      }
      buffer.writeln('');
    }

    if (data.openConversations.isNotEmpty) {
      buffer.writeln('# ─── OPEN CONVERSATIONS ───');
      buffer.writeln('Phone,Name,Last Message,Waiting Time');
      for (final c in data.openConversations) {
        buffer.writeln(
          '${c.customerPhone},${_escapeCsv(c.customerName ?? '')},${_escapeCsv(c.lastMessage)},${_fmtWaitTimeCsv(c.waitingTime)}',
        );
      }
      buffer.writeln('');
    }

    if (data.dailyBreakdown.isNotEmpty) {
      buffer.writeln('# ─── DAILY BREAKDOWN ───');
      buffer.writeln('Date,Leads,Revenue,Engagement Rate,Avg Response Time');
      for (final d in data.dailyBreakdown) {
        buffer.writeln(
          '${d.date},${d.leads},"${_fmtNumber(d.revenue)} BHD",${d.engagementRate.toStringAsFixed(1)}%,${_fmtDurationCsv(d.avgResponseTimeSeconds)}',
        );
      }
    }

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: 'analytics_$timestamp.csv',
      mimeType: 'text/csv',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ENHANCED PDF EXPORT
  // ─────────────────────────────────────────────────────────────────

  static Future<void> exportAnalyticsPdf({
    required AnalyticsData data,
    required String clientName,
    required String dateRange,
  }) async {
    try {
      await Future.wait([_loadArabicFont(), _loadLogoImage()]);

      // ── DEBUG: print every numeric value before touching the PDF ──────────
      final m = data.current;
      // ignore: avoid_print
      print('PDF EXPORT  -  DEBUG VALUES START');
      // ignore: avoid_print
      print('  leads=${m.leads}  revenue=${m.revenue}  engRate=${m.engagementRate}');
      // ignore: avoid_print
      print('  avgRT=${m.avgResponseTimeSeconds}  msgSent=${m.messagesSent}  msgRecv=${m.messagesReceived}');
      // ignore: avoid_print
      print('  apptBooked=${m.appointmentsBooked}  paymentsDone=${m.paymentsDone}');
      // ignore: avoid_print
      print('  openConvs=${m.openConversationCount}  overdue=${m.overdueConversationCount}');
      for (final e in m.employeeAvgResponseTime.entries) {
        // ignore: avoid_print
        print('  employee[${e.key}]=${e.value}  (inf=${e.value.isInfinite} nan=${e.value.isNaN})');
      }
      for (final c in data.campaigns) {
        // ignore: avoid_print
        print('  campaign[${c.name}] sent=${c.sent} eng=${c.engagementRate} rev=${c.revenue}  (eng.inf=${c.engagementRate.isInfinite} eng.nan=${c.engagementRate.isNaN})');
      }
      for (final d in data.dailyBreakdown) {
        // ignore: avoid_print
        print('  day[${d.date}] leads=${d.leads} rev=${d.revenue} eng=${d.engagementRate} rt=${d.avgResponseTimeSeconds}  (eng.inf=${d.engagementRate.isInfinite} rt.inf=${d.avgResponseTimeSeconds.isInfinite})');
      }
      // ignore: avoid_print
      print('PDF EXPORT  -  DEBUG VALUES END');
      // ──────────────────────────────────────────────────────────────────────

      // Sanitise all floating-point fields so no infinity/NaN reaches the PDF.
      final safeData = _sanitizeAnalyticsData(data);

      final pdf = pw.Document();
      final timestamp = _formatDateIso(DateTime.now());
      final subtitle = '$dateRange | $timestamp';
      const margin = pw.EdgeInsets.fromLTRB(28, 16, 28, 24);

      pw.MultiPage makePage(List<pw.Widget> Function(pw.Context) builder) =>
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: margin,
            header: (ctx) => _pdfPageHeader(clientName, subtitle),
            footer: (ctx) => _pdfPageFooter(ctx),
            build: builder,
          );

      // Page 1: Executive Summary
      pdf.addPage(makePage((_) => _pdfExecSummary(safeData)));

      // Page 2: Broadcast Performance (if campaigns exist)
      if (safeData.campaigns.isNotEmpty) {
        pdf.addPage(makePage((_) => _pdfBroadcastPage(safeData)));
      }

      // Page 3: Conversation Analytics
      pdf.addPage(makePage((_) => _pdfConversationsPage(safeData)));

      // Page 4: Daily Trends (if enough data)
      if (safeData.dailyBreakdown.length >= 3) {
        pdf.addPage(makePage((_) => _pdfDailyTrendsPage(safeData.dailyBreakdown)));
      }

      // Page 5: Daily Breakdown Table
      if (safeData.dailyBreakdown.isNotEmpty) {
        pdf.addPage(makePage((_) => _pdfDailyBreakdownPage(safeData.dailyBreakdown)));
      }

      // Page 6: Recommendations
      pdf.addPage(makePage((_) => _pdfRecommendationsPage(safeData)));

      final bytes = await pdf.save();
      _downloadFile(
        content: bytes,
        filename: 'vivid_analytics_$timestamp.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('PDF EXPORT ERROR: $e');
      // ignore: avoid_print
      print('PDF EXPORT STACK: $stackTrace');
      rethrow;
    }
  }

  /// Returns a copy of [data] with all double fields clamped to finite values.
  static AnalyticsData _sanitizeAnalyticsData(AnalyticsData data) {
    OverviewMetrics sanitizeMetrics(OverviewMetrics m) => OverviewMetrics(
          leads: m.leads,
          organicLeads: m.organicLeads,
          revenue: _n(m.revenue),
          appointmentsBooked: m.appointmentsBooked,
          paymentsDone: m.paymentsDone,
          engagementRate: _n(m.engagementRate),
          avgResponseTimeSeconds: _n(m.avgResponseTimeSeconds),
          employeeAvgResponseTime: {
            for (final e in m.employeeAvgResponseTime.entries)
              e.key: _n(e.value),
          },
          openConversationCount: m.openConversationCount,
          overdueConversationCount: m.overdueConversationCount,
          messagesSent: m.messagesSent,
          messagesReceived: m.messagesReceived,
        );

    List<DailyBreakdown> sanitizeDays(List<DailyBreakdown> days) => days
        .map((d) => DailyBreakdown(
              date: d.date,
              leads: d.leads,
              revenue: _n(d.revenue),
              engagementRate: _n(d.engagementRate),
              avgResponseTimeSeconds: _n(d.avgResponseTimeSeconds),
            ))
        .toList();

    List<CampaignPerformance> sanitizeCampaigns(
            List<CampaignPerformance> camps) =>
        camps
            .map((c) => CampaignPerformance(
                  id: c.id,
                  name: c.name,
                  sentAt: c.sentAt,
                  offerAmount: _n(c.offerAmount),
                  sent: c.sent,
                  responded: c.responded,
                  leads: c.leads,
                  revenue: _n(c.revenue),
                  engagementRate: _n(c.engagementRate),
                  respondedCustomers: c.respondedCustomers,
                  leadContributors: c.leadContributors,
                  recipients: c.recipients,
                  appointmentCustomers: c.appointmentCustomers,
                  paymentCustomers: c.paymentCustomers,
                ))
            .toList();

    return AnalyticsData(
      current: sanitizeMetrics(data.current),
      comparison: data.comparison != null ? sanitizeMetrics(data.comparison!) : null,
      dailyBreakdown: sanitizeDays(data.dailyBreakdown),
      comparisonDailyBreakdown: data.comparisonDailyBreakdown != null
          ? sanitizeDays(data.comparisonDailyBreakdown!)
          : null,
      campaigns: sanitizeCampaigns(data.campaigns),
      openConversations: data.openConversations,
      overdueConversations: data.overdueConversations,
      labeledCustomers: data.labeledCustomers,
      leadContributors: data.leadContributors,
      organicLeadContributors: data.organicLeadContributors,
      engagedCustomers: data.engagedCustomers,
      responseTimeEntries: data.responseTimeEntries,
      agentMessageCounts: data.agentMessageCounts,
      automatedMessageCount: data.automatedMessageCount,
      inboundCustomers: data.inboundCustomers,
      employeePerformance: data.employeePerformance,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL EXPORT
  // ─────────────────────────────────────────────────────────────────

  static Future<void> exportAnalyticsExcel({
    required AnalyticsData data,
    required String clientName,
    required String dateRange,
  }) async {
    final timestamp = _formatDateIso(DateTime.now());
    final wb = Excel.createExcel();

    // Rename default sheet and populate
    wb.rename('Sheet1', 'Executive Summary');
    _xlSummarySheet(wb['Executive Summary'], data, clientName, dateRange, timestamp);

    wb['Campaign Performance'];
    _xlCampaignSheet(wb['Campaign Performance'], data);

    wb['Employee Performance'];
    _xlEmployeeSheet(wb['Employee Performance'], data);

    wb['Daily Breakdown'];
    _xlDailySheet(wb['Daily Breakdown'], data);

    wb['Action Required'];
    _xlActionSheet(wb['Action Required'], data);

    final bytes = wb.save();
    if (bytes == null) throw Exception('Excel generation failed');
    _downloadFile(
      content: bytes,
      filename: 'vivid_analytics_$timestamp.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF PAGE 1: EXECUTIVE SUMMARY
  // ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _pdfExecSummary(AnalyticsData data) {
    final m = data.current;
    final insights = _generateInsights(data);

    return [
      _pdfSectionTitle('Executive Summary', _pdf.cyan),
      pw.SizedBox(height: 14),

      // KPI grid  -  2 columns × 3 rows
      pw.Row(children: [
        _pdfKpiCard('Total Leads', '${m.leads}', _pdf.cyan),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Revenue', '${m.revenue.toStringAsFixed(0)} BHD', _pdf.green),
      ]),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        _pdfKpiCard('Appointments Booked', '${m.appointmentsBooked}', _pdf.blue),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Payments Done', '${m.paymentsDone}', _pdf.teal),
      ]),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        _pdfKpiCard('Avg Engagement Rate', '${m.engagementRate.toStringAsFixed(1)}%', _pdf.amber),
        pw.SizedBox(width: 8),
        _pdfKpiCard(
          'Avg Response Time',
          _formatDurationPdf(m.avgResponseTimeSeconds),
          m.avgResponseTimeSeconds > 1800 ? _pdf.red : _pdf.green,
        ),
      ]),

      // Comparison row (if enabled)
      if (data.comparison != null) ...[
        pw.SizedBox(height: 14),
        _pdfSectionTitle('Comparison Period', _pdf.textMuted),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _pdfMiniStat('Leads', '${data.comparison!.leads}'),
          _pdfMiniStat('Revenue', '${data.comparison!.revenue.toStringAsFixed(0)} BHD'),
          _pdfMiniStat('Engagement', '${data.comparison!.engagementRate.toStringAsFixed(1)}%'),
          _pdfMiniStat('Messages Sent', '${data.comparison!.messagesSent}'),
        ]),
      ],

      if (insights.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        _pdfSectionTitle('Key Insights', _pdf.navy),
        pw.SizedBox(height: 10),
        ...insights.map(_pdfInsightBullet),
      ],
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF PAGE 2: BROADCAST PERFORMANCE
  // ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _pdfBroadcastPage(AnalyticsData data) {
    final m = data.current;
    final campaigns = data.campaigns;
    final totalSent = campaigns.fold<int>(0, (s, c) => s + c.sent);
    final totalResponded = campaigns.fold<int>(0, (s, c) => s + c.responded);
    final totalLeads = m.leads;
    final totalRevenue = m.revenue;
    final avgEng = campaigns.isEmpty
        ? 0.0
        : campaigns.fold<double>(0, (s, c) => s + c.engagementRate) / campaigns.length;

    return [
      _pdfSectionTitle('Broadcast Performance', _pdf.blue),
      pw.SizedBox(height: 12),

      // Overview stats row
      pw.Row(children: [
        _pdfMiniStat('Total Sent', '$totalSent'),
        _pdfMiniStat('Responded', '$totalResponded'),
        _pdfMiniStat('Leads', '$totalLeads'),
        _pdfMiniStat('Revenue', '${totalRevenue.toStringAsFixed(0)} BHD'),
        _pdfMiniStat('Avg Engagement', '${avgEng.toStringAsFixed(1)}%'),
      ]),
      pw.SizedBox(height: 16),

      // Campaign table with Rev/1K column
      _pdfSectionTitle('Campaign Performance', _pdf.blue),
      pw.SizedBox(height: 8),
      _buildEnhancedCampaignTable(campaigns),
      pw.SizedBox(height: 20),

      // Conversion funnel
      _pdfSectionTitle('Conversion Funnel', _pdf.teal),
      pw.SizedBox(height: 10),
      if (totalSent > 0) ...[
        _pdfFunnelItem('Sent', totalSent, totalSent, _pdf.navy),
        _pdfFunnelItem('Responded', totalResponded, totalSent, _pdf.cyan),
        _pdfFunnelItem('Leads', totalLeads, totalSent, _pdf.green),
        _pdfFunnelItem('Appointments Booked', m.appointmentsBooked, totalSent, _pdf.blue),
        _pdfFunnelItem('Payments Done', m.paymentsDone, totalSent, _pdf.teal),
      ],
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF PAGE 3: CONVERSATION ANALYTICS
  // ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _pdfConversationsPage(AnalyticsData data) {
    final m = data.current;
    final rtEntries = data.responseTimeEntries;

    final totalRt = rtEntries.length;

    // Open conversations (top 15 by wait time)
    final sorted = [...data.openConversations]..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    final top15 = sorted.take(15).toList();

    return [
      _pdfSectionTitle('Conversation Analytics', _pdf.cyan),
      pw.SizedBox(height: 12),

      // Overview row
      pw.Row(children: [
        _pdfMiniStat('Total Leads', '${m.leads}'),
        _pdfMiniStat('Organic Leads', '${m.organicLeads}'),
        _pdfMiniStat('Messages In', '${m.messagesReceived}'),
        _pdfMiniStat('Messages Out', '${m.messagesSent}'),
        _pdfMiniStat('Open', '${m.openConversationCount}'),
        _pdfMiniStat('Overdue', '${m.overdueConversationCount}', alert: m.overdueConversationCount > 0),
      ]),
      pw.SizedBox(height: 20),

      // Response time summary (single line, replaces bar chart)
      if (totalRt > 0) ...[
        _buildRtDistributionSummary(rtEntries),
        pw.SizedBox(height: 16),
      ],

      // Employee performance table
      if (data.employeePerformance.isNotEmpty) ...[
        _pdfSectionTitle('Employee Performance', _pdf.navy),
        pw.SizedBox(height: 6),
        _buildEmpSummaryLine(data.employeePerformance),
        pw.SizedBox(height: 10),
        _buildEmployeePerfTable(data.employeePerformance),
        pw.SizedBox(height: 20),
      ],

      // Open conversations
      if (top15.isNotEmpty) ...[
        _pdfSectionTitle('Open Conversations (longest wait first)', _pdf.orange),
        pw.SizedBox(height: 8),
        _buildOpenConversationsTable(top15),
      ],
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF PAGE 4: DAILY TRENDS
  // ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _pdfDailyTrendsPage(List<DailyBreakdown> days) {
    // Show last 21 days max for readability
    final recent = days.length > 21 ? days.sublist(days.length - 21) : days;

    final maxLeads = recent.map((d) => d.leads.toDouble()).fold<double>(1, max);
    final maxRev = recent.map((d) => d.revenue).fold<double>(1, max);
    final maxEng = recent.map((d) => d.engagementRate).fold<double>(1, max);

    return [
      _pdfSectionTitle('Daily Trends', _pdf.cyan),
      pw.SizedBox(height: 14),
      _pdfBarSection('Leads per Day', recent, (d) => d.leads.toDouble(), maxLeads, _pdf.cyan, (v) => v.toInt().toString()),
      pw.SizedBox(height: 16),
      _pdfBarSection('Revenue per Day (BHD)', recent, (d) => d.revenue, maxRev, _pdf.green, (v) => v > 0 ? v.toStringAsFixed(0) : '-'),
      pw.SizedBox(height: 16),
      _pdfBarSection('Engagement Rate per Day (%)', recent, (d) => d.engagementRate, maxEng, _pdf.blue, (v) => '${v.toStringAsFixed(0)}%'),
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF PAGE 5: DAILY BREAKDOWN TABLE
  // ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _pdfDailyBreakdownPage(List<DailyBreakdown> days) {
    return [
      _pdfSectionTitle('Daily Breakdown', _pdf.teal),
      pw.SizedBox(height: 12),
      _buildDailyTable(days),
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF PAGE 6: RECOMMENDATIONS
  // ─────────────────────────────────────────────────────────────────

  static List<pw.Widget> _pdfRecommendationsPage(AnalyticsData data) {
    final recs = _generateRecommendations(data);

    return [
      _pdfSectionTitle('Data-Driven Recommendations', _pdf.navy),
      pw.SizedBox(height: 6),
      pw.Text(
        'Based on your analytics data, here are actionable recommendations.',
        style: pw.TextStyle(fontSize: 9, color: _pdf.textMuted),
      ),
      pw.SizedBox(height: 16),
      ...recs.map((r) => _pdfRecommendationBlock(r.$1, r.$2)),
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF SHARED COMPONENTS
  // ─────────────────────────────────────────────────────────────────

  static pw.Widget _pdfPageHeader(String clientName, String subtitle) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      margin: const pw.EdgeInsets.only(bottom: 18),
      decoration: pw.BoxDecoration(
        color: _pdf.navy,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (_logoImage != null)
              pw.Image(_logoImage!, height: 28)
            else
              pw.Text('VIVID', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdf.cyan, letterSpacing: 3)),
            pw.SizedBox(height: 4),
            pw.Text('Analytics Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(clientName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#8B97B0'))),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _pdfPageFooter(pw.Context ctx) {
    // NOTE: pw.Container(width: double.infinity) must be wrapped in pw.Expanded
    // when inside a Row  -  otherwise the Row passes unbounded constraints and the
    // container tries to render with width=infinity, crashing PdfNum.
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(height: 1, color: _pdf.border),
        ),
      ],
    );
  }

  static pw.Widget _pdfSectionTitle(String text, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _pdfKpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color, width: 1.5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _pdf.textMuted)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  static pw.Widget _pdfMiniStat(String label, String value, {bool alert = false}) {
    final valueColor = alert ? _pdf.red : _pdf.navy;
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        margin: const pw.EdgeInsets.only(right: 4),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F8FAFC'),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _pdf.border, width: 0.5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: _pdf.textMuted)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: valueColor)),
        ]),
      ),
    );
  }

  static pw.Widget _pdfFunnelItem(String label, int count, int total, PdfColor color) {
    final pct = (safeDiv(count, total) * 100).clamp(0.0, 100.0);
    final filledFlex = pct.round().clamp(1, 100);
    final emptyFlex = (100 - filledFlex).clamp(0, 99);

    // Layout: [label 140] [bar track Expanded] [6px gap] [count 34px] [pct 28px]
    // The count is always visible in dark text right next to the bar's end.
    // The pct% is in accent color at the far right.
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _pdf.navy)),
        ),
        pw.Expanded(
          child: pw.Row(children: [
            pw.Expanded(
              flex: filledFlex,
              child: pw.Container(height: 18, color: color),
            ),
            if (emptyFlex > 0) pw.Expanded(
              flex: emptyFlex,
              child: pw.Container(height: 18, color: PdfColor.fromHex('#EEF2F8')),
            ),
          ]),
        ),
        pw.SizedBox(width: 6),
        // Count: always visible in dark text, immediately right of the bar track
        pw.SizedBox(
          width: 34,
          child: pw.Text(
            count > 0 ? '$count' : '-',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdf.navy),
            textAlign: pw.TextAlign.left,
          ),
        ),
        // Percentage: accent colour at far right
        pw.SizedBox(
          width: 28,
          child: pw.Text(
            '${pct.toStringAsFixed(0)}%',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ]),
    );
  }

  static pw.Widget _pdfBarSection(
    String title,
    List<DailyBreakdown> days,
    double Function(DailyBreakdown) getValue,
    double maxVal,
    PdfColor color,
    String Function(double) format,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdf.navy)),
        pw.SizedBox(height: 5),
        ...days.map((d) {
          final val = getValue(d);
          final frac = safeDiv(val, maxVal).clamp(0.0, 1.0);
          final filled = (frac * 100).round().clamp(0, 100);
          final empty = (100 - filled).clamp(0, 100);
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(children: [
              pw.SizedBox(
                width: 42,
                child: pw.Text(d.date.length >= 7 ? d.date.substring(5) : d.date, style: pw.TextStyle(fontSize: 7, color: _pdf.textMuted)),
              ),
              pw.Expanded(
                child: pw.Row(children: [
                  if (filled > 0) pw.Expanded(flex: filled, child: pw.Container(height: 9, color: color)),
                  if (empty > 0) pw.Expanded(flex: empty, child: pw.Container(height: 9, color: PdfColor.fromHex('#EEF2F8'))),
                ]),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(
                width: 48,
                child: pw.Text(format(val), style: pw.TextStyle(fontSize: 7, color: color), textAlign: pw.TextAlign.right),
              ),
            ]),
          );
        }),
      ],
    );
  }

  static pw.Widget _pdfInsightBullet(String text) {
    // Use Arabic font if text contains Arabic chars (e.g. employee/campaign names)
    final style = _arStyle(pw.TextStyle(fontSize: 9, color: _pdf.navy), text);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 6, height: 6, margin: const pw.EdgeInsets.only(top: 2, right: 8), decoration: pw.BoxDecoration(color: _pdf.cyan, shape: pw.BoxShape.circle)),
          pw.Expanded(child: pw.Text(text, style: style)),
        ],
      ),
    );
  }

  static pw.Widget _pdfRecommendationBlock(String title, String body) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _pdf.cyan, width: 3)),
          color: PdfColor.fromHex('#F0FDFB'),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: _arStyle(pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdf.navy), title)),
          pw.SizedBox(height: 4),
          pw.Text(body, style: _arStyle(pw.TextStyle(fontSize: 9, color: _pdf.textMuted), body)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF TABLE: ENHANCED CAMPAIGN TABLE (with Rev/1K column)
  // ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildEnhancedCampaignTable(List<CampaignPerformance> campaigns) {
    // Abbreviated headers so fixed-width columns fit without truncation.
    // Campaign name gets all remaining flex space (~247px on A4 with 28pt margins).
    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.0), // Campaign name  -  all remaining space
        1: const pw.FixedColumnWidth(44), // Date
        2: const pw.FixedColumnWidth(32), // Sent
        3: const pw.FixedColumnWidth(36), // Resp.  (5 chars needs ~26px at 7pt)
        4: const pw.FixedColumnWidth(36), // Leads  (5 chars needs ~26px at 7pt)
        5: const pw.FixedColumnWidth(36), // Rev.
        6: const pw.FixedColumnWidth(38), // Rev/1K (6 chars)
        7: const pw.FixedColumnWidth(32), // Eng%
        8: const pw.FixedColumnWidth(32), // Conv%
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: ['Campaign', 'Date', 'Sent', 'Resp.', 'Leads', 'Rev.', 'Rev/1K', 'Eng%', 'Conv%']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ))
              .toList(),
        ),
        ...List.generate(campaigns.length, (i) {
          final c = campaigns[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          final convPct = c.sent > 0 ? '${(safeDiv(c.leads, c.sent) * 100).toStringAsFixed(0)}%' : '-';
          final rev1k = c.sent > 0 ? (safeDiv(c.revenue, c.sent) * 1000).toStringAsFixed(1) : '-';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              // Name cell: 8pt, wraps naturally if long
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: pw.Text(
                  c.name,
                  style: _arStyle(pw.TextStyle(fontSize: 8, color: _pdf.navy), c.name),
                  textDirection: isArabicText(c.name) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: pw.Text(
                  c.sentAt != null ? _formatDateShort(c.sentAt!) : 'N/A',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              _numCell('${c.sent}', _pdf.navy),
              _numCell('${c.responded}', _pdf.green),
              _numCell('${c.leads}', _pdf.cyan),
              _numCell(c.revenue > 0 ? c.revenue.toStringAsFixed(0) : '-', c.revenue > 0 ? _pdf.green : _pdf.textMuted),
              _numCell(rev1k, c.revenue > 0 ? _pdf.teal : _pdf.textMuted),
              _numCell('${c.engagementRate.toStringAsFixed(0)}%', _pdf.blue),
              _numCell(convPct, _pdf.blue),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _numCell(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: color),
            textAlign: pw.TextAlign.center),
      );

  // ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildEmployeePerfTable(List<EmployeePerformance> allEmployees) {
    // Filter out zero-message employees; already sorted by conv rate desc from provider
    final employees = allEmployees.where((e) => e.messagesSent > 0).toList();

    pw.TextStyle hStyle() => pw.TextStyle(
        fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    pw.TextStyle dStyle(PdfColor c, {bool bold = false}) => pw.TextStyle(
        fontSize: 7.5, color: c, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    pw.Widget hCell(String t, {int flex = 10, pw.TextAlign align = pw.TextAlign.center}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: pw.Text(t, style: hStyle(), textAlign: align),
          ),
        );

    pw.Widget dCell(String t, PdfColor c, {int flex = 10, bool bold = false,
        pw.TextAlign align = pw.TextAlign.center}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: pw.Text(t, style: dStyle(c, bold: bold), textAlign: align),
          ),
        );

    final rows = <pw.Widget>[
      pw.Container(
        color: _pdf.navy,
        child: pw.Row(children: [
          hCell('Employee Name', flex: 20, align: pw.TextAlign.left),
          hCell('Messages Sent', flex: 9),
          hCell('Conversations', flex: 9),
          hCell('Avg Response', flex: 12),
          hCell('Appts Booked', flex: 10),
          hCell('Payments', flex: 9),
          hCell('Conv Rate', flex: 9),
          hCell('Revenue BHD', flex: 10),
        ]),
      ),
    ];

    for (var i = 0; i < employees.length; i++) {
      final e = employees[i];
      final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');

      final rtColor = e.avgResponseTimeSeconds == 0 ? _pdf.textMuted
          : e.avgResponseTimeSeconds < 300 ? _pdf.green
          : e.avgResponseTimeSeconds < 1800 ? _pdf.cyan
          : e.avgResponseTimeSeconds < 3600 ? _pdf.amber
          : _pdf.red;

      final convColor = e.conversionRate >= 15 ? _pdf.green
          : e.conversionRate >= 5 ? _pdf.amber
          : e.conversionRate > 0 ? _pdf.red
          : _pdf.textMuted;

      rows.add(pw.Container(
        color: bg,
        child: pw.Row(children: [
          pw.Expanded(
            flex: 20,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: pw.Text(
                _sanitizePdfName(e.name),
                style: _arStyle(pw.TextStyle(fontSize: 7.5, color: _pdf.navy), e.name),
              ),
            ),
          ),
          dCell('${e.messagesSent}', _pdf.textMuted, flex: 9),
          dCell('${e.conversationsHandled}', _pdf.textMuted, flex: 9),
          dCell(
            e.avgResponseTimeSeconds > 0 ? _formatDurationPdf(e.avgResponseTimeSeconds) : '-',
            rtColor, flex: 12,
          ),
          dCell('${e.appointmentsBooked}', _pdf.textMuted, flex: 10),
          dCell('${e.paymentsCollected}', _pdf.textMuted, flex: 9),
          dCell(
            e.conversationsHandled > 0 ? '${e.conversionRate.toStringAsFixed(1)}%' : '0%',
            convColor, flex: 9, bold: true,
          ),
          dCell(
            e.revenueAttributed > 0
                ? '${e.revenueAttributed.toStringAsFixed(0)} BHD'
                : '0',
            e.revenueAttributed > 0 ? _pdf.green : _pdf.textMuted, flex: 10,
          ),
        ]),
      ));
    }

    // Team Average row
    if (employees.isNotEmpty) {
      final withRt = employees.where((e) => e.avgResponseTimeSeconds > 0).toList();
      final avgRt = withRt.isEmpty ? 0.0
          : withRt.map((e) => e.avgResponseTimeSeconds).reduce((a, b) => a + b) / withRt.length;
      final avgConv = employees.map((e) => e.conversionRate).reduce((a, b) => a + b) / employees.length;
      final totalMsgs = employees.fold(0, (s, e) => s + e.messagesSent);
      final totalConvos = employees.fold(0, (s, e) => s + e.conversationsHandled);
      final totalAppts = employees.fold(0, (s, e) => s + e.appointmentsBooked);
      final totalPmts = employees.fold(0, (s, e) => s + e.paymentsCollected);
      final totalRevenue = employees.fold(0.0, (s, e) => s + e.revenueAttributed);

      final teamAvgBg = PdfColor.fromHex('#0a1628');
      final teamAvgAccent = PdfColor.fromHex('#00d4aa');
      rows.add(pw.Container(
        decoration: pw.BoxDecoration(
          color: teamAvgBg,
          border: pw.Border(top: pw.BorderSide(color: teamAvgAccent, width: 1.5)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            flex: 20,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: pw.Text('Team Average',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold,
                  color: teamAvgAccent)),
            ),
          ),
          dCell('$totalMsgs', PdfColors.white, flex: 9),
          dCell('$totalConvos', PdfColors.white, flex: 9),
          dCell(avgRt > 0 ? _formatDurationPdf(avgRt) : '-', PdfColors.white, flex: 12),
          dCell('$totalAppts', PdfColors.white, flex: 10),
          dCell('$totalPmts', PdfColors.white, flex: 9),
          dCell('${avgConv.toStringAsFixed(1)}%', PdfColors.white, flex: 9, bold: true),
          dCell(
            totalRevenue > 0 ? '${totalRevenue.toStringAsFixed(0)} BHD' : '0',
            totalRevenue > 0 ? _pdf.green : PdfColors.white, flex: 10,
          ),
        ]),
      ));
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _buildRtDistributionSummary(List<ResponseTimeEntry> rtEntries) {
    final b0 = rtEntries.where((e) => e.responseTimeSeconds < 300).length;
    final b1 = rtEntries.where((e) => e.responseTimeSeconds >= 300 && e.responseTimeSeconds < 1800).length;
    final b2 = rtEntries.where((e) => e.responseTimeSeconds >= 1800 && e.responseTimeSeconds < 3600).length;
    final b3 = rtEntries.where((e) => e.responseTimeSeconds >= 3600).length;
    return pw.Text(
      'Response time: <5 min: $b0  |  5-30 min: $b1  |  30 min-1h: $b2  |  >1 hour: $b3',
      style: pw.TextStyle(fontSize: 8, color: _pdf.textMuted),
    );
  }

  static pw.Widget _buildEmpSummaryLine(List<EmployeePerformance> emps) {
    final base = emps.where((e) => e.messagesSent > 0).toList();
    if (base.isEmpty) return pw.SizedBox();

    final qualifiers = base.where((e) => e.conversationsHandled >= 3).toList();
    final top = qualifiers.isEmpty ? null
        : qualifiers.reduce((a, b) => a.conversionRate >= b.conversionRate ? a : b);
    final active = base.reduce((a, b) => a.messagesSent >= b.messagesSent ? a : b);
    final withRt = base.where((e) => e.avgResponseTimeSeconds > 0).toList();
    final fastest = withRt.isEmpty ? null
        : withRt.reduce((a, b) => a.avgResponseTimeSeconds <= b.avgResponseTimeSeconds ? a : b);
    final withRev = base.where((e) => e.revenueAttributed > 0).toList();
    final topRev = withRev.isEmpty ? null
        : withRev.reduce((a, b) => a.revenueAttributed >= b.revenueAttributed ? a : b);

    final parts = <String>[
      if (top != null) 'Top Performer: ${_sanitizePdfName(top.name)} (${top.conversionRate.toStringAsFixed(1)}% conv)',
      'Most Active: ${_sanitizePdfName(active.name)} (${active.messagesSent} msgs)',
      if (fastest != null) 'Fastest: ${_sanitizePdfName(fastest.name)} (${_formatDurationPdf(fastest.avgResponseTimeSeconds)})',
      if (topRev != null) 'Top Revenue: ${_sanitizePdfName(topRev.name)} (${topRev.revenueAttributed.toStringAsFixed(0)} BHD)',
    ];

    return pw.Text(
      parts.join('  |  '),
      style: pw.TextStyle(fontSize: 7.5, color: _pdf.textMuted),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PDF INSIGHT + RECOMMENDATION GENERATORS
  // ─────────────────────────────────────────────────────────────────

  static List<String> _generateInsights(AnalyticsData data) {
    final m = data.current;
    final insights = <String>[];

    // 1. Best campaign by conversion rate
    if (data.campaigns.isNotEmpty) {
      final best = data.campaigns.reduce((a, b) =>
          safeDiv(a.leads, a.sent) >= safeDiv(b.leads, b.sent) ? a : b);
      final bestConv = safeDiv(best.leads, best.sent) * 100;
      insights.add('Top campaign: "${best.name}" achieved ${bestConv.toStringAsFixed(1)}% conversion (${best.leads} leads from ${best.sent} recipients).');
    }

    // 2. Revenue per 1K messages
    if (m.revenue > 0 && m.messagesSent > 0) {
      final rev1k = safeDiv(m.revenue, m.messagesSent) * 1000;
      insights.add('Revenue efficiency: BHD ${rev1k.toStringAsFixed(2)} per 1,000 messages sent.');
    }

    // 3. Conversion funnel percentages
    final totalSent = data.campaigns.fold<int>(0, (s, c) => s + c.sent);
    if (totalSent > 0 && m.leads > 0) {
      final leadPct = (safeDiv(m.leads, totalSent) * 100).toStringAsFixed(1);
      final bookedPct = m.leads > 0 && m.appointmentsBooked > 0
          ? ', ${(safeDiv(m.appointmentsBooked, m.leads) * 100).toStringAsFixed(0)}% booked appointments'
          : '';
      final paidPct = m.appointmentsBooked > 0 && m.paymentsDone > 0
          ? ', ${(safeDiv(m.paymentsDone, m.appointmentsBooked) * 100).toStringAsFixed(0)}% completed payment'
          : '';
      insights.add('Conversion funnel: $leadPct% of broadcast recipients became leads$bookedPct$paidPct.');
    }

    // 4. Agent response-time compliance
    final empMap = m.employeeAvgResponseTime;
    if (empMap.isNotEmpty) {
      final onTarget = empMap.values.where((v) => v <= 1800).length;
      final pct = (safeDiv(onTarget, empMap.length) * 100).toStringAsFixed(0);
      insights.add('$onTarget of ${empMap.length} agent${empMap.length == 1 ? '' : 's'} respond within 30 minutes ($pct% on target).');
    }

    // 5. Organic leads (only if present)
    if (m.organicLeads > 0) {
      insights.add('${m.organicLeads} organic lead${m.organicLeads == 1 ? '' : 's'} from direct conversations, not attributed to any broadcast.');
    }

    // 6. Overdue conversations (only if present)
    if (m.overdueConversationCount > 0) {
      insights.add('${m.overdueConversationCount} conversation${m.overdueConversationCount == 1 ? '' : 's'} currently overdue. Prioritise these for immediate follow-up.');
    }

    // 7. Top employee performer
    if (data.employeePerformance.isNotEmpty) {
      final qualified = data.employeePerformance
          .where((e) => e.conversationsHandled >= 3)
          .toList();
      if (qualified.isNotEmpty) {
        final top = qualified.first; // sorted by conv rate desc
        final teamAvg = safeDiv(
          qualified.fold<double>(0, (s, e) => s + e.conversionRate),
          qualified.length,
        );
        if (teamAvg > 0) {
          insights.add('${top.name} leads the team with ${top.conversionRate.toStringAsFixed(1)}% '
              'conversion across ${top.conversationsHandled} conversations '
              '(team avg: ${teamAvg.toStringAsFixed(1)}%).');
        } else if (data.current.appointmentsBooked > 0) {
          insights.add('Team booked ${data.current.appointmentsBooked} appointments from '
              '${data.current.leads} leads across ${data.employeePerformance.length} agents.');
        }
      }
    }

    return insights;
  }

  // ─────────────────────────────────────────────────────────────────
  // DYNAMIC RECOMMENDATION ENGINE
  // Each candidate has a priority bucket (lower = shown first).
  // Only the top 5 are surfaced; positive reinforcements fill last.
  // ─────────────────────────────────────────────────────────────────

  static List<(String, String)> _generateRecommendations(AnalyticsData data) {
    final m = data.current;

    // (priority, title, body)   -  lower priority number = shown first
    final candidates = <(int, String, String)>[];

    // ── helpers ──────────────────────────────────────────────────────
    final empMap   = m.employeeAvgResponseTime;
    final totalSent = data.campaigns.fold<int>(0, (s, c) => s + c.sent);
    // Period length in days (derived from daily breakdown, min 1)
    final periodDays = data.dailyBreakdown.isNotEmpty ? data.dailyBreakdown.length : 30;
    final weeksInPeriod = periodDays / 7.0;

    // ── 1. REVENUE / CONVERSION ───────────────────────────────────────

    // Payment conversion
    if (m.appointmentsBooked >= 1) {
      final payRate = safeDiv(m.paymentsDone, m.appointmentsBooked);
      if (payRate < 0.8) {
        final missed = m.appointmentsBooked - m.paymentsDone;
        candidates.add((1,
          'Implement payment reminder flow',
          '${(payRate * 100).toStringAsFixed(0)}% of booked appointments convert to payments. '
          'A 24-hour reminder message could recover $missed outstanding payment${missed == 1 ? '' : 's'}.',
        ));
      } else {
        candidates.add((5,
          'Strong payment conversion',
          '${(payRate * 100).toStringAsFixed(0)}% of bookings convert to payment  -  excellent execution. '
          'Consider early-payment incentives to push toward 90%+.',
        ));
      }
    }

    // Top campaign > 2x average conversion
    if (data.campaigns.length >= 2) {
      final convRates = data.campaigns
          .map((c) => safeDiv(c.leads, c.sent))
          .toList();
      final avgConv = safeDiv(
        convRates.fold<double>(0, (s, v) => s + v),
        convRates.length,
      );
      final best = data.campaigns.reduce((a, b) =>
          safeDiv(a.leads, a.sent) >= safeDiv(b.leads, b.sent) ? a : b);
      final bestConv = safeDiv(best.leads, best.sent);
      if (avgConv > 0 && bestConv >= avgConv * 2.0) {
        final mult = safeDiv(bestConv, avgConv);
        candidates.add((1,
          'Scale your top campaign format',
          '"${best.name}" achieved ${(bestConv * 100).toStringAsFixed(1)}% conversion  -  '
          '${mult.toStringAsFixed(1)}x your average. '
          'Replicate this campaign structure for other services.',
        ));
      }
    }

    // ── 2. RESPONSE TIME ─────────────────────────────────────────────

    if (empMap.isNotEmpty) {
      final over30 = empMap.values.where((v) => v > 1800).length;

      // More than 50% over 30-min target
      if (over30 > empMap.length / 2) {
        candidates.add((2,
          'Unlock faster response times',
          'Enabling AI auto-reply during peak hours or rebalancing workload could bring '
          'all $over30 agent${over30 == 1 ? '' : 's'} within the 30-minute window, '
          'boosting conversion and customer satisfaction.',
        ));
      }

      // Best agent 10x faster than worst
      final sortedTimes = empMap.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      if (sortedTimes.length >= 2) {
        final fastest = sortedTimes.first;
        final slowest = sortedTimes.last;
        if (fastest.value > 0 && slowest.value >= fastest.value * 10) {
          candidates.add((2,
            'Share best practices from top responders',
            '${_sanitizePdfName(fastest.key)} averages ${_formatDurationPdf(fastest.value)} '
            'while ${_sanitizePdfName(slowest.key)} averages ${_formatDurationPdf(slowest.value)}. '
            'A short training session or buddy system could significantly lift slower responders.',
          ));
        }
      }
    }

    // Average response time > 1 hour
    if (m.avgResponseTimeSeconds > 3600) {
      candidates.add((2,
        'Reduce average response time',
        'Current average is ${_formatDurationPdf(m.avgResponseTimeSeconds)}. '
        'Customers who receive a reply within 5 minutes are significantly more likely to convert.',
      ));
    } else if (m.avgResponseTimeSeconds > 0 && m.avgResponseTimeSeconds < 900) {
      // < 15 minutes  -  competitive advantage
      candidates.add((5,
        'Response time is a competitive advantage',
        'Your team averages ${_formatDurationPdf(m.avgResponseTimeSeconds)}  -  '
        'well within best-in-class for the GCC. '
        'Consider highlighting this speed in your marketing materials.',
      ));
    }

    // ── 3. CAMPAIGN OPTIMIZATION ─────────────────────────────────────

    // Broadcast cadence
    final campaignsPerWeek = safeDiv(data.campaigns.length, weeksInPeriod);
    if (campaignsPerWeek < 2) {
      final days = periodDays;
      candidates.add((3,
        'Increase broadcast cadence',
        'You sent ${data.campaigns.length} campaign${data.campaigns.length == 1 ? '' : 's'} '
        'in $days days. Revenue consistently spikes on broadcast days  -  '
        'consider 2-3 campaigns per week to sustain momentum.',
      ));
    } else {
      candidates.add((5,
        'Maintain broadcast momentum',
        'Consistent broadcasting at ${campaignsPerWeek.toStringAsFixed(1)} per week is driving '
        'a steady lead flow. Keep this cadence going.',
      ));
    }

    // ── 4. ENGAGEMENT ─────────────────────────────────────────────────

    if (data.campaigns.isNotEmpty && m.engagementRate > 0) {
      if (m.engagementRate < 5) {
        candidates.add((3,
          'Boost engagement through personalisation',
          'Current engagement is ${m.engagementRate.toStringAsFixed(1)}%. '
          'Using customer names, recent visit history, or service-specific offers '
          'can meaningfully increase message relevance and reply rates.',
        ));
      } else if (m.engagementRate < 10) {
        candidates.add((4,
          'Grow engagement through smarter segmentation',
          'Engagement at ${m.engagementRate.toStringAsFixed(1)}% shows a solid foundation. '
          'Segmenting by visit recency or service interest can push this meaningfully higher.',
        ));
      } else {
        candidates.add((5,
          'Exceptional engagement  -  expand reach',
          'At ${m.engagementRate.toStringAsFixed(1)}% engagement, your messaging resonates strongly. '
          'Consider increasing broadcast frequency or expanding to new customer segments.',
        ));
      }
    }

    // ── 5. ORGANIC LEADS ─────────────────────────────────────────────

    if (m.organicLeads > 0) {
      candidates.add((4,
        'Nurture organic leads',
        '${m.organicLeads} customer${m.organicLeads == 1 ? '' : 's'} initiated contact independently. '
        'These high-intent leads deserve priority response and a dedicated follow-up sequence.',
      ));
    } else if (totalSent > 0) {
      candidates.add((4,
        'Drive inbound conversations',
        'All leads came from broadcasts. Adding a WhatsApp click-to-chat button on your website '
        'and social profiles can capture organic interest between campaigns.',
      ));
    }

    // ── 6. OVERDUE CONVERSATIONS ──────────────────────────────────────

    if (m.overdueConversationCount > 3) {
      candidates.add((1,
        'Address overdue conversations',
        '${m.overdueConversationCount} conversations have exceeded the response threshold. '
        'These customers are at risk of dropping off  -  prioritise them now.',
      ));
    } else if (m.overdueConversationCount == 0 && m.openConversationCount >= 0) {
      candidates.add((5,
        'All conversations are current',
        'No overdue conversations  -  your team is staying on top of customer enquiries. '
        'Great operational discipline.',
      ));
    }

    // ── 7. GROWTH TREND ───────────────────────────────────────────────

    final cmp = data.comparison;
    if (cmp != null && cmp.leads > 0) {
      final delta = m.leads - cmp.leads;
      final pct = (safeDiv(delta.abs(), cmp.leads) * 100).toStringAsFixed(0);
      if (delta > 0) {
        candidates.add((5,
          'Lead growth trending up',
          'Leads increased by $pct% vs the previous period. '
          'Maintain the campaign mix that is driving this growth.',
        ));
      } else if (delta < 0) {
        candidates.add((3,
          'Reignite lead generation',
          'Leads decreased by $pct% vs the previous period. '
          'Review which campaign types drove the most leads last period and relaunch them.',
        ));
      }
    }

    // ── 8. EMPLOYEE PERFORMANCE ──────────────────────────────────────

    if (data.employeePerformance.isNotEmpty) {
      final qualified = data.employeePerformance
          .where((e) => e.conversationsHandled >= 3)
          .toList();
      if (qualified.length >= 2) {
        final teamAvgConv = safeDiv(
          qualified.fold<double>(0, (s, e) => s + e.conversionRate),
          qualified.length,
        );
        final top = qualified.first; // sorted by conv rate desc

        // Top employee >2x team avg → mentor recommendation
        if (teamAvgConv > 0 && top.conversionRate >= teamAvgConv * 2.0) {
          final mult = safeDiv(top.conversionRate, teamAvgConv);
          candidates.add((2,
            'Leverage ${top.name}\'s conversion technique',
            '${top.name} converts at ${top.conversionRate.toStringAsFixed(1)}%  -  '
            '${mult.toStringAsFixed(1)}x the team average of ${teamAvgConv.toStringAsFixed(1)}%. '
            'A short coaching session could lift overall team conversion significantly.',
          ));
        }

        // High volume, low conversion → training opportunity
        final lowConvEmp = qualified
            .where((e) => e.messagesSent >= 50 && e.conversionRate < teamAvgConv * 0.7)
            .toList();
        if (lowConvEmp.isNotEmpty) {
          final emp = lowConvEmp.first;
          candidates.add((3,
            'Sales coaching for ${emp.name}',
            '${emp.name} is handling ${emp.conversationsHandled} conversations '
            'but converting at only ${emp.conversionRate.toStringAsFixed(1)}%. '
            'Focused training could close the gap with the ${teamAvgConv.toStringAsFixed(1)}% team average.',
          ));
        }

        // Fast response + high conversion → positive reinforcement
        final fastAndStrong = qualified
            .where((e) =>
                e.avgResponseTimeSeconds > 0 &&
                e.avgResponseTimeSeconds < 600 &&
                e.conversionRate >= teamAvgConv)
            .toList();
        if (fastAndStrong.isNotEmpty) {
          final emp = fastAndStrong.first;
          candidates.add((5,
            '${emp.name}\'s speed-to-conversion model works',
            '${emp.name} combines a ${_formatDurationPdf(emp.avgResponseTimeSeconds)} average response '
            'with a ${emp.conversionRate.toStringAsFixed(1)}% conversion rate  -  '
            'demonstrating that fast response directly drives revenue.',
          ));
        }
      }
    }

    // ── SORT & LIMIT ──────────────────────────────────────────────────
    // Sort by priority (ascending), then ensure at least one positive
    // reinforcement (priority 5) if everything else is green.
    candidates.sort((a, b) => a.$1.compareTo(b.$1));

    final top5 = candidates.take(5).toList();

    // Guarantee at least one positive reinforcement when top 5 are all
    // actionable (priority < 5) and there is a positive candidate available.
    final hasPositive = top5.any((r) => r.$1 == 5);
    if (!hasPositive) {
      final positives = candidates.where((r) => r.$1 == 5).toList();
      if (positives.isNotEmpty && top5.length >= 5) {
        top5[4] = positives.first; // replace last with first positive
      }
    }

    final result = top5.map<(String, String)>((r) => (r.$2, r.$3)).toList();

    if (result.isEmpty) {
      result.add(('Performance is on track',
        'Key metrics are within healthy ranges. '
        'Continue monitoring engagement weekly and maintain broadcast frequency.'));
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL SHEET 1: EXECUTIVE SUMMARY
  // ─────────────────────────────────────────────────────────────────

  static void _xlSummarySheet(Sheet s, AnalyticsData data, String clientName, String dateRange, String timestamp) {
    final m = data.current;
    s.setColumnWidth(0, 28);
    s.setColumnWidth(1, 20);
    s.setColumnWidth(2, 20);

    // Title row
    s.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0));
    _xlSet(s, 0, 0, 'VIVID ANALYTICS REPORT  -  $clientName', header: true, fontSize: 14);
    s.setRowHeight(0, 32);

    // Subtitle
    s.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1));
    _xlSet(s, 0, 1, 'Period: $dateRange  |  Generated: $timestamp', subheader: true);

    // Blank
    s.setRowHeight(2, 8);

    // KPI section header
    s.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3));
    _xlSet(s, 0, 3, 'KEY METRICS', section: true);

    // Column headers
    _xlSet(s, 0, 4, 'Metric', header: true);
    _xlSet(s, 1, 4, 'Current Period', header: true);
    if (data.comparison != null) _xlSet(s, 2, 4, 'Comparison Period', header: true);

    final rows = [
      ('Total Leads', '${m.leads}', data.comparison != null ? '${data.comparison!.leads}' : null),
      ('Total Revenue (BHD)', m.revenue.toStringAsFixed(2), data.comparison != null ? data.comparison!.revenue.toStringAsFixed(2) : null),
      ('Appointments Booked', '${m.appointmentsBooked}', null),
      ('Payments Done', '${m.paymentsDone}', null),
      ('Engagement Rate', '${m.engagementRate.toStringAsFixed(1)}%', data.comparison != null ? '${data.comparison!.engagementRate.toStringAsFixed(1)}%' : null),
      ('Avg Response Time', _formatDurationPdf(m.avgResponseTimeSeconds), null),
      ('Open Conversations', '${m.openConversationCount}', null),
      ('Overdue Conversations', '${m.overdueConversationCount}', null),
      ('Messages Sent', '${m.messagesSent}', data.comparison != null ? '${data.comparison!.messagesSent}' : null),
      ('Messages Received', '${m.messagesReceived}', data.comparison != null ? '${data.comparison!.messagesReceived}' : null),
    ];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final alt = i % 2 != 0;
      _xlSet(s, 0, 5 + i, row.$1, alt: alt);
      _xlSet(s, 1, 5 + i, row.$2, alt: alt, align: HorizontalAlign.Center);
      if (row.$3 != null) _xlSet(s, 2, 5 + i, row.$3!, alt: alt, align: HorizontalAlign.Center);
    }

    // Insights section
    final insightStartRow = 5 + rows.length + 2;
    s.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: insightStartRow), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: insightStartRow));
    _xlSet(s, 0, insightStartRow, 'KEY INSIGHTS', section: true);

    final insights = _generateInsights(data);
    for (var i = 0; i < insights.length; i++) {
      s.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: insightStartRow + 1 + i), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: insightStartRow + 1 + i));
      _xlSet(s, 0, insightStartRow + 1 + i, '• ${insights[i]}', alt: i % 2 != 0);
      s.setRowHeight(insightStartRow + 1 + i, 24);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL SHEET 2: CAMPAIGN PERFORMANCE
  // ─────────────────────────────────────────────────────────────────

  static void _xlCampaignSheet(Sheet s, AnalyticsData data) {
    s.setColumnWidth(0, 28); // Campaign
    s.setColumnWidth(1, 12); // Date
    s.setColumnWidth(2, 10); // Sent
    s.setColumnWidth(3, 12); // Responded
    s.setColumnWidth(4, 10); // Leads
    s.setColumnWidth(5, 14); // Revenue
    s.setColumnWidth(6, 14); // Rev/1K
    s.setColumnWidth(7, 14); // Engagement %
    s.setColumnWidth(8, 14); // Conversion %

    final headers = ['Campaign', 'Date', 'Sent', 'Responded', 'Leads', 'Revenue (BHD)', 'Rev/1K Sent', 'Engagement %', 'Conversion %'];
    for (var i = 0; i < headers.length; i++) {
      _xlSet(s, i, 0, headers[i], header: true);
    }
    s.setRowHeight(0, 28);

    final campaigns = data.campaigns;
    for (var i = 0; i < campaigns.length; i++) {
      final c = campaigns[i];
      final r = i + 1;
      final alt = i % 2 != 0;
      _xlSet(s, 0, r, c.name, alt: alt);
      _xlSet(s, 1, r, c.sentAt != null ? _formatDateIso(c.sentAt!) : '', alt: alt);
      _xlSet(s, 2, r, c.sent, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 3, r, c.responded, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 4, r, c.leads, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 5, r, c.revenue, alt: alt, align: HorizontalAlign.Center, positive: c.revenue > 0);
      // Rev/1K formula: =IF(C{r+1}>0, F{r+1}/C{r+1}*1000, 0)
      final excelRow = r + 1; // 1-based for formula
      s.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r)).setFormula('=IF(C$excelRow>0,F$excelRow/C$excelRow*1000,0)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: r)).setFormula('=IF(C$excelRow>0,D$excelRow/C$excelRow*100,0)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: r)).setFormula('=IF(C$excelRow>0,E$excelRow/C$excelRow*100,0)');
    }

    // Totals row
    if (campaigns.isNotEmpty) {
      final totalRow = campaigns.length + 1;
      final lastDataRow = campaigns.length + 1; // 1-based
      _xlSet(s, 0, totalRow, 'TOTALS', header: true);
      s.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalRow)).setFormula('=SUM(C2:C$lastDataRow)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow)).setFormula('=SUM(D2:D$lastDataRow)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow)).setFormula('=SUM(E2:E$lastDataRow)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow)).setFormula('=SUM(F2:F$lastDataRow)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRow)).setFormula('=IF(C${totalRow+1}>0,F${totalRow+1}/C${totalRow+1}*1000,0)');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL SHEET 3: EMPLOYEE PERFORMANCE
  // ─────────────────────────────────────────────────────────────────

  static void _xlEmployeeSheet(Sheet s, AnalyticsData data) {
    s.setColumnWidth(0, 22);
    s.setColumnWidth(1, 12);
    s.setColumnWidth(2, 14);
    s.setColumnWidth(3, 18);
    s.setColumnWidth(4, 12);
    s.setColumnWidth(5, 12);
    s.setColumnWidth(6, 14);
    s.setColumnWidth(7, 16);

    const headers = [
      'Employee', 'Messages', 'Conversations', 'Avg Response',
      'Appts Booked', 'Payments', 'Conv Rate %', 'Revenue (BHD)',
    ];
    for (var i = 0; i < headers.length; i++) {
      _xlSet(s, i, 0, headers[i], header: true);
    }
    s.setRowHeight(0, 28);

    final employees = data.employeePerformance;

    for (var i = 0; i < employees.length; i++) {
      final e = employees[i];
      final alt = i % 2 != 0;
      final row = i + 1;
      _xlSet(s, 0, row, e.name, alt: alt);
      _xlSet(s, 1, row, e.messagesSent, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 2, row, e.conversationsHandled, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 3, row, _formatDurationPdf(e.avgResponseTimeSeconds), alt: alt, align: HorizontalAlign.Center);
      _xlStyleCell(s, 3, row,
          fontColor: e.avgResponseTimeSeconds < 300
              ? ExcelColor.fromHexString('FF059669')
              : e.avgResponseTimeSeconds < 1800
                  ? ExcelColor.fromHexString('FF0d9488')
                  : e.avgResponseTimeSeconds < 3600
                      ? ExcelColor.fromHexString('FFd97706')
                      : ExcelColor.fromHexString('FFdc2626'));
      _xlSet(s, 4, row, e.appointmentsBooked, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 5, row, e.paymentsCollected, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 6, row, e.conversionRate.toStringAsFixed(1), alt: alt,
          align: HorizontalAlign.Center, positive: e.conversionRate >= 20);
      _xlSet(s, 7, row, e.revenueAttributed.toStringAsFixed(3), alt: alt,
          align: HorizontalAlign.Right, positive: e.revenueAttributed > 0);
    }

    // TOTALS row
    if (employees.isNotEmpty) {
      final totalsRow = employees.length + 1;
      s.setRowHeight(totalsRow, 22);
      _xlSet(s, 0, totalsRow, 'TOTAL', header: true);
      _xlSet(s, 1, totalsRow, employees.fold(0, (sum, e) => sum + e.messagesSent), header: true, align: HorizontalAlign.Center);
      _xlSet(s, 2, totalsRow, employees.fold(0, (sum, e) => sum + e.conversationsHandled), header: true, align: HorizontalAlign.Center);
      _xlSet(s, 3, totalsRow, '', header: true);
      _xlSet(s, 4, totalsRow, employees.fold(0, (sum, e) => sum + e.appointmentsBooked), header: true, align: HorizontalAlign.Center);
      _xlSet(s, 5, totalsRow, employees.fold(0, (sum, e) => sum + e.paymentsCollected), header: true, align: HorizontalAlign.Center);
      _xlSet(s, 6, totalsRow, '', header: true);
      final totalRevenue = employees.fold(0.0, (sum, e) => sum + e.revenueAttributed);
      _xlSet(s, 7, totalsRow, totalRevenue.toStringAsFixed(3), header: true,
          align: HorizontalAlign.Right, positive: totalRevenue > 0);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL SHEET 4: DAILY BREAKDOWN
  // ─────────────────────────────────────────────────────────────────

  static void _xlDailySheet(Sheet s, AnalyticsData data) {
    s.setColumnWidth(0, 14);
    s.setColumnWidth(1, 12);
    s.setColumnWidth(2, 16);
    s.setColumnWidth(3, 18);
    s.setColumnWidth(4, 22);

    final headers = ['Date', 'Leads', 'Revenue (BHD)', 'Engagement Rate %', 'Avg Response Time'];
    for (var i = 0; i < headers.length; i++) {
      _xlSet(s, i, 0, headers[i], header: true);
    }
    s.setRowHeight(0, 28);

    final days = data.dailyBreakdown;
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final alt = i % 2 != 0;
      _xlSet(s, 0, i + 1, d.date, alt: alt);
      _xlSet(s, 1, i + 1, d.leads, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 2, i + 1, d.revenue, alt: alt, align: HorizontalAlign.Center, positive: d.revenue > 0);
      _xlSet(s, 3, i + 1, d.engagementRate, alt: alt, align: HorizontalAlign.Center);
      _xlSet(s, 4, i + 1, _formatDurationPdf(d.avgResponseTimeSeconds), alt: alt, align: HorizontalAlign.Center);
    }

    // Totals
    if (days.isNotEmpty) {
      final totalRow = days.length + 1;
      final lastData = days.length + 1;
      _xlSet(s, 0, totalRow, 'TOTALS', header: true);
      s.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow)).setFormula('=SUM(B2:B$lastData)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalRow)).setFormula('=SUM(C2:C$lastData)');
      s.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow)).setFormula('=AVERAGE(D2:D$lastData)');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL SHEET 5: ACTION REQUIRED (OPEN CONVERSATIONS)
  // ─────────────────────────────────────────────────────────────────

  static void _xlActionSheet(Sheet s, AnalyticsData data) {
    s.setColumnWidth(0, 20);
    s.setColumnWidth(1, 28);
    s.setColumnWidth(2, 50);
    s.setColumnWidth(3, 18);

    final headers = ['Phone', 'Customer Name', 'Last Message', 'Waiting Time'];
    for (var i = 0; i < headers.length; i++) {
      _xlSet(s, i, 0, headers[i], header: true);
    }
    s.setRowHeight(0, 28);

    final sorted = [...data.openConversations]..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    for (var i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      final alt = i % 2 != 0;
      final waitMin = c.waitingTime.inMinutes;
      final waitLabel = waitMin > 1440 ? '${waitMin ~/ 1440}d ${waitMin % 1440 ~/ 60}h' : waitMin > 60 ? '${waitMin ~/ 60}h ${waitMin % 60}m' : '${waitMin}m';
      _xlSet(s, 0, i + 1, c.customerPhone, alt: alt);
      _xlSet(s, 1, i + 1, c.customerName ?? '', alt: alt);
      _xlSet(s, 2, i + 1, c.lastMessage.length > 120 ? '${c.lastMessage.substring(0, 120)}…' : c.lastMessage, alt: alt);
      _xlSet(s, 3, i + 1, waitLabel, alt: alt, align: HorizontalAlign.Center, negative: waitMin > 30);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // EXCEL CELL HELPERS
  // ─────────────────────────────────────────────────────────────────

  static final _xlNavy = ExcelColor.fromHexString('FF0a1628');
  static final _xlCyan = ExcelColor.fromHexString('FF00d4aa');
  static final _xlDark = ExcelColor.fromHexString('FF1e293b');
  static final _xlAlt = ExcelColor.fromHexString('FFf8fafc');
  static final _xlWhite = ExcelColor.white;
  static final _xlGreen = ExcelColor.fromHexString('FF059669');
  static final _xlRed = ExcelColor.fromHexString('FFdc2626');
  static final _xlSection = ExcelColor.fromHexString('FF1e293b');
  static final _xlSectionText = ExcelColor.fromHexString('FF94a3b8');

  static void _xlSet(
    Sheet s,
    int col,
    int row,
    dynamic value, {
    bool header = false,
    bool subheader = false,
    bool section = false,
    bool alt = false,
    bool positive = false,
    bool negative = false,
    HorizontalAlign align = HorizontalAlign.Left,
    int? fontSize,
  }) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is int) {
      cell.value = IntCellValue(value);
    } else if (value is double) {
      cell.value = DoubleCellValue(value);
    } else {
      cell.value = TextCellValue(value.toString());
    }

    if (header) {
      cell.cellStyle = CellStyle(
        backgroundColorHex: _xlNavy,
        fontColorHex: _xlCyan,
        bold: true,
        horizontalAlign: align == HorizontalAlign.Left ? HorizontalAlign.Center : align,
        fontSize: fontSize ?? 10,
      );
    } else if (subheader) {
      cell.cellStyle = CellStyle(
        backgroundColorHex: _xlNavy,
        fontColorHex: _xlSectionText,
        fontSize: 9,
      );
    } else if (section) {
      cell.cellStyle = CellStyle(
        backgroundColorHex: _xlSection,
        fontColorHex: _xlCyan,
        bold: true,
        fontSize: 10,
      );
    } else {
      cell.cellStyle = CellStyle(
        backgroundColorHex: alt ? _xlAlt : _xlWhite,
        fontColorHex: negative
            ? _xlRed
            : positive
                ? _xlGreen
                : _xlDark,
        bold: negative || positive,
        horizontalAlign: align,
        fontSize: fontSize ?? 10,
      );
    }
  }

  /// Apply only a font color to an existing cell (used after setFormula).
  static void _xlStyleCell(Sheet s, int col, int row, {ExcelColor? fontColor}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.cellStyle = CellStyle(fontColorHex: fontColor ?? _xlDark, fontSize: 10);
  }

  // ─────────────────────────────────────────────────────────────────
  // FORMAT HELPERS
  // ─────────────────────────────────────────────────────────────────

  static String _formatDurationPdf(double seconds) {
    final s = _sfPdf(seconds); // guard infinity / NaN before any arithmetic
    if (s <= 0) return '0s';
    if (s < 60) return '${s.toStringAsFixed(0)}s';
    if (s < 3600) {
      final m = (s / 60).floor();
      final r = (s % 60).floor();
      return r > 0 ? '${m}m ${r}s' : '${m}m';
    }
    final h = (s / 3600).floor();
    final m = ((s % 3600) / 60).floor();
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  static String _fmtNumber(double v) {
    if (v == 0) return '0';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static final _numFmt = NumberFormat('#,###');
  static String _fmtInt(int v) => _numFmt.format(v);

  static String _fmtDurationCsv(double seconds) {
    if (seconds <= 0) return '0s';
    if (seconds < 60) return '${seconds.toStringAsFixed(0)}s';
    if (seconds < 3600) {
      final m = (seconds / 60).floor();
      final s = (seconds % 60).floor();
      return s > 0 ? '${m}m ${s}s' : '${m}m';
    }
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  static String _fmtWaitTimeCsv(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  static String _formatDateIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _formatDateShort(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day}/${d.month}';
  }

  static String _escapeCsv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _escapeHtml(String v) =>
      v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  // ─────────────────────────────────────────────────────────────────
  // LEGACY PDF TABLES (kept for backward compatibility)
  // ─────────────────────────────────────────────────────────────────


  static pw.Widget _buildOpenConversationsTable(List<OpenConversation> convos) {
    final sorted = [...convos]..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    final display = sorted.take(20).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FixedColumnWidth(55),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: ['Phone', 'Name', 'Last Message', 'Waiting'].map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              )).toList(),
        ),
        ...List.generate(display.length, (i) {
          final c = display[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          final waitMin = c.waitingTime.inMinutes;
          final waitLabel = waitMin > 1440 ? '${waitMin ~/ 1440}d' : waitMin > 60 ? '${waitMin ~/ 60}h' : '${waitMin}m';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(c.customerPhone, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                _sanitizePdfName(c.customerName ?? '-'),
                style: _arStyle(pw.TextStyle(fontSize: 8, color: _pdf.navy), c.customerName ?? ''),
                textDirection: isArabicText(c.customerName ?? '') ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                c.lastMessage.length > 60 ? '${c.lastMessage.substring(0, 60)}...' : c.lastMessage,
                style: _arStyle(pw.TextStyle(fontSize: 8, color: _pdf.textMuted), c.lastMessage),
                textDirection: isArabicText(c.lastMessage) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                waitLabel,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: waitMin > 30 ? _pdf.red : _pdf.amber),
                textAlign: pw.TextAlign.center,
              )),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildDailyTable(List<DailyBreakdown> days) {
    final recent = days.length > 30 ? days.sublist(days.length - 30) : days;
    final totalLeads = recent.fold<int>(0, (s, d) => s + d.leads);
    final totalRev = recent.fold<double>(0, (s, d) => s + d.revenue);

    // Column widths chosen so every header word fits on one line at 7pt with
    // 5px horizontal padding.  "Leads"(5ch)≈20px, "Revenue"(7ch)≈28px,
    // "Eng%"(4ch)≈16px, "Resp.Time"(9ch)≈36px all fit with room to spare.
    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),   // Date
        1: const pw.FixedColumnWidth(42), // Leads
        2: const pw.FixedColumnWidth(52), // Revenue
        3: const pw.FixedColumnWidth(42), // Eng%
        4: const pw.FixedColumnWidth(60), // Resp. Time
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: ['Date', 'Leads', 'Revenue', 'Eng%', 'Resp. Time'].map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              )).toList(),
        ),
        ...List.generate(recent.length, (i) {
          final d = recent[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(d.date, style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${d.leads}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdf.cyan), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(d.revenue > 0 ? d.revenue.toStringAsFixed(0) : '-', style: pw.TextStyle(fontSize: 9, color: d.revenue > 0 ? _pdf.green : _pdf.textMuted), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${d.engagementRate.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 9, color: _pdf.blue), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatDurationPdf(d.avgResponseTimeSeconds), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
            ],
          );
        }),
        // Totals row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalLeads', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdf.cyan), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalRev > 0 ? totalRev.toStringAsFixed(0) : '-', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdf.green), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: const pw.TextStyle(fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // LEGACY BRANDED HEADER (used by broadcast + activity exports)
  // ─────────────────────────────────────────────────────────────────

  // ignore: unused_element
  static pw.Widget _buildBrandedHeader(String clientName, String subtitle) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      margin: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(color: _pdf.navy, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('VIVID', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdf.cyan, letterSpacing: 3)),
            pw.SizedBox(height: 4),
            pw.Text('Analytics Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(clientName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#8B97B0'))),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Vivid Systems  |  vividsystems.co', style: pw.TextStyle(fontSize: 8, color: _pdf.textMuted)),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: _pdf.textMuted)),
      ],
    );
  }

  // ignore: unused_element
  static pw.Widget _buildColoredSectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _buildPdfStatCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: color, width: 1.5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _pdf.textMuted)),
          pw.SizedBox(height: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  static pw.Widget _buildPdfHeader(String title, String clientName, String subtitle) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pdf.navy)),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(clientName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdf.navy)),
            pw.Text(subtitle, style: pw.TextStyle(fontSize: 10, color: _pdf.textMuted)),
          ]),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Container(height: 3, color: _pdf.cyan),
      pw.SizedBox(height: 20),
    ]);
  }

  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(color: _pdf.cyan, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // LEGACY: BROADCAST ANALYTICS EXPORTS (unchanged)
  // ─────────────────────────────────────────────────────────────────

  static void exportBroadcastAnalyticsToCsv({required dynamic data}) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());
    buffer.writeln('BROADCAST ANALYTICS REPORT');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('Business,${ClientConfig.businessName}');
    buffer.writeln('');
    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Campaigns,${data.totalCampaigns}');
    buffer.writeln('Total Recipients,${data.totalRecipients}');
    buffer.writeln('Total Delivered,${data.totalDelivered}');
    buffer.writeln('Total Read,${data.totalRead}');
    buffer.writeln('Total Failed,${data.totalFailed}');
    buffer.writeln('Delivery Rate,${data.deliveryRate.toStringAsFixed(1)}%');
    buffer.writeln('Read Rate,${data.readRate.toStringAsFixed(1)}%');
    buffer.writeln('');
    buffer.writeln('RECENT CAMPAIGNS');
    buffer.writeln('Campaign,Recipients,Delivered,Read,Failed,Sent At');
    for (final c in data.recentCampaigns) {
      buffer.writeln('${_escapeCsv(c.name)},${c.recipients},${c.delivered},${c.read},${c.failed},${_formatDateIso(c.sentAt)}');
    }
    _downloadFile(content: utf8.encode(buffer.toString()), filename: 'broadcast_analytics_$timestamp.csv', mimeType: 'text/csv');
  }

  static void exportBroadcastAnalyticsToExcel({required dynamic data}) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());
    buffer.writeln('<html><head><meta charset="UTF-8"><style>');
    buffer.writeln('table { border-collapse: collapse; margin-bottom: 20px; }');
    buffer.writeln('th { background-color: #9C27B0; color: white; padding: 10px; }');
    buffer.writeln('td { padding: 8px; border: 1px solid #e0e0e0; }');
    buffer.writeln('.highlight { background-color: #f9f0ff; }');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<table width="500">');
    buffer.writeln('<tr><th colspan="2">Broadcast Analytics - ${_escapeHtml(ClientConfig.businessName)}</th></tr>');
    buffer.writeln('<tr><td>Total Campaigns</td><td>${data.totalCampaigns}</td></tr>');
    buffer.writeln('<tr><td>Total Recipients</td><td>${data.totalRecipients}</td></tr>');
    buffer.writeln('<tr><td>Delivered</td><td>${data.totalDelivered}</td></tr>');
    buffer.writeln('<tr><td>Read</td><td>${data.totalRead}</td></tr>');
    buffer.writeln('<tr><td>Failed</td><td>${data.totalFailed}</td></tr>');
    buffer.writeln('<tr><td>Delivery Rate</td><td>${data.deliveryRate.toStringAsFixed(1)}%</td></tr>');
    buffer.writeln('<tr><td>Read Rate</td><td>${data.readRate.toStringAsFixed(1)}%</td></tr>');
    buffer.writeln('</table>');
    buffer.writeln('<table width="700">');
    buffer.writeln('<tr><th>Campaign</th><th>Recipients</th><th>Delivered</th><th>Read</th><th>Failed</th></tr>');
    for (var i = 0; i < (data.recentCampaigns as List).length; i++) {
      final c = data.recentCampaigns[i];
      final cls = i % 2 != 0 ? ' class="highlight"' : '';
      buffer.writeln('<tr$cls><td>${_escapeHtml(c.name)}</td><td>${c.recipients}</td><td>${c.delivered}</td><td>${c.read}</td><td>${c.failed}</td></tr>');
    }
    buffer.writeln('</table></body></html>');
    _downloadFile(content: utf8.encode(buffer.toString()), filename: 'broadcast_analytics_$timestamp.xls', mimeType: 'application/vnd.ms-excel');
  }

  static Future<void> exportBroadcastAnalyticsToPdf({required dynamic data}) async {
    final pdf = pw.Document();
    final timestamp = _formatDateIso(DateTime.now());
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: pw.ThemeData(),
      header: (context) => _buildPdfHeader('Broadcast Analytics', ClientConfig.businessName, timestamp),
      footer: (context) => _buildPdfFooter(context),
      build: (context) => [
        _buildPdfSectionHeader('Summary'),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          _buildPdfStatCard('Campaigns', '${data.totalCampaigns}', _pdf.blue),
          pw.SizedBox(width: 8),
          _buildPdfStatCard('Recipients', '${data.totalRecipients}', _pdf.cyan),
          pw.SizedBox(width: 8),
          _buildPdfStatCard('Delivered', '${data.totalDelivered}', _pdf.green),
          pw.SizedBox(width: 8),
          _buildPdfStatCard('Failed', '${data.totalFailed}', _pdf.red),
        ]),
        pw.SizedBox(height: 20),
        _buildPdfSectionHeader('Recent Campaigns'),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FixedColumnWidth(55),
            2: const pw.FixedColumnWidth(55),
            3: const pw.FixedColumnWidth(40),
            4: const pw.FixedColumnWidth(40),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _pdf.navy),
              children: ['Campaign', 'Recipients', 'Delivered', 'Read', 'Failed'].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
            ),
            ...List.generate((data.recentCampaigns as List).length, (i) {
              final c = data.recentCampaigns[i];
              final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                    c.name as String,
                    style: _arStyle(pw.TextStyle(fontSize: 9, color: _pdf.navy), c.name as String),
                    textDirection: isArabicText(c.name as String) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  )),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.recipients}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.delivered}', style: pw.TextStyle(fontSize: 9, color: _pdf.green), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.read}', style: pw.TextStyle(fontSize: 9, color: _pdf.blue), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.failed}', style: pw.TextStyle(fontSize: 9, color: c.failed > 0 ? _pdf.red : _pdf.textMuted), textAlign: pw.TextAlign.center)),
                ],
              );
            }),
          ],
        ),
      ],
    ));
    final bytes = await pdf.save();
    _downloadFile(content: bytes, filename: 'broadcast_analytics_$timestamp.pdf', mimeType: 'application/pdf');
  }

  // ─────────────────────────────────────────────────────────────────
  // LEGACY: ACTIVITY LOG EXPORTS (unchanged)
  // ─────────────────────────────────────────────────────────────────

  static void exportActivityLogsToCsv({required List<ActivityLog> logs, String filename = 'activity_logs'}) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());
    buffer.writeln('ACTIVITY LOGS REPORT');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('Business,${ClientConfig.businessName}');
    buffer.writeln('Total Entries,${logs.length}');
    buffer.writeln('');
    buffer.writeln('Date,Time,User,Email,Action,Description');
    for (final log in logs) {
      final date = _formatDateIso(log.createdAt);
      final time = '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}:${log.createdAt.second.toString().padLeft(2, '0')}';
      buffer.writeln('$date,$time,${_escapeCsv(log.userName)},${_escapeCsv(log.userEmail ?? '')},${_escapeCsv(log.actionType.displayName)},${_escapeCsv(log.description)}');
    }
    _downloadFile(content: utf8.encode(buffer.toString()), filename: '${filename}_$timestamp.csv', mimeType: 'text/csv');
  }

  static void exportActivityLogsToExcel({required List<ActivityLog> logs, String filename = 'activity_logs'}) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());
    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="UTF-8"><style>');
    buffer.writeln('body { font-family: Arial, sans-serif; }');
    buffer.writeln('table { border-collapse: collapse; margin-bottom: 30px; }');
    buffer.writeln('th { background-color: #1E88E5; color: white; font-weight: bold; padding: 12px; text-align: left; }');
    buffer.writeln('td { padding: 10px; border: 1px solid #e0e0e0; }');
    buffer.writeln('.header { background-color: #0A1628; color: #00D9FF; font-size: 18px; padding: 15px; }');
    buffer.writeln('.highlight { background-color: #f0f7ff; }');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<table width="900">');
    buffer.writeln('<tr><th colspan="6" class="header">Activity Logs - ${_escapeHtml(ClientConfig.businessName)}</th></tr>');
    buffer.writeln('<tr><td colspan="6">Generated: $timestamp | Total: ${logs.length} entries</td></tr>');
    buffer.writeln('</table>');
    buffer.writeln('<table width="900">');
    buffer.writeln('<tr><th>Date</th><th>Time</th><th>User</th><th>Email</th><th>Action</th><th>Description</th></tr>');
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final rowClass = i % 2 == 0 ? '' : ' class="highlight"';
      final date = _formatDateIso(log.createdAt);
      final time = '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';
      buffer.writeln('<tr$rowClass><td>$date</td><td>$time</td><td>${_escapeHtml(log.userName)}</td><td>${_escapeHtml(log.userEmail ?? '')}</td><td>${_escapeHtml(log.actionType.displayName)}</td><td>${_escapeHtml(log.description)}</td></tr>');
    }
    buffer.writeln('</table></body></html>');
    _downloadFile(content: utf8.encode(buffer.toString()), filename: '${filename}_$timestamp.xls', mimeType: 'application/vnd.ms-excel');
  }

  // ─────────────────────────────────────────────────────────────────
  // ADMIN: COMPANY ANALYTICS CSV EXPORT
  // ─────────────────────────────────────────────────────────────────

  static void exportCompanyAnalyticsCsv(VividCompanyAnalytics data) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());

    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('# VIVID COMPANY ANALYTICS REPORT');
    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('');

    buffer.writeln('# ─── OVERVIEW ───');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Clients,${data.totalClients}');
    buffer.writeln('Total Messages,${data.totalMessages}');
    buffer.writeln('Total Broadcasts,${data.totalBroadcasts}');
    buffer.writeln('Total Recipients Reached,${data.totalRecipientsReached}');
    buffer.writeln('Unique Customers,${data.totalUniqueCustomers}');
    buffer.writeln('AI Messages,${data.totalAiMessages}');
    buffer.writeln('Manager Messages,${data.totalManagerMessages}');
    buffer.writeln('Automation Rate,${data.overallAutomationRate.toStringAsFixed(1)}%');
    buffer.writeln('Handoff Count,${data.handoffCount}');
    buffer.writeln('AI Enabled Customers,${data.aiEnabledCustomers}');
    buffer.writeln('AI Disabled Customers,${data.aiDisabledCustomers}');
    buffer.writeln('Today Messages,${data.todayMessages}');
    buffer.writeln('This Week Messages,${data.thisWeekMessages}');
    buffer.writeln('This Month Messages,${data.thisMonthMessages}');
    if (data.lastActivityAcrossAll != null) {
      buffer.writeln('Last Activity,${_formatDateIso(data.lastActivityAcrossAll!)}');
    }
    buffer.writeln('');

    buffer.writeln('# ─── BROADCAST DELIVERY ───');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Recipients,${data.broadcastTotalRecipients}');
    buffer.writeln('Delivered,${data.broadcastDeliveredCount}');
    buffer.writeln('Read,${data.broadcastReadCount}');
    buffer.writeln('Failed,${data.broadcastFailedCount}');
    if (data.broadcastTotalRecipients > 0) {
      buffer.writeln('Delivery Rate,${(data.broadcastDeliveredCount / data.broadcastTotalRecipients * 100).toStringAsFixed(1)}%');
      buffer.writeln('Read Rate,${(data.broadcastReadCount / data.broadcastTotalRecipients * 100).toStringAsFixed(1)}%');
    }
    buffer.writeln('');

    if (data.allClientActivities.isNotEmpty) {
      buffer.writeln('# ─── CLIENT BREAKDOWN ───');
      buffer.writeln('Client,Messages,Broadcasts,AI Messages,Manager Messages,Unique Customers,Automation Rate,Last Activity');
      for (final ca in data.allClientActivities) {
        final lastAct = ca.lastActivity != null ? _formatDateIso(ca.lastActivity!) : 'N/A';
        buffer.writeln(
          '${_escapeCsv(ca.clientName)},${ca.messageCount},${ca.broadcastCount},${ca.aiMessages},${ca.managerMessages},${ca.uniqueCustomers},${ca.automationRate.toStringAsFixed(1)}%,$lastAct',
        );
      }
      buffer.writeln('');
    }

    if (data.topCustomers.isNotEmpty) {
      buffer.writeln('# ─── TOP CUSTOMERS ───');
      buffer.writeln('Phone,Name,Messages,Client');
      for (final tc in data.topCustomers) {
        buffer.writeln('${tc.phone},${_escapeCsv(tc.name ?? '')},${tc.messageCount},${_escapeCsv(tc.clientName)}');
      }
      buffer.writeln('');
    }

    if (data.messagesByDay.isNotEmpty) {
      buffer.writeln('# ─── MESSAGES BY DAY (LAST 7 DAYS) ───');
      buffer.writeln('Date,Messages');
      final sortedDays = data.messagesByDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedDays) {
        buffer.writeln('${entry.key},${entry.value}');
      }
      buffer.writeln('');
    }

    if (data.messagesByHour.isNotEmpty) {
      buffer.writeln('# ─── MESSAGES BY HOUR ───');
      buffer.writeln('Hour,Messages');
      for (int h = 0; h < 24; h++) {
        final count = data.messagesByHour[h] ?? 0;
        if (count > 0) buffer.writeln('$h,$count');
      }
    }

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: 'vivid_company_analytics_$timestamp.csv',
      mimeType: 'text/csv',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ADMIN: COMPANY ANALYTICS PDF EXPORT
  // ─────────────────────────────────────────────────────────────────

  static Future<void> exportCompanyAnalyticsPdf(VividCompanyAnalytics data) async {
    await Future.wait([_loadArabicFont(), _loadLogoImage()]);

    final pdf = pw.Document();
    final timestamp = _formatDateIso(DateTime.now());
    final subtitle = 'Generated $timestamp';
    const margin = pw.EdgeInsets.fromLTRB(28, 16, 28, 24);

    pw.MultiPage makePage(List<pw.Widget> Function(pw.Context) builder) =>
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: margin,
          header: (ctx) => _pdfPageHeader('Vivid Systems', subtitle),
          footer: (ctx) => _buildPdfFooter(ctx),
          build: builder,
        );

    // Page 1: Executive Summary
    pdf.addPage(makePage((_) => [
      _pdfSectionTitle('Company Overview', _pdf.navy),
      pw.SizedBox(height: 14),
      pw.Row(children: [
        _pdfKpiCard('Clients', '${data.totalClients}', _pdf.blue),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Messages', _fmtInt(data.totalMessages), _pdf.cyan),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Broadcasts', '${data.totalBroadcasts}', _pdf.purple),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Customers', _fmtInt(data.totalUniqueCustomers), _pdf.green),
      ]),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        _pdfKpiCard('AI Messages', _fmtInt(data.totalAiMessages), _pdf.teal),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Manager Msgs', _fmtInt(data.totalManagerMessages), _pdf.orange),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Automation', '${data.overallAutomationRate.toStringAsFixed(1)}%', _pdf.cyan),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Handoffs', '${data.handoffCount}', _pdf.amber),
      ]),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        _pdfKpiCard('Today', '${data.todayMessages}', _pdf.green),
        pw.SizedBox(width: 8),
        _pdfKpiCard('This Week', '${data.thisWeekMessages}', _pdf.blue),
        pw.SizedBox(width: 8),
        _pdfKpiCard('This Month', '${data.thisMonthMessages}', _pdf.purple),
        pw.SizedBox(width: 8),
        _pdfKpiCard('Recipients', _fmtInt(data.totalRecipientsReached), _pdf.teal),
      ]),

      // Broadcast delivery summary
      if (data.broadcastTotalRecipients > 0) ...[
        pw.SizedBox(height: 20),
        _pdfSectionTitle('Broadcast Delivery', _pdf.purple),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          _pdfKpiCard('Delivered', '${data.broadcastDeliveredCount}', _pdf.green),
          pw.SizedBox(width: 8),
          _pdfKpiCard('Read', '${data.broadcastReadCount}', _pdf.blue),
          pw.SizedBox(width: 8),
          _pdfKpiCard('Failed', '${data.broadcastFailedCount}', data.broadcastFailedCount > 0 ? _pdf.red : _pdf.textMuted),
          pw.SizedBox(width: 8),
          _pdfKpiCard('Delivery %', '${(data.broadcastDeliveredCount / data.broadcastTotalRecipients * 100).toStringAsFixed(1)}%', _pdf.green),
        ]),
      ],

      // Messages by day bar chart (text-based)
      if (data.messagesByDay.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        _pdfSectionTitle('Last 7 Days Activity', _pdf.teal),
        pw.SizedBox(height: 10),
        _buildTextBarChart(data.messagesByDay, _pdf.cyan),
      ],
    ]));

    // Page 2: Client Breakdown Table
    if (data.allClientActivities.isNotEmpty) {
      pdf.addPage(makePage((_) => [
        _pdfSectionTitle('Client Breakdown', _pdf.navy),
        pw.SizedBox(height: 14),
        _buildClientBreakdownTable(data.allClientActivities),
      ]));
    }

    // Page 3: Top Customers + Busiest Hours
    if (data.topCustomers.isNotEmpty || data.messagesByHour.isNotEmpty) {
      pdf.addPage(makePage((_) => [
        if (data.topCustomers.isNotEmpty) ...[
          _pdfSectionTitle('Top Customers', _pdf.blue),
          pw.SizedBox(height: 10),
          _buildTopCustomersTable(data.topCustomers),
          pw.SizedBox(height: 20),
        ],
        if (data.messagesByHour.isNotEmpty) ...[
          _pdfSectionTitle('Busiest Hours', _pdf.orange),
          pw.SizedBox(height: 10),
          _buildHourlyChart(data.messagesByHour, _pdf.orange),
        ],
      ]));
    }

    final bytes = await pdf.save();
    _downloadFile(
      content: bytes,
      filename: 'vivid_company_analytics_$timestamp.pdf',
      mimeType: 'application/pdf',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ADMIN: CLIENT REPORT PDF EXPORT
  // ─────────────────────────────────────────────────────────────────

  static Future<void> exportClientReportPdf({
    required Client client,
    ConversationClientAnalytics? conversationData,
    BroadcastClientAnalytics? broadcastData,
    // New per-feature metrics (dynamic — only non-null sections are exported)
    ClientOverviewMetrics? overview,
    ConversationMetrics? conversations,
    BroadcastMetrics? broadcasts,
    ManagerChatMetrics? managerChat,
    LabelMetrics? labels,
    PredictiveMetrics? predictions,
  }) async {
    await Future.wait([_loadArabicFont(), _loadLogoImage()]);

    final pdf = pw.Document();
    final timestamp = _formatDateIso(DateTime.now());
    final subtitle = 'Generated $timestamp';
    const margin = pw.EdgeInsets.fromLTRB(28, 16, 28, 24);

    pw.MultiPage makePage(List<pw.Widget> Function(pw.Context) builder) =>
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: margin,
          header: (ctx) => _pdfPageHeader(client.name, subtitle),
          footer: (ctx) => _buildPdfFooter(ctx),
          build: builder,
        );

    final hasNewMetrics = overview != null || conversations != null ||
        broadcasts != null || managerChat != null ||
        labels != null || predictions != null;

    // ── New dynamic export (feature-based) ──

    if (hasNewMetrics) {
      // Page 1: Overview + Client Info
      if (overview != null) {
        final o = overview;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Overview', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('Days Active', '${o.daysActive}', _pdf.teal),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Features', '${o.enabledFeatureCount}', _pdf.blue),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Total Messages', _fmtInt(o.totalMessages), _pdf.cyan),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Unique Customers', _fmtInt(o.uniqueCustomers), _pdf.purple),
          ]),
          if (o.totalBroadcasts > 0 || o.totalManagerQueries > 0) ...[
            pw.SizedBox(height: 12),
            pw.Row(children: [
              if (o.totalBroadcasts > 0) ...[
                _pdfKpiCard('Broadcasts', _fmtInt(o.totalBroadcasts), _pdf.orange),
                pw.SizedBox(width: 8),
              ],
              if (o.totalManagerQueries > 0) ...[
                _pdfKpiCard('Manager Queries', _fmtInt(o.totalManagerQueries), _pdf.purple),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(child: pw.SizedBox()),
            ]),
          ],
          pw.SizedBox(height: 20),
          _pdfSectionTitle('Client Info', _pdf.teal),
          pw.SizedBox(height: 10),
          _buildClientInfoTable(client),
        ]));
      }

      // Page 2: Conversations
      if (conversations != null) {
        final c = conversations;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Conversations', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('Inbound', _fmtInt(c.inboundMessages), _pdf.cyan),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Outbound', _fmtInt(c.outboundMessages), _pdf.blue),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Customers', _fmtInt(c.uniqueCustomers), _pdf.purple),
            pw.SizedBox(width: 8),
            _pdfKpiCard('New This Month', _fmtInt(c.newCustomersThisMonth), _pdf.green),
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('AI Performance', _pdf.cyan),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _pdfKpiCard('Automation', '${c.automationRate.toStringAsFixed(1)}%',
                c.automationRate >= 80 ? _pdf.green : c.automationRate >= 60 ? _pdf.orange : _pdf.red),
            pw.SizedBox(width: 8),
            _pdfKpiCard('AI Messages', _fmtInt(c.aiMessages), _pdf.cyan),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Human Messages', _fmtInt(c.humanMessages), _pdf.blue),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Handoffs', _fmtInt(c.handoffCount), _pdf.orange),
          ]),
          if (c.hasTimestampColumns) ...[
            pw.SizedBox(height: 12),
            pw.Row(children: [
              _pdfKpiCard('Avg Response', _fmtDurationCsv(c.avgFirstResponseTime.inSeconds.toDouble()), _pdf.teal),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
            ]),
          ],
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Customer Insights', _pdf.purple),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _pdfKpiCard('Returning', _fmtInt(c.returningCustomers), _pdf.orange),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Single-Msg', _fmtInt(c.singleMessageCustomers), _pdf.red),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Avg Lifetime', '${c.avgCustomerLifetimeDays.toStringAsFixed(0)}d', _pdf.teal),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          if (c.hasMediaColumns) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('Message Types', _pdf.purple),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              _pdfKpiCard('Text', _fmtInt(c.textMessages), _pdf.cyan),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Voice', _fmtInt(c.voiceMessages), _pdf.orange),
              pw.SizedBox(width: 8),
              _pdfKpiCard('Media', _fmtInt(c.mediaMessages), _pdf.purple),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
            ]),
          ],
          if (c.hasSentByData && c.agentPerformance.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('Team Performance', _pdf.blue),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Agent', 'Messages', 'Avg Response', 'Active Days'],
              rows: c.agentPerformance.map((a) => [
                a.name,
                _fmtInt(a.messageCount),
                _fmtDurationCsv(a.avgResponseTime.inSeconds.toDouble()),
                '${a.activeDays}',
              ]).toList(),
            ),
          ],
        ]));
      }

      // Page 3: Broadcasts
      if (broadcasts != null) {
        final b = broadcasts;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Broadcasts', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('Campaigns', _fmtInt(b.totalCampaigns), _pdf.orange),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Recipients', _fmtInt(b.totalRecipientsReached), _pdf.cyan),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Delivery %', '${b.deliveryRate.toStringAsFixed(1)}%', _pdf.green),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Fail %', '${b.failRate.toStringAsFixed(1)}%', b.failRate > 5 ? _pdf.red : _pdf.textMuted),
          ]),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            _pdfKpiCard('Avg Size', b.avgCampaignSize.toStringAsFixed(0), _pdf.teal),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Unique Reach', _fmtInt(b.uniqueReach), _pdf.purple),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Unreachable', _fmtInt(b.unreachableCount), _pdf.red),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          if (b.broadcastDrivenConversations > 0 || b.totalOfferValue > 0) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('ROI & Impact', _pdf.green),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              if (b.totalOfferValue > 0) ...[
                _pdfKpiCard('Offer Value', '${_fmtInt(b.totalOfferValue.toInt())} BHD', _pdf.green),
                pw.SizedBox(width: 8),
              ],
              _pdfKpiCard('Broadcast-Driven Convos', _fmtInt(b.broadcastDrivenConversations), _pdf.cyan),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.SizedBox()),
            ]),
          ],
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Delivery Breakdown', _pdf.blue),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _pdfKpiCard('Accepted', _fmtInt(b.acceptedCount), _pdf.blue),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Delivered', _fmtInt(b.deliveredCount), _pdf.green),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Sent', _fmtInt(b.sentCount), _pdf.orange),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Failed', _fmtInt(b.failedCount), _pdf.red),
          ]),
          if (b.campaigns.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('Campaign History', _pdf.orange),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Campaign', 'Date', 'Recipients', 'Delivery %'],
              rows: b.campaigns.take(15).map((c) => [
                c.name,
                _formatDateIso(c.date),
                _fmtInt(c.recipients),
                '${c.deliveryRate.toStringAsFixed(1)}%',
              ]).toList(),
            ),
          ],
        ]));
      }

      // Page 4: Manager Chat
      if (managerChat != null) {
        final m = managerChat;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Manager Chat', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('Total Queries', _fmtInt(m.totalQueries), _pdf.purple),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Unique Users', _fmtInt(m.uniqueUsers), _pdf.blue),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          if (m.perUserBreakdown.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('Per-User Breakdown', _pdf.purple),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['User', 'Queries', 'Last Query'],
              rows: m.perUserBreakdown.map((u) => [
                u.userName,
                _fmtInt(u.queryCount),
                _formatDateIso(u.lastQuery),
              ]).toList(),
            ),
          ],
        ]));
      }

      // Page 5: Labels
      if (labels != null && labels.labelDistribution.isNotEmpty) {
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Labels', _pdf.navy),
          pw.SizedBox(height: 14),
          _buildPdfTable(
            headers: ['Label', 'Count', 'Unique Customers'],
            rows: labels.labelDistribution.entries.map((e) => [
              e.key,
              _fmtInt(e.value),
              _fmtInt(labels.labelByUniqueCustomer[e.key] ?? 0),
            ]).toList(),
          ),
        ]));
      }

      // Page 6: Predictions
      if (predictions != null) {
        final p = predictions;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Predictive Intelligence', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('Retention', '${p.retentionRate.toStringAsFixed(1)}%', _pdf.green),
            pw.SizedBox(width: 8),
            _pdfKpiCard('At Risk', _fmtInt(p.atRiskCount), _pdf.orange),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Lapsed', _fmtInt(p.lapsedCount), _pdf.red),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Avg Gap', '${p.avgGapDays.toStringAsFixed(0)}d', _pdf.teal),
          ]),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            _pdfKpiCard('Due This Week', _fmtInt(p.dueThisWeek), _pdf.amber),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Overdue', _fmtInt(p.overdueCount), _pdf.red),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          if (p.categoryDistribution.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('Customer Categories', _pdf.teal),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Category', 'Count'],
              rows: p.categoryDistribution.entries.map((e) => [e.key, _fmtInt(e.value)]).toList(),
            ),
          ],
          if (p.topServices.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfSectionTitle('Top Services', _pdf.amber),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Service', 'Count'],
              rows: p.topServices.entries.take(10).map((e) => [e.key, _fmtInt(e.value)]).toList(),
            ),
          ],
        ]));
      }
    }

    // ── Legacy export (old models) — kept for backward compat ──

    if (!hasNewMetrics) {
      if (conversationData != null) {
        final d = conversationData;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Conversation Analytics', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('AI Messages', _fmtInt(d.totalAiMessages), _pdf.cyan),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Manager Msgs', _fmtInt(d.totalManagerMessages), _pdf.orange),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Automation', '${d.automationRate.toStringAsFixed(1)}%', _pdf.green),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Customers', '${d.uniqueCustomers}', _pdf.blue),
          ]),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            _pdfKpiCard('Conversations', '${d.totalConversations}', _pdf.purple),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Avg Response', _fmtDurationCsv(d.avgResponseTime.inSeconds.toDouble()), _pdf.teal),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Bookings', '${d.successfulBookings}', _pdf.amber),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Days Active', '${d.daysSinceOnboarding}', _pdf.textMuted),
          ]),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('Client Info', _pdf.teal),
          pw.SizedBox(height: 10),
          _buildClientInfoTable(client),
        ]));
      }

      if (broadcastData != null) {
        final d = broadcastData;
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Broadcast Analytics', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _pdfKpiCard('Broadcasts', '${d.totalBroadcastsSent}', _pdf.purple),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Recipients', _fmtInt(d.totalRecipientsReached), _pdf.cyan),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Delivery %', '${d.deliveryRate.toStringAsFixed(1)}%', _pdf.green),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Read %', '${d.readRate.toStringAsFixed(1)}%', _pdf.blue),
          ]),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            _pdfKpiCard('Failed %', '${d.failedRate.toStringAsFixed(1)}%', d.failedRate > 5 ? _pdf.red : _pdf.textMuted),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Avg Campaign', d.avgCampaignSize.toStringAsFixed(0), _pdf.teal),
            pw.SizedBox(width: 8),
            _pdfKpiCard('Days Active', '${d.daysSinceOnboarding}', _pdf.textMuted),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('Client Info', _pdf.teal),
          pw.SizedBox(height: 10),
          _buildClientInfoTable(client),
        ]));
      }

      if (conversationData == null && broadcastData == null) {
        pdf.addPage(makePage((_) => [
          _pdfSectionTitle('Client Report', _pdf.navy),
          pw.SizedBox(height: 14),
          pw.Text('No analytics data available for this client.', style: pw.TextStyle(fontSize: 12, color: _pdf.textMuted)),
          pw.SizedBox(height: 20),
          _pdfSectionTitle('Client Info', _pdf.teal),
          pw.SizedBox(height: 10),
          _buildClientInfoTable(client),
        ]));
      }
    }

    final bytes = await pdf.save();
    _downloadFile(
      content: bytes,
      filename: '${client.slug}_report_$timestamp.pdf',
      mimeType: 'application/pdf',
    );
  }

  /// Generic PDF table helper
  static pw.Widget _buildPdfTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
        ...rows.map((row) => pw.TableRow(
          children: row.map((cell) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
          )).toList(),
        )),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ADMIN: COMMAND CENTER SUMMARY CSV
  // ─────────────────────────────────────────────────────────────────

  static void exportCommandCenterCsv({
    required VividCompanyAnalytics? analytics,
    required List<Client> clients,
    required List<ClientHealthScore> healthScores,
  }) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());

    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('# VIVID COMMAND CENTER SUMMARY');
    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('Total Clients,${clients.length}');
    buffer.writeln('');

    if (analytics != null) {
      buffer.writeln('# ─── PLATFORM METRICS ───');
      buffer.writeln('Metric,Value');
      buffer.writeln('Total Messages,${analytics.totalMessages}');
      buffer.writeln('Total Broadcasts,${analytics.totalBroadcasts}');
      buffer.writeln('Unique Customers,${analytics.totalUniqueCustomers}');
      buffer.writeln('Automation Rate,${analytics.overallAutomationRate.toStringAsFixed(1)}%');
      buffer.writeln('Today Messages,${analytics.todayMessages}');
      buffer.writeln('This Week Messages,${analytics.thisWeekMessages}');
      buffer.writeln('This Month Messages,${analytics.thisMonthMessages}');
      buffer.writeln('');
    }

    if (healthScores.isNotEmpty) {
      buffer.writeln('# ─── CLIENT HEALTH SCORES ───');
      buffer.writeln('Client,Score,Grade,Activity Recency,Message Volume,Feature Adoption,User Engagement,Config Completeness');
      for (final hs in healthScores) {
        final factors = <String>[];
        for (final f in hs.factors) {
          factors.add(f.score.round().toString());
        }
        // Pad to 5 factors
        while (factors.length < 5) {
          factors.add('0');
        }
        buffer.writeln('${_escapeCsv(hs.clientName)},${hs.score},${hs.grade},${factors.join(",")}');
      }
      buffer.writeln('');
    }

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: 'vivid_command_center_$timestamp.csv',
      mimeType: 'text/csv',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // ADMIN PDF HELPERS
  // ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildTextBarChart(Map<String, int> dayData, PdfColor barColor) {
    final sortedDays = dayData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = sortedDays.fold<int>(1, (mx, e) => e.value > mx ? e.value : mx);

    return pw.Column(
      children: sortedDays.map((entry) {
        final ratio = entry.value / maxVal;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 70,
                child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 8, color: _pdf.textMuted)),
              ),
              pw.Expanded(
                child: pw.Stack(
                  children: [
                    pw.Container(height: 14, color: PdfColor.fromHex('#F1F5F9')),
                    pw.Container(
                      height: 14,
                      width: ratio * 400,
                      color: barColor,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 30,
                child: pw.Text('${entry.value}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildHourlyChart(Map<int, int> hourData, PdfColor barColor) {
    final maxVal = hourData.values.fold<int>(1, (mx, v) => v > mx ? v : mx);
    // Show only hours with data
    final hours = hourData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return pw.Column(
      children: hours.map((entry) {
        final ratio = entry.value / maxVal;
        final label = '${entry.key.toString().padLeft(2, '0')}:00';
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 40, child: pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _pdf.textMuted))),
              pw.Expanded(
                child: pw.Stack(
                  children: [
                    pw.Container(height: 12, color: PdfColor.fromHex('#F1F5F9')),
                    pw.Container(height: 12, width: ratio * 400, color: barColor),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(width: 30, child: pw.Text('${entry.value}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildClientBreakdownTable(List<ClientActivity> clients) {
    final sorted = [...clients]..sort((a, b) => b.messageCount.compareTo(a.messageCount));
    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FixedColumnWidth(50),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(45),
        5: const pw.FixedColumnWidth(45),
        6: const pw.FixedColumnWidth(50),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: ['Client', 'Messages', 'Broadcasts', 'AI', 'Manager', 'Customers', 'Auto %'].map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
        ...List.generate(sorted.length, (i) {
          final ca = sorted[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(ca.clientName, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${ca.messageCount}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${ca.broadcastCount}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${ca.aiMessages}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${ca.managerMessages}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${ca.uniqueCustomers}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${ca.automationRate.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 8, color: ca.automationRate >= 70 ? _pdf.green : ca.automationRate >= 40 ? _pdf.amber : _pdf.red), textAlign: pw.TextAlign.center)),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTopCustomersTable(List<TopCustomerInfo> customers) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FixedColumnWidth(55),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdf.navy),
          children: ['Phone', 'Name', 'Messages', 'Client'].map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
        ...List.generate(customers.length, (i) {
          final tc = customers[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          final name = _sanitizePdfName(tc.name ?? '-');
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(tc.phone, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(
                name,
                style: _arStyle(const pw.TextStyle(fontSize: 8), tc.name ?? ''),
                textDirection: isArabicText(tc.name ?? '') ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${tc.messageCount}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(tc.clientName, style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildClientInfoTable(Client client) {
    final rows = <List<String>>[
      ['Name', client.name],
      ['Slug', client.slug],
      ['Features', client.enabledFeatures.join(', ')],
      if (client.conversationsPhone != null) ['Conversations Phone', client.conversationsPhone!],
      if (client.broadcastsPhone != null) ['Broadcasts Phone', client.broadcastsPhone!],
      ['Created', _formatDateIso(client.createdAt)],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _pdf.border, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(120),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.map((row) => pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(row[0], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdf.navy)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      )).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // FILE DOWNLOAD
  // ─────────────────────────────────────────────────────────────────

  static void _downloadFile({required List<int> content, required String filename, required String mimeType}) {
    final blob = html.Blob([Uint8List.fromList(content)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}

// ─────────────────────────────────────────────────────────────────
// PDF BRAND COLORS
// ─────────────────────────────────────────────────────────────────

class _PdfBrandColors {
  final cyan    = PdfColor.fromHex('#00d4aa');
  final navy    = PdfColor.fromHex('#0a1628');
  final green   = PdfColor.fromHex('#10b981');
  final blue    = PdfColor.fromHex('#3b82f6');
  final teal    = PdfColor.fromHex('#0d9488');
  final amber   = PdfColor.fromHex('#f59e0b');
  final orange  = PdfColor.fromHex('#f97316');
  final red     = PdfColor.fromHex('#ef4444');
  final purple  = PdfColor.fromHex('#8b5cf6');
  final textMuted = PdfColor.fromHex('#64748b');
  final border  = PdfColor.fromHex('#e2e8f0');
  final primary = PdfColor.fromHex('#00d4aa'); // alias
}
