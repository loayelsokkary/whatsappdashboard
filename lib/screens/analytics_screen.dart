import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/roi_analytics_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';
import '../services/supabase_service.dart';

// ================================================================
// DATE RANGE FILTER
// ================================================================

enum DateRangeFilter {
  last30Days('Last 30 Days'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  thisMonth('This Month'),
  allTime('All Time'),
  custom('Custom Range');

  final String label;
  const DateRangeFilter(this.label);

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case DateRangeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case DateRangeFilter.yesterday:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      case DateRangeFilter.last7Days:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      case DateRangeFilter.last30Days:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      case DateRangeFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DateRangeFilter.allTime:
        return DateTime(2020, 1, 1); // far enough back to capture everything
      case DateRangeFilter.custom:
        return null;
    }
  }

  DateTime? get endDate {
    if (this == DateRangeFilter.yesterday) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime.now();
  }
}

// ================================================================
// OVERDUE THRESHOLD OPTIONS
// ================================================================

class _OverdueOption {
  final String label;
  final Duration duration;
  const _OverdueOption(this.label, this.duration);
}

const _overdueOptions = [
  _OverdueOption('5 min', Duration(minutes: 5)),
  _OverdueOption('15 min', Duration(minutes: 15)),
  _OverdueOption('30 min', Duration(minutes: 30)),
  _OverdueOption('1 hour', Duration(hours: 1)),
  _OverdueOption('2 hours', Duration(hours: 2)),
];

// ================================================================
// MAIN SCREEN
// ================================================================

class AnalyticsScreen extends StatefulWidget {
  final void Function(String customerPhone)? onNavigateToConversation;
  const AnalyticsScreen({super.key, this.onNavigateToConversation});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateRangeFilter _dateFilter = DateRangeFilter.last30Days;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _compareEnabled = false;
  DateRangeFilter _compareDateFilter = DateRangeFilter.last30Days;
  DateTime? _compareCustomStart;
  DateTime? _compareCustomEnd;
  bool _showBroadcasts = false;
  String? _selectedCampaignId;
  int _overdueIndex = 2; // default 30 min
  bool _hasBothFeatures = false;

  @override
  void initState() {
    super.initState();
    _hasBothFeatures = ClientConfig.hasFeature('conversations') &&
        ClientConfig.hasFeature('broadcasts');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  DateTime? get _effectiveStart =>
      _dateFilter == DateRangeFilter.custom ? _customStart : _dateFilter.startDate;

  DateTime? get _effectiveEnd =>
      _dateFilter == DateRangeFilter.custom ? _customEnd : _dateFilter.endDate;

  void _loadAnalytics() {
    final client = ClientConfig.currentClient;
    if (client == null) return;

    final start = _effectiveStart;
    final end = _effectiveEnd;

    DateTime? compStart;
    DateTime? compEnd;
    if (_compareEnabled) {
      if (_compareDateFilter == DateRangeFilter.custom) {
        compStart = _compareCustomStart;
        compEnd = _compareCustomEnd;
      } else {
        compStart = _compareDateFilter.startDate;
        compEnd = _compareDateFilter.endDate;
      }
    }

    context.read<RoiAnalyticsProvider>().fetchAnalytics(
          clientId: client.id,
          messagesTable: ClientConfig.messagesTable,
          broadcastsTable: ClientConfig.broadcastsTable,
          startDate: start,
          endDate: end,
          campaignId: _showBroadcasts ? _selectedCampaignId : null,
          compareStartDate: compStart,
          compareEndDate: compEnd,
          overdueThreshold: _overdueOptions[_overdueIndex].duration,
        );
  }

  void _handleRefresh() {
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoiAnalyticsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? VividColors.darkNavy : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Thin progress bar whenever loading with existing data
          if (provider.isLoading && provider.data != null)
            LinearProgressIndicator(
              backgroundColor: isDark ? VividColors.navy : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(VividColors.cyan),
              minHeight: 2,
            ),
          // Error banner (non-blocking, only when we have stale data)
          if (provider.error != null && provider.data != null)
            _buildErrorBanner(provider.error!),
          // Content
          Expanded(
            child: provider.isLoading && provider.data == null
                ? _buildFirstLoad()
                : provider.error != null && provider.data == null
                    ? _buildError(provider.error!)
                    : provider.data == null
                        ? Center(
                            child: Text('No analytics data',
                                style: TextStyle(color: isDark ? VividColors.textMuted : const Color(0xFF64748B), fontSize: 14)))
                        : _buildContent(provider.data!),
          ),
        ],
      ),
    );
  }

  // ---- First load: header + filters visible, small spinner in content area ----
  Widget _buildFirstLoad() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(null),
          const SizedBox(height: 80),
          const Center(
            child: CircularProgressIndicator(color: VividColors.cyan),
          ),
        ],
      ),
    );
  }

  // ---- Error banner ----
  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: VividColors.statusUrgent.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: VividColors.statusUrgent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error,
                style: const TextStyle(color: VividColors.statusUrgent, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh, color: VividColors.statusUrgent, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ---- Full-screen error (no data at all) ----
  Widget _buildError(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: VividColors.statusUrgent, size: 48),
          const SizedBox(height: 16),
          Text(error,
              style: TextStyle(color: isDark ? VividColors.textSecondary : const Color(0xFF475569), fontSize: 14),
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

  // ---- Main content ----
  Widget _buildContent(AnalyticsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(data),
              const SizedBox(height: 32),
              if (_showBroadcasts)
                _BroadcastsView(
                  data: data,
                  isWide: isWide,
                  selectedCampaignId: _selectedCampaignId,
                  onCampaignChanged: (id) {
                    setState(() => _selectedCampaignId = id);
                    _loadAnalytics();
                  },
                )
              else
                _ConversationsView(
                  data: data,
                  isWide: isWide,
                  compareEnabled: _compareEnabled,
                  overdueIndex: _overdueIndex,
                  compareDateFilterLabel: _compareEnabled ? _compareDateFilter.label : null,
                  onOverdueChanged: (idx) {
                    setState(() => _overdueIndex = idx);
                    _loadAnalytics();
                  },
                  onReplyToConversation: widget.onNavigateToConversation,
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ---- Toolbar: two rows ----
  Widget _buildToolbar(AnalyticsData? data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final client = ClientConfig.currentClient;
    final daysActive = client != null
        ? DateTime.now().difference(client.createdAt).inDays
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Title + Export + Refresh
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ClientConfig.businessName,
                  style: TextStyle(
                    color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (daysActive != null)
                  Text(
                    '$daysActive days active',
                    style: TextStyle(color: isDark ? VividColors.textMuted : const Color(0xFF64748B), fontSize: 12),
                  ),
              ],
            ),
            const Spacer(),
            if (data != null) _buildExportButton(data),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _handleRefresh,
              icon: Icon(Icons.refresh_rounded, color: isDark ? VividColors.textMuted : const Color(0xFF64748B), size: 22),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: Filters + Toggle
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDateFilter(),
            _buildCompareToggle(),
            if (_compareEnabled) _buildCompareDateFilter(),
            if (_hasBothFeatures) _buildViewToggle(),
          ],
        ),
      ],
    );
  }

  // ---- View toggle ----
  Widget _buildViewToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? VividColors.navy : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VividColors.tealBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleTab(
            label: 'Conversations',
            icon: Icons.forum_outlined,
            isSelected: !_showBroadcasts,
            onTap: () {
              if (_showBroadcasts) {
                setState(() {
                  _showBroadcasts = false;
                  _selectedCampaignId = null;
                });
                _loadAnalytics();
              }
            },
          ),
          _toggleTab(
            label: 'Broadcasts',
            icon: Icons.campaign_outlined,
            isSelected: _showBroadcasts,
            onTap: () {
              if (!_showBroadcasts) {
                setState(() => _showBroadcasts = true);
                _loadAnalytics();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _toggleTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (label == 'Broadcasts' ? VividColors.brightBlue : VividColors.cyan)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: isSelected ? Colors.white : (isDark ? VividColors.textMuted : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? VividColors.textMuted : const Color(0xFF64748B)),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Date filter ----
  Widget _buildDateFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? VividColors.navy : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _dateFilter != DateRangeFilter.last30Days
              ? VividColors.cyan.withValues(alpha: 0.3)
              : VividColors.tealBlue.withValues(alpha: 0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateRangeFilter>(
          value: _dateFilter,
          icon: Icon(Icons.keyboard_arrow_down, color: isDark ? VividColors.textMuted : const Color(0xFF64748B), size: 18),
          dropdownColor: isDark ? VividColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13),
          items: DateRangeFilter.values.map((filter) {
            final isSelected = filter == _dateFilter;
            return DropdownMenuItem(
              value: filter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 13,
                      color: isSelected ? VividColors.cyan : (isDark ? VividColors.textMuted : const Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Text(filter.label, style: TextStyle(
                    color: isSelected ? (isDark ? VividColors.textPrimary : const Color(0xFF1E293B)) : (isDark ? VividColors.textSecondary : const Color(0xFF475569)),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  )),
                ],
              ),
            );
          }).toList(),
          onChanged: (filter) {
            if (filter == null || filter == _dateFilter) return;
            if (filter == DateRangeFilter.custom) {
              _showCustomDatePicker();
            } else {
              setState(() => _dateFilter = filter);
              _loadAnalytics();
            }
          },
        ),
      ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VividColors.cyan,
              onPrimary: VividColors.darkNavy,
              surface: VividColors.navy,
              onSurface: VividColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateFilter = DateRangeFilter.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
      _loadAnalytics();
    }
  }

  // ---- Compare toggle ----
  Widget _buildCompareToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? VividColors.navy : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VividColors.tealBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            child: Switch(
              value: _compareEnabled,
              onChanged: (v) {
                setState(() => _compareEnabled = v);
                _loadAnalytics();
              },
              activeTrackColor: VividColors.cyan.withValues(alpha: 0.3),
              inactiveThumbColor: VividColors.textMuted,
              inactiveTrackColor: isDark ? VividColors.tealBlue.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Text('Compare', style: TextStyle(color: isDark ? VividColors.textSecondary : const Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ---- Compare date filter (Period B) ----
  Widget _buildCompareDateFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('vs', style: TextStyle(
          color: (isDark ? VividColors.textMuted : const Color(0xFF94A3B8)).withValues(alpha: 0.6), fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? VividColors.navy : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: VividColors.brightBlue.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateRangeFilter>(
              value: _compareDateFilter,
              icon: Icon(Icons.keyboard_arrow_down, color: isDark ? VividColors.textMuted : const Color(0xFF64748B), size: 18),
              dropdownColor: isDark ? VividColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13),
              items: DateRangeFilter.values.map((filter) {
                final isSelected = filter == _compareDateFilter;
                return DropdownMenuItem(
                  value: filter,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 13,
                          color: isSelected ? VividColors.brightBlue : (isDark ? VividColors.textMuted : const Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      Text(filter.label, style: TextStyle(
                        color: isSelected ? (isDark ? VividColors.textPrimary : const Color(0xFF1E293B)) : (isDark ? VividColors.textSecondary : const Color(0xFF475569)),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      )),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (filter) {
                if (filter == null || filter == _compareDateFilter) return;
                if (filter == DateRangeFilter.custom) {
                  _showCompareCustomDatePicker();
                } else {
                  setState(() => _compareDateFilter = filter);
                  _loadAnalytics();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCompareCustomDatePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _compareCustomStart != null && _compareCustomEnd != null
          ? DateTimeRange(start: _compareCustomStart!, end: _compareCustomEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 60)), end: now.subtract(const Duration(days: 30))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VividColors.brightBlue,
              onPrimary: VividColors.darkNavy,
              surface: VividColors.navy,
              onSurface: VividColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _compareDateFilter = DateRangeFilter.custom;
        _compareCustomStart = picked.start;
        _compareCustomEnd = picked.end;
      });
      _loadAnalytics();
    }
  }

  // ---- Export button (filled accent) ----
  Widget _buildExportButton(AnalyticsData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: 'Export',
      color: isDark ? VividColors.navy : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
      ),
      offset: const Offset(0, 45),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'csv',
          child: Row(children: [
            Icon(Icons.table_chart_outlined, size: 16, color: isDark ? VividColors.textSecondary : const Color(0xFF475569)),
            const SizedBox(width: 10),
            Text('Export CSV', style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(children: [
            Icon(Icons.picture_as_pdf_outlined, size: 16, color: isDark ? VividColors.textSecondary : const Color(0xFF475569)),
            const SizedBox(width: 10),
            Text('Export PDF', style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13)),
          ]),
        ),
      ],
      onSelected: (format) {
        final clientName = ClientConfig.businessName;
        final dateRange = _dateFilter.label;
        if (format == 'csv') {
          AnalyticsExporter.exportAnalyticsCsv(data: data, clientName: clientName, dateRange: dateRange);
        } else {
          AnalyticsExporter.exportAnalyticsPdf(data: data, clientName: clientName, dateRange: dateRange);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: VividColors.cyan,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CONVERSATIONS VIEW
// ================================================================

class _ConversationsView extends StatelessWidget {
  final AnalyticsData data;
  final bool isWide;
  final bool compareEnabled;
  final int overdueIndex;
  final ValueChanged<int> onOverdueChanged;
  final String? compareDateFilterLabel;
  final void Function(String customerPhone)? onReplyToConversation;

  const _ConversationsView({
    required this.data,
    required this.isWide,
    required this.compareEnabled,
    required this.overdueIndex,
    required this.onOverdueChanged,
    this.compareDateFilterLabel,
    this.onReplyToConversation,
  });

  String? get _compareLabel => compareEnabled && compareDateFilterLabel != null
      ? compareDateFilterLabel!
      : null;

  void _showPipelineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _PipelineDialog(
        customers: data.labeledCustomers,
      ),
    );
  }

  void _showLeadsDialog(BuildContext context, String title, List<LeadContributor> leads) {
    showDialog(
      context: context,
      builder: (_) => _LeadsDialog(title: title, leads: leads),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final m = data.current;
    final c = data.comparison;

    // Compute booked count matching pipeline dialog (excludes customers who also paid)
    final paidPhones = data.labeledCustomers
        .where((lc) => lc.label == 'payment done')
        .map((lc) => lc.phone)
        .toSet();
    final bookedCount = data.labeledCustomers
        .where((lc) => lc.label == 'appointment booked' && !paidPhones.contains(lc.phone))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- OVERVIEW ----
        Text('Overview', style: TextStyle(
          color: sectionTitleColor, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Row 1: Leads, Organic Leads, Appointments Booked, Payment Done
        _cardRow(isWide, [
          _MetricCard(
            icon: Icons.people_alt,
            label: 'Leads',
            value: '${m.leads}',
            color: VividColors.cyan,
            description: 'Total conversations started in this period',
            isHighlight: m.leads > 0,
            change: c != null ? _calcChange(m.leads.toDouble(), c.leads.toDouble()) : null,
            compareLabel: _compareLabel,
            onTap: data.leadContributors.isNotEmpty
                ? () => _showLeadsDialog(context, 'All Leads', data.leadContributors)
                : null,
          ),
          _MetricCard(
            icon: Icons.nature_people,
            label: 'Organic Leads',
            value: '${m.organicLeads}',
            color: const Color(0xFF8B5CF6),
            description: 'Leads not attributed to any broadcast campaign',
            isHighlight: m.organicLeads > 0,
            change: c != null ? _calcChange(m.organicLeads.toDouble(), c.organicLeads.toDouble()) : null,
            compareLabel: _compareLabel,
            onTap: data.organicLeadContributors.isNotEmpty
                ? () => _showLeadsDialog(context, 'Organic Leads', data.organicLeadContributors)
                : null,
          ),
        ]),
        const SizedBox(height: 20),

        // Row 2: Appointments Booked, Payment Done
        _cardRow(isWide, [
          _MetricCard(
            icon: Icons.event_available,
            label: 'Appointments Booked',
            value: '$bookedCount',
            color: Colors.green,
            description: 'Confirmed bookings from conversations or campaigns',
            isHighlight: m.appointmentsBooked > 0,
            change: c != null ? _calcChange(m.appointmentsBooked.toDouble(), c.appointmentsBooked.toDouble()) : null,
            compareLabel: _compareLabel,
            onTap: data.labeledCustomers.isNotEmpty ? () => _showPipelineDialog(context) : null,
          ),
          _MetricCard(
            icon: Icons.payments,
            label: 'Payment Done',
            value: m.revenue > 0 ? '${m.revenue.toStringAsFixed(0)} BHD' : '0 BHD',
            color: const Color(0xFF06B6D4),
            description: 'Total BHD received (${m.paymentsDone} payments)',
            isHighlight: m.paymentsDone > 0,
            change: c != null ? _calcChange(m.revenue, c.revenue) : null,
            compareLabel: _compareLabel,
            onTap: data.labeledCustomers.isNotEmpty ? () => _showPipelineDialog(context) : null,
          ),
        ]),
        const SizedBox(height: 20),

        // Row 2: Engagement Rate, Avg Response Time, Messages Sent
        _cardRow(isWide, [
          _MetricCard(
            icon: Icons.trending_up,
            label: 'Engagement Rate',
            value: '${m.engagementRate.toStringAsFixed(1)}%',
            color: VividColors.brightBlue,
            description: 'Percentage of inbound messages relative to broadcasts sent',
            change: c != null ? _calcChange(m.engagementRate, c.engagementRate) : null,
            compareLabel: _compareLabel,
            onTap: data.engagedCustomers.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _EngagedCustomersDialog(customers: data.engagedCustomers))
                : null,
          ),
          _MetricCard(
            icon: Icons.timer,
            label: 'Avg Response Time',
            value: _fmtDuration(m.avgResponseTimeSeconds),
            color: Colors.orange,
            description: 'Average time for a human agent to send the first reply',
            change: c != null ? _calcChange(m.avgResponseTimeSeconds, c.avgResponseTimeSeconds) : null,
            invertChange: true,
            compareLabel: _compareLabel,
            onTap: data.responseTimeEntries.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _ResponseTimesDialog(entries: data.responseTimeEntries))
                : null,
          ),
          _MetricCard(
            icon: Icons.send,
            label: 'Messages Sent',
            value: '${m.messagesSent}',
            color: VividColors.cyan,
            description: 'Total outbound messages sent by agents and automations',
            change: c != null ? _calcChange(m.messagesSent.toDouble(), c.messagesSent.toDouble()) : null,
            compareLabel: _compareLabel,
            onTap: data.agentMessageCounts.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _MessagesSentDialog(
                      agentCounts: data.agentMessageCounts,
                      automatedCount: data.automatedMessageCount,
                    ))
                : null,
          ),
        ]),
        const SizedBox(height: 20),

        // Row 3: Messages Received, Open Conversations, Overdue
        _cardRow(isWide, [
          _MetricCard(
            icon: Icons.inbox,
            label: 'Messages Received',
            value: '${m.messagesReceived}',
            color: VividColors.brightBlue,
            description: 'Total inbound messages received from customers',
            change: c != null ? _calcChange(m.messagesReceived.toDouble(), c.messagesReceived.toDouble()) : null,
            compareLabel: _compareLabel,
            onTap: data.inboundCustomers.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _InboundCustomersDialog(customers: data.inboundCustomers))
                : null,
          ),
          _MetricCard(
            icon: Icons.chat_bubble_outline,
            label: 'Open Conversations',
            value: '${m.openConversationCount}',
            color: Colors.orange,
            description: 'Conversations currently awaiting a reply from your team',
            isHighlight: m.openConversationCount > 0,
            pulse: m.openConversationCount > 0,
            onTap: data.openConversations.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _OpenConversationsDialog(
                      conversations: data.openConversations,
                      title: 'Open Conversations',
                      color: Colors.orange,
                    ))
                : null,
          ),
          _MetricCard(
            icon: Icons.warning_amber,
            label: 'Overdue',
            value: '${m.overdueConversationCount}',
            color: Colors.red,
            description: 'Conversations where response time exceeded ${_overdueOptions[overdueIndex].label}',
            isHighlight: m.overdueConversationCount > 0,
            pulse: m.overdueConversationCount > 0,
            onTap: data.overdueConversations.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _OpenConversationsDialog(
                      conversations: data.overdueConversations,
                      title: 'Overdue Conversations',
                      color: Colors.red,
                    ))
                : null,
          ),
        ]),

        // ---- ACTION REQUIRED ----
        const SizedBox(height: 32),
        _buildOverdueSection(context),

        // ---- PER-EMPLOYEE RESPONSE TIME ----
        if (m.employeeAvgResponseTime.isNotEmpty) ...[
          const SizedBox(height: 32),
          _EmployeeResponseTimeSection(
            employeeTimes: m.employeeAvgResponseTime,
            isWide: isWide,
          ),
        ],

        // ---- TRENDS ----
        if (data.dailyBreakdown.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('Daily Trends', style: TextStyle(
            color: sectionTitleColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildTrendCharts(),
        ],

        // ---- CONVERSION FUNNEL ----
        if (m.leads > 0 || m.appointmentsBooked > 0 || m.paymentsDone > 0) ...[
          const SizedBox(height: 32),
          Text('Conversion Funnel', style: TextStyle(
            color: sectionTitleColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildConversionFunnel(context, m),
        ],

        // ---- PERFORMANCE ALERTS ----
        const SizedBox(height: 20),
        if (compareEnabled && data.comparison != null)
          _buildPerformanceAlerts()
        else if (!compareEnabled)
          _buildMutedNote('Enable comparison to see performance alerts'),
      ],
    );
  }

  Widget _buildConversionFunnel(BuildContext context, OverviewMetrics m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final stages = [
      _FunnelStage('Conversations', m.leads, VividColors.cyan),
      _FunnelStage('Appointments', m.appointmentsBooked, Colors.green),
      _FunnelStage('Payments', m.paymentsDone, const Color(0xFF06B6D4)),
    ];
    final maxVal = stages.map((s) => s.count).fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return _buildMutedNote('No conversion data yet', isDark: isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardBoxDecoration(isDark: isDark),
      child: Column(
        children: stages.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final widthFraction = maxVal > 0 ? (s.count / maxVal).clamp(0.08, 1.0) : 0.08;
          final convRate = idx > 0 && stages[idx - 1].count > 0
              ? (s.count / stages[idx - 1].count * 100).toStringAsFixed(1)
              : null;

          return Padding(
            padding: EdgeInsets.only(top: idx > 0 ? 12 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(s.label, style: TextStyle(
                        color: labelColor, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: widthFraction.toDouble(),
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [s.color.withValues(alpha: 0.7), s.color],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('${s.count}', style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    if (convRate != null) ...[
                      const SizedBox(width: 12),
                      Text('$convRate%', style: TextStyle(
                        color: VividColors.textMuted.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ],
                ),
                if (idx < stages.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 120, top: 4, bottom: 4),
                    child: Icon(Icons.arrow_downward, size: 14,
                        color: VividColors.textMuted.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendCharts() {
    final days = data.dailyBreakdown;
    final compDays = data.comparisonDailyBreakdown;

    final charts = [
      _TrendChart(title: 'Leads per Day', days: days, compDays: compDays,
          valueExtractor: (d) => d.leads.toDouble(), formatValue: (v) => v.toInt().toString(), barColor: VividColors.cyan),
      _TrendChart(title: 'Revenue per Day', days: days, compDays: compDays,
          valueExtractor: (d) => d.revenue, formatValue: (v) => '${v.toStringAsFixed(0)} BHD', barColor: Colors.green),
      _TrendChart(title: 'Engagement Rate', days: days, compDays: compDays,
          valueExtractor: (d) => d.engagementRate, formatValue: (v) => '${v.toStringAsFixed(1)}%', barColor: VividColors.brightBlue),
      _TrendChart(title: 'Avg Response Time', days: days, compDays: compDays,
          valueExtractor: (d) => d.avgResponseTimeSeconds, formatValue: (v) => _fmtDuration(v), barColor: Colors.orange),
    ];

    if (isWide) {
      return Column(children: [
        Row(children: [
          Expanded(child: charts[0]), const SizedBox(width: 20), Expanded(child: charts[1]),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: charts[2]), const SizedBox(width: 20), Expanded(child: charts[3]),
        ]),
      ]);
    }
    return Column(
      children: charts.expand((c) => [c, const SizedBox(height: 20)]).toList()..removeLast(),
    );
  }

  Widget _buildOverdueSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final overdueCount = data.overdueConversations.length;
    final openCount = data.openConversations.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with count + threshold inline
        Row(children: [
          Text('Action Required', style: TextStyle(
            color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          if (overdueCount > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: VividColors.statusUrgent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$overdueCount overdue', style: const TextStyle(
                color: VividColors.statusUrgent, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
          if (openCount > 0 && openCount > overdueCount) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: VividColors.statusWarning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$openCount open', style: const TextStyle(
                color: VividColors.statusWarning, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
          const Spacer(),
          Text('Threshold:', style: TextStyle(color: textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? VividColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: overdueIndex,
                dropdownColor: isDark ? VividColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(12),
                isDense: true,
                style: TextStyle(color: textPrimary, fontSize: 12),
                icon: Icon(Icons.keyboard_arrow_down, size: 14, color: textMuted),
                items: _overdueOptions.asMap().entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text('>${e.value.label}'));
                }).toList(),
                onChanged: (v) { if (v != null) onOverdueChanged(v); },
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (data.openConversations.isEmpty)
          _buildStatusCard('All conversations responded to', Icons.check_circle_outline, VividColors.statusSuccess)
        else
          _buildOverdueList(context),
      ],
    );
  }

  Widget _buildOverdueList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    // Show overdue first (sorted by longest wait), then open (non-overdue)
    final overdue = [...data.overdueConversations]
      ..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    final openOnly = data.openConversations
        .where((c) => !data.overdueConversations.any((o) => o.customerPhone == c.customerPhone))
        .toList()
      ..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    final all = [...overdue, ...openOnly];

    return Container(
      width: double.infinity,
      decoration: _cardBoxDecoration(isDark: isDark),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: all.take(15).toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          final isOverdue = overdue.any((o) => o.customerPhone == c.customerPhone);
          final isLong = c.waitingTime.inHours >= 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: idx < min(all.length, 15) - 1
                  ? Border(bottom: BorderSide(color: isDark ? VividColors.tealBlue.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)))
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: isOverdue
                      ? (isLong ? VividColors.statusUrgent : VividColors.statusWarning)
                      : VividColors.cyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.customerName ?? c.customerPhone,
                        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    if (c.customerName != null)
                      Text(c.customerPhone, style: TextStyle(color: textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  c.lastMessage.length > 60 ? '${c.lastMessage.substring(0, 60)}...' : c.lastMessage,
                  style: TextStyle(color: textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis, maxLines: 1,
                ),
              ),
              const SizedBox(width: 12),
              _waitTimePill(c.waitingTime, isLong: isLong, isMedium: isOverdue),
              const SizedBox(width: 12),
              if (onReplyToConversation != null)
                SizedBox(
                  height: 30,
                  child: TextButton.icon(
                    onPressed: () => onReplyToConversation!(c.customerPhone),
                    icon: const Icon(Icons.reply, size: 14),
                    label: const Text('Reply', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: VividColors.cyan,
                      backgroundColor: VividColors.cyan.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _waitTimePill(Duration d, {required bool isLong, required bool isMedium}) {
    final color = isLong ? VividColors.statusUrgent : isMedium ? VividColors.statusWarning : VividColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_fmtWaitTime(d),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPerformanceAlerts() {
    final m = data.current;
    final c = data.comparison!;
    final alerts = <Widget>[];

    if (c.avgResponseTimeSeconds > 0 && m.avgResponseTimeSeconds > c.avgResponseTimeSeconds) {
      final inc = ((m.avgResponseTimeSeconds - c.avgResponseTimeSeconds) / c.avgResponseTimeSeconds * 100).toStringAsFixed(0);
      alerts.add(_buildStatusCard('Response time increased by $inc%', Icons.timer_off_outlined, VividColors.statusUrgent));
    }
    if (alerts.isEmpty) {
      return _buildStatusCard('All metrics looking healthy', Icons.check_circle_outline, VividColors.statusSuccess);
    }
    return Column(children: alerts.expand((a) => [a, const SizedBox(height: 8)]).toList()..removeLast());
  }

  static double? _calcChange(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : null;
    return ((current - previous) / previous) * 100;
  }
}

// ================================================================
// EMPLOYEE RESPONSE TIME SECTION (with search + sort)
// ================================================================

enum _EmployeeSort { fastest, slowest, alphabetical }

class _EmployeeResponseTimeSection extends StatefulWidget {
  final Map<String, double> employeeTimes;
  final bool isWide;
  const _EmployeeResponseTimeSection({required this.employeeTimes, required this.isWide});

  @override
  State<_EmployeeResponseTimeSection> createState() => _EmployeeResponseTimeSectionState();
}

class _EmployeeResponseTimeSectionState extends State<_EmployeeResponseTimeSection> {
  String _search = '';
  _EmployeeSort _sort = _EmployeeSort.fastest;

  List<MapEntry<String, double>> get _filteredSorted {
    var entries = widget.employeeTimes.entries.toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      entries = entries.where((e) => e.key.toLowerCase().contains(q)).toList();
    }
    switch (_sort) {
      case _EmployeeSort.fastest:
        entries.sort((a, b) => a.value.compareTo(b.value));
      case _EmployeeSort.slowest:
        entries.sort((a, b) => b.value.compareTo(a.value));
      case _EmployeeSort.alphabetical:
        entries.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final containerBg = isDark ? VividColors.navy : Colors.white;
    final borderColor = isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0);
    final entries = _filteredSorted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title, search, sort
        Row(
          children: [
            Text('Response Time by Employee', style: TextStyle(
              color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Sort dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_EmployeeSort>(
                  value: _sort,
                  dropdownColor: containerBg,
                  borderRadius: BorderRadius.circular(12),
                  isDense: true,
                  icon: Icon(Icons.sort, size: 14, color: textMuted),
                  style: TextStyle(color: isDark ? VividColors.textSecondary : const Color(0xFF475569), fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: _EmployeeSort.fastest, child: Text('Fastest first')),
                    DropdownMenuItem(value: _EmployeeSort.slowest, child: Text('Slowest first')),
                    DropdownMenuItem(value: _EmployeeSort.alphabetical, child: Text('A → Z')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _sort = v); },
                ),
              ),
            ),
          ],
        ),
        // Search bar (show when > 6 employees)
        if (widget.employeeTimes.length > 6) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search employee...',
                hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5), fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: containerBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: VividColors.cyan),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Cards — uniform fixed-height grid
        if (entries.isEmpty)
          _buildMutedNote('No employees match your search', isDark: isDark)
        else if (widget.isWide)
          _buildWideGrid(entries)
        else
          _buildNarrowList(entries),
      ],
    );
  }

  Widget _buildWideGrid(List<MapEntry<String, double>> entries) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 3) {
      final chunk = entries.sublist(i, i + 3 > entries.length ? entries.length : i + 3);
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 16));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: 16),
              Expanded(child: _employeeCard(chunk[j])),
            ],
            // Fill remaining slots to keep uniform width
            for (var j = chunk.length; j < 3; j++) ...[
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildNarrowList(List<MapEntry<String, double>> entries) {
    return Column(
      children: entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _employeeCard(e),
      )).toList(),
    );
  }

  Widget _employeeCard(MapEntry<String, double> entry) {
    final seconds = entry.value;
    final color = seconds < 300
        ? VividColors.statusSuccess
        : seconds < 1800
            ? VividColors.statusWarning
            : VividColors.statusUrgent;

    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final tp = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
      final tm = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
      return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: isDark ? VividColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(entry.key, style: TextStyle(
                  color: tp, fontSize: 14, fontWeight: FontWeight.w500,
                ), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Avg reply time', style: TextStyle(
                  color: tm.withValues(alpha: 0.7), fontSize: 11,
                )),
              ],
            ),
          ),
          Text(_fmtDuration(seconds), style: TextStyle(
            color: color, fontSize: 24, fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
    });
  }
}

// ================================================================
// BROADCASTS VIEW
// ================================================================

class _BroadcastsView extends StatelessWidget {
  final AnalyticsData data;
  final bool isWide;
  final String? selectedCampaignId;
  final ValueChanged<String?> onCampaignChanged;

  const _BroadcastsView({
    required this.data,
    required this.isWide,
    required this.selectedCampaignId,
    required this.onCampaignChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCampaignFilter(context),
        const SizedBox(height: 24),
        if (selectedCampaignId == null)
          _buildAllCampaignsView(context)
        else
          _buildSingleCampaignView(context),
      ],
    );
  }

  Widget _buildCampaignFilter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? VividColors.navy : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedCampaignId,
          hint: Text('All Campaigns', style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13)),
          icon: Icon(Icons.keyboard_arrow_down, color: isDark ? VividColors.textMuted : const Color(0xFF64748B), size: 18),
          dropdownColor: isDark ? VividColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All Campaigns')),
            ...data.campaigns.map((c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onCampaignChanged,
        ),
      ),
    );
  }

  Widget _buildAllCampaignsView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalLeads = data.campaigns.fold<int>(0, (s, c) => s + c.leads);
    final totalRevenue = data.campaigns.fold<double>(0, (s, c) => s + c.revenue);
    final avgEngagement = data.campaigns.isNotEmpty
        ? data.campaigns.fold<double>(0, (s, c) => s + c.engagementRate) / data.campaigns.length
        : 0.0;
    final totalResponded = data.campaigns.fold<int>(0, (s, c) => s + c.responded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: TextStyle(
          color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        // Row 1
        _cardRow(isWide, [
          _MetricCard(icon: Icons.people_alt, label: 'Total Leads', value: '$totalLeads',
              color: VividColors.cyan, description: 'From campaigns', isHighlight: true,
              onTap: data.campaigns.any((c) => c.leadContributors.isNotEmpty)
                  ? () => showDialog(context: context, builder: (_) =>
                      _AllCampaignsLeadsDialog(campaigns: data.campaigns))
                  : null),
          _MetricCard(icon: Icons.attach_money, label: 'Total Revenue',
              value: totalRevenue > 0 ? '${totalRevenue.toStringAsFixed(0)} BHD' : '0 BHD',
              color: Colors.green, description: 'Campaign conversions',
              onTap: totalRevenue > 0
                  ? () => showDialog(context: context, builder: (_) =>
                      _AllCampaignsRevenueDialog(campaigns: data.campaigns))
                  : null),
          _MetricCard(icon: Icons.trending_up, label: 'Avg Engagement',
              value: '${avgEngagement.toStringAsFixed(1)}%',
              color: VividColors.brightBlue,
              description: 'Campaign recipients who replied (scoped to broadcasts only)',
              isHighlight: avgEngagement > 20,
              onTap: data.campaigns.isNotEmpty
                  ? () => showDialog(context: context, builder: (_) =>
                      _AllCampaignsEngagementDialog(campaigns: data.campaigns))
                  : null),
        ]),
        const SizedBox(height: 20),
        // Row 2
        _cardRow(isWide, [
          _MetricCard(icon: Icons.campaign, label: 'Campaigns Sent',
              value: '${data.campaigns.length}',
              color: VividColors.brightBlue, description: 'Total broadcasts',
              onTap: data.campaigns.isNotEmpty
                  ? () => showDialog(context: context, builder: (_) =>
                      _AllCampaignsListDialog(campaigns: data.campaigns))
                  : null),
          _MetricCard(icon: Icons.reply, label: 'Responded',
              value: '$totalResponded',
              color: VividColors.cyan, description: 'Unique replies',
              onTap: data.campaigns.any((c) => c.respondedCustomers.isNotEmpty)
                  ? () => showDialog(context: context, builder: (_) =>
                      _AllRespondedDialog(campaigns: data.campaigns))
                  : null),
        ]),
        const SizedBox(height: 32),
        Text('Campaign Performance', style: TextStyle(
          color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (data.campaigns.isEmpty)
          _buildMutedNote('No campaigns yet')
        else
          _buildCampaignsTable(context),
      ],
    );
  }

  Widget _buildCampaignsTable(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = [...data.campaigns]..sort((a, b) {
        if (a.sentAt == null && b.sentAt == null) return 0;
        if (a.sentAt == null) return 1;
        if (b.sentAt == null) return -1;
        return b.sentAt!.compareTo(a.sentAt!);
      });

    return Container(
      width: double.infinity,
      decoration: _cardBoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: const [
            Expanded(flex: 3, child: _TableHeader('CAMPAIGN')),
            Expanded(flex: 1, child: _TableHeader('SENT', center: true)),
            Expanded(flex: 1, child: _TableHeader('RESPONDED', center: true)),
            Expanded(flex: 1, child: _TableHeader('LEADS', center: true)),
            Expanded(flex: 1, child: _TableHeader('REVENUE', center: true)),
            Expanded(flex: 1, child: _TableHeader('ENG. RATE', center: true)),
          ]),
        ),
        // Rows
        ...sorted.asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: idx < sorted.length - 1
                  ? Border(bottom: BorderSide(color: VividColors.tealBlue.withValues(alpha: 0.1)))
                  : null,
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  if (c.sentAt != null)
                    Text('${c.sentAt!.day}/${c.sentAt!.month}/${c.sentAt!.year}',
                        style: TextStyle(color: isDark ? VividColors.textMuted : const Color(0xFF64748B), fontSize: 11)),
                ],
              )),
              Expanded(flex: 1, child: _tableCell('${c.sent}')),
              Expanded(flex: 1, child: _tableCell('${c.responded}')),
              Expanded(flex: 1, child: _tableCell('${c.leads}')),
              Expanded(flex: 1, child: _tableCell(
                  c.revenue > 0 ? '${c.revenue.toStringAsFixed(0)} BHD' : '-')),
              Expanded(flex: 1, child: _tableCell(
                  '${c.engagementRate.toStringAsFixed(1)}%')),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildSingleCampaignView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final campaign = data.campaigns.where((c) => c.id == selectedCampaignId).firstOrNull;
    if (campaign == null) return _buildMutedNote('Campaign not found');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Campaign Details', style: TextStyle(
          color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _cardRow(isWide, [
          _MetricCard(icon: Icons.send, label: 'Sent', value: '${campaign.sent}',
              color: VividColors.brightBlue, description: 'Recipients',
              onTap: campaign.recipients.isNotEmpty
                  ? () => showDialog(context: context, builder: (_) =>
                      _CampaignRecipientsDialog(
                        recipients: campaign.recipients,
                        campaignName: campaign.name,
                      ))
                  : null),
          _MetricCard(icon: Icons.reply, label: 'Responded', value: '${campaign.responded}',
              color: VividColors.statusSuccess, description: 'Unique replies',
              onTap: campaign.respondedCustomers.isNotEmpty
                  ? () => showDialog(context: context, builder: (_) =>
                      _CampaignRespondedDialog(
                        customers: campaign.respondedCustomers,
                        campaignName: campaign.name,
                      ))
                  : null),
          _MetricCard(icon: Icons.people_alt, label: 'Leads', value: '${campaign.leads}',
              color: VividColors.cyan, description: 'From this campaign',
              onTap: campaign.leadContributors.isNotEmpty
                  ? () => showDialog(
                      context: context,
                      builder: (_) => _LeadsDialog(
                        title: '${campaign.name} — Leads',
                        leads: campaign.leadContributors,
                      ))
                  : null),
        ]),
        const SizedBox(height: 20),
        _cardRow(isWide, [
          _MetricCard(
            icon: Icons.event_available,
            label: 'Appointments Booked',
            value: '${campaign.appointmentCustomers.length}',
            color: Colors.green,
            description: 'From this campaign',
            onTap: campaign.appointmentCustomers.isNotEmpty
                ? () => showDialog(
                    context: context,
                    builder: (_) => _CampaignLabeledDialog(
                      title: 'Appointments Booked',
                      customers: campaign.appointmentCustomers,
                      color: Colors.green,
                    ))
                : null,
          ),
          _MetricCard(
            icon: Icons.payments,
            label: 'Payment Done',
            value: '${campaign.paymentCustomers.length}',
            color: VividColors.cyan,
            description: campaign.revenue > 0
                ? '${campaign.revenue.toStringAsFixed(0)} BHD revenue'
                : 'No revenue yet',
            onTap: campaign.paymentCustomers.isNotEmpty
                ? () => showDialog(
                    context: context,
                    builder: (_) => _CampaignLabeledDialog(
                      title: 'Payment Done',
                      customers: campaign.paymentCustomers,
                      color: VividColors.cyan,
                    ))
                : null,
          ),
        ]),
        const SizedBox(height: 20),
        _cardRow(isWide, [
          _MetricCard(
            icon: Icons.attach_money,
            label: 'Revenue',
            value: campaign.revenue > 0 ? '${campaign.revenue.toStringAsFixed(0)} BHD' : '0 BHD',
            color: Colors.green,
            description: 'Offer: ${campaign.offerAmount.toStringAsFixed(0)} BHD × ${campaign.paymentCustomers.length}',
            onTap: campaign.paymentCustomers.isNotEmpty
                ? () => showDialog(
                    context: context,
                    builder: (_) => _CampaignLabeledDialog(
                      title: 'Revenue Breakdown',
                      customers: campaign.paymentCustomers,
                      color: Colors.green,
                      showRevenue: true,
                    ))
                : null,
          ),
          _MetricCard(
            icon: Icons.trending_up, label: 'Engagement Rate',
            value: '${campaign.engagementRate.toStringAsFixed(1)}%',
            color: campaign.engagementRate >= 10 ? VividColors.statusSuccess
                : campaign.engagementRate >= 5 ? VividColors.statusWarning : VividColors.brightBlue,
            description: '${campaign.responded}/${campaign.sent} responded',
            onTap: campaign.respondedCustomers.isNotEmpty
                ? () => showDialog(context: context, builder: (_) =>
                    _CampaignRespondedDialog(
                      customers: campaign.respondedCustomers,
                      campaignName: campaign.name,
                    ))
                : null,
          ),
        ]),
        if (data.dailyBreakdown.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('Daily Breakdown', style: TextStyle(
            color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (isWide)
            Row(children: [
              Expanded(child: _TrendChart(title: 'Leads per Day', days: data.dailyBreakdown,
                  compDays: data.comparisonDailyBreakdown,
                  valueExtractor: (d) => d.leads.toDouble(),
                  formatValue: (v) => v.toInt().toString(), barColor: VividColors.cyan)),
              const SizedBox(width: 20),
              Expanded(child: _TrendChart(title: 'Revenue per Day', days: data.dailyBreakdown,
                  compDays: data.comparisonDailyBreakdown,
                  valueExtractor: (d) => d.revenue,
                  formatValue: (v) => '${v.toStringAsFixed(0)} BHD', barColor: Colors.green)),
            ])
          else ...[
            _TrendChart(title: 'Leads per Day', days: data.dailyBreakdown,
                compDays: data.comparisonDailyBreakdown,
                valueExtractor: (d) => d.leads.toDouble(),
                formatValue: (v) => v.toInt().toString(), barColor: VividColors.cyan),
            const SizedBox(height: 20),
            _TrendChart(title: 'Revenue per Day', days: data.dailyBreakdown,
                compDays: data.comparisonDailyBreakdown,
                valueExtractor: (d) => d.revenue,
                formatValue: (v) => '${v.toStringAsFixed(0)} BHD', barColor: Colors.green),
          ],
          const SizedBox(height: 20),
          _TrendChart(title: 'Engagement Rate', days: data.dailyBreakdown,
              compDays: data.comparisonDailyBreakdown,
              valueExtractor: (d) => d.engagementRate,
              formatValue: (v) => '${v.toStringAsFixed(1)}%', barColor: VividColors.brightBlue),
        ],
      ],
    );
  }
}

// ================================================================
// SHARED HELPERS
// ================================================================

BoxDecoration _cardBoxDecoration({bool isDark = true, bool isHighlight = false, Color? highlightColor}) {
  return BoxDecoration(
    color: isDark ? VividColors.navy : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isHighlight
          ? (highlightColor ?? VividColors.cyan).withValues(alpha: 0.5)
          : isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
      width: isHighlight ? 2 : 1,
    ),
    boxShadow: isHighlight && highlightColor != null
        ? [BoxShadow(color: highlightColor.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))]
        : !isDark
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
  );
}

Widget _cardRow(bool isWide, List<Widget> cards) {
  if (isWide) {
    final children = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      children.add(Expanded(child: cards[i]));
      if (i < cards.length - 1) children.add(const SizedBox(width: 20));
    }
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
  }
  return Column(
    children: cards.expand((c) => [c, const SizedBox(height: 12)]).toList()..removeLast(),
  );
}

Widget _buildStatusCard(String text, IconData icon, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500))),
    ]),
  );
}

Widget _buildMutedNote(String text, {bool isDark = true}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: _cardBoxDecoration(isDark: isDark),
    child: Center(
      child: Text(text, style: TextStyle(
        color: isDark ? VividColors.textMuted : const Color(0xFF94A3B8), fontSize: 13)),
    ),
  );
}

Widget _tableCell(String text, {Color? color, bool bold = false, bool isDark = true}) {
  return Text(text, textAlign: TextAlign.center, style: TextStyle(
    color: color ?? (isDark ? VividColors.textSecondary : const Color(0xFF475569)), fontSize: 13,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
  ));
}

class _FunnelStage {
  final String label;
  final int count;
  final Color color;
  const _FunnelStage(this.label, this.count, this.color);
}

String _emptyStateMessage(String title) {
  final t = title.toLowerCase();
  if (t.contains('revenue')) {
    return 'No payments recorded in this period.\nRevenue is tracked when a customer completes a payment linked to a campaign.';
  }
  if (t.contains('engagement')) {
    return 'No engagement data yet.\nThis metric shows inbound replies relative to broadcast messages sent.';
  }
  if (t.contains('response')) {
    return 'No response time data yet.\nThis tracks how quickly agents reply to customer messages.';
  }
  if (t.contains('lead')) {
    return 'No leads in this period.\nLeads are counted when a new customer conversation starts.';
  }
  return 'No data for this period';
}

String _fmtDuration(double seconds) {
  if (seconds <= 0) return '0s';
  if (seconds < 60) return '${seconds.toStringAsFixed(0)}s';
  if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}m';
  final h = seconds ~/ 3600;
  final m = ((seconds % 3600) / 60).toInt();
  return '${h}h ${m}m';
}

String _fmtWaitTime(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

// ================================================================
// TABLE HEADER
// ================================================================

class _TableHeader extends StatelessWidget {
  final String text;
  final bool center;
  const _TableHeader(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(text, textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: isDark ? VividColors.textMuted : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ));
  }
}

// ================================================================
// METRIC CARD
// ================================================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? description;
  final bool isHighlight;
  final double? change;
  final bool invertChange;
  final String? compareLabel;
  final bool pulse;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.description,
    this.isHighlight = false,
    this.change,
    this.invertChange = false,
    this.compareLabel,
    this.pulse = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? VividColors.navy : Colors.white;
    final borderColor = isHighlight
        ? color.withValues(alpha: 0.5)
        : isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0);
    final labelColor = isDark ? VividColors.textMuted : const Color(0xFF64748B);
    final descColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isHighlight ? 2 : 1),
        boxShadow: isHighlight
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))]
            : !isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: pulse
                  ? _PulsingIcon(icon: icon, color: color)
                  : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(
                color: labelColor, fontSize: 14, fontWeight: FontWeight.w500,
              ), overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(
              color: color, fontSize: 36, fontWeight: FontWeight.bold, height: 1,
            )),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, style: TextStyle(
              color: descColor, fontSize: 12,
            ), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (change != null) ...[
            const SizedBox(height: 4),
            _buildChangeIndicator(isDark),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }
    return card;
  }

  Widget _buildChangeIndicator(bool isDark) {
    if (change == null) return const SizedBox.shrink();
    final isPositive = change! > 0;
    final isNegative = change! < 0;
    final isGood = invertChange ? isNegative : isPositive;
    final isBad = invertChange ? isPositive : isNegative;
    final Color indicatorColor;
    if (isGood) {
      indicatorColor = VividColors.statusSuccess;
    } else if (isBad) {
      indicatorColor = VividColors.statusUrgent;
    } else {
      indicatorColor = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    }
    // Arrow shows actual direction of change; color shows good/bad
    final arrow = isPositive ? '\u25B2' : '\u25BC';
    final text = '${change!.abs().toStringAsFixed(0)}%';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$arrow $text', style: TextStyle(color: indicatorColor, fontSize: 11, fontWeight: FontWeight.w600)),
        if (compareLabel != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: ' vs. ', style: TextStyle(color: (isDark ? VividColors.textMuted : const Color(0xFF94A3B8)).withValues(alpha: 0.5), fontSize: 10)),
                TextSpan(text: compareLabel!, style: TextStyle(color: (isDark ? VividColors.textMuted : const Color(0xFF64748B)).withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

// ================================================================
// PULSING ICON (for live metrics)
// ================================================================

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}

// ================================================================
// TREND CHART
// ================================================================

class _TrendChart extends StatefulWidget {
  final String title;
  final List<DailyBreakdown> days;
  final List<DailyBreakdown>? compDays;
  final double Function(DailyBreakdown) valueExtractor;
  final String Function(double) formatValue;
  final Color barColor;

  const _TrendChart({
    required this.title,
    required this.days,
    this.compDays,
    required this.valueExtractor,
    required this.formatValue,
    required this.barColor,
  });

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final axisLabelColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final days = widget.days.length > 60 ? widget.days.sublist(widget.days.length - 60) : widget.days;
    if (days.isEmpty) {
      return SizedBox(
        height: 280,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: _cardBoxDecoration(isDark: isDark),
          child: Center(
            child: Text(_emptyStateMessage(widget.title),
                style: TextStyle(color: isDark ? VividColors.textMuted.withValues(alpha: 0.5) : const Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final values = days.map(widget.valueExtractor).toList();
    final compValues = widget.compDays != null
        ? widget.compDays!.map(widget.valueExtractor).toList()
        : <double>[];
    final allValues = [...values, ...compValues];
    final maxVal = allValues.isEmpty ? 1.0 : allValues.reduce(max);
    final avgVal = values.isNotEmpty ? values.reduce((a, b) => a + b) / values.length : 0.0;
    final allZero = values.every((v) => v == 0);

    if (allZero) {
      return SizedBox(
        height: 280,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: _cardBoxDecoration(isDark: isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: TextStyle(color: widget.barColor, fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Center(child: Text(
                _emptyStateMessage(widget.title),
                style: TextStyle(color: isDark ? VividColors.textMuted.withValues(alpha: 0.5) : const Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              )),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    const chartHeight = 160.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 280),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardBoxDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(widget.title,
                style: TextStyle(color: widget.barColor, fontSize: 14, fontWeight: FontWeight.w500))),
            if (_hoveredIndex != null && _hoveredIndex! < days.length)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_shortDate(days[_hoveredIndex!].date)}: ${widget.formatValue(values[_hoveredIndex!])}',
                  style: TextStyle(color: widget.barColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: chartHeight,
            child: Row(
              children: [
                // Y-axis labels
                SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.formatValue(maxVal),
                          style: TextStyle(color: axisLabelColor, fontSize: 9)),
                      Text(widget.formatValue(maxVal / 2),
                          style: TextStyle(color: axisLabelColor, fontSize: 9)),
                      Text('0',
                          style: TextStyle(color: axisLabelColor, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chart area (line graph)
                Expanded(
                  child: MouseRegion(
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartW = constraints.maxWidth;
                        return Stack(children: [
                          // Avg line
                          if (maxVal > 0 && avgVal > 0)
                            Positioned(
                              bottom: (avgVal / maxVal) * (chartHeight - 10),
                              left: 0, right: 0,
                              child: CustomPaint(
                                size: const Size(double.infinity, 1),
                                painter: _DottedLinePainter(color: VividColors.tealBlue.withValues(alpha: 0.15)),
                              ),
                            ),
                          // Comparison line + fill
                          if (compValues.isNotEmpty)
                            CustomPaint(
                              size: Size(chartW, chartHeight),
                              painter: _LineChartPainter(
                                values: compValues,
                                maxVal: maxVal,
                                color: Colors.white.withValues(alpha: 0.35),
                                fillAlpha: 0.05,
                              ),
                            ),
                          // Current line + fill
                          CustomPaint(
                            size: Size(chartW, chartHeight),
                            painter: _LineChartPainter(
                              values: values,
                              maxVal: maxVal,
                              color: widget.barColor,
                              fillAlpha: 0.15,
                            ),
                          ),
                          // Hover detection areas
                          Row(
                            children: List.generate(days.length, (i) {
                              return Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoveredIndex = i),
                                  child: Tooltip(
                                    message: '${days[i].date}\n${widget.formatValue(values[i])}',
                                    child: SizedBox(height: chartHeight),
                                  ),
                                ),
                              );
                            }),
                          ),
                          // Hover dot
                          if (_hoveredIndex != null && _hoveredIndex! < values.length)
                            Positioned(
                              left: days.length > 1
                                  ? (_hoveredIndex! / (days.length - 1)) * (chartW - 4)
                                  : chartW / 2 - 2,
                              bottom: maxVal > 0 ? (values[_hoveredIndex!] / maxVal) * (chartHeight - 10) - 4 : 0,
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: widget.barColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: widget.barColor.withValues(alpha: 0.5), blurRadius: 6)],
                                ),
                              ),
                            ),
                        ]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (days.length >= 3)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_shortDate(days.first.date), style: TextStyle(color: axisLabelColor, fontSize: 10)),
              Text(_shortDate(days[days.length ~/ 2].date), style: TextStyle(color: axisLabelColor, fontSize: 10)),
              Text(_shortDate(days.last.date), style: TextStyle(color: axisLabelColor, fontSize: 10)),
            ]),
          if (widget.compDays != null && widget.compDays!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(widget.barColor, 'Current', axisLabelColor),
              const SizedBox(width: 20),
              _legendDot(isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFFCBD5E1), 'Previous', axisLabelColor),
            ]),
          ],
        ],
      ),
    ),
    );
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    if (parts.length == 3) return '${parts[1]}/${parts[2]}';
    return date;
  }

  Widget _legendDot(Color color, String label, Color labelColor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: labelColor.withValues(alpha: 0.7), fontSize: 11)),
    ]);
  }
}

// ================================================================
// DOTTED LINE PAINTER
// ================================================================

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================================================================
// LINE CHART PAINTER
// ================================================================

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final double maxVal;
  final Color color;
  final double fillAlpha;

  _LineChartPainter({
    required this.values,
    required this.maxVal,
    required this.color,
    this.fillAlpha = 0.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxVal <= 0) return;

    final h = size.height - 10; // match chartHeight - 10 padding
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length > 1 ? (i / (values.length - 1)) * size.width : size.width / 2;
      final y = size.height - (values[i] / maxVal) * h;
      points.add(Offset(x, y));
    }

    // Draw filled area
    if (points.length >= 2) {
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()..color = color.withValues(alpha: fillAlpha)..style = PaintingStyle.fill,
      );
    }

    // Draw line
    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxVal != maxVal || oldDelegate.color != color;
}

// ================================================================
// LEADS DIALOG (scrollable contributor list)
// ================================================================

class _LeadsDialog extends StatefulWidget {
  final String title;
  final List<LeadContributor> leads;

  const _LeadsDialog({required this.title, required this.leads});

  @override
  State<_LeadsDialog> createState() => _LeadsDialogState();
}

class _LeadsDialogState extends State<_LeadsDialog> {
  late List<LeadContributor> _leads;

  @override
  void initState() {
    super.initState();
    _leads = List.of(widget.leads);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final divColor = isDark ? VividColors.tealBlue.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.people_alt, color: VividColors.cyan, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title, style: TextStyle(
                      color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VividColors.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_leads.length}', style: const TextStyle(
                      color: VividColors.cyan, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Each entry represents a new conversation session (24h gap rule)',
                  style: TextStyle(color: textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              // List
              Expanded(
                child: _leads.isEmpty
                    ? Center(child: Text('No leads in this period',
                        style: TextStyle(color: textMuted, fontSize: 13)))
                    : ListView.separated(
                        itemCount: _leads.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: divColor),
                        itemBuilder: (context, i) {
                          final lead = _leads[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: VividColors.cyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    lead.displayName.isNotEmpty
                                        ? lead.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: VividColors.cyan, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lead.displayName, style: TextStyle(
                                        color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                      if (lead.name != null)
                                        Text(lead.phone, style: TextStyle(
                                          color: textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${lead.date.day}/${lead.date.month}/${lead.date.year}',
                                      style: TextStyle(color: textSecondary, fontSize: 12)),
                                    if (!lead.isOrganic)
                                      Text('via broadcast',
                                          style: TextStyle(color: textMuted, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setState(() => _leads.removeAt(i)),
                                  child: Tooltip(
                                    message: 'Hide from this view',
                                    child: Icon(Icons.close, size: 15,
                                        color: VividColors.statusUrgent.withValues(alpha: 0.7)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CAMPAIGN LABELED DIALOG (Appointment Booked / Payment Done lists)
// ================================================================

class _CampaignLabeledDialog extends StatefulWidget {
  final String title;
  final List<LabeledCustomer> customers;
  final Color color;
  final bool showRevenue;

  const _CampaignLabeledDialog({
    required this.title,
    required this.customers,
    required this.color,
    this.showRevenue = false,
  });

  @override
  State<_CampaignLabeledDialog> createState() => _CampaignLabeledDialogState();
}

class _CampaignLabeledDialogState extends State<_CampaignLabeledDialog> {
  late List<LabeledCustomer> _customers;

  @override
  void initState() {
    super.initState();
    _customers = List.of(widget.customers);
  }

  void _handleRemove(LabeledCustomer customer) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? VividColors.navy : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove label?',
            style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'This will clear the label for ${customer.displayName} in Supabase.',
          style: TextStyle(color: isDark ? VividColors.textSecondary : const Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? VividColors.textMuted : const Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: VividColors.statusUrgent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _customers.removeWhere((c) => c.phone == customer.phone));
    try {
      await SupabaseService.instance.updateConversationLabel(
        customerPhone: customer.phone,
        label: '',
      );
    } catch (_) {
      setState(() => _customers = List.of(widget.customers));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final divColor = isDark ? VividColors.tealBlue.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final total = _customers.fold<double>(0, (s, c) => s + c.offerAmount);
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.people_alt, color: widget.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title, style: TextStyle(
                      color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_customers.length}', style: TextStyle(
                      color: widget.color, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              // Revenue summary (for Revenue Breakdown view)
              if (widget.showRevenue && _customers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_customers[0].offerAmount.toStringAsFixed(0)} BHD × ${_customers.length} = ${total.toStringAsFixed(0)} BHD',
                        style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Customer list
              Expanded(
                child: _customers.isEmpty
                    ? Center(child: Text('No customers yet',
                        style: TextStyle(color: textMuted, fontSize: 13)))
                    : ListView.separated(
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: divColor),
                        itemBuilder: (context, i) {
                          final c = _customers[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: widget.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                                    style: TextStyle(color: widget.color, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.displayName, style: TextStyle(
                                        color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                      if (c.name != null)
                                        Text(c.phone, style: TextStyle(
                                          color: textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${c.date.day}/${c.date.month}/${c.date.year}',
                                      style: TextStyle(color: textSecondary, fontSize: 12)),
                                    if (widget.showRevenue)
                                      Text(
                                        '${c.offerAmount.toStringAsFixed(0)} BHD',
                                        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _handleRemove(c),
                                  child: Tooltip(
                                    message: 'Clear label in Supabase',
                                    child: Icon(Icons.close, size: 15,
                                        color: VividColors.statusUrgent.withValues(alpha: 0.7)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// PIPELINE DIALOG (Kanban-style: Booked → Paid)
// ================================================================

class _PipelineDialog extends StatefulWidget {
  final List<LabeledCustomer> customers;

  const _PipelineDialog({required this.customers});

  @override
  State<_PipelineDialog> createState() => _PipelineDialogState();
}

class _PipelineDialogState extends State<_PipelineDialog> {
  late List<LabeledCustomer> _booked;
  late List<LabeledCustomer> _paid;

  @override
  void initState() {
    super.initState();
    _categorize();
  }

  void _categorize() {
    // Customers with payment done are in "paid", rest in "booked"
    final paidPhones = <String>{};
    for (final c in widget.customers) {
      if (c.label == 'payment done') paidPhones.add(c.phone);
    }
    _booked = widget.customers
        .where((c) => c.label == 'appointment booked' && !paidPhones.contains(c.phone))
        .toList();
    _paid = widget.customers
        .where((c) => c.label == 'payment done')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.view_kanban, color: VividColors.cyan, size: 24),
                  const SizedBox(width: 10),
                  Text('Customer Pipeline', style: TextStyle(
                    color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: textMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Drag customers between stages to update their status',
                  style: TextStyle(color: textMuted, fontSize: 12)),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildColumn(
                      'Appointment Booked',
                      Icons.event_available,
                      Colors.green,
                      _booked,
                      'appointment booked',
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildColumn(
                      'Payment Done',
                      Icons.payments,
                      const Color(0xFF06B6D4),
                      _paid,
                      'payment done',
                      revenueHeader: _buildRevenueHeader(_paid),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueHeader(List<LabeledCustomer> paid) {
    if (paid.isEmpty) return const SizedBox.shrink();
    final total = paid.fold<double>(0, (s, c) => s + c.offerAmount);

    // Group by campaign name (null → Organic)
    final Map<String, List<LabeledCustomer>> byCampaign = {};
    for (final c in paid) {
      final key = c.campaignName ?? 'Organic';
      byCampaign.putIfAbsent(key, () => []).add(c);
    }

    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.calculate, color: Colors.green, size: 14),
              const SizedBox(width: 6),
              Text(
                'Total: ${total.toStringAsFixed(0)} BHD',
                style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ]),
            if (byCampaign.length > 1) ...[
              const SizedBox(height: 6),
              ...byCampaign.entries.map((e) {
                final offerPerUnit = e.value.isNotEmpty ? e.value.first.offerAmount : 0.0;
                final sub = e.value.fold<double>(0, (s, c) => s + c.offerAmount);
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(e.key,
                          style: TextStyle(
                            color: isDark ? VividColors.textMuted : const Color(0xFF64748B),
                            fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${offerPerUnit.toStringAsFixed(0)}×${e.value.length} = ${sub.toStringAsFixed(0)} BHD',
                      style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ]),
                );
              }),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildColumn(String title, IconData icon, Color color, List<LabeledCustomer> items, String targetLabel, {Widget? revenueHeader}) {
    return DragTarget<LabeledCustomer>(
      onWillAcceptWithDetails: (details) => details.data.label != targetLabel,
      onAcceptWithDetails: (details) {
        _handleDrop(details.data, targetLabel);
      },
      builder: (context, candidateData, rejectedData) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovering ? color.withValues(alpha: 0.08) : (isDark ? VividColors.navy : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering ? color.withValues(alpha: 0.5) : (isDark ? VividColors.tealBlue.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${items.length}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
              if (revenueHeader != null) ...[
                const SizedBox(height: 10),
                revenueHeader,
              ] else
                const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(
                        isHovering ? 'Drop here' : 'No customers yet',
                        style: TextStyle(color: VividColors.textMuted.withValues(alpha: 0.5), fontSize: 12),
                      ))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildCustomerCard(
                          items[index], color,
                          onRemove: () => _handleRemove(items[index]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerCard(LabeledCustomer customer, Color color, {required VoidCallback onRemove}) {
    return Draggable<LabeledCustomer>(
      data: customer,
      feedback: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Material(
            color: Colors.transparent,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? VividColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.5)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: Text(customer.displayName,
                  style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 13)),
            ),
          );
        }
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _CustomerTile(customer: customer, color: color, onRemove: onRemove),
      ),
      child: _CustomerTile(customer: customer, color: color, onRemove: onRemove),
    );
  }

  void _handleRemove(LabeledCustomer customer) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? VividColors.navy : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove from pipeline?',
            style: TextStyle(color: isDark ? VividColors.textPrimary : const Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'This will clear the label for ${customer.displayName} and remove them from the pipeline.',
          style: TextStyle(color: isDark ? VividColors.textSecondary : const Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? VividColors.textMuted : const Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: VividColors.statusUrgent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _booked.removeWhere((c) => c.phone == customer.phone);
      _paid.removeWhere((c) => c.phone == customer.phone);
    });

    try {
      await SupabaseService.instance.updateConversationLabel(
        customerPhone: customer.phone,
        label: '',
      );
    } catch (_) {
      setState(() => _categorize());
    }
  }

  void _handleDrop(LabeledCustomer customer, String targetLabel) async {
    // Optimistic update
    setState(() {
      if (targetLabel == 'payment done') {
        _booked.removeWhere((c) => c.phone == customer.phone);
        _paid.add(LabeledCustomer(
          phone: customer.phone, name: customer.name,
          label: 'payment done', date: DateTime.now(),
        ));
      } else {
        _paid.removeWhere((c) => c.phone == customer.phone);
        _booked.add(LabeledCustomer(
          phone: customer.phone, name: customer.name,
          label: 'appointment booked', date: DateTime.now(),
        ));
      }
    });

    // Update in Supabase
    try {
      final titleLabel = targetLabel == 'payment done' ? 'Payment Done' : 'Appointment Booked';
      await SupabaseService.instance.updateConversationLabel(
        customerPhone: customer.phone,
        label: titleLabel,
      );
    } catch (e) {
      // Revert on error
      setState(() => _categorize());
    }
  }

}

// ================================================================
// CUSTOMER TILE (hoverable, with remove button)
// ================================================================

class _CustomerTile extends StatefulWidget {
  final LabeledCustomer customer;
  final Color color;
  final VoidCallback onRemove;

  const _CustomerTile({
    required this.customer,
    required this.color,
    required this.onRemove,
  });

  @override
  State<_CustomerTile> createState() => _CustomerTileState();
}

class _CustomerTileState extends State<_CustomerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered
              ? (isDark ? VividColors.deepBlue : const Color(0xFFF1F5F9))
              : (isDark ? VividColors.darkNavy : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.3)
                : isDark ? VividColors.tealBlue.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.customer.displayName, style: TextStyle(
                    color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(widget.customer.phone, style: TextStyle(
                    color: textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.customer.date.day}/${widget.customer.date.month}/${widget.customer.date.year}',
                    style: TextStyle(color: widget.color.withValues(alpha: 0.7), fontSize: 10),
                  ),
                ],
              ),
            ),
            if (_hovered)
              GestureDetector(
                onTap: widget.onRemove,
                child: Tooltip(
                  message: 'Remove from pipeline',
                  child: Icon(Icons.close, size: 16, color: VividColors.statusUrgent.withValues(alpha: 0.8)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SHARED DIALOG HELPERS
// ================================================================

/// Generic header row used by all analytics detail dialogs.
Widget _dialogHeader(BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required int count,
  String? subtitle,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
  final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(
          color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: textMuted, size: 20),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: textMuted, fontSize: 12)),
      ],
    ],
  );
}

Widget _emptyState(String msg, {bool isDark = true}) => Center(
  child: Text(msg, style: TextStyle(
    color: isDark ? VividColors.textMuted : const Color(0xFF94A3B8), fontSize: 13)));

Widget _dialogDivider({bool isDark = true}) =>
    Divider(height: 1, color: isDark ? VividColors.tealBlue.withValues(alpha: 0.1) : const Color(0xFFE2E8F0));

// ================================================================
// ENGAGED CUSTOMERS DIALOG (Engagement Rate)
// ================================================================

class _EngagedCustomersDialog extends StatelessWidget {
  final List<EngagedCustomer> customers;
  const _EngagedCustomersDialog({required this.customers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final sorted = [...customers]..sort((a, b) => b.date.compareTo(a.date));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.trending_up, color: VividColors.brightBlue,
              title: 'Engaged Customers',
              count: sorted.length,
              subtitle: 'Campaign recipients who sent at least one reply'),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty ? _emptyState('No engaged customers', isDark: isDark) :
              ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = sorted[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(c.displayName, VividColors.brightBlue),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (c.name != null)
                          Text(c.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Text('${c.date.day}/${c.date.month}/${c.date.year}',
                          style: TextStyle(color: textSecondary, fontSize: 12)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// RESPONSE TIMES DIALOG (Avg Response Time)
// ================================================================

class _ResponseTimesDialog extends StatelessWidget {
  final List<ResponseTimeEntry> entries;
  const _ResponseTimesDialog({required this.entries});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final sorted = [...entries]..sort((a, b) => b.responseTimeSeconds.compareTo(a.responseTimeSeconds));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.timer, color: Colors.orange,
              title: 'Response Times',
              count: sorted.length,
              subtitle: 'Per-conversation first-reply times (sorted slowest first)'),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty ? _emptyState('No response time data', isDark: isDark) :
              ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final e = sorted[i];
                  final isOver30m = e.responseTimeSeconds > 1800;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(e.displayName, Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (e.name != null)
                          Text(e.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isOver30m ? Colors.red : Colors.green).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _fmtDuration(e.responseTimeSeconds),
                          style: TextStyle(
                            color: isOver30m ? Colors.red : Colors.green,
                            fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// MESSAGES SENT DIALOG (per-agent breakdown)
// ================================================================

class _MessagesSentDialog extends StatelessWidget {
  final Map<String, int> agentCounts;
  final int automatedCount;
  const _MessagesSentDialog({required this.agentCounts, required this.automatedCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final agents = agentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = agents.fold<int>(0, (s, e) => s + e.value) + automatedCount;
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.send, color: VividColors.cyan,
              title: 'Messages Sent',
              count: total,
              subtitle: 'Breakdown by agent and automation'),
            const SizedBox(height: 16),
            Expanded(
              child: agents.isEmpty && automatedCount == 0
                  ? _emptyState('No sent messages', isDark: isDark)
                  : ListView(children: [
                      ...agents.map((e) => _agentRow(e.key, e.value, total, VividColors.cyan, textPrimary, isDark)),
                      if (automatedCount > 0)
                        _agentRow('Automated (Broadcast)', automatedCount, total,
                            isDark ? VividColors.textMuted : const Color(0xFF94A3B8), textPrimary, isDark),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _agentRow(String name, int count, int total, Color color, Color textPrimary, bool isDark) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: TextStyle(
            color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
          Text('$count  (${pct.toStringAsFixed(1)}%)',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: isDark ? VividColors.tealBlue.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
            minHeight: 4,
          ),
        ),
        _dialogDivider(isDark: isDark),
      ]),
    );
  }
}

// ================================================================
// INBOUND CUSTOMERS DIALOG (Messages Received)
// ================================================================

class _InboundCustomersDialog extends StatelessWidget {
  final List<InboundCustomer> customers;
  const _InboundCustomersDialog({required this.customers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.inbox, color: VividColors.brightBlue,
              title: 'Messages Received',
              count: customers.length,
              subtitle: 'Customers who sent messages (sorted by volume)'),
            const SizedBox(height: 16),
            Expanded(
              child: customers.isEmpty ? _emptyState('No inbound messages', isDark: isDark) :
              ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = customers[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(c.displayName, VividColors.brightBlue),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (c.name != null)
                          Text(c.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${c.messageCount} msg${c.messageCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: VividColors.cyan, fontSize: 12, fontWeight: FontWeight.w600)),
                        if (c.lastMessageAt != null)
                          Text(
                            '${c.lastMessageAt!.day}/${c.lastMessageAt!.month}/${c.lastMessageAt!.year}',
                            style: TextStyle(color: textMuted, fontSize: 10)),
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// OPEN / OVERDUE CONVERSATIONS DIALOG
// ================================================================

class _OpenConversationsDialog extends StatelessWidget {
  final List<OpenConversation> conversations;
  final String title;
  final Color color;
  const _OpenConversationsDialog({required this.conversations, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final sorted = [...conversations]..sort((a, b) => b.waitingTime.compareTo(a.waitingTime));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.chat_bubble_outline, color: color,
              title: title,
              count: sorted.length,
              subtitle: 'Sorted by longest wait time first'),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty ? _emptyState('No conversations', isDark: isDark) :
              ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = sorted[i];
                  final name = c.customerName ?? c.customerPhone;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _avatar(name, color),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (c.customerName != null)
                          Text(c.customerPhone, style: TextStyle(color: textMuted, fontSize: 11)),
                        const SizedBox(height: 3),
                        Text(
                          c.lastMessage.length > 70
                              ? '${c.lastMessage.substring(0, 70)}…'
                              : c.lastMessage,
                          style: TextStyle(color: textSecondary, fontSize: 11),
                          maxLines: 2,
                        ),
                      ])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_fmtWaitTime(c.waitingTime),
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// BROADCASTS — ALL CAMPAIGNS SUMMARY DIALOGS
// ================================================================

class _AllCampaignsLeadsDialog extends StatelessWidget {
  final List<CampaignPerformance> campaigns;
  const _AllCampaignsLeadsDialog({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final all = campaigns.expand((c) => c.leadContributors).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.people_alt, color: VividColors.cyan,
              title: 'Campaign Leads',
              count: all.length,
              subtitle: 'All lead sessions across campaigns (may include duplicates across campaigns)'),
            const SizedBox(height: 16),
            Expanded(
              child: all.isEmpty ? _emptyState('No leads yet', isDark: isDark) :
              ListView.separated(
                itemCount: all.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final l = all[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(l.displayName, VividColors.cyan),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (l.name != null)
                          Text(l.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Text('${l.date.day}/${l.date.month}/${l.date.year}',
                          style: TextStyle(color: textSecondary, fontSize: 12)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AllCampaignsRevenueDialog extends StatelessWidget {
  final List<CampaignPerformance> campaigns;
  const _AllCampaignsRevenueDialog({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final withRevenue = campaigns.where((c) => c.revenue > 0).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final total = withRevenue.fold<double>(0, (s, c) => s + c.revenue);
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.attach_money, color: Colors.green,
              title: 'Revenue Breakdown',
              count: withRevenue.length,
              subtitle: 'Per-campaign revenue from Payment Done labels'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.calculate, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text('Total: ${total.toStringAsFixed(0)} BHD',
                    style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: withRevenue.isEmpty ? _emptyState('No revenue yet', isDark: isDark) :
              ListView.separated(
                itemCount: withRevenue.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = withRevenue[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                        Text(
                          '${c.offerAmount.toStringAsFixed(0)} BHD × ${c.paymentCustomers.length}',
                          style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Text('${c.revenue.toStringAsFixed(0)} BHD',
                          style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AllCampaignsEngagementDialog extends StatelessWidget {
  final List<CampaignPerformance> campaigns;
  const _AllCampaignsEngagementDialog({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final sorted = [...campaigns]..sort((a, b) => b.engagementRate.compareTo(a.engagementRate));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.trending_up, color: VividColors.brightBlue,
              title: 'Engagement by Campaign',
              count: sorted.length,
              subtitle: 'Replied / Sent  (sorted highest first)'),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty ? _emptyState('No campaigns', isDark: isDark) :
              ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = sorted[i];
                  final color = c.engagementRate >= 10 ? VividColors.statusSuccess
                      : c.engagementRate >= 5 ? VividColors.statusWarning : VividColors.brightBlue;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                        Text('${c.responded} / ${c.sent} replied',
                            style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Text('${c.engagementRate.toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AllCampaignsListDialog extends StatelessWidget {
  final List<CampaignPerformance> campaigns;
  const _AllCampaignsListDialog({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final textSecondary = isDark ? VividColors.textSecondary : const Color(0xFF475569);
    final sorted = [...campaigns]..sort((a, b) {
        if (a.sentAt == null) return 1;
        if (b.sentAt == null) return -1;
        return b.sentAt!.compareTo(a.sentAt!);
      });
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.campaign, color: VividColors.brightBlue,
              title: 'Campaigns Sent',
              count: sorted.length,
              subtitle: 'All campaigns, newest first'),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty ? _emptyState('No campaigns', isDark: isDark) :
              ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = sorted[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                        if (c.sentAt != null)
                          Text('${c.sentAt!.day}/${c.sentAt!.month}/${c.sentAt!.year}',
                              style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${c.sent} recipients',
                            style: TextStyle(color: textSecondary, fontSize: 12)),
                        if (c.offerAmount > 0)
                          Text('${c.offerAmount.toStringAsFixed(0)} BHD offer',
                              style: const TextStyle(color: Colors.green, fontSize: 11)),
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AllRespondedDialog extends StatelessWidget {
  final List<CampaignPerformance> campaigns;
  const _AllRespondedDialog({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    // Deduplicate by phone — keep entry with highest message count
    final Map<String, InboundCustomer> dedup = {};
    for (final camp in campaigns) {
      for (final c in camp.respondedCustomers) {
        final ex = dedup[c.phone];
        if (ex == null || c.messageCount > ex.messageCount) dedup[c.phone] = c;
      }
    }
    final all = dedup.values.toList()
      ..sort((a, b) => b.messageCount.compareTo(a.messageCount));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.reply, color: VividColors.cyan,
              title: 'Campaign Responders',
              count: all.length,
              subtitle: 'Unique customers who replied to any campaign'),
            const SizedBox(height: 16),
            Expanded(
              child: all.isEmpty ? _emptyState('No responses yet', isDark: isDark) :
              ListView.separated(
                itemCount: all.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = all[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(c.displayName, VividColors.cyan),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (c.name != null)
                          Text(c.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Text('${c.messageCount} msg${c.messageCount == 1 ? '' : 's'}',
                          style: const TextStyle(color: VividColors.cyan, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// CAMPAIGN RECIPIENTS DIALOG (Sent card — single campaign)
// ================================================================

class _CampaignRecipientsDialog extends StatelessWidget {
  final List<CampaignRecipient> recipients;
  final String campaignName;
  const _CampaignRecipientsDialog({required this.recipients, required this.campaignName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.send, color: VividColors.brightBlue,
              title: 'Recipients',
              count: recipients.length,
              subtitle: campaignName),
            const SizedBox(height: 16),
            Expanded(
              child: recipients.isEmpty ? _emptyState('No recipients', isDark: isDark) :
              ListView.separated(
                itemCount: recipients.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final r = recipients[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(r.displayName, VividColors.brightBlue),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (r.name != null)
                          Text(r.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// CAMPAIGN RESPONDED DIALOG (Responded card — single campaign)
// ================================================================

class _CampaignRespondedDialog extends StatelessWidget {
  final List<InboundCustomer> customers;
  final String campaignName;
  const _CampaignRespondedDialog({required this.customers, required this.campaignName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? VividColors.textPrimary : const Color(0xFF1E293B);
    final textMuted = isDark ? VividColors.textMuted : const Color(0xFF94A3B8);
    final sorted = [...customers]..sort((a, b) => b.messageCount.compareTo(a.messageCount));
    return Dialog(
      backgroundColor: isDark ? VividColors.darkNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogHeader(context,
              icon: Icons.reply, color: VividColors.statusSuccess,
              title: 'Responded',
              count: sorted.length,
              subtitle: campaignName),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty ? _emptyState('No responses yet', isDark: isDark) :
              ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, __) => _dialogDivider(isDark: isDark),
                itemBuilder: (_, i) {
                  final c = sorted[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      _avatar(c.displayName, VividColors.statusSuccess),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.displayName, style: TextStyle(
                          color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        if (c.name != null)
                          Text(c.phone, style: TextStyle(color: textMuted, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${c.messageCount} msg${c.messageCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: VividColors.statusSuccess, fontSize: 12, fontWeight: FontWeight.w600)),
                        if (c.lastMessageAt != null)
                          Text(
                            '${c.lastMessageAt!.day}/${c.lastMessageAt!.month}/${c.lastMessageAt!.year}',
                            style: TextStyle(color: textMuted, fontSize: 10)),
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// SHARED AVATAR HELPER
// ================================================================

Widget _avatar(String name, Color color) {
  return Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );
}
