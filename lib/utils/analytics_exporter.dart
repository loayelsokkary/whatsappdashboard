import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../providers/roi_analytics_provider.dart';
import 'initials_helper.dart';

/// Utility class for exporting analytics data to CSV and PDF.
/// Works with the v4 ROI analytics data models.
class AnalyticsExporter {
  static final _pdfColors = _PdfBrandColors();

  // ============================================
  // ANALYTICS - CSV (Change 9: Organized export)
  // ============================================

  static void exportAnalyticsCsv({
    required AnalyticsData data,
    required String clientName,
    required String dateRange,
  }) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());
    final m = data.current;

    // Section: Header
    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('# ANALYTICS REPORT');
    buffer.writeln('# ═══════════════════════════════════════');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('Business,${_escapeCsv(clientName)}');
    buffer.writeln('Date Range,$dateRange');
    buffer.writeln('');

    // Section: Overview
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

    // Section: Comparison
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

    // Section: Campaign performance
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

    // Section: Open conversations
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

    // Section: Daily breakdown
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

  // CSV formatting helpers
  static String _fmtNumber(double v) {
    if (v == 0) return '0';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _fmtInt(int v) {
    if (v < 1000) return v.toString();
    if (v < 1000000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '${(v / 1000000).toStringAsFixed(1)}M';
  }

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

  // ============================================
  // ANALYTICS - PDF (Change 8: Branded export)
  // ============================================

  static Future<void> exportAnalyticsPdf({
    required AnalyticsData data,
    required String clientName,
    required String dateRange,
  }) async {
    final pdf = pw.Document();
    final timestamp = _formatDateIso(DateTime.now());
    final m = data.current;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData(),
        header: (context) => _buildBrandedHeader(clientName, '$dateRange  |  $timestamp'),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          // Overview section
          _buildColoredSectionHeader('Overview Metrics', _pdfColors.cyan),
          pw.SizedBox(height: 14),
          // 2x4 KPI grid
          pw.Row(children: [
            _buildPdfStatCard('Leads', '${m.leads}', _pdfColors.cyan),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Revenue', '${m.revenue.toStringAsFixed(0)} BHD', _pdfColors.green),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Engagement', '${m.engagementRate.toStringAsFixed(0)}%', _pdfColors.blue),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Avg Response', _formatDurationPdf(m.avgResponseTimeSeconds), _pdfColors.orange),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildPdfStatCard('Messages Sent', '${m.messagesSent}', _pdfColors.blue),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Messages Received', '${m.messagesReceived}', _pdfColors.cyan),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Open Convos', '${m.openConversationCount}', m.overdueConversationCount > 0 ? _pdfColors.red : _pdfColors.teal),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Overdue', '${m.overdueConversationCount}', m.overdueConversationCount > 0 ? _pdfColors.red : _pdfColors.green),
          ]),
          pw.SizedBox(height: 24),

          // Campaign performance
          if (data.campaigns.isNotEmpty) ...[
            _buildColoredSectionHeader('Campaign Performance', _pdfColors.blue),
            pw.SizedBox(height: 14),
            _buildCampaignTable(data.campaigns),
            pw.SizedBox(height: 24),
          ],

          // Open conversations
          if (data.openConversations.isNotEmpty) ...[
            _buildColoredSectionHeader('Open Conversations', _pdfColors.orange),
            pw.SizedBox(height: 14),
            _buildOpenConversationsTable(data.openConversations),
            pw.SizedBox(height: 24),
          ],

          // Daily breakdown
          if (data.dailyBreakdown.isNotEmpty) ...[
            _buildColoredSectionHeader('Daily Breakdown', _pdfColors.teal),
            pw.SizedBox(height: 14),
            _buildDailyTable(data.dailyBreakdown),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      content: bytes,
      filename: 'analytics_$timestamp.pdf',
      mimeType: 'application/pdf',
    );
  }

  static String _formatDurationPdf(double seconds) {
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

  // ============================================
  // PDF TABLES
  // ============================================

  static pw.Widget _buildCampaignTable(List<CampaignPerformance> campaigns) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FixedColumnWidth(50),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(35),
        5: const pw.FixedColumnWidth(45),
        6: const pw.FixedColumnWidth(40),
        7: const pw.FixedColumnWidth(45),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdfColors.navy),
          children: ['Campaign', 'Date', 'Sent', 'Responded', 'Leads', 'Revenue', 'Eng. %', 'Conv. %'].map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
        ...List.generate(campaigns.length, (i) {
          final c = campaigns[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          final convRate = c.sent > 0 ? '${(c.leads / c.sent * 100).toStringAsFixed(0)}%' : '-';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                c.name,
                style: pw.TextStyle(fontSize: 8, color: _pdfColors.navy),
                textDirection: isArabicText(c.name) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                c.sentAt != null ? _formatDateShort(c.sentAt!) : 'N/A',
                style: const pw.TextStyle(fontSize: 7),
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.sent}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.responded}', style: pw.TextStyle(fontSize: 8, color: _pdfColors.green), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.leads}', style: pw.TextStyle(fontSize: 8, color: _pdfColors.cyan), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                c.revenue > 0 ? c.revenue.toStringAsFixed(0) : '-',
                style: pw.TextStyle(fontSize: 8, color: c.revenue > 0 ? _pdfColors.green : _pdfColors.textMuted),
                textAlign: pw.TextAlign.center,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.engagementRate.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfColors.blue), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(convRate, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfColors.blue), textAlign: pw.TextAlign.center)),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildOpenConversationsTable(List<OpenConversation> convos) {
    final sorted = [...convos]..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    final display = sorted.take(20).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FixedColumnWidth(55),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdfColors.navy),
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
                c.customerName ?? '-',
                style: pw.TextStyle(fontSize: 8, color: _pdfColors.navy),
                textDirection: isArabicText(c.customerName ?? '') ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                c.lastMessage.length > 60 ? '${c.lastMessage.substring(0, 60)}...' : c.lastMessage,
                style: pw.TextStyle(fontSize: 8, color: _pdfColors.textMuted),
                textDirection: isArabicText(c.lastMessage) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(
                waitLabel,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: waitMin > 30 ? _pdfColors.red : _pdfColors.orange),
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

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FixedColumnWidth(40),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(55),
        4: const pw.FixedColumnWidth(55),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdfColors.navy),
          children: ['Date', 'Leads', 'Revenue', 'Eng. Rate', 'Resp. Time'].map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
        ...List.generate(recent.length, (i) {
          final d = recent[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(d.date, style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${d.leads}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfColors.cyan), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(d.revenue > 0 ? d.revenue.toStringAsFixed(0) : '-', style: pw.TextStyle(fontSize: 9, color: d.revenue > 0 ? _pdfColors.green : _pdfColors.textMuted), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${d.engagementRate.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 9, color: _pdfColors.blue), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_formatDurationPdf(d.avgResponseTimeSeconds), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
            ],
          );
        }),
      ],
    );
  }

  // ============================================
  // PDF HELPER WIDGETS
  // ============================================

  // Change 8: Branded dark navy header rectangle
  static pw.Widget _buildBrandedHeader(String clientName, String subtitle) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      margin: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        color: _pdfColors.navy,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('VIVID', style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _pdfColors.primary,
                letterSpacing: 3,
              )),
              pw.SizedBox(height: 4),
              pw.Text('Analytics Report', style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              )),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(clientName, style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              )),
              pw.SizedBox(height: 2),
              pw.Text(subtitle, style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('#8B97B0'),
              )),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Vivid Dashboard', style: pw.TextStyle(fontSize: 9, color: _pdfColors.textMuted)),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: _pdfColors.textMuted)),
      ],
    );
  }

  // Change 8: Colored section headers
  static pw.Widget _buildColoredSectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
      ),
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
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _pdfColors.textMuted)),
            pw.SizedBox(height: 6),
            pw.Text(value, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ============================================
  // LEGACY: PDF header used by broadcast exports
  // ============================================

  static pw.Widget _buildPdfHeader(String title, String clientName, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pdfColors.navy)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(clientName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfColors.navy)),
                pw.Text(subtitle, style: pw.TextStyle(fontSize: 10, color: _pdfColors.textMuted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 3, color: _pdfColors.primary),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(color: _pdfColors.primary, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  // ============================================
  // LEGACY BROADCAST EXPORTS (used by broadcast_analytics_screen)
  // ============================================

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

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: 'broadcast_analytics_$timestamp.csv',
      mimeType: 'text/csv',
    );
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
    for (var i = 0; i < data.recentCampaigns.length; i++) {
      final c = data.recentCampaigns[i];
      final cls = i % 2 != 0 ? ' class="highlight"' : '';
      buffer.writeln('<tr$cls><td>${_escapeHtml(c.name)}</td><td>${c.recipients}</td><td>${c.delivered}</td><td>${c.read}</td><td>${c.failed}</td></tr>');
    }
    buffer.writeln('</table></body></html>');

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: 'broadcast_analytics_$timestamp.xls',
      mimeType: 'application/vnd.ms-excel',
    );
  }

  static Future<void> exportBroadcastAnalyticsToPdf({required dynamic data}) async {
    final pdf = pw.Document();
    final timestamp = _formatDateIso(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData(),
        header: (context) => _buildPdfHeader('Broadcast Analytics', ClientConfig.businessName, timestamp),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildPdfSectionHeader('Summary'),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            _buildPdfStatCard('Campaigns', '${data.totalCampaigns}', _pdfColors.blue),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Recipients', '${data.totalRecipients}', _pdfColors.cyan),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Delivered', '${data.totalDelivered}', _pdfColors.green),
            pw.SizedBox(width: 8),
            _buildPdfStatCard('Failed', '${data.totalFailed}', _pdfColors.red),
          ]),
          pw.SizedBox(height: 20),
          _buildPdfSectionHeader('Recent Campaigns'),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FixedColumnWidth(55),
              2: const pw.FixedColumnWidth(55),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(40),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _pdfColors.navy),
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
                      style: pw.TextStyle(fontSize: 9, color: _pdfColors.navy),
                      textDirection: isArabicText(c.name as String) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    )),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.recipients}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.delivered}', style: pw.TextStyle(fontSize: 9, color: _pdfColors.green), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.read}', style: pw.TextStyle(fontSize: 9, color: _pdfColors.blue), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${c.failed}', style: pw.TextStyle(fontSize: 9, color: c.failed > 0 ? _pdfColors.red : _pdfColors.textMuted), textAlign: pw.TextAlign.center)),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(content: bytes, filename: 'broadcast_analytics_$timestamp.pdf', mimeType: 'application/pdf');
  }

  // ============================================
  // ACTIVITY LOGS EXPORT - CSV
  // ============================================

  static void exportActivityLogsToCsv({
    required List<ActivityLog> logs,
    String filename = 'activity_logs',
  }) {
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
      buffer.writeln(
        '$date,$time,'
        '${_escapeCsv(log.userName)},'
        '${_escapeCsv(log.userEmail ?? '')},'
        '${_escapeCsv(log.actionType.displayName)},'
        '${_escapeCsv(log.description)}',
      );
    }

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: '${filename}_$timestamp.csv',
      mimeType: 'text/csv',
    );
  }

  // ============================================
  // ACTIVITY LOGS EXPORT - EXCEL
  // ============================================

  static void exportActivityLogsToExcel({
    required List<ActivityLog> logs,
    String filename = 'activity_logs',
  }) {
    final buffer = StringBuffer();
    final timestamp = _formatDateIso(DateTime.now());

    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="UTF-8">');
    buffer.writeln('<style>');
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
      buffer.writeln(
        '<tr$rowClass>'
        '<td>$date</td>'
        '<td>$time</td>'
        '<td>${_escapeHtml(log.userName)}</td>'
        '<td>${_escapeHtml(log.userEmail ?? '')}</td>'
        '<td>${_escapeHtml(log.actionType.displayName)}</td>'
        '<td>${_escapeHtml(log.description)}</td>'
        '</tr>',
      );
    }
    buffer.writeln('</table></body></html>');

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: '${filename}_$timestamp.xls',
      mimeType: 'application/vnd.ms-excel',
    );
  }

  // ============================================
  // UTILITIES
  // ============================================

  static void _downloadFile({
    required List<int> content,
    required String filename,
    required String mimeType,
  }) {
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

  static String _formatDateIso(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateShort(DateTime d) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day}/${d.month}';
  }

  static String _escapeCsv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _escapeHtml(String v) {
    return v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }
}

// ============================================
// PDF BRAND COLORS
// ============================================

class _PdfBrandColors {
  final primary = PdfColor.fromHex('#00D9FF');
  final navy = PdfColor.fromHex('#0A1628');
  final blue = PdfColor.fromHex('#1E88E5');
  final cyan = PdfColor.fromHex('#00BCD4');
  final teal = PdfColor.fromHex('#26A69A');
  final green = PdfColor.fromHex('#4CAF50');
  final orange = PdfColor.fromHex('#FF9800');
  final red = PdfColor.fromHex('#F44336');
  final purple = PdfColor.fromHex('#9C27B0');
  final textMuted = PdfColor.fromHex('#78909C');
}
