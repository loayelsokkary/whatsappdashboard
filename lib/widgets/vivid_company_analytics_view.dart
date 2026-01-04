import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_analytics_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/vivid_theme.dart';

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VividColors.darkNavy,
            VividColors.navy,
            VividColors.deepBlue.withOpacity(0.5),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: Consumer<AdminAnalyticsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingCompany) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: VividColors.cyan),
                        SizedBox(height: 16),
                        Text(
                          'Loading company analytics...',
                          style: TextStyle(color: VividColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                final analytics = provider.companyAnalytics;
                if (analytics == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 64,
                          color: VividColors.textMuted.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No analytics data available',
                          style: TextStyle(color: VividColors.textMuted),
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

                return _buildAnalyticsContent(analytics);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                const Text(
                  'Vivid Company Analytics',
                  style: TextStyle(
                    color: VividColors.textPrimary,
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
                        color: VividColors.textMuted.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(VividCompanyAnalytics analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row - Key metrics
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.business,
                  label: 'Total Clients',
                  value: analytics.totalClients.toString(),
                  color: VividColors.brightBlue,
                  description: 'Active accounts',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  icon: Icons.message,
                  label: 'Total Messages',
                  value: _formatNumber(analytics.totalMessages),
                  color: VividColors.cyan,
                  description: 'All-time conversations',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  icon: Icons.auto_awesome,
                  label: 'Automation Rate',
                  value: '${analytics.overallAutomationRate.toStringAsFixed(1)}%',
                  color: analytics.overallAutomationRate >= 80 ? Colors.green : Colors.orange,
                  description: analytics.overallAutomationRate >= 80 ? 'Excellent' : 'Good',
                  isHighlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Second row
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.smart_toy,
                  label: 'AI Messages',
                  value: _formatNumber(analytics.totalAiMessages),
                  color: VividColors.cyan,
                  description: 'Handled by AI',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  icon: Icons.support_agent,
                  label: 'Manager Messages',
                  value: _formatNumber(analytics.totalManagerMessages),
                  color: VividColors.brightBlue,
                  description: 'Human interventions',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  icon: Icons.people,
                  label: 'Unique Customers',
                  value: _formatNumber(analytics.totalUniqueCustomers),
                  color: Colors.purple,
                  description: 'Total people reached',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Third row - Broadcasts
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.campaign,
                  label: 'Total Broadcasts',
                  value: analytics.totalBroadcasts.toString(),
                  color: Colors.orange,
                  description: 'Campaigns sent',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  icon: Icons.group,
                  label: 'Recipients Reached',
                  value: _formatNumber(analytics.totalRecipientsReached),
                  color: Colors.teal,
                  description: 'Via broadcasts',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _MetricCard(
                  icon: Icons.access_time,
                  label: 'Last Activity',
                  value: _formatLastActivity(analytics.lastActivityAcrossAll),
                  color: VividColors.textMuted,
                  description: 'Most recent message',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Most active clients section
          _buildMostActiveClients(analytics.mostActiveClients),
          const SizedBox(height: 32),

          // Activity chart (last 7 days)
          _buildActivityChart(analytics.messagesByDay),
        ],
      ),
    );
  }

  Widget _buildMostActiveClients(List<ClientActivity> clients) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
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
              const Text(
                'Most Active Clients',
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (clients.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No activity data yet',
                  style: TextStyle(color: VividColors.textMuted),
                ),
              ),
            )
          else
            ...clients.asMap().entries.map((entry) {
              final index = entry.key;
              final client = entry.value;
              return _buildClientActivityRow(index + 1, client);
            }),
        ],
      ),
    );
  }

  Widget _buildClientActivityRow(int rank, ClientActivity client) {
    final rankColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey[400]
            : rank == 3
                ? Colors.orange[700]
                : VividColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
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
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  client.lastActivity != null
                      ? 'Last active: ${_formatLastActivity(client.lastActivity)}'
                      : 'No recent activity',
                  style: TextStyle(
                    color: VividColors.textMuted.withOpacity(0.7),
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

  Widget _buildActivityChart(Map<String, int> messagesByDay) {
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
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
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
              const Text(
                'Message Volume (Last 7 Days)',
                style: TextStyle(
                  color: VividColors.textPrimary,
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
                            color: VividColors.textMuted.withOpacity(0.7),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? color.withOpacity(0.5) : VividColors.tealBlue.withOpacity(0.2),
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
                  style: const TextStyle(
                    color: VividColors.textMuted,
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
                color: VividColors.textMuted.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}