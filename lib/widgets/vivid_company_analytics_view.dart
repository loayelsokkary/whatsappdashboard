import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_analytics_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';
import '../utils/toast_service.dart';

/// Company-wide analytics view for Vivid admin dashboard
class VividCompanyAnalyticsView extends StatefulWidget {
  const VividCompanyAnalyticsView({super.key});

  @override
  State<VividCompanyAnalyticsView> createState() => _VividCompanyAnalyticsViewState();
}

class _VividCompanyAnalyticsViewState extends State<VividCompanyAnalyticsView> {
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    final adminProvider = context.read<AdminProvider>();
    final analyticsProvider = context.read<AdminAnalyticsProvider>();
    analyticsProvider.fetchCompanyAnalytics(adminProvider.clients);
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            vc.background,
            vc.surface,
            vc.surfaceAlt.withOpacity(0.5),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: Consumer<AdminAnalyticsProvider>(
              builder: (context, provider, _) {
                final vc = context.vividColors;
                final analytics = provider.companyAnalytics;
                if (analytics == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 64,
                          color: vc.textMuted.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No analytics data available',
                          style: TextStyle(color: vc.textMuted),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadAnalytics,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return _buildAnalyticsContent(context, analytics);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: VividColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: VividColors.cyan.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.business,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vivid Company Analytics',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VividColors.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: VividColors.cyan),
                          SizedBox(width: 6),
                          Text(
                            'Real-time',
                            style: TextStyle(
                              color: VividColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Aggregate metrics across all clients',
                      style: TextStyle(
                        color: vc.textMuted.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildExportButton(context),
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    final vc = context.vividColors;
    final analytics = context.read<AdminAnalyticsProvider>().companyAnalytics;
    return PopupMenuButton<String>(
      onSelected: (format) async {
        if (analytics == null) return;
        try {
          if (format == 'csv') {
            AnalyticsExporter.exportCompanyAnalyticsCsv(analytics);
          } else if (format == 'pdf') {
            await AnalyticsExporter.exportCompanyAnalyticsPdf(analytics);
          }
          if (mounted) {
            VividToast.show(context, message: '${format.toUpperCase()} exported', type: ToastType.success);
          }
        } catch (e) {
          if (mounted) {
            VividToast.show(context, message: 'Export failed: $e', type: ToastType.error);
          }
        }
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: vc.surface,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'csv', child: Row(children: [
          Icon(Icons.table_chart, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Text('Export CSV', style: TextStyle(color: vc.textPrimary)),
        ])),
        PopupMenuItem(value: 'pdf', child: Row(children: [
          Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Text('Export PDF', style: TextStyle(color: vc.textPrimary)),
        ])),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: VividColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: VividColors.brightBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, color: vc.background, size: 18),
            const SizedBox(width: 6),
            Text('Export', style: TextStyle(color: vc.background, fontWeight: FontWeight.w600, fontSize: 13)),
            Icon(Icons.arrow_drop_down, color: vc.background, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveCardRow(List<Widget> cards, {required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: cards.expand((card) => [card, const SizedBox(height: 12)]).toList()..removeLast(),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      children.add(Expanded(child: cards[i]));
      if (i < cards.length - 1) children.add(const SizedBox(width: 20));
    }
    return Row(children: children);
  }

  Widget _buildAnalyticsContent(BuildContext context, VividCompanyAnalytics analytics) {
    final vc = context.vividColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final horizontalPadding = isMobile ? 16.0 : 32.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row - Key metrics
              _buildResponsiveCardRow([
                _MetricCard(
                  icon: Icons.business,
                  label: 'Total Clients',
                  value: analytics.totalClients.toString(),
                  color: VividColors.brightBlue,
                  description: 'Active accounts',
                ),
                _MetricCard(
                  icon: Icons.message,
                  label: 'Total Messages',
                  value: _formatNumber(analytics.totalMessages),
                  color: VividColors.cyan,
                  description: 'All-time conversations',
                ),
                _MetricCard(
                  icon: Icons.auto_awesome,
                  label: 'Automation Rate',
                  value: '${analytics.overallAutomationRate.toStringAsFixed(1)}%',
                  color: analytics.overallAutomationRate >= 80 ? Colors.green : Colors.orange,
                  description: analytics.overallAutomationRate >= 80 ? 'Excellent' : 'Good',
                  isHighlight: true,
                ),
              ], isMobile: isMobile),
              const SizedBox(height: 20),

              // Second row
              _buildResponsiveCardRow([
                _MetricCard(
                  icon: Icons.smart_toy,
                  label: 'AI Messages',
                  value: _formatNumber(analytics.totalAiMessages),
                  color: VividColors.cyan,
                  description: 'Handled by AI',
                ),
                _MetricCard(
                  icon: Icons.support_agent,
                  label: 'Manager Messages',
                  value: _formatNumber(analytics.totalManagerMessages),
                  color: VividColors.brightBlue,
                  description: 'Human interventions',
                ),
                _MetricCard(
                  icon: Icons.people,
                  label: 'Unique Customers',
                  value: _formatNumber(analytics.totalUniqueCustomers),
                  color: Colors.purple,
                  description: 'Total people reached',
                ),
              ], isMobile: isMobile),
              const SizedBox(height: 20),

              // Third row - Broadcasts
              _buildResponsiveCardRow([
                _MetricCard(
                  icon: Icons.campaign,
                  label: 'Total Broadcasts',
                  value: analytics.totalBroadcasts.toString(),
                  color: Colors.orange,
                  description: 'Campaigns sent',
                ),
                _MetricCard(
                  icon: Icons.group,
                  label: 'Recipients Reached',
                  value: _formatNumber(analytics.totalRecipientsReached),
                  color: Colors.teal,
                  description: 'Via broadcasts',
                ),
                _MetricCard(
                  icon: Icons.access_time,
                  label: 'Last Activity',
                  value: _formatLastActivity(analytics.lastActivityAcrossAll),
                  color: vc.textMuted,
                  description: 'Most recent message',
                ),
              ], isMobile: isMobile),
              const SizedBox(height: 32),

              // Most active clients section
              _buildMostActiveClients(context, analytics.mostActiveClients),
              const SizedBox(height: 32),

              // Activity chart (last 7 days)
              _buildActivityChart(context, analytics.messagesByDay),
              const SizedBox(height: 32),

              // Time period stats
              _buildSectionHeader(context, Icons.date_range, 'Message Volume by Period'),
              const SizedBox(height: 16),
              _buildResponsiveCardRow([
                _MetricCard(
                  icon: Icons.today,
                  label: 'Today',
                  value: _formatNumber(analytics.todayMessages),
                  color: VividColors.cyan,
                  description: 'Messages today',
                ),
                _MetricCard(
                  icon: Icons.view_week,
                  label: 'This Week',
                  value: _formatNumber(analytics.thisWeekMessages),
                  color: VividColors.brightBlue,
                  description: 'Messages this week',
                ),
                _MetricCard(
                  icon: Icons.calendar_month,
                  label: 'This Month',
                  value: _formatNumber(analytics.thisMonthMessages),
                  color: Colors.purple,
                  description: 'Messages this month',
                ),
              ], isMobile: isMobile),
              const SizedBox(height: 32),

              // Client breakdown table
              _buildClientBreakdownTable(context, analytics.allClientActivities, isMobile: isMobile),

              // Broadcast performance
              if (analytics.broadcastTotalRecipients > 0) ...[
                const SizedBox(height: 32),
                _buildSectionHeader(context, Icons.campaign, 'Broadcast Performance'),
                const SizedBox(height: 16),
                _buildResponsiveCardRow([
                  _MetricCard(
                    icon: Icons.done_all,
                    label: 'Delivered',
                    value: _formatNumber(analytics.broadcastDeliveredCount),
                    color: Colors.green,
                    description: '${(analytics.broadcastDeliveredCount / analytics.broadcastTotalRecipients * 100).toStringAsFixed(1)}% rate',
                  ),
                  _MetricCard(
                    icon: Icons.visibility,
                    label: 'Read',
                    value: _formatNumber(analytics.broadcastReadCount),
                    color: Colors.blue,
                    description: '${(analytics.broadcastReadCount / analytics.broadcastTotalRecipients * 100).toStringAsFixed(1)}% rate',
                  ),
                  _MetricCard(
                    icon: Icons.error_outline,
                    label: 'Failed',
                    value: _formatNumber(analytics.broadcastFailedCount),
                    color: analytics.broadcastFailedCount > 0 ? Colors.red : Colors.orange,
                    description: '${(analytics.broadcastFailedCount / analytics.broadcastTotalRecipients * 100).toStringAsFixed(1)}% rate',
                  ),
                ], isMobile: isMobile),
              ],
              const SizedBox(height: 32),

              // Busiest hours
              _buildBusiestHoursChart(context, analytics.messagesByHour, isMobile: isMobile),
              const SizedBox(height: 32),

              // Top customers
              _buildTopCustomers(context, analytics.topCustomers),
              const SizedBox(height: 32),

              // AI performance
              _buildAiPerformanceSection(context, analytics, isMobile: isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMostActiveClients(BuildContext context, List<ClientActivity> clients) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VividColors.brightBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.leaderboard, color: VividColors.brightBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Most Active Clients',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (clients.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No activity data yet',
                  style: TextStyle(color: vc.textMuted),
                ),
              ),
            )
          else
            ...clients.asMap().entries.map((entry) {
              final index = entry.key;
              final client = entry.value;
              return _buildClientActivityRow(context, index + 1, client);
            }),
        ],
      ),
    );
  }

  Widget _buildClientActivityRow(BuildContext context, int rank, ClientActivity client) {
    final vc = context.vividColors;
    final rankColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey[400]
            : rank == 3
                ? Colors.orange[700]
                : vc.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3
            ? Border.all(color: rankColor!.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.clientName,
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  client.lastActivity != null
                      ? 'Last active: ${_formatLastActivity(client.lastActivity)}'
                      : 'No recent activity',
                  style: TextStyle(
                    color: vc.textMuted.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.message, size: 14, color: VividColors.cyan),
                  const SizedBox(width: 4),
                  Text(
                    '${client.messageCount}',
                    style: const TextStyle(
                      color: VividColors.cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (client.broadcastCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '${client.broadcastCount}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart(BuildContext context, Map<String, int> messagesByDay) {
    final vc = context.vividColors;
    // Get last 7 days
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    });

    final maxMessages = messagesByDay.values.isEmpty
        ? 1
        : messagesByDay.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.show_chart, color: VividColors.cyan, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Message Volume (Last 7 Days)',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final count = messagesByDay[day] ?? 0;
                final height = maxMessages > 0 ? (count / maxMessages) * 120 : 0.0;
                final dayParts = day.split('-');
                final dayLabel = '${dayParts[2]}/${dayParts[1]}';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          count.toString(),
                          style: const TextStyle(
                            color: VividColors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height.clamp(4.0, 120.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
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
                          dayLabel,
                          style: TextStyle(
                            color: vc.textMuted.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    final vc = context.vividColors;
    return Row(
      children: [
        Icon(icon, color: vc.textMuted, size: 20),
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

  Widget _buildClientBreakdownTable(BuildContext context, List<ClientActivity> clients, {bool isMobile = false}) {
    final vc = context.vividColors;
    if (clients.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart, color: Colors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Client Breakdown',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMobile)
            // Mobile: card-based list
            ...clients.map((client) => _buildMobileClientCard(context, client))
          else ...[
            // Desktop: Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Client', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                  Expanded(flex: 2, child: Text('Messages', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('AI', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Manager', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Customers', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Auto Rate', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Desktop: Table rows
            ...clients.map((client) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: vc.surfaceAlt.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(client.clientName, style: TextStyle(color: vc.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text(_formatNumber(client.messageCount), style: const TextStyle(color: VividColors.cyan, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text(_formatNumber(client.aiMessages), style: const TextStyle(color: VividColors.cyan, fontSize: 13), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text(_formatNumber(client.managerMessages), style: const TextStyle(color: VividColors.brightBlue, fontSize: 13), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text(client.uniqueCustomers.toString(), style: const TextStyle(color: Colors.purple, fontSize: 13), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('${client.automationRate.toStringAsFixed(0)}%', style: TextStyle(color: client.automationRate >= 80 ? Colors.green : Colors.orange, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileClientCard(BuildContext context, ClientActivity client) {
    final vc = context.vividColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vc.surfaceAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  client.clientName,
                  style: TextStyle(color: vc.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (client.automationRate >= 80 ? Colors.green : Colors.orange).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${client.automationRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: client.automationRate >= 80 ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMobileStatItem(context, 'Messages', _formatNumber(client.messageCount), VividColors.cyan)),
              Expanded(child: _buildMobileStatItem(context, 'AI', _formatNumber(client.aiMessages), VividColors.cyan)),
              Expanded(child: _buildMobileStatItem(context, 'Manager', _formatNumber(client.managerMessages), VividColors.brightBlue)),
              Expanded(child: _buildMobileStatItem(context, 'Customers', client.uniqueCustomers.toString(), Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatItem(BuildContext context, String label, String value, Color color) {
    final vc = context.vividColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: vc.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBusiestHoursChart(BuildContext context, Map<int, int> messagesByHour, {bool isMobile = false}) {
    final vc = context.vividColors;
    if (messagesByHour.isEmpty) return const SizedBox.shrink();

    final maxCount = messagesByHour.values.reduce((a, b) => a > b ? a : b);

    final barsWidget = SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final count = messagesByHour[hour] ?? 0;
          final height = maxCount > 0 ? (count / maxCount) * 140 : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text(
                      count.toString(),
                      style: const TextStyle(
                        color: VividColors.cyan,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    height: height.clamp(2.0, 140.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.orange, Colors.amber],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hour % 3 == 0 ? '${hour}h' : '',
                    style: TextStyle(
                      color: vc.textMuted.withOpacity(0.7),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule, color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Busiest Hours',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 600, child: barsWidget),
            )
          else
            barsWidget,
        ],
      ),
    );
  }

  Widget _buildTopCustomers(BuildContext context, List<TopCustomerInfo> customers) {
    final vc = context.vividColors;
    if (customers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people, color: Colors.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Most Active Customers',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...customers.asMap().entries.map((entry) {
            final index = entry.key;
            final customer = entry.value;
            final rankColor = index == 0
                ? Colors.amber
                : index == 1
                    ? Colors.grey[400]
                    : index == 2
                        ? Colors.orange[700]
                        : vc.textMuted;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: index < 3 ? Border.all(color: rankColor!.withOpacity(0.3)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: rankColor!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text('#${index + 1}', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name ?? customer.phone,
                          style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        Text(
                          customer.clientName,
                          style: TextStyle(color: vc.textMuted.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.message, size: 14, color: VividColors.cyan),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(customer.messageCount),
                        style: const TextStyle(color: VividColors.cyan, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAiPerformanceSection(BuildContext context, VividCompanyAnalytics analytics, {bool isMobile = false}) {
    final vc = context.vividColors;
    final total = analytics.totalAiMessages + analytics.totalManagerMessages;
    final aiPercent = total > 0 ? (analytics.totalAiMessages / total * 100) : 0.0;
    final managerPercent = total > 0 ? (analytics.totalManagerMessages / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: VividColors.cyan, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Performance',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // AI vs Manager ratio bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  if (aiPercent > 0)
                    Expanded(
                      flex: aiPercent.round().clamp(1, 100),
                      child: Container(
                        color: VividColors.cyan,
                        alignment: Alignment.center,
                        child: aiPercent > 10
                            ? Text('AI ${aiPercent.toStringAsFixed(0)}%',
                                style: TextStyle(color: vc.background, fontSize: 12, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                  if (managerPercent > 0)
                    Expanded(
                      flex: managerPercent.round().clamp(1, 100),
                      child: Container(
                        color: VividColors.brightBlue,
                        alignment: Alignment.center,
                        child: managerPercent > 10
                            ? Text('Manager ${managerPercent.toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildResponsiveCardRow([
            _MetricCard(
              icon: Icons.swap_horiz,
              label: 'Handoffs',
              value: analytics.handoffCount.toString(),
              color: Colors.orange,
              description: 'AI tried, manager stepped in',
            ),
            _MetricCard(
              icon: Icons.check_circle,
              label: 'AI Enabled',
              value: analytics.aiEnabledCustomers.toString(),
              color: Colors.green,
              description: 'Customers with AI on',
            ),
            _MetricCard(
              icon: Icons.cancel,
              label: 'AI Disabled',
              value: analytics.aiDisabledCustomers.toString(),
              color: Colors.red,
              description: 'Customers with AI off',
            ),
          ], isMobile: isMobile),
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

  String _formatLastActivity(DateTime? date) {
    if (date == null) return 'N/A';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
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
  final String? description;
  final bool isHighlight;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.description,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? color.withOpacity(0.5) : vc.border,
          width: isHighlight ? 2 : 1,
        ),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: TextStyle(
                color: vc.textMuted.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
