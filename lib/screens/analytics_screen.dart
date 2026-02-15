import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isExporting = false;
  String _selectedType = 'conversations'; // 'conversations' or 'broadcasts'

  // Check which features are enabled
  bool get _conversationsEnabled => ClientConfig.conversationsPhone?.isNotEmpty == true;
  bool get _broadcastsEnabled => 
      ClientConfig.broadcastsWebhookUrl?.isNotEmpty == true || 
      ClientConfig.broadcastsPhone?.isNotEmpty == true;
  bool get _showToggle => _conversationsEnabled && _broadcastsEnabled;

  @override
  void initState() {
    super.initState();
    // Default to conversations if enabled, otherwise broadcasts
    if (!_conversationsEnabled && _broadcastsEnabled) {
      _selectedType = 'broadcasts';
    }
    Future.microtask(() {
      _fetchAnalytics();
    });
  }

  void _fetchAnalytics() {
    final provider = context.read<AnalyticsProvider>();
    provider.fetchAnalytics(type: _selectedType);
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
            onPressed: _fetchAnalytics,
            style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(AnalyticsData data) {
    return RefreshIndicator(
      onRefresh: () async => _fetchAnalytics(),
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
                // Header with Toggle and Export
                _buildHeader(data, isWide),
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

  Widget _buildHeader(AnalyticsData data, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Title with icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: _selectedType == 'conversations' 
                    ? VividColors.primaryGradient
                    : const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE040FB)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _selectedType == 'conversations' ? Icons.chat : Icons.campaign,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedType == 'conversations' ? 'Conversations' : 'Broadcasts'} Analytics',
                    style: const TextStyle(
                      color: VividColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedType == 'conversations' 
                        ? 'Customer chat statistics and activity'
                        : 'Broadcast campaign performance',
                    style: const TextStyle(color: VividColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Export Button
            _buildExportButton(data, isWide),
          ],
        ),
        
        // Analytics Type Toggle (only show if both features enabled)
        if (_showToggle) ...[
          const SizedBox(height: 20),
          _buildAnalyticsToggle(),
        ],
      ],
    );
  }

  Widget _buildAnalyticsToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(
            label: 'Conversations',
            icon: Icons.chat,
            isSelected: _selectedType == 'conversations',
            color: VividColors.cyan,
            onTap: () {
              if (_selectedType != 'conversations') {
                setState(() => _selectedType = 'conversations');
                _fetchAnalytics();
              }
            },
          ),
          const SizedBox(width: 4),
          _buildToggleOption(
            label: 'Broadcasts',
            icon: Icons.campaign,
            isSelected: _selectedType == 'broadcasts',
            color: const Color(0xFF9C27B0),
            onTap: () {
              if (_selectedType != 'broadcasts') {
                setState(() => _selectedType = 'broadcasts');
                _fetchAnalytics();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(colors: [color, color.withOpacity(0.7)])
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : VividColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : VividColors.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(AnalyticsData data, bool isWide) {
    return PopupMenuButton<String>(
      onSelected: (format) => _handleExport(format, data),
      enabled: !_isExporting,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: VividColors.navy,
      itemBuilder: (context) => [
        _buildExportMenuItem('csv', 'CSV', Icons.table_chart, 'Spreadsheet format'),
        _buildExportMenuItem('excel', 'Excel', Icons.grid_on, 'Formatted workbook'),
        _buildExportMenuItem('pdf', 'PDF', Icons.picture_as_pdf, 'Professional report'),
        const PopupMenuDivider(),
        _buildExportMenuItem('all', 'Export All', Icons.download, 'All formats'),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: VividColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: VividColors.brightBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isExporting)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.download, color: Colors.white, size: 18),
            if (isWide) ...[
              const SizedBox(width: 8),
              Text(_isExporting ? 'Exporting...' : 'Export', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildExportMenuItem(String value, String title, IconData icon, String subtitle) {
    final colors = {'csv': Colors.green, 'excel': const Color(0xFF217346), 'pdf': Colors.red, 'all': VividColors.cyan};
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colors[value]!.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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

  Future<void> _handleExport(String format, AnalyticsData data) async {
    setState(() => _isExporting = true);

    try {
      final dailyActivity = data.last7Days;
      final topCustomers = data.topCustomers;

      switch (format) {
        case 'csv':
          AnalyticsExporter.exportAnalyticsToCsv(data: data, dailyActivity: dailyActivity, topCustomers: topCustomers, analyticsType: _selectedType);
          _showExportSuccess('CSV');
          break;
        case 'excel':
          AnalyticsExporter.exportAnalyticsToExcel(data: data, dailyActivity: dailyActivity, topCustomers: topCustomers, analyticsType: _selectedType);
          _showExportSuccess('Excel');
          break;
        case 'pdf':
          await AnalyticsExporter.exportAnalyticsToPdf(data: data, dailyActivity: dailyActivity, topCustomers: topCustomers, analyticsType: _selectedType);
          _showExportSuccess('PDF');
          break;
        case 'all':
          AnalyticsExporter.exportAnalyticsToCsv(data: data, dailyActivity: dailyActivity, topCustomers: topCustomers, analyticsType: _selectedType);
          await Future.delayed(const Duration(milliseconds: 300));
          AnalyticsExporter.exportAnalyticsToExcel(data: data, dailyActivity: dailyActivity, topCustomers: topCustomers, analyticsType: _selectedType);
          await Future.delayed(const Duration(milliseconds: 300));
          await AnalyticsExporter.exportAnalyticsToPdf(data: data, dailyActivity: dailyActivity, topCustomers: topCustomers, analyticsType: _selectedType);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text('$format exported successfully'),
        ]),
        backgroundColor: VividColors.statusSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showExportError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Export failed: $error')),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildMainStats(AnalyticsData data, bool isWide, bool isMedium) {
    final isConversations = _selectedType == 'conversations';
    final hasAi = ClientConfig.currentClient?.hasAiConversations ?? false;

    final cards = <_StatCard>[
      _StatCard(
        title: isConversations ? 'Total Messages' : 'Total Recipients',
        value: data.totalMessages.toString(),
        icon: isConversations ? Icons.chat : Icons.people,
        color: VividColors.brightBlue,
      ),
      // Only show AI Responses card for AI-enabled clients
      if (isConversations && hasAi)
        _StatCard(
          title: 'AI Responses',
          value: data.aiResponses.toString(),
          icon: Icons.smart_toy,
          color: VividColors.cyan,
        ),
      if (!isConversations) ...[
        _StatCard(
          title: 'Campaigns',
          value: data.aiResponses.toString(),
          icon: Icons.campaign,
          color: VividColors.cyan,
        ),
        _StatCard(
          title: 'Total Sent',
          value: data.totalSent.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Total Failed',
          value: data.totalFailed.toString(),
          icon: Icons.error_outline,
          color: Colors.red,
        ),
        _StatCard(
          title: 'Delivery Rate',
          value: '${data.deliveryRate.toStringAsFixed(1)}%',
          icon: Icons.done_all,
          color: Colors.blue,
        ),
      ],
      if (isConversations) ...[
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
      ],
    ];

    if (isWide) {
      return Row(
        children: cards.map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: card))).toList(),
      );
    } else if (isMedium) {
      return Column(
        children: [
          Row(children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]),
          const SizedBox(height: 16),
          if (cards.length > 2)
            Row(children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              if (cards.length > 3)
                Expanded(child: cards[3])
              else
                const Expanded(child: SizedBox()),
            ]),
        ],
      );
    } else {
      return Column(children: cards.map((card) => Padding(padding: const EdgeInsets.only(bottom: 12), child: card)).toList());
    }
  }

  Widget _buildTimeStats(AnalyticsData data, bool isWide, bool isMedium) {
    final label = _selectedType == 'conversations' ? 'Messages' : 'Recipients';
    final cards = [
      _TimeStatCard(title: 'Today', value: data.todayMessages.toString(), icon: Icons.today, gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)], label: label),
      _TimeStatCard(title: 'This Week', value: data.thisWeekMessages.toString(), icon: Icons.date_range, gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)], label: label),
      _TimeStatCard(title: 'This Month', value: data.thisMonthMessages.toString(), icon: Icons.calendar_month, gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)], label: label),
    ];

    if (isWide || isMedium) {
      return Row(children: cards.map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: card))).toList());
    } else {
      return Column(children: cards.map((card) => Padding(padding: const EdgeInsets.only(bottom: 12), child: card)).toList());
    }
  }

  Widget _buildActivityChart(AnalyticsData data) {
    final maxCount = data.last7Days.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);
    final color = _selectedType == 'conversations' ? VividColors.primaryGradient : const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE040FB)]);

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
          Row(
            children: [
              Icon(_selectedType == 'conversations' ? Icons.show_chart : Icons.bar_chart, color: _selectedType == 'conversations' ? VividColors.cyan : const Color(0xFF9C27B0), size: 20),
              const SizedBox(width: 10),
              Text(_selectedType == 'conversations' ? 'Last 7 Days Activity' : 'Last 7 Days Recipients', style: const TextStyle(color: VividColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 24),
          ...data.last7Days.map((day) {
            final percentage = maxCount > 0 ? day.count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(_formatDate(day.date), style: const TextStyle(color: VividColors.textMuted, fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 24, decoration: BoxDecoration(color: VividColors.deepBlue, borderRadius: BorderRadius.circular(6))),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(gradient: color, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: (_selectedType == 'conversations' ? VividColors.brightBlue : const Color(0xFF9C27B0)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 40, child: Text(day.count.toString(), style: const TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
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
          Row(
            children: [
              Icon(Icons.people, color: VividColors.cyan, size: 20),
              const SizedBox(width: 10),
              Text(_selectedType == 'conversations' ? 'Top Customers' : 'Top Campaigns', style: const TextStyle(color: VividColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          if (data.topCustomers.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No ${_selectedType == 'conversations' ? 'customers' : 'campaigns'} yet', style: const TextStyle(color: VividColors.textMuted))))
          else
            ...data.topCustomers.asMap().entries.map((entry) => _CustomerTile(rank: entry.key + 1, customer: entry.value, isBroadcasts: _selectedType == 'broadcasts')).toList(),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final bh = date.toUtc().add(const Duration(hours: 3));
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[bh.weekday - 1]}, ${months[bh.month - 1]} ${bh.day}';
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

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

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
                Text(title, style: const TextStyle(color: VividColors.textMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(color: VividColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
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
  final String label;

  const _TimeStatCard({required this.title, required this.value, required this.icon, required this.gradient, this.label = 'Messages'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final int rank;
  final TopCustomer customer;
  final bool isBroadcasts;

  const _CustomerTile({required this.rank, required this.customer, this.isBroadcasts = false});

  @override
  Widget build(BuildContext context) {
    final colors = [VividColors.cyan, VividColors.brightBlue, VividColors.tealBlue, const Color(0xFF9C27B0), const Color(0xFFFF9800)];
    final color = colors[(rank - 1) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: VividColors.deepBlue.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(rank.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.displayName, style: const TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                if (customer.name != null && !isBroadcasts) Text(customer.phone, style: const TextStyle(color: VividColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(customer.messageCount.toString(), style: const TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(isBroadcasts ? 'recipients' : 'messages', style: const TextStyle(color: VividColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}