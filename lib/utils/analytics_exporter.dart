import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

/// Utility class for exporting analytics data to CSV, Excel, and PDF
class AnalyticsExporter {
  // Brand colors for PDF
  static final _pdfColors = _PdfBrandColors();

  // ============================================
  // ANALYTICS EXPORT - CSV
  // ============================================

  static void exportAnalyticsToCsv({
    required dynamic data,
    required List<dynamic> dailyActivity,
    required List<dynamic> topCustomers,
    required String analyticsType,
    String filename = 'analytics_export',
  }) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String().split('T')[0];

    buffer.writeln('${analyticsType.toUpperCase()} ANALYTICS REPORT');
    buffer.writeln('Generated,$timestamp');
    buffer.writeln('Business,${ClientConfig.businessName}');
    buffer.writeln('');

    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Value');
    if (analyticsType == 'broadcasts') {
      buffer.writeln('Total Recipients,${data.totalMessages}');
      buffer.writeln('Total Campaigns,${data.aiResponses}');
      buffer.writeln('Avg Recipients per Campaign,${data.aiResponses > 0 ? (data.totalMessages / data.aiResponses).round() : 0}');
      buffer.writeln('Today Recipients,${data.todayMessages}');
      buffer.writeln('This Week Recipients,${data.thisWeekMessages}');
      buffer.writeln('This Month Recipients,${data.thisMonthMessages}');
    } else {
      final hasAi = ClientConfig.currentClient?.hasAiConversations ?? false;
      buffer.writeln('Total Messages,${data.totalMessages}');
      if (hasAi) {
        buffer.writeln('AI Responses,${data.aiResponses}');
      }
      buffer.writeln('Manager Responses,${data.managerResponses}');
      buffer.writeln('Unique Customers,${data.uniqueCustomers}');
      buffer.writeln('Today,${data.todayMessages}');
      buffer.writeln('This Week,${data.thisWeekMessages}');
      buffer.writeln('This Month,${data.thisMonthMessages}');
      if (data.totalMessages > 0) {
        if (hasAi) {
          final aiRate = ((data.aiResponses / data.totalMessages) * 100).toStringAsFixed(1);
          buffer.writeln('AI Response Rate,$aiRate%');
        }
        final managerRate = ((data.managerResponses / data.totalMessages) * 100).toStringAsFixed(1);
        buffer.writeln('Manager Response Rate,$managerRate%');
      }
    }
    buffer.writeln('');

    buffer.writeln('DAILY ACTIVITY');
    buffer.writeln(analyticsType == 'broadcasts' ? 'Date,Recipients' : 'Date,Messages');
    for (final day in dailyActivity) {
      buffer.writeln('${_formatDateIso(day.date)},${day.count}');
    }
    buffer.writeln('');

    if (analyticsType == 'broadcasts') {
      buffer.writeln('TOP CAMPAIGNS');
      buffer.writeln('Rank,Campaign,Recipients');
      for (var i = 0; i < topCustomers.length; i++) {
        final c = topCustomers[i];
        final name = c.name ?? 'Unnamed Campaign';
        buffer.writeln('${i + 1},${_escapeCsv(name)},${c.messageCount}');
      }
    } else {
      buffer.writeln('TOP CUSTOMERS');
      buffer.writeln('Rank,Name,Phone,Messages');
      for (var i = 0; i < topCustomers.length; i++) {
        final c = topCustomers[i];
        final name = c.name ?? 'Unknown';
        buffer.writeln('${i + 1},${_escapeCsv(name)},${c.phone},${c.messageCount}');
      }
    }

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: '${filename}_${analyticsType}_$timestamp.csv',
      mimeType: 'text/csv',
    );
  }

  // ============================================
  // ANALYTICS EXPORT - EXCEL
  // ============================================

  static void exportAnalyticsToExcel({
    required dynamic data,
    required List<dynamic> dailyActivity,
    required List<dynamic> topCustomers,
    required String analyticsType,
    String filename = 'analytics_export',
  }) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final typeTitle = analyticsType == 'conversations' ? 'Conversations' : 'Broadcasts';

    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; }');
    buffer.writeln('table { border-collapse: collapse; margin-bottom: 30px; }');
    buffer.writeln('th { background-color: #1E88E5; color: white; font-weight: bold; padding: 12px; text-align: left; }');
    buffer.writeln('td { padding: 10px; border: 1px solid #e0e0e0; }');
    buffer.writeln('.header { background-color: #0A1628; color: #00D9FF; font-size: 18px; padding: 15px; }');
    buffer.writeln('.metric-label { font-weight: 600; background-color: #f8f9fa; color: #333; }');
    buffer.writeln('.number { text-align: right; font-weight: 500; color: #1E88E5; }');
    buffer.writeln('.highlight { background-color: #f0f7ff; }');
    buffer.writeln('</style></head><body>');

    // Summary Table
    buffer.writeln('<table width="500">');
    buffer.writeln('<tr><th colspan="2" class="header">$typeTitle Analytics - ${_escapeHtml(ClientConfig.businessName)}</th></tr>');
    buffer.writeln('<tr><td class="metric-label">Report Generated</td><td>$timestamp</td></tr>');
    if (analyticsType == 'broadcasts') {
      buffer.writeln('<tr><td class="metric-label">Total Recipients</td><td class="number">${data.totalMessages}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">Total Campaigns</td><td class="number">${data.aiResponses}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">Avg Recipients per Campaign</td><td class="number">${data.aiResponses > 0 ? (data.totalMessages / data.aiResponses).round() : 0}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">Today Recipients</td><td class="number">${data.todayMessages}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">This Week Recipients</td><td class="number">${data.thisWeekMessages}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">This Month Recipients</td><td class="number">${data.thisMonthMessages}</td></tr>');
    } else {
      final hasAi = ClientConfig.currentClient?.hasAiConversations ?? false;
      buffer.writeln('<tr><td class="metric-label">Total Messages</td><td class="number">${data.totalMessages}</td></tr>');
      if (hasAi) {
        buffer.writeln('<tr><td class="metric-label">AI Responses</td><td class="number">${data.aiResponses}</td></tr>');
      }
      buffer.writeln('<tr><td class="metric-label">Manager Responses</td><td class="number">${data.managerResponses}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">Unique Customers</td><td class="number">${data.uniqueCustomers}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">Today</td><td class="number">${data.todayMessages}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">This Week</td><td class="number">${data.thisWeekMessages}</td></tr>');
      buffer.writeln('<tr><td class="metric-label">This Month</td><td class="number">${data.thisMonthMessages}</td></tr>');
    }
    buffer.writeln('</table>');

    // Daily Activity Table
    final activityLabel = analyticsType == 'broadcasts' ? 'Recipients' : 'Messages';
    buffer.writeln('<table width="300">');
    buffer.writeln('<tr><th colspan="2">Daily Activity</th></tr>');
    buffer.writeln('<tr><th>Date</th><th>$activityLabel</th></tr>');
    for (var i = 0; i < dailyActivity.length; i++) {
      final day = dailyActivity[i];
      final rowClass = i % 2 == 0 ? '' : ' class="highlight"';
      buffer.writeln('<tr$rowClass><td>${_formatDateIso(day.date)}</td><td class="number">${day.count}</td></tr>');
    }
    buffer.writeln('</table>');

    // Top Campaigns / Top Customers Table
    if (analyticsType == 'broadcasts') {
      buffer.writeln('<table width="400">');
      buffer.writeln('<tr><th colspan="3">Top Campaigns</th></tr>');
      buffer.writeln('<tr><th>#</th><th>Campaign</th><th>Recipients</th></tr>');
      for (var i = 0; i < topCustomers.length; i++) {
        final c = topCustomers[i];
        final rowClass = i % 2 == 0 ? '' : ' class="highlight"';
        final name = c.name ?? 'Unnamed Campaign';
        buffer.writeln('<tr$rowClass><td>${i + 1}</td><td>${_escapeHtml(name)}</td><td class="number">${c.messageCount}</td></tr>');
      }
    } else {
      buffer.writeln('<table width="500">');
      buffer.writeln('<tr><th colspan="4">Top Customers</th></tr>');
      buffer.writeln('<tr><th>#</th><th>Name</th><th>Phone</th><th>Messages</th></tr>');
      for (var i = 0; i < topCustomers.length; i++) {
        final c = topCustomers[i];
        final rowClass = i % 2 == 0 ? '' : ' class="highlight"';
        final name = c.name ?? 'Unknown';
        buffer.writeln('<tr$rowClass><td>${i + 1}</td><td>${_escapeHtml(name)}</td><td>${c.phone}</td><td class="number">${c.messageCount}</td></tr>');
      }
    }
    buffer.writeln('</table></body></html>');

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: '${filename}_${analyticsType}_$timestamp.xls',
      mimeType: 'application/vnd.ms-excel',
    );
  }

  // ============================================
  // ANALYTICS EXPORT - PDF
  // ============================================

  static Future<void> exportAnalyticsToPdf({
    required dynamic data,
    required List<dynamic> dailyActivity,
    required List<dynamic> topCustomers,
    required String analyticsType,
    String filename = 'analytics_report',
  }) async {
    final pdf = pw.Document();
    final timestamp = DateTime.now();
    final timestampStr = _formatDateIso(timestamp);
    final typeTitle = analyticsType == 'conversations' ? 'Conversations' : 'Broadcasts';

    final isBroadcasts = analyticsType == 'broadcasts';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(typeTitle, timestampStr),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildPdfSectionHeader('Summary Statistics'),
          pw.SizedBox(height: 16),
          isBroadcasts ? _buildPdfBroadcastStatsRow(data) : _buildPdfStatsRow(data),
          pw.SizedBox(height: 20),
          _buildPdfTimeStats(data, label: isBroadcasts ? 'recipients' : 'messages'),
          pw.SizedBox(height: 24),
          _buildPdfSectionHeader(isBroadcasts ? 'Activity (Last 7 Days)' : 'Activity (Last 7 Days)'),
          pw.SizedBox(height: 16),
          _buildPdfActivityChart(dailyActivity.take(7).toList()),
          pw.SizedBox(height: 24),
          _buildPdfSectionHeader(isBroadcasts ? 'Top Campaigns' : 'Top Customers'),
          pw.SizedBox(height: 16),
          isBroadcasts ? _buildPdfCampaignListTable(topCustomers) : _buildPdfCustomerTable(topCustomers),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      content: bytes,
      filename: '${filename}_${analyticsType}_$timestampStr.pdf',
      mimeType: 'application/pdf',
    );
  }

  // ============================================
  // PDF HELPER WIDGETS
  // ============================================

  static pw.Widget _buildPdfHeader(String title, String timestamp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$title Analytics',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _pdfColors.navy,
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  ClientConfig.businessName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfColors.navy,
                  ),
                ),
                pw.Text(
                  timestamp,
                  style: pw.TextStyle(fontSize: 10, color: _pdfColors.textMuted),
                ),
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

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Vivid Dashboard',
          style: pw.TextStyle(fontSize: 9, color: _pdfColors.textMuted),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: _pdfColors.textMuted),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _pdfColors.primary,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfStatsRow(dynamic data) {
    final hasAi = ClientConfig.currentClient?.hasAiConversations ?? false;
    return pw.Row(
      children: [
        _buildPdfStatCard('Total Messages', data.totalMessages.toString(), _pdfColors.blue),
        pw.SizedBox(width: 10),
        if (hasAi) ...[
          _buildPdfStatCard('AI Responses', data.aiResponses.toString(), _pdfColors.cyan),
          pw.SizedBox(width: 10),
        ],
        _buildPdfStatCard('Manager', data.managerResponses.toString(), _pdfColors.teal),
        pw.SizedBox(width: 10),
        _buildPdfStatCard('Customers', data.uniqueCustomers.toString(), _pdfColors.orange),
      ],
    );
  }

  static pw.Widget _buildPdfBroadcastStatsRow(dynamic data) {
    return pw.Row(
      children: [
        _buildPdfStatCard('Total Recipients', data.totalMessages.toString(), _pdfColors.blue),
        pw.SizedBox(width: 10),
        _buildPdfStatCard('Campaigns', data.aiResponses.toString(), _pdfColors.cyan),
        pw.SizedBox(width: 10),
        _buildPdfStatCard('Avg/Campaign', data.aiResponses > 0 ? (data.totalMessages / data.aiResponses).round().toString() : '0', _pdfColors.teal),
        pw.SizedBox(width: 10),
        _buildPdfStatCard('Total Campaigns', data.uniqueCustomers.toString(), _pdfColors.orange),
      ],
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
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: _pdfColors.textMuted),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTimeStats(dynamic data, {String label = 'messages'}) {
    return pw.Row(
      children: [
        _buildPdfGradientCard('Today', data.todayMessages.toString(), _pdfColors.purple, sublabel: label),
        pw.SizedBox(width: 10),
        _buildPdfGradientCard('This Week', data.thisWeekMessages.toString(), _pdfColors.green, sublabel: label),
        pw.SizedBox(width: 10),
        _buildPdfGradientCard('This Month', data.thisMonthMessages.toString(), _pdfColors.red, sublabel: label),
      ],
    );
  }

  static pw.Widget _buildPdfGradientCard(String label, String value, PdfColor color, {String sublabel = 'messages'}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.Text(
              sublabel,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfActivityChart(List<dynamic> days) {
    if (days.isEmpty) {
      return pw.Text(
        'No activity data',
        style: pw.TextStyle(color: _pdfColors.textMuted),
      );
    }

    int maxCount = 0;
    for (final day in days) {
      final count = day.count as int;
      if (count > maxCount) maxCount = count;
    }

    return pw.Column(
      children: days.map((day) {
        final count = day.count as int;
        final pct = maxCount > 0 ? count / maxCount : 0.0;
        final filledFlex = (pct * 100).round().clamp(1, 100);
        final emptyFlex = 100 - filledFlex;

        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 75,
                child: pw.Text(
                  _formatDateShort(day.date as DateTime),
                  style: pw.TextStyle(fontSize: 10, color: _pdfColors.navy),
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  height: 18,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#E8E8E8'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    children: [
                      if (pct > 0)
                        pw.Expanded(
                          flex: filledFlex,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              color: _pdfColors.primary,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      if (pct < 1)
                        pw.Expanded(
                          flex: emptyFlex,
                          child: pw.Container(),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 35,
                child: pw.Text(
                  count.toString(),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildPdfCustomerTable(List<dynamic> customers) {
    if (customers.isEmpty) {
      return pw.Text(
        'No customers yet',
        style: pw.TextStyle(color: _pdfColors.textMuted),
      );
    }

    final rankColors = [
      _pdfColors.cyan,
      _pdfColors.blue,
      _pdfColors.teal,
      _pdfColors.purple,
      _pdfColors.orange,
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(35),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FixedColumnWidth(55),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdfColors.navy),
          children: ['#', 'Name', 'Phone', 'Messages'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            );
          }).toList(),
        ),
        ...List.generate(customers.length, (i) {
          final c = customers[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          final rankColor = rankColors[i % rankColors.length];
          final name = c.name ?? 'Unknown';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Center(
                  child: pw.Container(
                    width: 22,
                    height: 22,
                    decoration: pw.BoxDecoration(
                      color: rankColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '${i + 1}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: _pdfColors.navy)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(c.phone, style: pw.TextStyle(fontSize: 9, color: _pdfColors.navy)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  c.messageCount.toString(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfColors.primary,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildPdfCampaignListTable(List<dynamic> campaigns) {
    if (campaigns.isEmpty) {
      return pw.Text('No campaigns yet', style: pw.TextStyle(color: _pdfColors.textMuted));
    }

    final rankColors = [_pdfColors.cyan, _pdfColors.blue, _pdfColors.teal, _pdfColors.purple, _pdfColors.orange];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(35),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(65),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdfColors.navy),
          children: ['#', 'Campaign', 'Recipients'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            );
          }).toList(),
        ),
        ...List.generate(campaigns.length, (i) {
          final c = campaigns[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8F9FA');
          final rankColor = rankColors[i % rankColors.length];
          final name = c.name ?? 'Unnamed Campaign';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Center(
                  child: pw.Container(
                    width: 22, height: 22,
                    decoration: pw.BoxDecoration(color: rankColor, borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Center(child: pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                  ),
                ),
              ),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(name, style: pw.TextStyle(fontSize: 9, color: _pdfColors.navy))),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(c.messageCount.toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfColors.primary), textAlign: pw.TextAlign.center),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ============================================
  // BROADCAST ANALYTICS EXPORT - CSV
  // ============================================

  static void exportBroadcastAnalyticsToCsv({
    required dynamic data, // BroadcastAnalyticsData
    String filename = 'broadcast_analytics_export',
  }) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String().split('T')[0];

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

    buffer.writeln('DAILY ACTIVITY (LAST 7 DAYS)');
    buffer.writeln('Date,Campaigns,Recipients');
    for (final day in data.last7Days) {
      buffer.writeln('${_formatDateIso(day.date)},${day.campaigns},${day.recipients}');
    }
    buffer.writeln('');

    buffer.writeln('RECENT CAMPAIGNS');
    buffer.writeln('Campaign,Recipients,Delivered,Read,Failed,Delivery Rate,Read Rate,Sent At');
    for (final c in data.recentCampaigns) {
      buffer.writeln(
        '${_escapeCsv(c.name)},${c.recipients},${c.delivered},${c.read},${c.failed},'
        '${c.deliveryRate.toStringAsFixed(1)}%,${c.readRate.toStringAsFixed(1)}%,${_formatDateIso(c.sentAt)}',
      );
    }

    _downloadFile(
      content: utf8.encode(buffer.toString()),
      filename: '${filename}_$timestamp.csv',
      mimeType: 'text/csv',
    );
  }

  // ============================================
  // BROADCAST ANALYTICS EXPORT - EXCEL
  // ============================================

  static void exportBroadcastAnalyticsToExcel({
    required dynamic data, // BroadcastAnalyticsData
    String filename = 'broadcast_analytics_export',
  }) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String().split('T')[0];

    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; }');
    buffer.writeln('table { border-collapse: collapse; margin-bottom: 30px; }');
    buffer.writeln('th { background-color: #9C27B0; color: white; font-weight: bold; padding: 12px; text-align: left; }');
    buffer.writeln('td { padding: 10px; border: 1px solid #e0e0e0; }');
    buffer.writeln('.header { background-color: #0A1628; color: #00D9FF; font-size: 18px; padding: 15px; }');
    buffer.writeln('.metric-label { font-weight: 600; background-color: #f8f9fa; color: #333; }');
    buffer.writeln('.number { text-align: right; font-weight: 500; color: #9C27B0; }');
    buffer.writeln('.highlight { background-color: #f9f0ff; }');
    buffer.writeln('.rate-good { color: #4CAF50; font-weight: 600; }');
    buffer.writeln('.rate-mid { color: #FF9800; font-weight: 600; }');
    buffer.writeln('.rate-bad { color: #F44336; font-weight: 600; }');
    buffer.writeln('</style></head><body>');

    // Summary Table
    buffer.writeln('<table width="500">');
    buffer.writeln('<tr><th colspan="2" class="header">Broadcast Analytics - ${_escapeHtml(ClientConfig.businessName)}</th></tr>');
    buffer.writeln('<tr><td class="metric-label">Report Generated</td><td>$timestamp</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Total Campaigns</td><td class="number">${data.totalCampaigns}</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Total Recipients</td><td class="number">${data.totalRecipients}</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Total Delivered</td><td class="number">${data.totalDelivered}</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Total Read</td><td class="number">${data.totalRead}</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Total Failed</td><td class="number">${data.totalFailed}</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Delivery Rate</td><td class="number">${data.deliveryRate.toStringAsFixed(1)}%</td></tr>');
    buffer.writeln('<tr><td class="metric-label">Read Rate</td><td class="number">${data.readRate.toStringAsFixed(1)}%</td></tr>');
    buffer.writeln('</table>');

    // Daily Activity Table
    buffer.writeln('<table width="400">');
    buffer.writeln('<tr><th colspan="3">Daily Activity (Last 7 Days)</th></tr>');
    buffer.writeln('<tr><th>Date</th><th>Campaigns</th><th>Recipients</th></tr>');
    for (var i = 0; i < data.last7Days.length; i++) {
      final day = data.last7Days[i];
      final rowClass = i % 2 == 0 ? '' : ' class="highlight"';
      buffer.writeln('<tr$rowClass><td>${_formatDateIso(day.date)}</td><td class="number">${day.campaigns}</td><td class="number">${day.recipients}</td></tr>');
    }
    buffer.writeln('</table>');

    // Recent Campaigns Table
    buffer.writeln('<table width="800">');
    buffer.writeln('<tr><th colspan="7">Recent Campaign Performance</th></tr>');
    buffer.writeln('<tr><th>Campaign</th><th>Recipients</th><th>Delivered</th><th>Read</th><th>Failed</th><th>Delivery Rate</th><th>Read Rate</th></tr>');
    for (var i = 0; i < data.recentCampaigns.length; i++) {
      final c = data.recentCampaigns[i];
      final rowClass = i % 2 == 0 ? '' : ' class="highlight"';
      final drClass = c.deliveryRate >= 70 ? 'rate-good' : (c.deliveryRate >= 40 ? 'rate-mid' : 'rate-bad');
      final rrClass = c.readRate >= 70 ? 'rate-good' : (c.readRate >= 40 ? 'rate-mid' : 'rate-bad');
      buffer.writeln(
        '<tr$rowClass><td>${_escapeHtml(c.name)}</td><td class="number">${c.recipients}</td>'
        '<td class="number">${c.delivered}</td><td class="number">${c.read}</td><td class="number">${c.failed}</td>'
        '<td class="$drClass">${c.deliveryRate.toStringAsFixed(1)}%</td><td class="$rrClass">${c.readRate.toStringAsFixed(1)}%</td></tr>',
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
  // BROADCAST ANALYTICS EXPORT - PDF
  // ============================================

  static Future<void> exportBroadcastAnalyticsToPdf({
    required dynamic data, // BroadcastAnalyticsData
    String filename = 'broadcast_analytics_report',
  }) async {
    final pdf = pw.Document();
    final timestamp = DateTime.now();
    final timestampStr = _formatDateIso(timestamp);
    final purple = PdfColor.fromHex('#9C27B0');
    final green = PdfColor.fromHex('#4CAF50');
    final red = PdfColor.fromHex('#F44336');
    final blue = PdfColor.fromHex('#2196F3');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Broadcast Analytics',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pdfColors.navy),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(ClientConfig.businessName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfColors.navy)),
                    pw.Text(timestampStr, style: pw.TextStyle(fontSize: 10, color: _pdfColors.textMuted)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 3, color: purple),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildPdfSectionHeaderColored('Summary Statistics', purple),
          pw.SizedBox(height: 16),
          // Top metrics row
          pw.Row(children: [
            _buildPdfStatCard('Total Campaigns', data.totalCampaigns.toString(), purple),
            pw.SizedBox(width: 10),
            _buildPdfStatCard('Total Recipients', data.totalRecipients.toString(), blue),
            pw.SizedBox(width: 10),
            _buildPdfStatCard('Delivered', data.totalDelivered.toString(), green),
            pw.SizedBox(width: 10),
            _buildPdfStatCard('Read', data.totalRead.toString(), _pdfColors.cyan),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _buildPdfGradientCard('Delivery Rate', '${data.deliveryRate.toStringAsFixed(1)}%', green, sublabel: 'of recipients'),
            pw.SizedBox(width: 10),
            _buildPdfGradientCard('Read Rate', '${data.readRate.toStringAsFixed(1)}%', blue, sublabel: 'of recipients'),
            pw.SizedBox(width: 10),
            _buildPdfGradientCard('Failed', data.totalFailed.toString(), red, sublabel: 'recipients'),
          ]),
          pw.SizedBox(height: 24),
          _buildPdfSectionHeaderColored('Activity (Last 7 Days)', purple),
          pw.SizedBox(height: 16),
          _buildPdfBroadcastActivityChart(data.last7Days),
          pw.SizedBox(height: 24),
          _buildPdfSectionHeaderColored('Recent Campaign Performance', purple),
          pw.SizedBox(height: 16),
          _buildPdfCampaignTable(data.recentCampaigns),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      content: bytes,
      filename: '${filename}_$timestampStr.pdf',
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _buildPdfSectionHeaderColored(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _buildPdfBroadcastActivityChart(List<dynamic> days) {
    if (days.isEmpty) {
      return pw.Text('No activity data', style: pw.TextStyle(color: _pdfColors.textMuted));
    }

    int maxCount = 0;
    for (final day in days) {
      final count = day.recipients as int;
      if (count > maxCount) maxCount = count;
    }

    return pw.Column(
      children: days.map((day) {
        final count = day.recipients as int;
        final campaigns = day.campaigns as int;
        final pct = maxCount > 0 ? count / maxCount : 0.0;
        final filledFlex = (pct * 100).round().clamp(1, 100);
        final emptyFlex = 100 - filledFlex;

        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 75,
                child: pw.Text(_formatDateShort(day.date as DateTime), style: pw.TextStyle(fontSize: 10, color: _pdfColors.navy)),
              ),
              pw.Expanded(
                child: pw.Container(
                  height: 18,
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8'), borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Row(
                    children: [
                      if (pct > 0)
                        pw.Expanded(
                          flex: filledFlex,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#9C27B0'), borderRadius: pw.BorderRadius.circular(4)),
                          ),
                        ),
                      if (pct < 1)
                        pw.Expanded(flex: emptyFlex, child: pw.Container()),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 55,
                child: pw.Text(
                  '$count rcpts',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.SizedBox(
                width: 45,
                child: pw.Text(
                  '$campaigns camps',
                  style: pw.TextStyle(fontSize: 8, color: _pdfColors.textMuted),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildPdfCampaignTable(List<dynamic> campaigns) {
    if (campaigns.isEmpty) {
      return pw.Text('No campaigns yet', style: pw.TextStyle(color: _pdfColors.textMuted));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FixedColumnWidth(50),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(40),
        5: const pw.FixedColumnWidth(55),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#9C27B0')),
          children: ['Campaign', 'Recipients', 'Delivered', 'Read', 'Failed', 'Read Rate'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            );
          }).toList(),
        ),
        ...List.generate(campaigns.length, (i) {
          final c = campaigns[i];
          final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F9F0FF');
          final readRate = c.readRate as double;
          final rateColor = readRate >= 70
              ? PdfColor.fromHex('#4CAF50')
              : readRate >= 40
                  ? PdfColor.fromHex('#FF9800')
                  : PdfColor.fromHex('#F44336');

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(c.name as String, style: pw.TextStyle(fontSize: 9, color: _pdfColors.navy))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((c.recipients as int).toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((c.delivered as int).toString(), style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#4CAF50')), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((c.read as int).toString(), style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#2196F3')), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((c.failed as int).toString(), style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#F44336')), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${readRate.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: rateColor), textAlign: pw.TextAlign.center)),
            ],
          );
        }),
      ],
    );
  }

  // ============================================
  // ACTIVITY LOGS EXPORT - CSV
  // ============================================

  static void exportActivityLogsToCsv({
    required List<ActivityLog> logs,
    String filename = 'activity_logs',
  }) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String().split('T')[0];

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
    final timestamp = DateTime.now().toIso8601String().split('T')[0];

    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: Arial, sans-serif; }');
    buffer.writeln('table { border-collapse: collapse; margin-bottom: 30px; }');
    buffer.writeln('th { background-color: #1E88E5; color: white; font-weight: bold; padding: 12px; text-align: left; }');
    buffer.writeln('td { padding: 10px; border: 1px solid #e0e0e0; }');
    buffer.writeln('.header { background-color: #0A1628; color: #00D9FF; font-size: 18px; padding: 15px; }');
    buffer.writeln('.highlight { background-color: #f0f7ff; }');
    buffer.writeln('.action-login { color: #4CAF50; font-weight: 600; }');
    buffer.writeln('.action-logout { color: #78909C; font-weight: 600; }');
    buffer.writeln('.action-message { color: #00BCD4; font-weight: 600; }');
    buffer.writeln('.action-broadcast { color: #FF9800; font-weight: 600; }');
    buffer.writeln('.action-ai { color: #1E88E5; font-weight: 600; }');
    buffer.writeln('.action-user { color: #9C27B0; font-weight: 600; }');
    buffer.writeln('.action-default { color: #333; font-weight: 600; }');
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
      final actionClass = _getActionCssClass(log.actionType);
      final date = _formatDateIso(log.createdAt);
      final time = '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';
      buffer.writeln(
        '<tr$rowClass>'
        '<td>$date</td>'
        '<td>$time</td>'
        '<td>${_escapeHtml(log.userName)}</td>'
        '<td>${_escapeHtml(log.userEmail ?? '')}</td>'
        '<td class="$actionClass">${_escapeHtml(log.actionType.displayName)}</td>'
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

  static String _getActionCssClass(ActionType type) {
    switch (type) {
      case ActionType.login:
        return 'action-login';
      case ActionType.logout:
        return 'action-logout';
      case ActionType.messageSent:
        return 'action-message';
      case ActionType.broadcastSent:
        return 'action-broadcast';
      case ActionType.aiToggled:
        return 'action-ai';
      case ActionType.userCreated:
      case ActionType.userUpdated:
      case ActionType.userDeleted:
        return 'action-user';
      default:
        return 'action-default';
    }
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