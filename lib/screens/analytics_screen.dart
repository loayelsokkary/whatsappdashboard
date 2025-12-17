import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';
import '../theme/vivid_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AnalyticsProvider>().fetchAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();

    return Scaffold(
      backgroundColor: VividColors.darkNavy,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: VividColors.cyan))
          : provider.error != null
              ? _buildError(provider.error!)
              : provider.analytics == null
                  ? const Center(child: Text('No data', style: TextStyle(color: VividColors.textMuted)))
                  : _buildAnalytics(provider.analytics!),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: VividColors.statusUrgent),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: VividColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<AnalyticsProvider>().fetchAnalytics(),
            style: ElevatedButton.styleFrom(
              backgroundColor: VividColors.brightBlue,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(AnalyticsData data) {
    return RefreshIndicator(
      onRefresh: () => context.read<AnalyticsProvider>().fetchAnalytics(),
      color: VividColors.cyan,
      backgroundColor: VividColors.navy,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final isMedium = constraints.maxWidth > 500;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWide ? 32 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(
                        color: VividColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => context.read<AnalyticsProvider>().fetchAnalytics(),
                      icon: const Icon(Icons.refresh, color: VividColors.cyan),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Stats Cards
                _buildMainStats(data, isWide, isMedium),
                const SizedBox(height: 24),

                // Time-based Stats
                _buildTimeStats(data, isWide, isMedium),
                const SizedBox(height: 24),

                // Charts Row
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildActivityChart(data)),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildTopCustomers(data)),
                    ],
                  )
                else ...[
                  _buildActivityChart(data),
                  const SizedBox(height: 24),
                  _buildTopCustomers(data),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainStats(AnalyticsData data, bool isWide, bool isMedium) {
    final cards = [
      _StatCard(
        title: 'Total Messages',
        value: data.totalMessages.toString(),
        icon: Icons.chat,
        color: VividColors.brightBlue,
      ),
      _StatCard(
        title: 'AI Responses',
        value: data.aiResponses.toString(),
        icon: Icons.smart_toy,
        color: VividColors.cyan,
      ),
      _StatCard(
        title: 'Manager Responses',
        value: data.managerResponses.toString(),
        icon: Icons.support_agent,
        color: VividColors.tealBlue,
      ),
      _StatCard(
        title: 'Unique Customers',
        value: data.uniqueCustomers.toString(),
        icon: Icons.people,
        color: const Color(0xFFFF9800),
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((card) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: card,
        ))).toList(),
      );
    } else if (isMedium) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 16),
            Expanded(child: cards[3]),
          ]),
        ],
      );
    } else {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card,
        )).toList(),
      );
    }
  }

  Widget _buildTimeStats(AnalyticsData data, bool isWide, bool isMedium) {
    final cards = [
      _TimeStatCard(
        title: 'Today',
        value: data.todayMessages.toString(),
        icon: Icons.today,
        gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
      ),
      _TimeStatCard(
        title: 'This Week',
        value: data.thisWeekMessages.toString(),
        icon: Icons.date_range,
        gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      ),
      _TimeStatCard(
        title: 'This Month',
        value: data.thisMonthMessages.toString(),
        icon: Icons.calendar_month,
        gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      ),
    ];

    if (isWide || isMedium) {
      return Row(
        children: cards.map((card) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: card,
        ))).toList(),
      );
    } else {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card,
        )).toList(),
      );
    }
  }

  Widget _buildActivityChart(AnalyticsData data) {
    final maxCount = data.last7Days
        .map((d) => d.count)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 Days Activity',
            style: TextStyle(
              color: VividColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ...data.last7Days.map((day) {
            final percentage = maxCount > 0 ? day.count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatDate(day.date),
                      style: const TextStyle(
                        color: VividColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: VividColors.deepBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: VividColors.primaryGradient,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: VividColors.brightBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      day.count.toString(),
                      style: const TextStyle(
                        color: VividColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopCustomers(AnalyticsData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Customers',
            style: TextStyle(
              color: VividColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          if (data.topCustomers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No customers yet',
                  style: TextStyle(color: VividColors.textMuted),
                ),
              ),
            )
          else
            ...data.topCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;
              return _CustomerTile(
                rank: index + 1,
                customer: customer,
              );
            }).toList(),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

// ============================================
// STAT CARDS
// ============================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }
}

class _TimeStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const _TimeStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Messages',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final int rank;
  final TopCustomer customer;

  const _CustomerTile({required this.rank, required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = [
      VividColors.cyan,
      VividColors.brightBlue,
      VividColors.tealBlue,
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
    ];
    final color = colors[(rank - 1) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VividColors.deepBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Customer info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.displayName,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer.name != null)
                  Text(
                    customer.phone,
                    style: const TextStyle(
                      color: VividColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          // Message count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                customer.messageCount.toString(),
                style: const TextStyle(
                  color: VividColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text(
                'messages',
                style: TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}