import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/broadcast_analytics_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';
import '../utils/toast_service.dart';

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
    VividToast.show(context,
      message: '$format exported successfully',
      type: ToastType.success,
    );
  }

  void _showExportError(String error) {
    VividToast.show(context,
      message: 'Export failed: $error',
      type: ToastType.error,
    );
  }

  Widget _buildExportButton(BuildContext context, BroadcastAnalyticsData data) {
    final vc = context.vividColors;
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
      color: vc.surface,
      itemBuilder: (context) => [
        _buildExportMenuItem(context, 'csv',   'CSV',        Icons.table_chart,    'Spreadsheet format', menuColors),
        _buildExportMenuItem(context, 'excel', 'Excel',      Icons.grid_on,        'Formatted workbook', menuColors),
        _buildExportMenuItem(context, 'pdf',   'PDF',        Icons.picture_as_pdf, 'Professional report', menuColors),
        const PopupMenuDivider(),
        _buildExportMenuItem(context, 'all',   'Export All', Icons.download,       'All formats', menuColors),
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
    BuildContext context,
    String value, String title, IconData icon, String subtitle,
    Map<String, Color> colors,
  ) {
    final vc = context.vividColors;
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
                Text(title, style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: vc.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<BroadcastAnalyticsProvider>();
    final analytics = provider.analytics;

    return Container(
      color: vc.background,
      child: analytics == null
              ? _buildEmptyState(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final contentPadding = isMobile ? 12.0 : 24.0;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              const Icon(Icons.analytics, color: VividColors.cyan, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Broadcast Analytics',
                                  style: TextStyle(
                                    color: vc.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildExportButton(context, analytics),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Key Metrics Row
                          if (isMobile)
                            _buildMobileMetricCards(analytics, constraints.maxWidth, contentPadding)
                          else
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
                              ],
                            ),
                          const SizedBox(height: 24),

                          // Status Breakdown & Activity Chart
                          if (isMobile)
                            Column(
                              children: [
                                _StatusBreakdown(analytics: analytics),
                                const SizedBox(height: 16),
                                _ActivityChart(data: analytics.last7Days),
                              ],
                            )
                          else
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
                          _CampaignPerformanceTable(campaigns: analytics.recentCampaigns, isMobile: isMobile),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final vc = context.vividColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: vc.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No analytics data yet',
            style: TextStyle(
              color: vc.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start sending broadcasts to see analytics',
            style: TextStyle(
              color: vc.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetricCards(BroadcastAnalyticsData analytics, double maxWidth, double padding) {
    final cardWidth = (maxWidth - padding * 2 - 12) / 2;
    final cards = <Widget>[
      _MetricCard(
        icon: Icons.campaign,
        label: 'Total Campaigns',
        value: analytics.totalCampaigns.toString(),
        color: VividColors.brightBlue,
      ),
      _MetricCard(
        icon: Icons.people,
        label: 'Total Recipients',
        value: _formatNumber(analytics.totalRecipients),
        color: VividColors.cyan,
      ),
      _MetricCard(
        icon: Icons.check_circle,
        label: 'Total Sent',
        value: _formatNumber(analytics.totalDelivered),
        color: Colors.green,
      ),
      _MetricCard(
        icon: Icons.error_outline,
        label: 'Total Failed',
        value: _formatNumber(analytics.totalFailed),
        color: Colors.red,
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
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
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vc.border,
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
            style: TextStyle(
              color: vc.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: vc.textMuted,
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
    final vc = context.vividColors;
    final total = analytics.totalRecipients;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vc.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Status',
            style: TextStyle(
              color: vc.textPrimary,
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
    final vc = context.vividColors;
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
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Text(
              '$count (${(percentage * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: vc.textPrimary,
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
            backgroundColor: vc.surfaceAlt,
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
    final vc = context.vividColors;
    int maxRecipients = 1;
    for (final d in data) {
      if (d.recipients > maxRecipients) {
        maxRecipients = d.recipients;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vc.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Last 7 Days Activity',
                style: TextStyle(
                  color: vc.textPrimary,
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
                  Text(
                    'Recipients',
                    style: TextStyle(
                      color: vc.textMuted,
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
              children: _buildBars(context, maxRecipients),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBars(BuildContext context, int maxRecipients) {
    final vc = context.vividColors;
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
                style: TextStyle(
                  color: vc.textMuted,
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
  final bool isMobile;

  const _CampaignPerformanceTable({required this.campaigns, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vc.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Campaign Performance',
            style: TextStyle(
              color: vc.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          if (isMobile)
            // Mobile: card-based list
            ...campaigns.map((campaign) => _buildMobileCampaignCard(context, campaign)).toList()
          else ...[
            // Desktop: Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Campaign', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                  Expanded(flex: 1, child: Text('Recipients', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Accepted', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Failed', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Desktop: Table Rows
            ...campaigns.map((campaign) => _buildCampaignRow(context, campaign)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCampaignCard(BuildContext context, CampaignPerformance campaign) {
    final vc = context.vividColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaign.name,
            style: TextStyle(
              color: vc.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(campaign.sentAt),
            style: TextStyle(
              color: vc.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MobileMetricItem(label: 'Recipients', value: campaign.recipients.toString(), color: vc.textPrimary),
              ),
              Expanded(
                child: _MobileMetricItem(label: 'Accepted', value: campaign.delivered.toString(), color: Colors.green),
              ),
              Expanded(
                child: _MobileMetricItem(label: 'Failed', value: campaign.failed.toString(), color: campaign.failed > 0 ? Colors.red : vc.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignRow(BuildContext context, CampaignPerformance campaign) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: vc.borderSubtle,
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
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(campaign.sentAt),
                  style: TextStyle(
                    color: vc.textMuted,
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
              style: TextStyle(color: vc.textPrimary),
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
                color: campaign.failed > 0 ? Colors.red : vc.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
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

// ============================================
// MOBILE METRIC ITEM (for campaign cards)
// ============================================

class _MobileMetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MobileMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: vc.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
