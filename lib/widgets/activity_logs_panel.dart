import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/activity_logs_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';

class ActivityLogsPanel extends StatefulWidget {
  final String? clientId; // null for Vivid admin viewing all
  final String? clientName;

  const ActivityLogsPanel({
    super.key,
    this.clientId,
    this.clientName,
  });

  @override
  State<ActivityLogsPanel> createState() => _ActivityLogsPanelState();
}

class _ActivityLogsPanelState extends State<ActivityLogsPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLogs();
    });
  }

  void _loadLogs() {
    final provider = context.read<ActivityLogsProvider>();
    if (widget.clientId != null) {
      provider.fetchLogs(clientId: widget.clientId);
    } else {
      provider.fetchAllLogs();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityLogsProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider),
            const SizedBox(height: 16),
            _buildFilters(provider),
            const SizedBox(height: 16),
            _buildStats(provider),
            const SizedBox(height: 16),
            Expanded(child: _buildLogsList(provider)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(ActivityLogsProvider provider) {
    return Row(
      children: [
        Icon(Icons.history, color: VividColors.cyan, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.clientName != null 
                    ? '${widget.clientName} Activity Logs'
                    : 'All Activity Logs',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: VividColors.textPrimary,
                ),
              ),
              Text(
                '${provider.logs.length} activities${provider.allLogs.length != provider.logs.length ? " (filtered from ${provider.allLogs.length})" : ""}',
                style: const TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (provider.logs.isNotEmpty)
          _buildExportButton(provider),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _loadLogs,
          icon: provider.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
                )
              : const Icon(Icons.refresh, color: VividColors.textSecondary),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildExportButton(ActivityLogsProvider provider) {
    return PopupMenuButton<String>(
      onSelected: (format) => _handleExport(format, provider.logs),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: VividColors.navy,
      itemBuilder: (context) => [
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CSV', style: TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text('Spreadsheet format', style: TextStyle(color: VividColors.textMuted, fontSize: 11)),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Excel', style: TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text('Formatted workbook', style: TextStyle(color: VividColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ],
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, color: VividColors.darkNavy, size: 16),
            SizedBox(width: 6),
            Text(
              'Export',
              style: TextStyle(
                color: VividColors.darkNavy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: VividColors.darkNavy, size: 18),
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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Text('${format.toUpperCase()} exported successfully'),
      ]),
      backgroundColor: VividColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildFilters(ActivityLogsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: VividColors.textMuted, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Filters',
                style: TextStyle(
                  color: VividColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (provider.selectedUserId != null ||
                  provider.selectedActionType != null ||
                  provider.startDate != null ||
                  provider.searchQuery.isNotEmpty ||
                  provider.filterAiOnly)
                TextButton.icon(
                  onPressed: () {
                    provider.clearFilters();
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: VividColors.statusUrgent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Search
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search by name or description...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: VividColors.darkNavy,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),

              // User filter
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
                width: 200,
              ),

              // Action type filter
              _buildDropdown<ActionType?>(
                value: provider.selectedActionType,
                hint: 'All Actions',
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Actions')),
                  ...ActionType.values
                    .where((type) => type != ActionType.aiToggled || ClientConfig.hasAiConversations)
                    .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    )),
                ],
                onChanged: provider.setActionTypeFilter,
                width: 180,
              ),

              // Date range
              _buildDateRangeButton(provider),

              // AI filter (only for AI-enabled clients)
              if (ClientConfig.hasAiConversations)
                FilterChip(
                  label: const Text('AI Activity'),
                  selected: provider.filterAiOnly,
                  onSelected: (value) => provider.setAiFilter(value),
                  avatar: const Icon(Icons.smart_toy, size: 16),
                  selectedColor: VividColors.brightBlue.withOpacity(0.3),
                  checkmarkColor: VividColors.brightBlue,
                  labelStyle: TextStyle(
                    color: provider.filterAiOnly ? VividColors.brightBlue : VividColors.textSecondary,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: provider.filterAiOnly ? VividColors.brightBlue : VividColors.tealBlue.withOpacity(0.3),
                  ),
                  backgroundColor: VividColors.darkNavy,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VividColors.darkNavy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: VividColors.textMuted)),
          isExpanded: true,
          dropdownColor: VividColors.navy,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(color: VividColors.textPrimary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDateRangeButton(ActivityLogsProvider provider) {
    final hasDateFilter = provider.startDate != null || provider.endDate != null;
    
    return OutlinedButton.icon(
      onPressed: () => _showDateRangePicker(provider),
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(
        hasDateFilter
            ? '${_formatDate(provider.startDate)} - ${_formatDate(provider.endDate)}'
            : 'Date Range',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: hasDateFilter ? VividColors.cyan : VividColors.textSecondary,
        side: BorderSide(
          color: hasDateFilter ? VividColors.cyan : VividColors.tealBlue.withOpacity(0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Any';
    return '${date.day}/${date.month}/${date.year}';
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
      provider.setDateRange(picked.start, picked.end);
    }
  }

  Widget _buildStats(ActivityLogsProvider provider) {
    final todayCount = provider.todayLogs.length;
    final weekCount = provider.thisWeekLogs.length;
    final typeBreakdown = provider.logCountsByType;

    return Row(
      children: [
        _buildStatCard('Today', todayCount.toString(), Icons.today, VividColors.cyan),
        const SizedBox(width: 12),
        _buildStatCard('This Week', weekCount.toString(), Icons.date_range, VividColors.brightBlue),
        const SizedBox(width: 12),
        _buildStatCard('Messages', (typeBreakdown[ActionType.messageSent] ?? 0).toString(), Icons.send, VividColors.statusSuccess),
        const SizedBox(width: 12),
        _buildStatCard('Broadcasts', (typeBreakdown[ActionType.broadcastSent] ?? 0).toString(), Icons.campaign, VividColors.statusWarning),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VividColors.navy,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: VividColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(ActivityLogsProvider provider) {
    if (provider.isLoading && provider.logs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: VividColors.cyan),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: VividColors.statusUrgent, size: 48),
            const SizedBox(height: 16),
            Text(provider.error!, style: const TextStyle(color: VividColors.textMuted)),
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

    if (provider.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: VividColors.textMuted.withOpacity(0.5), size: 64),
            const SizedBox(height: 16),
            const Text(
              'No activity logs found',
              style: TextStyle(color: VividColors.textMuted, fontSize: 16),
            ),
            if (provider.allLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  provider.clearFilters();
                  _searchController.clear();
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: provider.logs.length,
        separatorBuilder: (_, __) => Divider(
          color: VividColors.tealBlue.withOpacity(0.1),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final log = provider.logs[index];
          return _buildLogItem(log);
        },
      ),
    );
  }

  Widget _buildLogItem(ActivityLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
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
                Row(
                  children: [
                    Text(
                      log.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: VividColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    // AI status badge (only for AI-enabled clients)
                    if (ClientConfig.hasAiConversations && log.actionType == ActionType.aiToggled)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (log.metadata['ai_enabled'] == true
                                    ? VividColors.statusSuccess
                                    : VividColors.statusUrgent)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.smart_toy,
                                size: 10,
                                color: log.metadata['ai_enabled'] == true
                                    ? VividColors.statusSuccess
                                    : VividColors.statusUrgent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                log.metadata['ai_enabled'] == true ? 'AI On' : 'AI Off',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: log.metadata['ai_enabled'] == true
                                      ? VividColors.statusSuccess
                                      : VividColors.statusUrgent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.description,
                  style: const TextStyle(
                    color: VividColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (log.metadata.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildMetadataChips(log.metadata),
                ],
              ],
            ),
          ),
          
          // Timestamp
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(log.createdAt),
                style: const TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 11,
                ),
              ),
              Text(
                _formatDateShort(log.createdAt),
                style: const TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChips(Map<String, dynamic> metadata) {
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
            color: VividColors.darkNavy,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${_formatKey(entry.key)}: ${_formatValue(entry.value)}',
            style: const TextStyle(
              fontSize: 10,
              color: VividColors.textMuted,
            ),
          ),
        );
      }).toList(),
    );
  }

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
      case ActionType.bookingReminder:
        return Icons.calendar_month;
    }
  }

  Color _getActionColor(ActionType type) {
    switch (type) {
      case ActionType.login:
        return VividColors.statusSuccess;
      case ActionType.logout:
        return VividColors.textMuted;
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
      case ActionType.bookingReminder:
        return VividColors.cyan;
    }
  }

  String _formatTime(DateTime dt) {
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final hour = bh.hour.toString().padLeft(2, '0');
    final minute = bh.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateShort(DateTime dt) {
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final nowBh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final diff = nowBh.difference(bh);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && bh.day == nowBh.day) return 'Today';
    if (diff.inHours < 48) return 'Yesterday';
    return '${bh.day}/${bh.month}/${bh.year}';
  }
}