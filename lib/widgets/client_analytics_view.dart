import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/admin_analytics_provider.dart';
import '../theme/vivid_theme.dart';

/// Analytics view for a specific client in the admin panel
class ClientAnalyticsView extends StatefulWidget {
  final Client client;

  const ClientAnalyticsView({super.key, required this.client});

  @override
  State<ClientAnalyticsView> createState() => _ClientAnalyticsViewState();
}

class _ClientAnalyticsViewState extends State<ClientAnalyticsView> {
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didUpdateWidget(ClientAnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.id != widget.client.id) {
      _loadAnalytics();
    }
  }

  void _loadAnalytics() {
    final provider = context.read<AdminAnalyticsProvider>();
    
    if (widget.client.hasFeature('conversations')) {
      provider.fetchConversationAnalytics(widget.client);
    } else if (widget.client.hasFeature('broadcasts')) {
      provider.fetchBroadcastAnalytics(widget.client);
    }
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
          // Header
          Container(
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
                    Icons.insights,
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
                        '${widget.client.name} Analytics',
                        style: const TextStyle(
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.client.hasFeature('conversations') 
                                      ? Icons.chat_bubble_outline 
                                      : Icons.campaign_outlined,
                                  size: 14,
                                  color: VividColors.cyan,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.client.hasFeature('conversations') 
                                      ? 'Conversations' 
                                      : 'Broadcasts',
                                  style: const TextStyle(
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
                            'Internal performance metrics',
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
          ),
          
          // Content
          Expanded(
            child: Consumer<AdminAnalyticsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: VividColors.cyan),
                        SizedBox(height: 16),
                        Text(
                          'Loading analytics...',
                          style: TextStyle(color: VividColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          style: const TextStyle(color: VividColors.textMuted),
                          textAlign: TextAlign.center,
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

                if (widget.client.hasFeature('conversations')) {
                  return _buildConversationAnalytics(provider);
                } else if (widget.client.hasFeature('broadcasts')) {
                  return _buildBroadcastAnalytics(provider);
                } else {
                  return const Center(
                    child: Text(
                      'No analytics available for this client type',
                      style: TextStyle(color: VividColors.textMuted),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationAnalytics(AdminAnalyticsProvider provider) {
    final analytics = provider.getConversationAnalytics(widget.client.id);
    
    if (analytics == null) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: VividColors.textMuted),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: Column(
        children: [
          // Main metrics row
          Row(
            children: [
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.smart_toy,
                  label: 'AI Messages',
                  value: analytics.totalAiMessages.toString(),
                  color: VividColors.cyan,
                  description: 'Total responses by AI',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.support_agent,
                  label: 'Manager Messages',
                  value: analytics.totalManagerMessages.toString(),
                  color: VividColors.brightBlue,
                  description: 'Human interventions',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.auto_awesome,
                  label: 'Automation Rate',
                  value: '${analytics.automationRate.toStringAsFixed(1)}%',
                  color: _getAutomationRateColor(analytics.automationRate),
                  description: _getAutomationRateLabel(analytics.automationRate),
                  isHighlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Secondary metrics row
          Row(
            children: [
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.timer,
                  label: 'Avg Response Time',
                  value: _formatDuration(analytics.avgResponseTime),
                  color: Colors.orange,
                  description: analytics.avgResponseTime == Duration.zero 
                      ? 'Enable timestamp tracking in n8n'
                      : 'Average AI response speed',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.calendar_today,
                  label: 'Successful Bookings',
                  value: analytics.successfulBookings.toString(),
                  color: Colors.green,
                  description: 'Detected booking confirmations',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.access_time,
                  label: 'Last Activity',
                  value: _formatLastActivity(analytics.lastActivity),
                  color: VividColors.textMuted,
                  description: 'Most recent conversation',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Universal metrics row
          Row(
            children: [
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.people,
                  label: 'Unique Customers',
                  value: analytics.uniqueCustomers.toString(),
                  color: Colors.purple,
                  description: 'Total people reached',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.chat_bubble_outline,
                  label: 'Total Conversations',
                  value: analytics.totalConversations.toString(),
                  color: VividColors.cyan,
                  description: 'All-time conversations',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.event,
                  label: 'Client Since',
                  value: '${analytics.daysSinceOnboarding}d',
                  color: Colors.teal,
                  description: 'Days since onboarding',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Automation breakdown
          _AutomationBreakdown(
            aiMessages: analytics.totalAiMessages,
            managerMessages: analytics.totalManagerMessages,
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastAnalytics(AdminAnalyticsProvider provider) {
    final analytics = provider.getBroadcastAnalytics(widget.client.id);
    
    if (analytics == null) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: VividColors.textMuted),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: Column(
        children: [
          // Main metrics row
          Row(
            children: [
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.campaign,
                  label: 'Broadcasts Sent',
                  value: analytics.totalBroadcastsSent.toString(),
                  color: VividColors.brightBlue,
                  description: 'Total campaigns',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.people,
                  label: 'Recipients Reached',
                  value: _formatNumber(analytics.totalRecipientsReached),
                  color: VividColors.cyan,
                  description: 'Total people messaged',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.access_time,
                  label: 'Last Activity',
                  value: _formatLastActivity(analytics.lastActivity),
                  color: VividColors.textMuted,
                  description: 'Most recent broadcast',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Rates row
          Row(
            children: [
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.done_all,
                  label: 'Delivery Rate',
                  value: '${analytics.deliveryRate.toStringAsFixed(1)}%',
                  color: Colors.green,
                  description: 'Successfully delivered',
                  isHighlight: analytics.deliveryRate >= 90,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.visibility,
                  label: 'Read Rate',
                  value: '${analytics.readRate.toStringAsFixed(1)}%',
                  color: Colors.blue,
                  description: 'Opened by recipients',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.error_outline,
                  label: 'Failed Rate',
                  value: '${analytics.failedRate.toStringAsFixed(1)}%',
                  color: analytics.failedRate > 5 ? Colors.red : Colors.orange,
                  description: 'Failed to deliver',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Universal metrics row
          Row(
            children: [
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.group,
                  label: 'Avg Campaign Size',
                  value: analytics.avgCampaignSize.toStringAsFixed(0),
                  color: Colors.purple,
                  description: 'Recipients per campaign',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _LargeMetricCard(
                  icon: Icons.event,
                  label: 'Client Since',
                  value: '${analytics.daysSinceOnboarding}d',
                  color: Colors.teal,
                  description: 'Days since onboarding',
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(child: SizedBox()), // Empty space for alignment
            ],
          ),
          const SizedBox(height: 32),
          // Delivery breakdown
          _DeliveryBreakdown(
            deliveryRate: analytics.deliveryRate,
            readRate: analytics.readRate,
            failedRate: analytics.failedRate,
          ),
        ],
      ),
    );
  }

  Color _getAutomationRateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getAutomationRateLabel(double rate) {
    if (rate >= 80) return 'Excellent performance';
    if (rate >= 60) return 'Good performance';
    if (rate >= 40) return 'Needs improvement';
    return 'Low automation';
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return 'N/A'; // No timestamp data yet
    } else if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
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
// LARGE METRIC CARD
// ============================================

class _LargeMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? description;
  final bool isHighlight;

  const _LargeMetricCard({
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
        boxShadow: isHighlight ? [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ] : null,
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

// ============================================
// AUTOMATION BREAKDOWN (for conversation clients)
// ============================================

class _AutomationBreakdown extends StatelessWidget {
  final int aiMessages;
  final int managerMessages;

  const _AutomationBreakdown({
    required this.aiMessages,
    required this.managerMessages,
  });

  @override
  Widget build(BuildContext context) {
    final total = aiMessages + managerMessages;
    final aiPercent = total > 0 ? aiMessages / total : 0.0;
    final managerPercent = total > 0 ? managerMessages / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(28),
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
                child: const Icon(Icons.pie_chart, color: VividColors.brightBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Response Breakdown',
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  if (aiPercent > 0)
                    Expanded(
                      flex: (aiPercent * 100).round(),
                      child: Container(
                        color: VividColors.cyan,
                        alignment: Alignment.center,
                        child: aiPercent > 0.1
                            ? Text(
                                '${(aiPercent * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: VividColors.darkNavy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  if (managerPercent > 0)
                    Expanded(
                      flex: (managerPercent * 100).round(),
                      child: Container(
                        color: VividColors.brightBlue,
                        alignment: Alignment.center,
                        child: managerPercent > 0.1
                            ? Text(
                                '${(managerPercent * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            children: [
              Expanded(child: _LegendItem(color: VividColors.cyan, label: 'AI Handled', value: aiMessages)),
              const SizedBox(width: 32),
              Expanded(child: _LegendItem(color: VividColors.brightBlue, label: 'Manager Handled', value: managerMessages)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// DELIVERY BREAKDOWN (for broadcast clients)
// ============================================

class _DeliveryBreakdown extends StatelessWidget {
  final double deliveryRate;
  final double readRate;
  final double failedRate;

  const _DeliveryBreakdown({
    required this.deliveryRate,
    required this.readRate,
    required this.failedRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
                child: const Icon(Icons.bar_chart, color: VividColors.brightBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delivery Breakdown',
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _RateBar(label: 'Delivered', rate: deliveryRate, color: Colors.green),
          const SizedBox(height: 16),
          _RateBar(label: 'Read', rate: readRate, color: Colors.blue),
          const SizedBox(height: 16),
          _RateBar(label: 'Failed', rate: failedRate, color: Colors.red),
        ],
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  final String label;
  final double rate;
  final Color color;

  const _RateBar({
    required this.label,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: VividColors.textMuted,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: VividColors.deepBlue,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 55,
          child: Text(
            '${rate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: VividColors.textMuted.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}