import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/roi_analytics_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';

enum DateRangeFilter {
  allTime('All Time'),
  today('Today'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  thisMonth('This Month');

  final String label;
  const DateRangeFilter(this.label);

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case DateRangeFilter.allTime:
        return null;
      case DateRangeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case DateRangeFilter.last7Days:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      case DateRangeFilter.last30Days:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      case DateRangeFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime? get endDate => this == DateRangeFilter.allTime ? null : DateTime.now();
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateRangeFilter _dateFilter = DateRangeFilter.allTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  void _loadAnalytics() {
    final client = ClientConfig.currentClient;
    if (client == null) return;

    context.read<RoiAnalyticsProvider>().fetchAnalytics(
          clientId: client.id,
          messagesTable: ClientConfig.messagesTable,
          broadcastsTable: ClientConfig.broadcastsTable,
          startDate: _dateFilter.startDate,
          endDate: _dateFilter.endDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<RoiAnalyticsProvider>();

    return Scaffold(
      backgroundColor: vc.background,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: VividColors.cyan))
          : provider.error != null
              ? _buildError(context, provider.error!)
              : provider.data == null
                  ? Center(
                      child: Text('No analytics data',
                          style: TextStyle(color: vc.textMuted)))
                  : _buildContent(context, provider.data!),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    final vc = context.vividColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: VividColors.statusUrgent, size: 48),
          const SizedBox(height: 16),
          Text(error,
              style: TextStyle(color: vc.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh, color: VividColors.cyan, size: 18),
            label: const Text('Retry', style: TextStyle(color: VividColors.cyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnalyticsData data) {
    return RefreshIndicator(
      onRefresh: () async => _loadAnalytics(),
      color: VividColors.cyan,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final padding = isWide ? 32.0 : 20.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, data),
                const SizedBox(height: 28),
                _AnalyticsView(data: data, isWide: isWide),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AnalyticsData data) {
    final vc = context.vividColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ClientConfig.businessName,
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analytics',
                style: TextStyle(color: vc.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        _buildDateFilter(context),
        const SizedBox(width: 12),
        _buildExportButton(context, data),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _loadAnalytics,
          icon: Icon(Icons.refresh_rounded, color: vc.textMuted, size: 20),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildExportButton(BuildContext context, AnalyticsData data) {
    final vc = context.vividColors;
    return PopupMenuButton<String>(
      icon: Icon(Icons.download_rounded, color: vc.textMuted, size: 20),
      tooltip: 'Export',
      color: vc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: vc.popupBorder),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, size: 16, color: vc.textSecondary),
              const SizedBox(width: 10),
              Text('Export CSV', style: TextStyle(color: vc.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 16, color: vc.textSecondary),
              const SizedBox(width: 10),
              Text('Export PDF', style: TextStyle(color: vc.textPrimary, fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (format) => _handleExport(format, data),
    );
  }

  void _handleExport(String format, AnalyticsData data) {
    final clientName = ClientConfig.businessName;
    final dateRange = _dateFilter.label;

    if (format == 'csv') {
      AnalyticsExporter.exportAnalyticsCsv(
        data: data,
        clientName: clientName,
        dateRange: dateRange,
      );
    } else {
      AnalyticsExporter.exportAnalyticsPdf(
        data: data,
        clientName: clientName,
        dateRange: dateRange,
      );
    }
  }

  Widget _buildDateFilter(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.popupBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateRangeFilter>(
          value: _dateFilter,
          icon: Icon(Icons.keyboard_arrow_down, color: vc.textMuted, size: 18),
          dropdownColor: vc.surface,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(color: vc.textPrimary, fontSize: 13),
          items: DateRangeFilter.values.map((filter) {
            final isSelected = filter == _dateFilter;
            return DropdownMenuItem(
              value: filter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: isSelected ? VividColors.cyan : vc.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: isSelected ? vc.textPrimary : vc.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (filter) {
            if (filter != null && filter != _dateFilter) {
              setState(() => _dateFilter = filter);
              _loadAnalytics();
            }
          },
        ),
      ),
    );
  }
}

// ================================================================
// ANALYTICS VIEW
// ================================================================
class _AnalyticsView extends StatelessWidget {
  final AnalyticsData data;
  final bool isWide;

  const _AnalyticsView({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final m = data.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1 — Hero metrics
        _buildMetricRow([
          _MetricData(
            label: 'Leads',
            value: '${m.leads}',
            subtitle: '24h-gap sessions',
            color: VividColors.cyan,
            icon: Icons.person_add_outlined,
          ),
          _MetricData(
            label: 'Revenue',
            value: m.revenue > 0 ? '${m.revenue.toStringAsFixed(0)} BHD' : '0',
            subtitle: 'From campaign conversions',
            color: VividColors.statusSuccess,
            icon: Icons.attach_money_outlined,
          ),
          _MetricData(
            label: 'Engagement Rate',
            value: '${m.engagementRate.toStringAsFixed(1)}%',
            subtitle: '${m.messagesSent} outbound msgs',
            color: VividColors.brightBlue,
            icon: Icons.trending_up,
            progress: m.engagementRate / 100,
          ),
        ]),
        const SizedBox(height: 20),

        // Row 2 — Secondary metrics
        _buildMetricRow([
          _MetricData(
            label: 'Avg Response Time',
            value: _formatDuration(m.avgResponseTimeSeconds),
            subtitle: 'Human reply time',
            color: VividColors.statusWarning,
            icon: Icons.speed_outlined,
          ),
          _MetricData(
            label: 'Open Conversations',
            value: '${m.openConversationCount}',
            subtitle: '${m.overdueConversationCount} overdue',
            color: m.overdueConversationCount > 0 ? VividColors.statusUrgent : VividColors.cyan,
            icon: Icons.chat_bubble_outline,
          ),
          _MetricData(
            label: 'Messages',
            value: '${m.messagesReceived}',
            subtitle: '${m.messagesSent} sent / ${m.messagesReceived} received',
            color: VividColors.brightBlue,
            icon: Icons.forum_outlined,
          ),
        ]),
        const SizedBox(height: 32),

        // Open / Overdue conversations
        if (data.openConversations.isNotEmpty) ...[
          _sectionTitle(
            context,
            data.overdueConversations.isNotEmpty
                ? 'Open Conversations (${data.overdueConversations.length} overdue)'
                : 'Open Conversations',
            Icons.chat_outlined,
          ),
          const SizedBox(height: 16),
          _buildOpenConversations(context),
          const SizedBox(height: 32),
        ],

        // Campaign performance
        if (data.campaigns.isNotEmpty) ...[
          _sectionTitle(context, 'Campaign Performance', Icons.campaign_outlined),
          const SizedBox(height: 16),
          _buildCampaignsTable(context),
          const SizedBox(height: 32),
        ],

        // Daily trends
        if (data.dailyBreakdown.isNotEmpty) ...[
          _sectionTitle(context, 'Daily Trends', Icons.trending_up),
          const SizedBox(height: 16),
          _buildDailyChart(context),
        ],
      ],
    );
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '0s';
    if (seconds < 60) return '${seconds.toStringAsFixed(0)}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}m';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }

  Widget _buildMetricRow(List<_MetricData> metrics) {
    if (isWide) {
      return Row(
        children: metrics.map((m) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _LargeMetricCard(data: m),
            ),
          );
        }).toList(),
      );
    }
    return Column(
      children: metrics.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LargeMetricCard(data: m),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    final vc = context.vividColors;
    return Row(
      children: [
        Icon(icon, color: VividColors.cyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: vc.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---- Open Conversations ----
  Widget _buildOpenConversations(BuildContext context) {
    final vc = context.vividColors;
    final convs = data.openConversations;
    // Sort overdue first, then by waiting time desc
    final sorted = [...convs]..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: sorted.take(10).toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          final isOverdue = data.overdueConversations.any((o) => o.customerPhone == c.customerPhone);
          final waitLabel = _formatWaitTime(c.waitingTime);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: idx < min(sorted.length, 10) - 1
                  ? Border(bottom: BorderSide(color: vc.borderSubtle))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOverdue ? VividColors.statusUrgent : VividColors.statusWarning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.customerName ?? c.customerPhone,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.customerName != null)
                        Text(c.customerPhone,
                            style: TextStyle(color: vc.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    c.lastMessage,
                    style: TextStyle(color: vc.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  waitLabel,
                  style: TextStyle(
                    color: isOverdue ? VividColors.statusUrgent : vc.textMuted,
                    fontSize: 12,
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatWaitTime(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  // ---- Campaign Performance Table ----
  Widget _buildCampaignsTable(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: vc.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: VividColors.tealBlue.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Campaign',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('Sent',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('Responded',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('Leads',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('Revenue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          ...data.campaigns.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: c != data.campaigns.last
                      ? Border(
                          bottom: BorderSide(
                              color: VividColors.tealBlue.withValues(alpha: 0.08)))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: TextStyle(
                                  color: vc.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                          if (c.sentAt != null)
                            Text(
                                '${c.sentAt!.day}/${c.sentAt!.month}/${c.sentAt!.year}',
                                style: TextStyle(
                                    color: vc.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Expanded(
                        flex: 1,
                        child: Text('${c.sent}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: vc.textSecondary, fontSize: 13))),
                    Expanded(
                        flex: 1,
                        child: Text('${c.responded}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.responded > 0 ? VividColors.statusSuccess : vc.textMuted,
                                fontSize: 13))),
                    Expanded(
                        flex: 1,
                        child: Text('${c.leads}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.leads > 0 ? VividColors.cyan : vc.textMuted,
                                fontSize: 13))),
                    Expanded(
                        flex: 1,
                        child: Text(
                            c.revenue > 0 ? '${c.revenue.toStringAsFixed(0)}' : '-',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.revenue > 0
                                    ? VividColors.statusSuccess
                                    : vc.textMuted,
                                fontSize: 13))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ---- Daily Trends Chart ----
  Widget _buildDailyChart(BuildContext context) {
    final vc = context.vividColors;
    final days = data.dailyBreakdown.length > 30
        ? data.dailyBreakdown.sublist(data.dailyBreakdown.length - 30)
        : data.dailyBreakdown;
    if (days.isEmpty) return const SizedBox.shrink();

    final maxLeads = days.map((d) => d.leads).reduce(max).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leads per day — last ${days.length} days',
              style: TextStyle(
                  color: vc.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final h = maxLeads > 0 ? (day.leads / maxLeads) * 90 : 0.0;
                return Expanded(
                  child: Tooltip(
                    message: '${day.date}\nLeads: ${day.leads}\nRevenue: ${day.revenue.toStringAsFixed(0)}',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      height: max(1, h),
                      decoration: BoxDecoration(
                        color: VividColors.cyan.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(context, VividColors.cyan, 'Leads'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final vc = context.vividColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: vc.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ================================================================
// SHARED METRIC CARD
// ================================================================
class _MetricData {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData? icon;
  final double? progress;

  const _MetricData({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    this.icon,
    this.progress,
  });
}

class _LargeMetricCard extends StatelessWidget {
  final _MetricData data;

  const _LargeMetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (data.icon != null) ...[
                Icon(data.icon, size: 16, color: data.color.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                      color: vc.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.subtitle,
            style: TextStyle(color: vc.textMuted, fontSize: 12),
          ),
          if (data.progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: data.progress!.clamp(0.0, 1.0),
                backgroundColor: vc.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(data.color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
