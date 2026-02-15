import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/broadcast_analytics_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';

/// Analytics screen for broadcast campaigns
class BroadcastAnalyticsScreen extends StatefulWidget {
  const BroadcastAnalyticsScreen({super.key});

  @override
  State<BroadcastAnalyticsScreen> createState() => _BroadcastAnalyticsScreenState();
}

class _BroadcastAnalyticsScreenState extends State<BroadcastAnalyticsScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BroadcastAnalyticsProvider>().fetchAnalytics();
    });
  }

  Future<void> _handleExport(String format, BroadcastAnalyticsData data) async {
    setState(() => _isExporting = true);
    try {
      switch (format) {
        case 'csv':
          AnalyticsExporter.exportBroadcastAnalyticsToCsv(data: data);
          _showExportSuccess('CSV');
          break;
        case 'excel':
          AnalyticsExporter.exportBroadcastAnalyticsToExcel(data: data);
          _showExportSuccess('Excel');
          break;
        case 'pdf':
          await AnalyticsExporter.exportBroadcastAnalyticsToPdf(data: data);
          _showExportSuccess('PDF');
          break;
        case 'all':
          AnalyticsExporter.exportBroadcastAnalyticsToCsv(data: data);
          await Future.delayed(const Duration(milliseconds: 300));
          AnalyticsExporter.exportBroadcastAnalyticsToExcel(data: data);
          await Future.delayed(const Duration(milliseconds: 300));
          await AnalyticsExporter.exportBroadcastAnalyticsToPdf(data: data);
          _showExportSuccess('All formats');
          break;
      }
    } catch (e) {
      _showExportError(e.toString());
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showExportSuccess(String format) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Text('$format exported successfully'),
      ]),
      backgroundColor: VividColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showExportError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('Export failed: $error')),
      ]),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildExportButton(BroadcastAnalyticsData data) {
    final menuColors = {
      'csv': Colors.green,
      'excel': const Color(0xFF217346),
      'pdf': Colors.red,
      'all': VividColors.cyan,
    };
    return PopupMenuButton<String>(
      onSelected: (format) => _handleExport(format, data),
      enabled: !_isExporting,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: VividColors.navy,
      itemBuilder: (context) => [
        _buildExportMenuItem('csv',   'CSV',        Icons.table_chart,    'Spreadsheet format', menuColors),
        _buildExportMenuItem('excel', 'Excel',      Icons.grid_on,        'Formatted workbook', menuColors),
        _buildExportMenuItem('pdf',   'PDF',        Icons.picture_as_pdf, 'Professional report', menuColors),
        const PopupMenuDivider(),
        _buildExportMenuItem('all',   'Export All', Icons.download,       'All formats', menuColors),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE040FB)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: const Color(0xFF9C27B0).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isExporting)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.download, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _isExporting ? 'Exporting...' : 'Export',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildExportMenuItem(
    String value, String title, IconData icon, String subtitle,
    Map<String, Color> colors,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colors[value]!.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: colors[value], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: VividColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcastAnalyticsProvider>();
    final analytics = provider.analytics;

    return Container(
      color: VividColors.darkNavy,
      child: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VividColors.cyan),
            )
          : analytics == null
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.analytics, color: VividColors.cyan, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Broadcast Analytics',
                              style: TextStyle(
                                color: VividColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildExportButton(analytics),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Key Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.campaign,
                              label: 'Total Campaigns',
                              value: analytics.totalCampaigns.toString(),
                              color: VividColors.brightBlue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.people,
                              label: 'Total Recipients',
                              value: _formatNumber(analytics.totalRecipients),
                              color: VividColors.cyan,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.check_circle,
                              label: 'Total Sent',
                              value: _formatNumber(analytics.totalDelivered),
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.error_outline,
                              label: 'Total Failed',
                              value: _formatNumber(analytics.totalFailed),
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.done_all,
                              label: 'Delivery Rate',
                              value: '${analytics.deliveryRate.toStringAsFixed(1)}%',
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Status Breakdown & Activity Chart
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Breakdown
                          Expanded(
                            flex: 1,
                            child: _StatusBreakdown(analytics: analytics),
                          ),
                          const SizedBox(width: 24),
                          // Activity Chart
                          Expanded(
                            flex: 2,
                            child: _ActivityChart(data: analytics.last7Days),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Recent Campaigns Performance
                      _CampaignPerformanceTable(campaigns: analytics.recentCampaigns),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: VividColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No analytics data yet',
            style: TextStyle(
              color: VividColors.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start sending broadcasts to see analytics',
            style: TextStyle(
              color: VividColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

// ============================================
// METRIC CARD
// ============================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: VividColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: VividColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// STATUS BREAKDOWN
// ============================================

class _StatusBreakdown extends StatelessWidget {
  final BroadcastAnalyticsData analytics;

  const _StatusBreakdown({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final total = analytics.totalRecipients;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Status',
            style: TextStyle(
              color: VividColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _StatusRow(
            label: 'Accepted',
            count: analytics.totalDelivered,
            total: total,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Failed',
            count: analytics.totalFailed,
            total: total,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Text(
              '$count (${(percentage * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(
                color: VividColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: VividColors.deepBlue,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ============================================
// ACTIVITY CHART
// ============================================

class _ActivityChart extends StatelessWidget {
  final List<DailyBroadcastActivity> data;

  const _ActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    int maxRecipients = 1;
    for (final d in data) {
      if (d.recipients > maxRecipients) {
        maxRecipients = d.recipients;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Last 7 Days Activity',
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: VividColors.cyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Recipients',
                    style: TextStyle(
                      color: VividColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _buildBars(maxRecipients),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBars(int maxRecipients) {
    return data.map((day) {
      final barHeight = maxRecipients > 0
          ? (day.recipients / maxRecipients * 120)
          : 0.0;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (day.recipients > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    day.recipients.toString(),
                    style: const TextStyle(
                      color: VividColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Container(
                height: barHeight.clamp(4.0, 120.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      VividColors.brightBlue,
                      VividColors.cyan,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDay(day.date),
                style: const TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _formatDay(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

// ============================================
// CAMPAIGN PERFORMANCE TABLE
// ============================================

class _CampaignPerformanceTable extends StatelessWidget {
  final List<CampaignPerformance> campaigns;

  const _CampaignPerformanceTable({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Campaign Performance',
            style: TextStyle(
              color: VividColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: VividColors.deepBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Campaign', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(flex: 1, child: Text('Recipients', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Accepted', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Failed', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Delivery Rate', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Table Rows
          ...campaigns.map((campaign) => _buildCampaignRow(campaign)).toList(),
        ],
      ),
    );
  }

  Widget _buildCampaignRow(CampaignPerformance campaign) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.name,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(campaign.sentAt),
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.recipients.toString(),
              style: const TextStyle(color: VividColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.delivered.toString(),
              style: const TextStyle(color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.failed.toString(),
              style: TextStyle(
                color: campaign.failed > 0 ? Colors.red : VividColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRateColor(campaign.deliveryRate).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${campaign.deliveryRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _getRateColor(campaign.deliveryRate),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRateColor(double rate) {
    if (rate >= 70) return Colors.green;
    if (rate >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final bh = date.toUtc().add(const Duration(hours: 3));
    final nowBh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final diff = nowBh.difference(bh);

    if (diff.inDays == 0 && bh.day == nowBh.day) {
      return 'Today';
    } else if (diff.inDays <= 1 && bh.day == nowBh.subtract(const Duration(days: 1)).day) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${bh.day}/${bh.month}/${bh.year}';
    }
  }
}