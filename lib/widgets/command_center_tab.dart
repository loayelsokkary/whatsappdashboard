import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../providers/admin_provider.dart';
import '../providers/admin_analytics_provider.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';
import '../utils/analytics_exporter.dart';
import '../utils/health_scorer.dart';
import '../utils/toast_service.dart';

/// Command Center home screen for Vivid super admins.
/// Shows summary stats, client health overview, and live activity feed.
class CommandCenterTab extends StatefulWidget {
  /// Callback to switch to the Clients tab and select a specific client.
  final void Function(Client client)? onSelectClient;

  const CommandCenterTab({super.key, this.onSelectClient});

  @override
  State<CommandCenterTab> createState() => _CommandCenterTabState();
}

class _CommandCenterTabState extends State<CommandCenterTab> {
  List<ActivityLog> _activityLogs = [];
  bool _isLoadingLogs = false;
  RealtimeChannel? _logsChannel;

  // Health scores
  Map<String, ClientHealthScore> _healthScores = {};
  Map<String, int> _activeUserCounts = {};
  Map<String, int> _totalUserCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDataLoaded();
      _fetchActivityLogs();
      _subscribeToActivityLogs();
    });
  }

  @override
  void dispose() {
    _logsChannel?.unsubscribe();
    super.dispose();
  }

  void _ensureDataLoaded() {
    final adminProvider = context.read<AdminProvider>();
    final analyticsProvider = context.read<AdminAnalyticsProvider>();

    if (adminProvider.clients.isEmpty) {
      adminProvider.fetchClients().then((_) {
        if (analyticsProvider.companyAnalytics == null && adminProvider.clients.isNotEmpty) {
          analyticsProvider.fetchCompanyAnalytics(adminProvider.clients);
        }
        _fetchUserEngagementData();
      });
    } else {
      if (analyticsProvider.companyAnalytics == null) {
        analyticsProvider.fetchCompanyAnalytics(adminProvider.clients);
      }
      _fetchUserEngagementData();
    }
  }

  Future<void> _fetchUserEngagementData() async {
    try {
      final adminProvider = context.read<AdminProvider>();

      // Total users per client
      final totalCounts = <String, int>{};
      for (final user in adminProvider.allUsers) {
        final clientId = user['client_id'] as String?;
        if (clientId != null) {
          totalCounts[clientId] = (totalCounts[clientId] ?? 0) + 1;
        }
      }

      // Active users (login events in last 7 days) from activity_logs
      final activeCounts = <String, int>{};
      try {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
        final response = await SupabaseService.client
            .from('activity_logs')
            .select('client_id, user_id')
            .eq('action_type', 'login')
            .gte('created_at', sevenDaysAgo);
        final rows = response as List;
        // Count unique users per client
        final seen = <String, Set<String>>{};
        for (final row in rows) {
          final clientId = row['client_id'] as String?;
          final userId = row['user_id'] as String?;
          if (clientId != null && userId != null) {
            seen.putIfAbsent(clientId, () => {});
            seen[clientId]!.add(userId);
          }
        }
        for (final entry in seen.entries) {
          activeCounts[entry.key] = entry.value.length;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activeUserCounts = activeCounts;
          _totalUserCounts = totalCounts;
          _recomputeHealthScores();
        });
      }
    } catch (_) {}
  }

  void _recomputeHealthScores() {
    final adminProvider = context.read<AdminProvider>();
    final analyticsProvider = context.read<AdminAnalyticsProvider>();
    final scores = HealthScorer.computeHealthScores(
      clients: adminProvider.clients,
      analytics: analyticsProvider.companyAnalytics,
      activeUserCounts: _activeUserCounts,
      totalUserCounts: _totalUserCounts,
    );
    _healthScores = {for (final s in scores) s.clientId: s};
  }

  Future<void> _fetchActivityLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final logs = await SupabaseService.instance.fetchActivityLogs(limit: 20);
      if (mounted) {
        setState(() {
          _activityLogs = logs;
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  void _subscribeToActivityLogs() {
    _logsChannel = SupabaseService.client
        .channel('command_center_activity_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_logs',
          callback: (payload) {
            _fetchActivityLogs();
          },
        )
        .subscribe();
  }

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final padding = isMobile ? 16.0 : 32.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(vc, isMobile),
                SizedBox(height: isMobile ? 16 : 24),
                _buildSummaryStats(vc, isMobile),
                SizedBox(height: isMobile ? 16 : 24),
                _buildClientHealthSection(vc, isMobile),
                SizedBox(height: isMobile ? 16 : 24),
                _buildActivityFeedSection(vc, isMobile),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader(VividColorScheme vc, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
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
          child: const Icon(Icons.dashboard, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Command Center',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: isMobile ? 20 : 28,
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
                          'Live',
                          style: TextStyle(
                            color: VividColors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Overview of all client operations',
                      style: TextStyle(
                        color: vc.textMuted.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        _buildExportButton(vc),
      ],
    );
  }

  Widget _buildExportButton(VividColorScheme vc) {
    return PopupMenuButton<String>(
      onSelected: (format) {
        final analytics = context.read<AdminAnalyticsProvider>().companyAnalytics;
        final clients = context.read<AdminProvider>().clients;
        final healthScores = _healthScores.values.toList();
        try {
          AnalyticsExporter.exportCommandCenterCsv(
            analytics: analytics,
            clients: clients,
            healthScores: healthScores,
          );
          VividToast.show(context, message: 'CSV exported', type: ToastType.success);
        } catch (e) {
          VividToast.show(context, message: 'Export failed: $e', type: ToastType.error);
        }
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: vc.surface,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'csv', child: Row(children: [
          Icon(Icons.table_chart, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Text('Export Summary CSV', style: TextStyle(color: vc.textPrimary)),
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

  // ── Summary Stat Cards ──────────────────────────────────

  Widget _buildSummaryStats(VividColorScheme vc, bool isMobile) {
    final adminProvider = context.watch<AdminProvider>();
    final analyticsProvider = context.watch<AdminAnalyticsProvider>();
    final analytics = analyticsProvider.companyAnalytics;

    final cards = [
      _SummaryCard(
        icon: Icons.business,
        label: 'Total Clients',
        value: adminProvider.clients.length.toString(),
        color: VividColors.brightBlue,
      ),
      _SummaryCard(
        icon: Icons.people,
        label: 'Total Users',
        value: adminProvider.allUsers.length.toString(),
        color: Colors.purple,
      ),
      _SummaryCard(
        icon: Icons.message,
        label: 'Total Messages',
        value: _formatNumber(analytics?.totalMessages ?? 0),
        color: VividColors.cyan,
      ),
      _SummaryCard(
        icon: Icons.campaign,
        label: 'Total Broadcasts',
        value: _formatNumber(analytics?.totalBroadcasts ?? 0),
        color: Colors.orange,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
        ],
      );
    }

    return Row(
      children: cards
          .expand((c) => [Expanded(child: c), const SizedBox(width: 16)])
          .toList()
        ..removeLast(),
    );
  }

  // ── Client Health Overview ──────────────────────────────

  Widget _buildClientHealthSection(VividColorScheme vc, bool isMobile) {
    final adminProvider = context.watch<AdminProvider>();
    final analyticsProvider = context.watch<AdminAnalyticsProvider>();
    final analytics = analyticsProvider.companyAnalytics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client Health',
          style: TextStyle(
            color: vc.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (adminProvider.isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(color: VividColors.cyan),
            ),
          )
        else if (adminProvider.clients.isEmpty)
          _buildEmptyState(vc, 'No clients found', Icons.business_outlined)
        else
          _buildClientCards(vc, isMobile, adminProvider.clients, analytics),
      ],
    );
  }

  Widget _buildClientCards(
    VividColorScheme vc,
    bool isMobile,
    List<Client> clients,
    VividCompanyAnalytics? analytics,
  ) {
    // Build a map of client activities for quick lookup
    final activityMap = <String, ClientActivity>{};
    if (analytics != null) {
      for (final ca in analytics.allClientActivities) {
        activityMap[ca.clientId] = ca;
      }
    }

    // Recompute health scores if analytics changed
    if (_healthScores.isEmpty && clients.isNotEmpty) {
      _recomputeHealthScores();
    }

    if (isMobile) {
      return Column(
        children: clients.map((client) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ClientHealthCard(
              client: client,
              activity: activityMap[client.id],
              healthScore: _healthScores[client.id],
              onTap: () => widget.onSelectClient?.call(client),
            ),
          );
        }).toList(),
      );
    }

    // Desktop: 2 or 3 columns
    final rows = <Widget>[];
    for (var i = 0; i < clients.length; i += 3) {
      final rowCards = <Widget>[];
      for (var j = i; j < i + 3 && j < clients.length; j++) {
        rowCards.add(Expanded(
          child: _ClientHealthCard(
            client: clients[j],
            activity: activityMap[clients[j].id],
            healthScore: _healthScores[clients[j].id],
            onTap: () => widget.onSelectClient?.call(clients[j]),
          ),
        ));
        if (j < i + 2 && j < clients.length - 1) {
          rowCards.add(const SizedBox(width: 16));
        }
      }
      // Fill remaining slots if less than 3
      while (rowCards.where((w) => w is Expanded).length < 3) {
        rowCards.add(const SizedBox(width: 16));
        rowCards.add(const Expanded(child: SizedBox.shrink()));
      }
      rows.add(Row(children: rowCards));
      rows.add(const SizedBox(height: 16));
    }

    return Column(children: rows);
  }

  // ── Activity Feed ───────────────────────────────────────

  Widget _buildActivityFeedSection(VividColorScheme vc, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Live Activity Feed',
              style: TextStyle(
                color: vc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // "View All" placeholder
            TextButton.icon(
              onPressed: () {
                // Future: switch to Activity Logs tab
              },
              icon: const Icon(Icons.open_in_new, size: 16, color: VividColors.cyan),
              label: const Text(
                'View All',
                style: TextStyle(color: VividColors.cyan, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: vc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: vc.border),
          ),
          child: _isLoadingLogs
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: VividColors.cyan)),
                )
              : _activityLogs.isEmpty
                  ? _buildEmptyState(vc, 'No recent activity', Icons.history)
                  : _buildLogList(vc),
        ),
      ],
    );
  }

  Widget _buildLogList(VividColorScheme vc) {
    final adminProvider = context.read<AdminProvider>();
    // Build a client name map
    final clientNameMap = <String, String>{};
    for (final c in adminProvider.clients) {
      clientNameMap[c.id] = c.name;
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activityLogs.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: vc.border),
      itemBuilder: (context, index) {
        final log = _activityLogs[index];
        final clientName = log.clientId != null ? clientNameMap[log.clientId] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _actionColor(log.actionType).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _actionIcon(log.actionType),
                  color: _actionColor(log.actionType),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            log.userName,
                            style: TextStyle(
                              color: vc.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (clientName != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: VividColors.cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              clientName,
                              style: const TextStyle(
                                color: VividColors.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.description,
                      style: TextStyle(color: vc.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _relativeTime(log.createdAt),
                style: TextStyle(color: vc.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(VividColorScheme vc, String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: vc.textMuted.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: vc.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  IconData _actionIcon(ActionType type) {
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
        return Icons.add_business;
      case ActionType.clientUpdated:
        return Icons.business;
      case ActionType.impersonationStart:
      case ActionType.impersonationEnd:
        return Icons.admin_panel_settings;
    }
  }

  Color _actionColor(ActionType type) {
    switch (type) {
      case ActionType.login:
      case ActionType.logout:
        return VividColors.brightBlue;
      case ActionType.messageSent:
        return VividColors.cyan;
      case ActionType.broadcastSent:
        return Colors.orange;
      case ActionType.aiToggled:
        return VividColors.cyan;
      case ActionType.userCreated:
      case ActionType.clientCreated:
        return VividColors.statusSuccess;
      case ActionType.userUpdated:
      case ActionType.clientUpdated:
        return VividColors.statusWarning;
      case ActionType.userDeleted:
      case ActionType.userBlocked:
        return VividColors.statusUrgent;
      case ActionType.impersonationStart:
      case ActionType.impersonationEnd:
        return VividColors.statusWarning;
    }
  }
}

// ══════════════════════════════════════════════════════════
// Summary Card
// ══════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.all(20),
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
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Client Health Card
// ══════════════════════════════════════════════════════════

class _ClientHealthCard extends StatefulWidget {
  final Client client;
  final ClientActivity? activity;
  final ClientHealthScore? healthScore;
  final VoidCallback? onTap;

  const _ClientHealthCard({
    required this.client,
    this.activity,
    this.healthScore,
    this.onTap,
  });

  @override
  State<_ClientHealthCard> createState() => _ClientHealthCardState();
}

class _ClientHealthCardState extends State<_ClientHealthCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final adminProvider = context.watch<AdminProvider>();
    final healthStatus = adminProvider.getHealthStatus(widget.client.id);
    final statusColor = _healthColorFromStatus(healthStatus);
    final score = widget.healthScore;

    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main card content (tappable to navigate)
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + grade badge + chevron
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.client.name,
                          style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (score != null) _GradeBadge(grade: score.grade, color: score.gradeColor),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: vc.textMuted, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Feature chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.client.enabledFeatures.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: VividColors.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: VividColors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      Icon(Icons.message, size: 14, color: vc.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.activity?.messageCount ?? 0} msgs',
                        style: TextStyle(color: vc.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 14, color: vc.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        adminProvider.getLastLoginLabel(widget.client.id),
                        style: TextStyle(color: vc.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expand/collapse for health details
          if (score != null) ...[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: vc.border)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.monitor_heart, size: 14, color: score.gradeColor),
                    const SizedBox(width: 6),
                    Text(
                      'Health: ${score.score}/100',
                      style: TextStyle(color: score.gradeColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: vc.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              _HealthScoreDetail(score: score),
          ],
        ],
      ),
    );
  }

  static Color _healthColorFromStatus(int status) {
    switch (status) {
      case 0: return VividColors.statusSuccess;
      case 1: return VividColors.statusWarning;
      default: return VividColors.statusUrgent;
    }
  }
}

// ══════════════════════════════════════════════════════════
// Grade Badge
// ══════════════════════════════════════════════════════════

class _GradeBadge extends StatelessWidget {
  final String grade;
  final Color color;

  const _GradeBadge({required this.grade, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          grade,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Health Score Detail (expandable section)
// ══════════════════════════════════════════════════════════

class _HealthScoreDetail extends StatelessWidget {
  final ClientHealthScore score;

  const _HealthScoreDetail({required this.score});

  static const _factorExplanations = {
    'Activity Recency': 'How recently anyone from this client logged in or sent a message. Green if active in last 24 hours.',
    'Message Volume': 'Average daily messages since onboarding. Higher volume = healthier engagement.',
    'Feature Adoption': 'How many of the 3 core features (Conversations, Broadcasts, AI Assistant) are enabled.',
    'User Engagement': 'Percentage of the client\'s users who logged in within the last 7 days.',
    'Config Completeness': 'Whether enabled features have all required configuration (phone numbers, webhooks).',
  };

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isHealthy = score.recommendations.length == 1 &&
        score.recommendations.first.contains('healthy');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VividColors.brightBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VividColors.brightBlue.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: VividColors.brightBlue.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Client Health Score measures how actively and effectively this client uses the Vivid Dashboard. '
                    'It\u2019s calculated from 5 factors weighted by importance.',
                    style: TextStyle(color: vc.textSecondary, fontSize: 10, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Overall score display
          Row(
            children: [
              Text(
                '${score.score}',
                style: TextStyle(
                  color: score.gradeColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grade ${score.grade}',
                    style: TextStyle(color: score.gradeColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'out of 100',
                    style: TextStyle(color: vc.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Factor bars
          ...score.factors.map((factor) => _buildFactorBar(vc, factor)),

          // Recommendations
          const SizedBox(height: 4),
          if (isHealthy)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VividColors.statusSuccess.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VividColors.statusSuccess.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: VividColors.statusSuccess),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All metrics looking healthy \u2014 no action needed.',
                      style: TextStyle(color: VividColors.statusSuccess, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else if (score.recommendations.isNotEmpty) ...[
            ...score.recommendations.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r,
                      style: TextStyle(color: vc.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildFactorBar(VividColorScheme vc, HealthFactor factor) {
    final barColor = factor.score >= 70
        ? VividColors.statusSuccess
        : factor.score >= 40
            ? VividColors.statusWarning
            : VividColors.statusUrgent;
    final explanation = _factorExplanations[factor.name];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '${factor.name} (${(factor.weight * 100).round()}%)',
                      style: TextStyle(color: vc.textSecondary, fontSize: 11),
                    ),
                    if (explanation != null) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: explanation,
                        child: Icon(Icons.help_outline, size: 12, color: vc.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${factor.score.round()}',
                style: TextStyle(color: vc.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: factor.score / 100,
              backgroundColor: vc.border,
              color: barColor,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            factor.description,
            style: TextStyle(color: vc.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
