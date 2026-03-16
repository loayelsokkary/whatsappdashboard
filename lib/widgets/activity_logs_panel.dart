import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/activity_logs_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';
import '../utils/toast_service.dart';

class ActivityLogsPanel extends StatefulWidget {
  final String? clientId; // null for Vivid admin viewing all
  final String? clientName;
  final bool isAdmin; // true when used inside AdminPanel

  const ActivityLogsPanel({
    super.key,
    this.clientId,
    this.clientName,
    this.isAdmin = false,
  });

  @override
  State<ActivityLogsPanel> createState() => _ActivityLogsPanelState();
}

class _ActivityLogsPanelState extends State<ActivityLogsPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Track which log entries have expanded metadata
  final Set<String> _expandedMetadata = {};

  // Date preset selection
  String _datePreset = 'all'; // 'all', 'today', '7days', '30days', 'custom'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLogs();
    });
    _scrollController.addListener(_onScroll);
  }

  void _loadLogs() {
    final provider = context.read<ActivityLogsProvider>();
    if (widget.clientId != null) {
      provider.fetchLogs(clientId: widget.clientId);
    } else {
      provider.fetchAllLogs();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<ActivityLogsProvider>();
      // First exhaust the local display buffer, then fetch more from server
      if (provider.hasMoreToDisplay) {
        provider.showMore();
      } else if (provider.hasMore && !provider.isLoadingMore) {
        provider.loadMore();
      }
    }
  }

  static String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 10000) {
      final thousands = count ~/ 1000;
      final remainder = (count % 1000) ~/ 100;
      return remainder > 0 ? '$thousands,${(count % 1000).toString().padLeft(3, '0')}' : '${thousands}k';
    }
    return '${(count / 1000).toStringAsFixed(1)}k';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityLogsProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(provider, isMobile),
                  const SizedBox(height: 16),
                  _buildFilters(provider, isMobile),
                  const SizedBox(height: 16),
                  _buildStats(provider, isMobile),
                  const SizedBox(height: 16),
                  Expanded(child: _buildLogsList(provider, isMobile)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════

  Widget _buildHeader(ActivityLogsProvider provider, bool isMobile) {
    final vc = context.vividColors;
    return Row(
      children: [
        Icon(Icons.history, color: VividColors.cyan, size: isMobile ? 22 : 28),
        SizedBox(width: isMobile ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isAdmin
                    ? 'Activity Logs'
                    : widget.clientName != null
                        ? '${widget.clientName} Activity Logs'
                        : 'All Activity Logs',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: vc.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_formatCount(provider.filteredCount)} activities${provider.filteredCount != provider.totalFetchedCount ? " (filtered from ${_formatCount(provider.totalFetchedCount)})" : ""}${provider.hasMore ? "+" : ""}',
                style: TextStyle(color: vc.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (provider.logs.isNotEmpty) _buildExportButton(provider),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _loadLogs,
          icon: provider.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
                )
              : Icon(Icons.refresh, color: vc.textSecondary),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildExportButton(ActivityLogsProvider provider) {
    final vc = context.vividColors;
    return PopupMenuButton<String>(
      onSelected: (format) => _handleExport(format, provider.logs),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: vc.surface,
      itemBuilder: (context) {
        final vc = context.vividColors;
        return [
          PopupMenuItem(
            value: 'csv',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.table_chart, color: Colors.green, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CSV', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600)),
                    Text('Spreadsheet format', style: TextStyle(color: vc.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'excel',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF217346).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.grid_on, color: Color(0xFF217346), size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Excel', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600)),
                    Text('Formatted workbook', style: TextStyle(color: vc.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: VividColors.primaryGradient,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: VividColors.brightBlue.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, color: vc.background, size: 16),
            const SizedBox(width: 6),
            Text(
              'Export',
              style: TextStyle(
                color: vc.background,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: vc.background, size: 18),
          ],
        ),
      ),
    );
  }

  void _handleExport(String format, List<ActivityLog> logs) {
    switch (format) {
      case 'csv':
        AnalyticsExporter.exportActivityLogsToCsv(logs: logs);
        break;
      case 'excel':
        AnalyticsExporter.exportActivityLogsToExcel(logs: logs);
        break;
    }

    VividToast.show(context,
      message: '${format.toUpperCase()} exported successfully',
      type: ToastType.success,
    );
  }

  // ══════════════════════════════════════════════════════
  // FILTERS
  // ══════════════════════════════════════════════════════

  bool get _hasActiveFilters {
    final provider = context.read<ActivityLogsProvider>();
    return provider.selectedClientId != null ||
        provider.selectedUserId != null ||
        provider.selectedActionType != null ||
        provider.startDate != null ||
        provider.searchQuery.isNotEmpty ||
        provider.filterAiOnly;
  }

  Widget _buildFilters(ActivityLogsProvider provider, bool isMobile) {
    final vc = context.vividColors;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              Icon(Icons.filter_list, color: vc.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  color: vc.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: () {
                    provider.clearFilters();
                    _searchController.clear();
                    setState(() => _datePreset = 'all');
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Reset Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: VividColors.statusUrgent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 1: Client dropdown (admin) + Search + User dropdown
          if (isMobile) ...[
            // Mobile: stack vertically
            if (widget.isAdmin) ...[
              _buildClientDropdown(provider),
              const SizedBox(height: 8),
            ],
            _buildSearchField(provider),
            const SizedBox(height: 8),
            _buildDropdown<String?>(
              value: provider.selectedUserId,
              hint: 'All Users',
              items: [
                const DropdownMenuItem(value: null, child: Text('All Users')),
                ...provider.uniqueUsers.map((user) {
                  final isBlocked = provider.blockedUserIds.contains(user['id']);
                  final displayName = (user['name'] ?? 'Unknown') + (isBlocked ? ' (Blocked)' : '');
                  return DropdownMenuItem(
                    value: user['id'],
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: isBlocked ? Colors.red.withOpacity(0.7) : null,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: provider.setUserFilter,
            ),
            const SizedBox(height: 8),
            _buildDropdown<ActionType?>(
              value: provider.selectedActionType,
              hint: 'All Actions',
              items: [
                const DropdownMenuItem(value: null, child: Text('All Actions')),
                ...ActionType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_getActionIcon(type), size: 14, color: _getActionColor(type)),
                          const SizedBox(width: 6),
                          Text(type.displayName),
                        ],
                      ),
                    )),
              ],
              onChanged: provider.setActionTypeFilter,
            ),
            const SizedBox(height: 8),
            _buildDatePresets(provider),
          ] else ...[
            // Desktop: horizontal wrap
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (widget.isAdmin)
                  SizedBox(width: 200, child: _buildClientDropdown(provider)),
                SizedBox(width: 250, child: _buildSearchField(provider)),
                SizedBox(
                  width: 200,
                  child: _buildDropdown<String?>(
                    value: provider.selectedUserId,
                    hint: 'All Users',
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Users')),
                      ...provider.uniqueUsers.map((user) {
                        final isBlocked = provider.blockedUserIds.contains(user['id']);
                        final displayName = (user['name'] ?? 'Unknown') + (isBlocked ? ' (Blocked)' : '');
                        return DropdownMenuItem(
                          value: user['id'],
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: isBlocked ? Colors.red.withOpacity(0.7) : null,
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: provider.setUserFilter,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _buildDropdown<ActionType?>(
                    value: provider.selectedActionType,
                    hint: 'All Actions',
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Actions')),
                      ...ActionType.values.map((type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(_getActionIcon(type), size: 14, color: _getActionColor(type)),
                                const SizedBox(width: 6),
                                Text(type.displayName),
                              ],
                            ),
                          )),
                    ],
                    onChanged: provider.setActionTypeFilter,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDatePresets(provider),
          ],

          // AI filter (only for AI-enabled clients, non-admin)
          if (!widget.isAdmin && ClientConfig.hasAiConversations) ...[
            const SizedBox(height: 8),
            FilterChip(
              label: const Text('AI Activity'),
              selected: provider.filterAiOnly,
              onSelected: (value) => provider.setAiFilter(value),
              avatar: const Icon(Icons.smart_toy, size: 16),
              selectedColor: VividColors.brightBlue.withOpacity(0.3),
              checkmarkColor: VividColors.brightBlue,
              labelStyle: TextStyle(
                color: provider.filterAiOnly ? VividColors.brightBlue : vc.textSecondary,
                fontSize: 13,
              ),
              side: BorderSide(
                color: provider.filterAiOnly ? VividColors.brightBlue : vc.popupBorder,
              ),
              backgroundColor: vc.background,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientDropdown(ActivityLogsProvider provider) {
    final vc = context.vividColors;
    final clients = context.watch<AdminProvider>().clients;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: vc.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: provider.selectedClientId,
          hint: Text('All Clients', style: TextStyle(color: vc.textMuted)),
          isExpanded: true,
          dropdownColor: vc.surface,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, size: 14, color: VividColors.cyan),
                  const SizedBox(width: 6),
                  Text('All Clients'),
                ],
              ),
            ),
            ...clients.map((c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: provider.setClientFilter,
          style: TextStyle(color: vc.textPrimary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSearchField(ActivityLogsProvider provider) {
    final vc = context.vividColors;
    return TextField(
      controller: _searchController,
      onChanged: provider.setSearchQuery,
      decoration: InputDecoration(
        hintText: 'Search by name or description...',
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: vc.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: vc.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: vc.textMuted)),
          isExpanded: true,
          dropdownColor: vc.surface,
          items: items,
          onChanged: onChanged,
          style: TextStyle(color: vc.textPrimary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDatePresets(ActivityLogsProvider provider) {
    final vc = context.vividColors;
    final presets = <String, String>{
      'all': 'All Time',
      'today': 'Today',
      '7days': 'Last 7 Days',
      '30days': 'Last 30 Days',
      'custom': 'Custom',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.entries.map((entry) {
        final isActive = _datePreset == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isActive,
          onSelected: (_) => _applyDatePreset(entry.key, provider),
          selectedColor: VividColors.cyan.withOpacity(0.2),
          checkmarkColor: VividColors.cyan,
          labelStyle: TextStyle(
            color: isActive ? VividColors.cyan : vc.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isActive ? VividColors.cyan : vc.popupBorder,
          ),
          backgroundColor: vc.background,
          avatar: entry.key == 'custom' && isActive
              ? const Icon(Icons.date_range, size: 14, color: VividColors.cyan)
              : null,
        );
      }).toList(),
    );
  }

  void _applyDatePreset(String preset, ActivityLogsProvider provider) {
    setState(() => _datePreset = preset);
    final now = DateTime.now();

    switch (preset) {
      case 'all':
        provider.setDateRange(null, null);
        break;
      case 'today':
        final startOfDay = DateTime(now.year, now.month, now.day);
        provider.setDateRange(startOfDay, now);
        break;
      case '7days':
        provider.setDateRange(now.subtract(const Duration(days: 7)), now);
        break;
      case '30days':
        provider.setDateRange(now.subtract(const Duration(days: 30)), now);
        break;
      case 'custom':
        _showDateRangePicker(provider);
        break;
    }
  }

  Future<void> _showDateRangePicker(ActivityLogsProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: provider.startDate != null && provider.endDate != null
          ? DateTimeRange(start: provider.startDate!, end: provider.endDate!)
          : null,
      builder: (context, child) {
        final vc = context.vividColors;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: VividColors.cyan,
              onPrimary: vc.background,
              surface: vc.surface,
              onSurface: vc.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setDateRange(picked.start, picked.end);
    }
  }

  // ══════════════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════════════

  Widget _buildStats(ActivityLogsProvider provider, bool isMobile) {
    final todayCount = provider.todayLogs.length;
    final weekCount = provider.thisWeekLogs.length;
    final typeBreakdown = provider.logCountsByType;

    final cards = [
      _buildStatCard('Actions Today', todayCount.toString(), Icons.today, VividColors.cyan, 'All user actions logged today'),
      _buildStatCard('Actions This Week', weekCount.toString(), Icons.date_range, VividColors.brightBlue, 'Total actions in the past 7 days'),
      _buildStatCard('Messages Sent', (typeBreakdown[ActionType.messageSent] ?? 0).toString(), Icons.send, VividColors.statusSuccess, 'Manual messages sent by agents'),
      _buildStatCard('Broadcasts Sent', (typeBreakdown[ActionType.broadcastSent] ?? 0).toString(), Icons.campaign, VividColors.statusWarning, 'Bulk broadcasts dispatched'),
    ];

    if (isMobile) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards.map((c) => SizedBox(
          width: double.infinity,
          child: c,
        )).toList(),
      );
    }
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: vc.textMuted)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9, color: vc.textMuted.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // LOG LIST
  // ══════════════════════════════════════════════════════

  Widget _buildLogsList(ActivityLogsProvider provider, bool isMobile) {
    final vc = context.vividColors;
    if (provider.isLoading && provider.allLogs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: VividColors.cyan),
      );
    }

    if (provider.error != null && provider.allLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: VividColors.statusUrgent, size: 48),
            const SizedBox(height: 16),
            Text(provider.error!, style: TextStyle(color: vc.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.filteredCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: vc.textMuted.withOpacity(0.5), size: 64),
            const SizedBox(height: 16),
            Text(
              'No activity logs found',
              style: TextStyle(color: vc.textMuted, fontSize: 16),
            ),
            if (provider.totalFetchedCount > 0) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  provider.clearFilters();
                  _searchController.clear();
                  setState(() => _datePreset = 'all');
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    // Use displayedLogs for lazy rendering, show footer when more available
    final displayed = provider.displayedLogs;
    final showFooter = provider.hasMoreToDisplay || provider.hasMore || provider.isLoadingMore;

    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: displayed.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= displayed.length) {
            return _buildLoadMoreFooter(provider);
          }
          final log = displayed[index];
          final showDivider = index < displayed.length - 1;
          return Column(
            children: [
              _buildLogItem(log, isMobile),
              if (showDivider) Divider(color: vc.borderSubtle, height: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreFooter(ActivityLogsProvider provider) {
    final vc = context.vividColors;
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
          ),
        ),
      );
    }

    // Show how many are displayed vs total
    final displayedCount = provider.displayedLogs.length;
    final totalFiltered = provider.filteredCount;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Text(
              'Showing $displayedCount of ${_formatCount(totalFiltered)}${provider.hasMore ? "+" : ""}',
              style: TextStyle(color: vc.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: provider.hasMoreToDisplay
                  ? provider.showMore
                  : provider.hasMore
                      ? provider.loadMore
                      : null,
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(provider.hasMoreToDisplay ? 'Show More' : 'Load More'),
              style: OutlinedButton.styleFrom(
                foregroundColor: VividColors.cyan,
                side: const BorderSide(color: VividColors.cyan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // LOG ITEM
  // ══════════════════════════════════════════════════════

  Widget _buildLogItem(ActivityLog log, bool isMobile) {
    final vc = context.vividColors;
    final isExpanded = _expandedMetadata.contains(log.id);
    final hasMetadata = log.metadata.isNotEmpty;

    return InkWell(
      onTap: hasMetadata
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedMetadata.remove(log.id);
                } else {
                  _expandedMetadata.add(log.id);
                }
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActionColor(log.actionType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActionIcon(log.actionType),
                    color: _getActionColor(log.actionType),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User name + action type badge row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            log.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: vc.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getActionColor(log.actionType).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.actionType.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getActionColor(log.actionType),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Client badge (admin mode)
                          if (widget.isAdmin && log.clientId != null)
                            _buildClientBadge(log.clientId!),
                          // AI status badge
                          if (log.actionType == ActionType.aiToggled)
                            _buildAiBadge(log),
                        ],
                      ),
                      // User email
                      if (log.userEmail != null && log.userEmail!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          log.userEmail!,
                          style: TextStyle(color: vc.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        log.description,
                        style: TextStyle(color: vc.textSecondary, fontSize: 12),
                      ),
                      // Metadata chips (collapsed view)
                      if (hasMetadata && !isExpanded) ...[
                        const SizedBox(height: 4),
                        _buildMetadataChips(log.metadata),
                      ],
                    ],
                  ),
                ),

                // Timestamp + expand indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatRelativeTime(log.createdAt),
                      style: TextStyle(color: vc.textMuted, fontSize: 11),
                    ),
                    if (hasMetadata)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: vc.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Expanded metadata section
            if (isExpanded && hasMetadata) ...[
              const SizedBox(height: 8),
              _buildExpandedMetadata(log.metadata),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientBadge(String clientId) {
    final clients = context.read<AdminProvider>().clients;
    final client = clients.where((c) => c.id == clientId).firstOrNull;
    final name = client?.name ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: VividColors.brightBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 10,
          color: VividColors.cyan,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAiBadge(ActivityLog log) {
    final aiEnabled = log.metadata['ai_enabled'] == true;
    final color = aiEnabled ? VividColors.statusSuccess : VividColors.statusUrgent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            aiEnabled ? 'AI On' : 'AI Off',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChips(Map<String, dynamic> metadata) {
    final vc = context.vividColors;
    final displayItems = metadata.entries
        .where((e) => !e.key.contains('_id') && e.value != null)
        .take(3)
        .toList();

    if (displayItems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: displayItems.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: vc.background,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${_formatKey(entry.key)}: ${_formatValue(entry.value)}',
            style: TextStyle(fontSize: 10, color: vc.textMuted),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpandedMetadata(Map<String, dynamic> metadata) {
    final vc = context.vividColors;
    return Container(
      margin: const EdgeInsets.only(left: 46), // align with content after icon
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, size: 14, color: vc.textMuted),
              const SizedBox(width: 6),
              Text(
                'Metadata',
                style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(metadata),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: vc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatValue(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    final str = value.toString();
    return str.length > 30 ? '${str.substring(0, 30)}...' : str;
  }

  IconData _getActionIcon(ActionType type) {
    switch (type) {
      case ActionType.login:
        return Icons.login;
      case ActionType.logout:
        return Icons.logout;
      case ActionType.messageSent:
        return Icons.send;
      case ActionType.broadcastSent:
        return Icons.campaign;
      case ActionType.aiToggled:
        return Icons.smart_toy;
      case ActionType.userCreated:
        return Icons.person_add;
      case ActionType.userUpdated:
        return Icons.edit;
      case ActionType.userDeleted:
        return Icons.person_remove;
      case ActionType.userBlocked:
        return Icons.block;
      case ActionType.clientCreated:
        return Icons.business;
      case ActionType.clientUpdated:
        return Icons.edit_note;
      case ActionType.impersonationStart:
      case ActionType.impersonationEnd:
        return Icons.admin_panel_settings;
    }
  }

  Color _getActionColor(ActionType type) {
    switch (type) {
      case ActionType.login:
        return VividColors.statusSuccess;
      case ActionType.logout:
        return Colors.grey;
      case ActionType.messageSent:
        return VividColors.cyan;
      case ActionType.broadcastSent:
        return VividColors.statusWarning;
      case ActionType.aiToggled:
        return VividColors.brightBlue;
      case ActionType.userCreated:
        return VividColors.statusSuccess;
      case ActionType.userUpdated:
        return VividColors.brightBlue;
      case ActionType.userDeleted:
        return VividColors.statusUrgent;
      case ActionType.userBlocked:
        return VividColors.statusUrgent;
      case ActionType.clientCreated:
        return VividColors.statusSuccess;
      case ActionType.clientUpdated:
        return VividColors.brightBlue;
      case ActionType.impersonationStart:
      case ActionType.impersonationEnd:
        return VividColors.statusWarning;
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final diff = now.difference(bh);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24 && bh.day == now.day) return '${diff.inHours}h ago';
    if (diff.inHours < 48 && now.day - bh.day == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[bh.month - 1]} ${bh.day}';
  }
}
