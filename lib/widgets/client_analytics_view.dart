import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/admin_analytics_provider.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';
import '../utils/toast_service.dart';

// Reuse the DateRangeFilter from analytics_screen.dart concept
enum _DateFilter {
  last30Days('Last 30 Days'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  thisMonth('This Month'),
  allTime('All Time'),
  custom('Custom Range');

  final String label;
  const _DateFilter(this.label);

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case _DateFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _DateFilter.yesterday:
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
      case _DateFilter.last7Days:
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
      case _DateFilter.last30Days:
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 30));
      case _DateFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _DateFilter.allTime:
        return DateTime(2020, 1, 1);
      case _DateFilter.custom:
        return null;
    }
  }

  DateTime? get endDate {
    if (this == _DateFilter.yesterday) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime.now();
  }
}

// Tab definition
class _TabDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _TabDef(this.key, this.label, this.icon, this.color);
}

final _fmt = NumberFormat('#,###');

/// Analytics view for a specific client in the admin panel
class ClientAnalyticsView extends StatefulWidget {
  final Client client;

  const ClientAnalyticsView({super.key, required this.client});

  @override
  State<ClientAnalyticsView> createState() => _ClientAnalyticsViewState();
}

class _ClientAnalyticsViewState extends State<ClientAnalyticsView>
    with TickerProviderStateMixin {
  _DateFilter _dateFilter = _DateFilter.last30Days;
  DateTimeRange? _customRange;
  late TabController _tabController;
  late List<_TabDef> _tabs;

  bool _isLoading = false;
  bool _hasLabelColumn = false;

  // Per-section data
  ClientOverviewMetrics? _overview;
  ConversationMetrics? _conversations;
  BroadcastMetrics? _broadcasts;
  ManagerChatMetrics? _managerChat;
  LabelMetrics? _labels;
  PredictiveMetrics? _predictions;

  Client get client => widget.client;

  @override
  void initState() {
    super.initState();
    _buildTabs();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _detectCapabilitiesAndLoad();
  }

  @override
  void didUpdateWidget(ClientAnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.id != client.id) {
      _overview = null;
      _conversations = null;
      _broadcasts = null;
      _managerChat = null;
      _labels = null;
      _predictions = null;
      _buildTabs();
      _tabController.dispose();
      _tabController = TabController(length: _tabs.length, vsync: this);
      _detectCapabilitiesAndLoad();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _buildTabs() {
    _tabs = [
      const _TabDef('overview', 'Overview', Icons.dashboard, VividColors.cyan),
    ];
    if (client.hasFeature('conversations')) {
      _tabs.add(const _TabDef(
          'conversations', 'Conversations', Icons.forum, VividColors.cyan));
    }
    if (client.hasFeature('broadcasts')) {
      _tabs.add(
          const _TabDef('broadcasts', 'Broadcasts', Icons.campaign, Colors.orange));
    }
    if (client.hasFeature('manager_chat')) {
      _tabs.add(const _TabDef(
          'manager_chat', 'Manager Chat', Icons.smart_toy, Colors.purple));
    }
    if (client.hasFeature('labels') || _hasLabelColumn) {
      _tabs.add(const _TabDef('labels', 'Labels', Icons.label, Colors.amber));
    }
    if (client.hasFeature('predictive_intelligence') &&
        client.customerPredictionsTable != null) {
      _tabs.add(const _TabDef(
          'predictive', 'Predictions', Icons.auto_graph, Colors.teal));
    }
    _tabs.add(
        const _TabDef('insights', 'Insights', Icons.lightbulb, Colors.amber));
  }

  Future<void> _detectCapabilitiesAndLoad() async {
    if (client.messagesTable != null) {
      try {
        await SupabaseService.adminClient
            .from(client.messagesTable!)
            .select('label')
            .limit(1);
        _hasLabelColumn = true;
      } catch (_) {
        _hasLabelColumn = false;
      }
    }
    // Rebuild tabs now that we know about label column
    final oldLen = _tabs.length;
    _buildTabs();
    if (_tabs.length != oldLen) {
      _tabController.dispose();
      _tabController = TabController(length: _tabs.length, vsync: this);
    }
    if (mounted) setState(() {});
    _loadAllSections();
  }

  DateTime? get _start {
    if (_dateFilter == _DateFilter.custom) {
      return _customRange?.start;
    }
    return _dateFilter.startDate;
  }

  DateTime? get _end {
    if (_dateFilter == _DateFilter.custom) {
      return _customRange?.end;
    }
    return _dateFilter.endDate;
  }

  Future<void> _loadAllSections() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final provider = context.read<AdminAnalyticsProvider>();
    final start = _start;
    final end = _end;

    try {
      // Load overview always
      final overviewFuture =
          provider.fetchClientOverview(client, start: start, end: end);

      // Load feature-specific sections in parallel
      Future<ConversationMetrics>? convFuture;
      Future<BroadcastMetrics>? bcastFuture;
      Future<ManagerChatMetrics>? mchatFuture;
      Future<LabelMetrics?>? labelFuture;
      Future<PredictiveMetrics?>? predFuture;

      if (client.hasFeature('conversations')) {
        convFuture =
            provider.fetchConversationMetrics(client, start: start, end: end);
      }
      if (client.hasFeature('broadcasts')) {
        bcastFuture =
            provider.fetchBroadcastMetrics(client, start: start, end: end);
      }
      if (client.hasFeature('manager_chat')) {
        mchatFuture =
            provider.fetchManagerChatMetrics(client, start: start, end: end);
      }
      if (_hasLabelColumn || client.hasFeature('labels')) {
        labelFuture =
            provider.fetchLabelMetrics(client, start: start, end: end);
      }
      if (client.hasFeature('predictive_intelligence') &&
          client.customerPredictionsTable != null) {
        predFuture = provider.fetchPredictiveMetrics(client);
      }

      _overview = await overviewFuture;
      if (convFuture != null) _conversations = await convFuture;
      if (bcastFuture != null) _broadcasts = await bcastFuture;
      if (mchatFuture != null) _managerChat = await mchatFuture;
      if (labelFuture != null) _labels = await labelFuture;
      if (predFuture != null) _predictions = await predFuture;
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onDateFilterChanged(_DateFilter filter) async {
    if (filter == _DateFilter.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customRange,
      );
      if (picked == null) return;
      _customRange = picked;
    }
    setState(() => _dateFilter = filter);
    _loadAllSections();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [vc.background, vc.surface, vc.surfaceAlt.withOpacity(0.5)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(vc),
          _buildTabBar(vc),
          Expanded(
            child: _isLoading && _overview == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) => _buildTabContent(tab)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VividColorScheme vc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: VividColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: VividColors.cyan.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.insights, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${client.name} Analytics',
                      style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: VividColors.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${client.enabledFeatures.length} features enabled',
                            style: const TextStyle(
                              color: VividColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildDateFilterDropdown(vc),
              const SizedBox(width: 12),
              _buildExportButton(vc),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterDropdown(VividColorScheme vc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_DateFilter>(
          value: _dateFilter,
          dropdownColor: vc.surface,
          style: TextStyle(color: vc.textPrimary, fontSize: 13),
          icon: Icon(Icons.arrow_drop_down, color: vc.textMuted, size: 20),
          items: _DateFilter.values
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.label),
                  ))
              .toList(),
          onChanged: (f) {
            if (f != null) _onDateFilterChanged(f);
          },
        ),
      ),
    );
  }

  Widget _buildExportButton(VividColorScheme vc) {
    return PopupMenuButton<String>(
      onSelected: (format) async {
        try {
          if (format == 'pdf') {
            await AnalyticsExporter.exportClientReportPdf(
              client: client,
              overview: _overview,
              conversations: _conversations,
              broadcasts: _broadcasts,
              managerChat: _managerChat,
              labels: _labels,
              predictions: _predictions,
            );
          }
          if (mounted) {
            VividToast.show(context,
                message: '${format.toUpperCase()} exported',
                type: ToastType.success);
          }
        } catch (e) {
          if (mounted) {
            VividToast.show(context,
                message: 'Export failed: $e', type: ToastType.error);
          }
        }
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: vc.surface,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
            const SizedBox(width: 10),
            Text('Export PDF', style: TextStyle(color: vc.textPrimary)),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: VividColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: VividColors.brightBlue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, color: vc.background, size: 18),
            const SizedBox(width: 6),
            Text('Export',
                style: TextStyle(
                    color: vc.background,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            Icon(Icons.arrow_drop_down, color: vc.background, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(VividColorScheme vc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: vc.border, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: VividColors.cyan,
        indicatorWeight: 3,
        labelColor: VividColors.cyan,
        unselectedLabelColor: vc.textMuted,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: _tabs
            .map((t) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 18, color: t.color),
                      const SizedBox(width: 8),
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTabContent(_TabDef tab) {
    switch (tab.key) {
      case 'overview':
        return _buildOverviewSection();
      case 'conversations':
        return _buildConversationsSection();
      case 'broadcasts':
        return _buildBroadcastsSection();
      case 'manager_chat':
        return _buildManagerChatSection();
      case 'labels':
        return _buildLabelsSection();
      case 'predictive':
        return _buildPredictiveSection();
      case 'insights':
        return _buildInsightsSection();
      default:
        return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // OVERVIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildOverviewSection() {
    final vc = context.vividColors;
    if (_overview == null) return _emptyState(vc, 'Loading overview...');
    final o = _overview!;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final pad = isMobile ? 16.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          children: [
            _cardRow([
              _MetricCard(
                  icon: Icons.calendar_today,
                  label: 'Days Active',
                  value: _fmt.format(o.daysActive),
                  color: Colors.teal,
                  description: 'Since onboarding'),
              _MetricCard(
                  icon: Icons.extension,
                  label: 'Enabled Features',
                  value: '${o.enabledFeatureCount}',
                  color: VividColors.brightBlue,
                  description: client.enabledFeatures.join(', ')),
              _MetricCard(
                  icon: Icons.message,
                  label: 'Total Messages',
                  value: _fmt.format(o.totalMessages),
                  color: VividColors.cyan,
                  description: 'All conversations'),
            ], isMobile),
            const SizedBox(height: 20),
            _cardRow([
              _MetricCard(
                  icon: Icons.people,
                  label: 'Unique Customers',
                  value: _fmt.format(o.uniqueCustomers),
                  color: Colors.purple,
                  description: 'Total people reached'),
              if (o.totalBroadcasts > 0)
                _MetricCard(
                    icon: Icons.campaign,
                    label: 'Total Broadcasts',
                    value: _fmt.format(o.totalBroadcasts),
                    color: Colors.orange,
                    description: 'Campaigns sent'),
              if (o.totalManagerQueries > 0)
                _MetricCard(
                    icon: Icons.smart_toy,
                    label: 'Manager Queries',
                    value: _fmt.format(o.totalManagerQueries),
                    color: Colors.purple,
                    description: 'AI assistant usage'),
            ], isMobile),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONVERSATIONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildConversationsSection() {
    final vc = context.vividColors;
    if (_conversations == null) {
      return _emptyState(vc, 'No conversation data yet');
    }
    final c = _conversations!;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final pad = isMobile ? 16.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Key metrics
            _sectionHeader(vc, 'Key Metrics', Icons.forum, VividColors.cyan),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                  icon: Icons.call_received,
                  label: 'Inbound',
                  value: _fmt.format(c.inboundMessages),
                  color: VividColors.cyan,
                  description: 'Messages received from customers'),
              _MetricCard(
                  icon: Icons.call_made,
                  label: 'Outbound',
                  value: _fmt.format(c.outboundMessages),
                  color: VividColors.brightBlue,
                  description: 'Replies sent (AI + human)'),
              _MetricCard(
                  icon: Icons.people,
                  label: 'Unique Customers',
                  value: _fmt.format(c.uniqueCustomers),
                  color: Colors.blueGrey,
                  description: 'Distinct phone numbers'),
            ], isMobile),
            const SizedBox(height: 12),
            _cardRow([
              _MetricCard(
                  icon: Icons.person_add,
                  label: 'New This Month',
                  value: _fmt.format(c.newCustomersThisMonth),
                  color: Colors.teal,
                  description: 'First-time customers this month'),
              _MetricCard(
                  icon: Icons.replay,
                  label: 'Returning',
                  value: _fmt.format(c.returningCustomers),
                  color: Colors.blueGrey,
                  description: 'Messaged more than once'),
            ], isMobile),

            // Row 2: AI Performance
            const SizedBox(height: 32),
            _sectionHeader(
                vc, 'AI Performance', Icons.auto_awesome, VividColors.cyan),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                icon: Icons.auto_awesome,
                label: 'Automation Rate',
                value: '${c.automationRate.toStringAsFixed(1)}%',
                color: _automationColor(c.automationRate),
                description: _automationLabel(c.automationRate),
                isHighlight: true,
              ),
              _MetricCard(
                  icon: Icons.smart_toy,
                  label: 'AI Messages',
                  value: _fmt.format(c.aiMessages),
                  color: VividColors.cyan,
                  description: 'Responses generated by AI'),
              _MetricCard(
                  icon: Icons.support_agent,
                  label: 'Human Messages',
                  value: _fmt.format(c.humanMessages),
                  color: VividColors.brightBlue,
                  description: 'Responses by team members'),
            ], isMobile),
            const SizedBox(height: 12),
            if (c.handoffCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MetricCard(
                    icon: Icons.swap_horiz,
                    label: 'AI → Human Handoffs',
                    value: _fmt.format(c.handoffCount),
                    color: Colors.orange,
                    description: 'Conversations requiring human intervention'),
              ),
            _AutomationBar(
              aiMessages: c.aiMessages,
              humanMessages: c.humanMessages,
              handoffs: c.handoffCount,
            ),

            // Row 3: Response Time
            if (c.hasTimestampColumns) ...[
              const SizedBox(height: 32),
              _sectionHeader(
                  vc, 'Response Time', Icons.timer, Colors.orange),
              const SizedBox(height: 16),
              _MetricCard(
                icon: Icons.timer,
                label: 'Avg First Response',
                value: _fmtDuration(c.avgFirstResponseTime),
                color: _responseTimeColor(c.avgFirstResponseTime),
                description: 'Time for first AI/human reply',
              ),
              if (c.perAgentResponseTime.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAgentResponseTable(vc, c.perAgentResponseTime),
              ],
            ],

            // Row 4: Activity Patterns
            const SizedBox(height: 32),
            _sectionHeader(
                vc, 'Activity Patterns', Icons.schedule, Colors.teal),
            const SizedBox(height: 16),
            if (c.messagesByHour.isNotEmpty)
              _HourlyChart(
                  data: c.messagesByHour,
                  title: 'Messages by Hour',
                  color: VividColors.cyan),
            if (c.messagesByDayOfWeek.isNotEmpty) ...[
              const SizedBox(height: 20),
              _DayOfWeekChart(
                  data: c.messagesByDayOfWeek, color: VividColors.brightBlue),
            ],
            if (c.dailyVolume.isNotEmpty) ...[
              const SizedBox(height: 20),
              _DailyVolumeChart(data: c.dailyVolume, color: VividColors.cyan),
            ],

            // Row 5: Message Types
            if (c.hasMediaColumns) ...[
              const SizedBox(height: 32),
              _sectionHeader(
                  vc, 'Message Types', Icons.attach_file, Colors.purple),
              const SizedBox(height: 16),
              _StackedBar(segments: [
                _BarSegment('Text', c.textMessages, VividColors.cyan),
                _BarSegment('Voice', c.voiceMessages, Colors.orange),
                _BarSegment('Media', c.mediaMessages, Colors.purple),
              ]),
            ],

            // Row 6: Team Performance
            if (c.hasSentByData && c.agentPerformance.isNotEmpty) ...[
              const SizedBox(height: 32),
              _sectionHeader(
                  vc, 'Team Performance', Icons.group, VividColors.brightBlue),
              const SizedBox(height: 16),
              _buildAgentTable(vc, c.agentPerformance),
            ],

            // Row 7: Customer Insights
            const SizedBox(height: 32),
            _sectionHeader(
                vc, 'Customer Insights', Icons.person_search, Colors.purple),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                  icon: Icons.timelapse,
                  label: 'Avg Lifetime',
                  value: '${c.avgCustomerLifetimeDays.toStringAsFixed(0)}d',
                  color: Colors.teal,
                  description: 'Average customer engagement span'),
              _MetricCard(
                  icon: Icons.person_off,
                  label: 'Single-Message',
                  value: _fmt.format(c.singleMessageCustomers),
                  color: Colors.red,
                  description: 'Sent only 1 message'),
            ], isMobile),
            if (c.topCustomers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTopCustomersTable(vc, c.topCustomers),
            ],
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // BROADCASTS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBroadcastsSection() {
    final vc = context.vividColors;
    if (_broadcasts == null) {
      return _emptyState(vc, 'No broadcast data yet');
    }
    final b = _broadcasts!;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final pad = isMobile ? 16.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Key Metrics
            _sectionHeader(
                vc, 'Campaign Metrics', Icons.campaign, Colors.orange),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                  icon: Icons.campaign,
                  label: 'Total Campaigns',
                  value: _fmt.format(b.totalCampaigns),
                  color: Colors.blueGrey,
                  description: 'Broadcast campaigns sent'),
              _MetricCard(
                  icon: Icons.people,
                  label: 'Recipients Reached',
                  value: _fmt.format(b.totalRecipientsReached),
                  color: VividColors.cyan,
                  description: 'Total recipients across all campaigns'),
              _MetricCard(
                  icon: Icons.check_circle,
                  label: 'Delivery Rate',
                  value: '${b.deliveryRate.toStringAsFixed(1)}%',
                  color: Colors.teal,
                  description: 'Successfully delivered messages',
                  isHighlight: true),
            ], isMobile),
            const SizedBox(height: 12),
            _cardRow([
              _MetricCard(
                  icon: Icons.error_outline,
                  label: 'Fail Rate',
                  value: '${b.failRate.toStringAsFixed(1)}%',
                  color: b.failRate > 5 ? Colors.red : Colors.blueGrey,
                  description: 'Messages that failed to deliver'),
              _MetricCard(
                  icon: Icons.group,
                  label: 'Avg Campaign Size',
                  value: b.avgCampaignSize.toStringAsFixed(0),
                  color: Colors.blueGrey,
                  description: 'Average recipients per campaign'),
            ], isMobile),

            // Row 2: ROI
            if (b.broadcastDrivenConversations > 0 ||
                b.totalOfferValue > 0) ...[
              const SizedBox(height: 32),
              _sectionHeader(vc, 'ROI & Impact', Icons.trending_up,
                  Colors.green),
              const SizedBox(height: 16),
              _cardRow([
                if (b.totalOfferValue > 0)
                  _MetricCard(
                      icon: Icons.attach_money,
                      label: 'Total Offer Value',
                      value: '${_fmt.format(b.totalOfferValue.toInt())} BHD',
                      color: Colors.green),
                _MetricCard(
                    icon: Icons.forum,
                    label: 'Broadcast-Driven Convos',
                    value: _fmt.format(b.broadcastDrivenConversations),
                    color: VividColors.cyan,
                    description: 'Conversations within 48h of broadcast',
                    isHighlight: true),
              ], isMobile),
            ],

            // Row 3: Delivery Breakdown
            const SizedBox(height: 32),
            _sectionHeader(vc, 'Delivery Breakdown', Icons.bar_chart,
                VividColors.brightBlue),
            const SizedBox(height: 16),
            _StackedBar(segments: [
              _BarSegment('Accepted', b.acceptedCount, Colors.blue),
              _BarSegment('Delivered', b.deliveredCount, Colors.green),
              _BarSegment('Sent', b.sentCount, Colors.orange),
              _BarSegment('Failed', b.failedCount, Colors.red),
            ]),

            // Row 4: Campaign List
            if (b.campaigns.isNotEmpty) ...[
              const SizedBox(height: 32),
              _sectionHeader(vc, 'Campaign History', Icons.history,
                  Colors.orange),
              const SizedBox(height: 16),
              _buildCampaignTable(vc, b.campaigns),
            ],

            // Row 5: Audience
            const SizedBox(height: 32),
            _sectionHeader(
                vc, 'Audience Insights', Icons.people_alt, Colors.purple),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                  icon: Icons.repeat,
                  label: 'Repeat Recipients',
                  value: _fmt.format(b.repeatRecipients),
                  color: Colors.teal,
                  description: 'People who received 2+ campaigns'),
              _MetricCard(
                  icon: Icons.person,
                  label: 'Unique Reach',
                  value: _fmt.format(b.uniqueReach),
                  color: Colors.blueGrey,
                  description: 'Distinct phone numbers targeted'),
              _MetricCard(
                  icon: Icons.block,
                  label: 'Unreachable',
                  value: _fmt.format(b.unreachableCount),
                  color: Colors.red,
                  description: 'Failed on every campaign attempt'),
            ], isMobile),
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANAGER CHAT
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildManagerChatSection() {
    final vc = context.vividColors;
    if (_managerChat == null) {
      return _emptyState(vc, 'No manager chat data yet');
    }
    final m = _managerChat!;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final pad = isMobile ? 16.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                vc, 'AI Assistant Usage', Icons.smart_toy, Colors.purple),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                  icon: Icons.question_answer,
                  label: 'Total Queries',
                  value: _fmt.format(m.totalQueries),
                  color: Colors.blueGrey,
                  description: 'Questions asked to the AI assistant',
                  isHighlight: true),
              _MetricCard(
                  icon: Icons.people,
                  label: 'Unique Users',
                  value: _fmt.format(m.uniqueUsers),
                  color: VividColors.brightBlue,
                  description: 'Team members who used the assistant'),
            ], isMobile),
            if (m.perUserBreakdown.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionHeader(
                  vc, 'Per-User Breakdown', Icons.person, Colors.purple),
              const SizedBox(height: 12),
              _buildUserQueryTable(vc, m.perUserBreakdown),
            ],
            if (m.usageByHour.isNotEmpty) ...[
              const SizedBox(height: 24),
              _HourlyChart(
                  data: m.usageByHour,
                  title: 'Queries by Hour',
                  color: Colors.purple),
            ],
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // LABELS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLabelsSection() {
    final vc = context.vividColors;
    if (_labels == null || _labels!.labelDistribution.isEmpty) {
      return _emptyState(vc, 'No label data available for this client');
    }
    final l = _labels!;
    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth < 600 ? 16.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                vc, 'Label Distribution', Icons.label, Colors.amber),
            const SizedBox(height: 4),
            Text('Total messages tagged with each label (includes repeat tags per customer)',
                style: TextStyle(color: vc.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            ...l.labelDistribution.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HorizontalBar(
                    label: e.key,
                    value: e.value,
                    maxValue: l.labelDistribution.values
                        .fold(0, (a, b) => a > b ? a : b),
                    color: _labelColor(e.key),
                  ),
                )),
            if (l.labelByUniqueCustomer.isNotEmpty) ...[
              const SizedBox(height: 32),
              _sectionHeader(vc, 'Unique Customers per Label',
                  Icons.people_alt, Colors.teal),
              const SizedBox(height: 4),
              Text('How many distinct customers reached each stage (deduplicated by phone number)',
                  style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              ...l.labelByUniqueCustomer.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HorizontalBar(
                      label: e.key,
                      value: e.value,
                      maxValue: l.labelByUniqueCustomer.values
                          .fold(0, (a, b) => a > b ? a : b),
                      color: _labelColor(e.key),
                    ),
                  )),
            ],
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // PREDICTIVE INTELLIGENCE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPredictiveSection() {
    final vc = context.vividColors;
    if (_predictions == null) {
      return _emptyState(
          vc, 'Predictions not configured — enable predictive intelligence');
    }
    final p = _predictions!;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final pad = isMobile ? 16.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(vc, 'Customer Categories', Icons.auto_graph,
                Colors.teal),
            const SizedBox(height: 16),
            if (p.categoryDistribution.isNotEmpty)
              ...p.categoryDistribution.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HorizontalBar(
                      label: e.key,
                      value: e.value,
                      maxValue: p.totalCustomers > 0
                          ? p.totalCustomers
                          : p.categoryDistribution.values
                              .fold(0, (a, b) => a > b ? a : b),
                      color: _categoryColor(e.key),
                    ),
                  )),
            const SizedBox(height: 24),
            _sectionHeader(
                vc, 'Key Metrics', Icons.analytics, Colors.teal),
            const SizedBox(height: 16),
            _cardRow([
              _MetricCard(
                  icon: Icons.verified,
                  label: 'Retention Rate',
                  value: '${p.retentionRate.toStringAsFixed(1)}%',
                  color: Colors.teal,
                  description: 'Customers who returned after first visit',
                  isHighlight: true),
              _MetricCard(
                  icon: Icons.warning,
                  label: 'At Risk',
                  value: _fmt.format(p.atRiskCount),
                  color: Colors.orange,
                  description: 'Overdue but still recoverable'),
              _MetricCard(
                  icon: Icons.cancel,
                  label: 'Lapsed',
                  value: _fmt.format(p.lapsedCount),
                  color: Colors.red,
                  description: 'No visit in 2x their usual gap'),
            ], isMobile),
            const SizedBox(height: 12),
            _cardRow([
              _MetricCard(
                  icon: Icons.event,
                  label: 'Due This Week',
                  value: _fmt.format(p.dueThisWeek),
                  color: Colors.blueGrey,
                  description: 'Expected to visit in the next 7 days'),
              _MetricCard(
                  icon: Icons.alarm,
                  label: 'Overdue',
                  value: _fmt.format(p.overdueCount),
                  color: Colors.red,
                  description: 'Past their expected return date'),
              _MetricCard(
                  icon: Icons.timelapse,
                  label: 'Avg Gap',
                  value: '${p.avgGapDays.toStringAsFixed(0)}d',
                  color: Colors.teal,
                  description: 'Average days between visits'),
            ], isMobile),
            if (p.topServices.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionHeader(
                  vc, 'Top Services', Icons.star, Colors.amber),
              const SizedBox(height: 16),
              ...p.topServices.entries.take(10).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HorizontalBar(
                      label: e.key,
                      value: e.value,
                      maxValue: p.topServices.values
                          .fold(0, (a, b) => a > b ? a : b),
                      color: Colors.teal,
                    ),
                  )),
            ],
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // INSIGHTS & RECOMMENDATIONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildInsightsSection() {
    final vc = context.vividColors;
    final recommendations = _generateRecommendations();
    if (recommendations.isEmpty) {
      return _emptyState(vc, 'Collecting data for insights...');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              vc, 'Upsell Opportunities', Icons.trending_up, Colors.green),
          const SizedBox(height: 16),
          ..._buildRecommendationCards(
              recommendations.where((r) => r.type == _RecType.upsell), vc),
          const SizedBox(height: 32),
          _sectionHeader(
              vc, 'Performance Alerts', Icons.warning_amber, Colors.orange),
          const SizedBox(height: 16),
          ..._buildRecommendationCards(
              recommendations.where((r) => r.type == _RecType.alert), vc),
          const SizedBox(height: 32),
          _sectionHeader(
              vc, 'Growth Insights', Icons.insights, VividColors.cyan),
          const SizedBox(height: 16),
          ..._buildRecommendationCards(
              recommendations.where((r) => r.type == _RecType.growth), vc),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<_Recommendation> _generateRecommendations() {
    final recs = <_Recommendation>[];

    // Upsell
    if (!client.hasFeature('broadcasts') && _conversations != null) {
      recs.add(_Recommendation(
        type: _RecType.upsell,
        priority: _Priority.high,
        icon: Icons.campaign,
        color: Colors.orange,
        title: 'Enable Broadcasts',
        description:
            'This client has ${_fmt.format(_conversations!.uniqueCustomers)} unique customers — enable Broadcasts to re-engage them with targeted campaigns.',
      ));
    }
    if (!client.hasFeature('labels') && _conversations != null) {
      recs.add(_Recommendation(
        type: _RecType.upsell,
        priority: _Priority.medium,
        icon: Icons.label,
        color: Colors.amber,
        title: 'Enable Labels',
        description:
            'Enable Labels to track appointment bookings and payment conversions automatically.',
      ));
    }
    if (!client.hasFeature('predictive_intelligence') &&
        _conversations != null) {
      recs.add(_Recommendation(
        type: _RecType.upsell,
        priority: _Priority.medium,
        icon: Icons.auto_graph,
        color: Colors.teal,
        title: 'Enable Predictions',
        description:
            'Enable Predictive Intelligence to identify at-risk customers before they lapse.',
      ));
    }
    if (!client.hasFeature('manager_chat')) {
      recs.add(_Recommendation(
        type: _RecType.upsell,
        priority: _Priority.low,
        icon: Icons.smart_toy,
        color: Colors.purple,
        title: 'Enable AI Assistant',
        description:
            'Enable Manager Chat so the team can get instant answers about their customers.',
      ));
    }
    if (!client.hasFeature('analytics')) {
      recs.add(_Recommendation(
        type: _RecType.upsell,
        priority: _Priority.low,
        icon: Icons.analytics,
        color: VividColors.cyan,
        title: 'Enable Self-Service Analytics',
        description:
            'Give ${client.name} access to their own analytics dashboard.',
      ));
    }

    // Alerts
    if (_conversations != null) {
      if (_conversations!.automationRate < 60) {
        recs.add(_Recommendation(
          type: _RecType.alert,
          priority: _Priority.high,
          icon: Icons.auto_awesome,
          color: Colors.red,
          title: 'Low Automation Rate',
          description:
              'AI automation is at ${_conversations!.automationRate.toStringAsFixed(1)}% — review AI responses to improve.',
        ));
      }
      if (_conversations!.singleMessageCustomers > 0) {
        final rate = _conversations!.uniqueCustomers > 0
            ? (_conversations!.singleMessageCustomers /
                    _conversations!.uniqueCustomers *
                    100)
                .round()
            : 0;
        if (rate > 40) {
          recs.add(_Recommendation(
            type: _RecType.alert,
            priority: _Priority.high,
            icon: Icons.person_off,
            color: Colors.orange,
            title: 'High Single-Message Rate',
            description:
                '$rate% of customers sent only 1 message — potential lost leads.',
          ));
        }
      }
    }
    if (_broadcasts != null && _broadcasts!.failRate > 10) {
      recs.add(_Recommendation(
        type: _RecType.alert,
        priority: _Priority.high,
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'High Broadcast Fail Rate',
        description:
            '${_broadcasts!.failRate.toStringAsFixed(1)}% of broadcasts are failing — check phone number quality.',
      ));
    }
    if (_predictions != null && _predictions!.atRiskCount > 0) {
      recs.add(_Recommendation(
        type: _RecType.alert,
        priority: _Priority.high,
        icon: Icons.warning,
        color: Colors.orange,
        title: 'At-Risk Customers',
        description:
            '${_fmt.format(_predictions!.atRiskCount)} customers are at risk of lapsing — send a retention broadcast.',
      ));
    }

    // Growth
    if (_conversations != null && _conversations!.aiMessages > 0) {
      final hoursSaved =
          (_conversations!.aiMessages * 2 / 60).toStringAsFixed(1);
      recs.add(_Recommendation(
        type: _RecType.growth,
        priority: _Priority.medium,
        icon: Icons.smart_toy,
        color: VividColors.cyan,
        title: 'AI Efficiency',
        description:
            'AI handled ${_conversations!.automationRate.toStringAsFixed(1)}% of conversations, saving ~$hoursSaved hours of manual work.',
      ));
    }
    if (_broadcasts != null && _broadcasts!.broadcastDrivenConversations > 0) {
      recs.add(_Recommendation(
        type: _RecType.growth,
        priority: _Priority.medium,
        icon: Icons.campaign,
        color: Colors.green,
        title: 'Broadcast Impact',
        description:
            'Broadcasts drove ${_fmt.format(_broadcasts!.broadcastDrivenConversations)} new conversations.',
      ));
    }
    if (_conversations != null && _conversations!.monthlyNewCustomers.length >= 2) {
      final months = _conversations!.monthlyNewCustomers.keys.toList()..sort();
      if (months.length >= 2) {
        final prev =
            _conversations!.monthlyNewCustomers[months[months.length - 2]] ?? 0;
        final curr = _conversations!.monthlyNewCustomers[months.last] ?? 0;
        if (prev > 0) {
          final growth = ((curr - prev) / prev * 100).round();
          if (growth > 0) {
            recs.add(_Recommendation(
              type: _RecType.growth,
              priority: _Priority.low,
              icon: Icons.trending_up,
              color: Colors.green,
              title: 'Customer Growth',
              description:
                  'Customer base grew $growth% month-over-month ($prev → $curr).',
            ));
          }
        }
      }
    }

    // Sort by priority
    recs.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return recs;
  }

  Iterable<Widget> _buildRecommendationCards(
      Iterable<_Recommendation> recs, VividColorScheme vc) {
    if (recs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('No items in this category',
              style: TextStyle(color: vc.textMuted, fontSize: 13)),
        )
      ];
    }
    return recs.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: vc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: r.color.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: r.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(r.icon, color: r.color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.title,
                                style: TextStyle(
                                    color: vc.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.priority == _Priority.high
                                  ? Colors.red.withOpacity(0.15)
                                  : r.priority == _Priority.medium
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r.priority.name.toUpperCase(),
                              style: TextStyle(
                                color: r.priority == _Priority.high
                                    ? Colors.red
                                    : r.priority == _Priority.medium
                                        ? Colors.orange
                                        : Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.description,
                          style: TextStyle(
                              color: vc.textMuted, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  Widget _sectionHeader(
      VividColorScheme vc, String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                color: vc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _cardRow(List<Widget> cards, bool isMobile) {
    if (cards.isEmpty) return const SizedBox();
    if (isMobile) {
      return Column(
        children: cards
            .expand((c) => [c, const SizedBox(height: 12)])
            .toList()
          ..removeLast(),
      );
    }
    return Row(
      children: cards
          .expand((c) => [Expanded(child: c), const SizedBox(width: 16)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _emptyState(VividColorScheme vc, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, color: vc.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: vc.textMuted, fontSize: 15)),
        ],
      ),
    );
  }

  // ─── Tables ────────────────────────────────────────────────────

  Widget _buildAgentResponseTable(
      VividColorScheme vc, Map<String, Duration> perAgent) {
    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    child: Text('Agent',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Text('Avg Response',
                    style: TextStyle(
                        color: vc.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
          Divider(height: 1, color: vc.border),
          ...perAgent.entries.map((e) {
            final color = _responseTimeColor(e.value);
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                      child: Text(e.key,
                          style: TextStyle(
                              color: vc.textPrimary, fontSize: 13))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_fmtDuration(e.value),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAgentTable(
      VividColorScheme vc, List<AgentPerformance> agents) {
    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Agent',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('Messages',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Avg Response',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('Days',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          Divider(height: 1, color: vc.border),
          ...agents.map((a) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(a.name,
                            style: TextStyle(
                                color: vc.textPrimary, fontSize: 13))),
                    Expanded(
                        flex: 2,
                        child: Text(_fmt.format(a.messageCount),
                            style: TextStyle(
                                color: VividColors.cyan, fontSize: 13),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text(_fmtDuration(a.avgResponseTime),
                            style: TextStyle(
                                color: _responseTimeColor(a.avgResponseTime),
                                fontSize: 13),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${a.activeDays}',
                            style: TextStyle(
                                color: vc.textMuted, fontSize: 13),
                            textAlign: TextAlign.center)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTopCustomersTable(
      VividColorScheme vc, List<TopCustomerInfo> customers) {
    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Top Customers',
                style: TextStyle(
                    color: vc.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          Divider(height: 1, color: vc.border),
          ...customers.take(10).map((c) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(c.name ?? c.phone,
                          style: TextStyle(
                              color: vc.textPrimary, fontSize: 13)),
                    ),
                    Text('${_fmt.format(c.messageCount)} msgs',
                        style: TextStyle(
                            color: VividColors.cyan,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCampaignTable(
      VividColorScheme vc, List<CampaignSummary> campaigns) {
    final df = DateFormat('MMM d, yyyy');
    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Campaign',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('Date',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Expanded(
                    child: Text('Recipients',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('Delivery',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          Divider(height: 1, color: vc.border),
          ...campaigns.take(20).map((c) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(c.name,
                            style: TextStyle(
                                color: vc.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                    Expanded(
                        flex: 2,
                        child: Text(df.format(c.date),
                            style: TextStyle(
                                color: vc.textMuted, fontSize: 12))),
                    Expanded(
                        child: Text(_fmt.format(c.recipients),
                            style: TextStyle(
                                color: vc.textPrimary, fontSize: 13),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('${c.deliveryRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: c.deliveryRate > 90
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildUserQueryTable(
      VividColorScheme vc, List<UserQuerySummary> users) {
    final df = DateFormat('MMM d');
    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('User',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Expanded(
                    child: Text('Queries',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Last Query',
                        style: TextStyle(
                            color: vc.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          Divider(height: 1, color: vc.border),
          ...users.map((u) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(u.userName,
                            style: TextStyle(
                                color: vc.textPrimary, fontSize: 13))),
                    Expanded(
                        child: Text(_fmt.format(u.queryCount),
                            style: TextStyle(
                                color: Colors.purple, fontSize: 13),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text(df.format(u.lastQuery),
                            style: TextStyle(
                                color: vc.textMuted, fontSize: 12),
                            textAlign: TextAlign.right)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────

  Color _automationColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  String _automationLabel(double rate) {
    if (rate >= 80) return 'Excellent performance';
    if (rate >= 60) return 'Good performance';
    if (rate >= 40) return 'Needs improvement';
    return 'Low automation';
  }

  Color _responseTimeColor(Duration d) {
    if (d == Duration.zero) return Colors.grey;
    if (d.inMinutes < 5) return Colors.green;
    if (d.inMinutes < 30) return Colors.orange;
    return Colors.red;
  }

  String _fmtDuration(Duration d) {
    if (d == Duration.zero) return 'N/A';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  Color _labelColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('enquir') || l.contains('inquiry')) return Colors.blue;
    if (l.contains('appointment') || l.contains('booking')) return Colors.green;
    if (l.contains('payment') || l.contains('paid')) return Colors.teal;
    if (l.contains('cancel') || l.contains('no show')) return Colors.red;
    if (l.contains('follow')) return Colors.orange;
    return Colors.purple;
  }

  Color _categoryColor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('new')) return Colors.blue;
    if (c.contains('returning')) return Colors.green;
    if (c.contains('regular')) return Colors.teal;
    if (c.contains('risk')) return Colors.orange;
    if (c.contains('lapsed')) return Colors.red;
    return Colors.purple;
  }
}

// ═══════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlight ? color.withOpacity(0.5) : vc.border,
          width: isHighlight ? 2 : 1,
        ),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: vc.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!,
                style: TextStyle(
                    color: vc.textMuted.withOpacity(0.7), fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ─── Automation Stacked Bar ──────────────────────────────────────

class _AutomationBar extends StatelessWidget {
  final int aiMessages;
  final int humanMessages;
  final int handoffs;

  const _AutomationBar({
    required this.aiMessages,
    required this.humanMessages,
    required this.handoffs,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final total = aiMessages + humanMessages;
    if (total == 0) return const SizedBox();
    final aiPct = aiMessages / total;
    final humanPct = humanMessages / total;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VividColors.brightBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart,
                    color: VividColors.brightBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Response Breakdown',
                  style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  if (aiPct > 0)
                    Expanded(
                      flex: (aiPct * 100).round(),
                      child: Container(
                        color: VividColors.cyan,
                        alignment: Alignment.center,
                        child: aiPct > 0.1
                            ? Text('${(aiPct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    color: vc.background,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                  if (humanPct > 0)
                    Expanded(
                      flex: (humanPct * 100).round(),
                      child: Container(
                        color: VividColors.brightBlue,
                        alignment: Alignment.center,
                        child: humanPct > 0.1
                            ? Text('${(humanPct * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _LegendItem(
                      color: VividColors.cyan,
                      label: 'AI Handled',
                      value: _fmt.format(aiMessages))),
              const SizedBox(width: 16),
              Expanded(
                  child: _LegendItem(
                      color: VividColors.brightBlue,
                      label: 'Human Handled',
                      value: _fmt.format(humanMessages))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stacked Bar (generic) ───────────────────────────────────────

class _BarSegment {
  final String label;
  final int value;
  final Color color;
  const _BarSegment(this.label, this.value, this.color);
}

class _StackedBar extends StatelessWidget {
  final List<_BarSegment> segments;
  const _StackedBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final total = segments.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: vc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: vc.border),
        ),
        child: Text('No data', style: TextStyle(color: vc.textMuted)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 36,
              child: Row(
                children: segments
                    .where((s) => s.value > 0)
                    .map((s) => Expanded(
                          flex: (s.value / total * 100).round().clamp(1, 100),
                          child: Container(
                            color: s.color,
                            alignment: Alignment.center,
                            child: (s.value / total) > 0.08
                                ? Text(
                                    '${(s.value / total * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: segments
                .map((s) => _LegendItem(
                    color: s.color,
                    label: s.label,
                    value: _fmt.format(s.value)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Horizontal Bar ──────────────────────────────────────────────

class _HorizontalBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _HorizontalBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final pct = maxValue > 0 ? value / maxValue : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(color: vc.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: vc.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(_fmt.format(value),
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// ─── Hourly Chart ────────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  final Map<int, int> data;
  final String title;
  final Color color;

  const _HourlyChart(
      {required this.data, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final val = data[h] ?? 0;
                final height = maxVal > 0 ? (val / maxVal * 100) : 0.0;
                return Expanded(
                  child: Tooltip(
                    message: '${h.toString().padLeft(2, '0')}:00 — ${_fmt.format(val)}',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: height.clamp(2, 100),
                      decoration: BoxDecoration(
                        color: val > 0
                            ? color.withOpacity(0.3 + (val / maxVal) * 0.7)
                            : vc.surfaceAlt,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00:00',
                  style: TextStyle(color: vc.textMuted, fontSize: 10)),
              Text('12:00',
                  style: TextStyle(color: vc.textMuted, fontSize: 10)),
              Text('23:00',
                  style: TextStyle(color: vc.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Day of Week Chart ───────────────────────────────────────────

class _DayOfWeekChart extends StatelessWidget {
  final Map<int, int> data;
  final Color color;

  const _DayOfWeekChart({required this.data, required this.color});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Messages by Day',
              style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final val = data[i + 1] ?? 0;
                final height = maxVal > 0 ? (val / maxVal * 80) : 0.0;
                return Expanded(
                  child: Tooltip(
                    message: '${_days[i]} — ${_fmt.format(val)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: height.clamp(2, 80),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_days[i],
                            style: TextStyle(
                                color: vc.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Volume Line Chart ─────────────────────────────────────

class _DailyVolumeChart extends StatelessWidget {
  final Map<String, int> data;
  final Color color;

  const _DailyVolumeChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    if (data.isEmpty) return const SizedBox();
    final sortedKeys = data.keys.toList()..sort();
    final values = sortedKeys.map((k) => data[k] ?? 0).toList();
    final maxVal = values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Volume',
              style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter:
                  _SparklinePainter(values: values, maxVal: maxVal, color: color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (sortedKeys.isNotEmpty)
                Text(sortedKeys.first.substring(5),
                    style: TextStyle(color: vc.textMuted, fontSize: 10)),
              if (sortedKeys.length > 1)
                Text(sortedKeys.last.substring(5),
                    style: TextStyle(color: vc.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final int maxVal;
  final Color color;

  _SparklinePainter(
      {required this.values, required this.maxVal, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxVal == 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final step = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - (values[i] / maxVal * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo((values.length - 1) * step, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Legend Item ──────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: vc.textMuted.withOpacity(0.9), fontSize: 11)),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Recommendation models ───────────────────────────────────────

enum _RecType { upsell, alert, growth }
enum _Priority { high, medium, low }

class _Recommendation {
  final _RecType type;
  final _Priority priority;
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _Recommendation({
    required this.type,
    required this.priority,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
