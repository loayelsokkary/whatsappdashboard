import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/admin_analytics_provider.dart';
import '../providers/agent_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../widgets/client_analytics_view.dart';
import '../widgets/vivid_company_analytics_view.dart';
import '../utils/initials_helper.dart';
import '../widgets/activity_logs_panel.dart';
import '../widgets/command_center_tab.dart';
import '../widgets/settings_tab.dart';
import '../main.dart';
import '../utils/toast_service.dart';
import '../services/impersonate_service.dart';

/// Launch client impersonation / "View as Client" mode.
void _launchClientPreview(BuildContext context, Client client) {
  final currentUser = ClientConfig.currentUser;
  if (currentUser == null) return;

  ImpersonateService.startImpersonation(client);

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const _ClientPreviewScreen()),
  );
}

/// Admin Panel - Manage clients and users
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      provider.fetchClients();
      provider.fetchAllUsers();
      provider.fetchLastLoginPerClient();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Scaffold(
      backgroundColor: vc.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CommandCenterTab(
                  onSelectClient: (client) {
                    _tabController.animateTo(1);
                    context.read<AdminProvider>().selectClient(client);
                  },
                ),
                _ClientsTab(
                  onViewAnalytics: (client) {
                    context.read<AdminProvider>().selectClient(client);
                    _tabController.animateTo(3);
                  },
                ),
                _UsersTab(),
                _AnalyticsTab(),
                const VividCompanyAnalyticsView(),
                const ActivityLogsPanel(isAdmin: true),
                const SettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launchPreview(Client client) => _launchClientPreview(context, client);

  Widget _buildHeader() {
    final vc = context.vividColors;
    final agent = context.watch<AgentProvider>().agent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 10 : 16,
          ),
          decoration: BoxDecoration(
            color: vc.surface,
            border: Border(
              bottom: BorderSide(color: vc.border),
            ),
          ),
          child: Row(
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: VividColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),

              // Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vivid Admin',
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isMobile)
                    Text(
                      'Manage clients and users',
                      style: TextStyle(
                        color: vc.textMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Preview as Client
              _buildPreviewButton(isMobile),
              const SizedBox(width: 8),

              // User info
              if (agent != null) ...[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: VividColors.brightBlue.withOpacity(0.2),
                  child: Text(
                    agent.initials,
                    style: const TextStyle(
                      color: VividColors.cyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        agent.name,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'Administrator',
                        style: TextStyle(
                          color: VividColors.cyan,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.read<AgentProvider>().logout(),
                  icon: Icon(Icons.logout, color: vc.textMuted),
                  tooltip: 'Logout',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewButton(bool isMobile) {
    final vc = context.vividColors;
    final clients = context.watch<AdminProvider>().clients;

    return PopupMenuButton<Client>(
      onSelected: _launchPreview,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: vc.surface,
      constraints: const BoxConstraints(maxHeight: 360, maxWidth: 260),
      itemBuilder: (context) {
        final vc = context.vividColors;
        return [
          PopupMenuItem<Client>(
            enabled: false,
            height: 32,
            child: Text('Preview as Client', style: TextStyle(color: vc.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          ...clients.map((c) => PopupMenuItem<Client>(
                value: c,
                child: Row(
                  children: [
                    Icon(Icons.business, size: 16, color: VividColors.cyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(color: vc.textPrimary, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ];
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: VividColors.statusWarning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VividColors.statusWarning.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.preview, size: 16, color: VividColors.statusWarning),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              const Text(
                'Preview',
                style: TextStyle(
                  color: VividColors.statusWarning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16, color: VividColors.statusWarning),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final vc = context.vividColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          color: vc.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: VividColors.cyan,
            indicatorWeight: 3,
            labelColor: VividColors.cyan,
            unselectedLabelColor: vc.textMuted,
            isScrollable: isMobile,
            tabAlignment: isMobile ? TabAlignment.start : null,
            tabs: isMobile
                ? const [
                    Tab(icon: Tooltip(message: 'Home', child: Icon(Icons.dashboard))),
                    Tab(icon: Tooltip(message: 'Clients', child: Icon(Icons.business))),
                    Tab(icon: Tooltip(message: 'Users', child: Icon(Icons.people))),
                    Tab(icon: Tooltip(message: 'Client Analytics', child: Icon(Icons.insights))),
                    Tab(icon: Tooltip(message: 'Vivid Analytics', child: Icon(Icons.auto_graph))),
                    Tab(icon: Tooltip(message: 'Activity Logs', child: Icon(Icons.history))),
                    Tab(icon: Tooltip(message: 'Settings', child: Icon(Icons.settings))),
                  ]
                : const [
                    Tab(icon: Icon(Icons.dashboard), text: 'Home'),
                    Tab(icon: Icon(Icons.business), text: 'Clients'),
                    Tab(icon: Icon(Icons.people), text: 'Users'),
                    Tab(icon: Icon(Icons.insights), text: 'Client Analytics'),
                    Tab(icon: Icon(Icons.auto_graph), text: 'Vivid Analytics'),
                    Tab(icon: Icon(Icons.history), text: 'Activity Logs'),
                    Tab(icon: Icon(Icons.settings), text: 'Settings'),
                  ],
          ),
        );
      },
    );
  }
}

// ============================================
// CLIENTS TAB
// ============================================

class _ClientsTab extends StatelessWidget {
  final void Function(Client client)? onViewAnalytics;

  const _ClientsTab({this.onViewAnalytics});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<AdminProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          // Mobile: show detail full-screen when a client is selected
          if (provider.selectedClient != null) {
            return Column(
              children: [
                // Back button header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: vc.surface,
                    border: Border(
                      bottom: BorderSide(color: vc.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => provider.clearSelection(),
                        icon: Icon(Icons.arrow_back, color: vc.textPrimary),
                        tooltip: 'Back to clients',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider.selectedClient!.name,
                          style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _ClientDetail(client: provider.selectedClient!),
                ),
              ],
            );
          }

          // Mobile: full-screen client list
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showClientDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Client'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VividColors.brightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: provider.clients.isEmpty
                        ? _buildEmptyState(context, 'No clients yet', 'Add your first client to get started')
                        : ListView.builder(
                            itemCount: provider.clients.length,
                            itemBuilder: (context, index) {
                              final client = provider.clients[index];
                              final isSelected = provider.selectedClient?.id == client.id;
                              return _ClientProfileCard(
                                client: client,
                                isSelected: isSelected,
                                onTap: () => provider.selectClient(client),
                                onEdit: () => _showClientDialog(context, client: client),
                                onDelete: () => _confirmDelete(context, client),
                                onPreview: () => _launchClientPreview(context, client),
                                onAnalytics: onViewAnalytics != null ? () => onViewAnalytics!(client) : null,
                              );
                            },
                          ),
              ),
            ],
          );
        }

        // Desktop: side-by-side layout
        return Row(
          children: [
            // Client list
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  // Add button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showClientDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VividColors.brightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // List
                  Expanded(
                    child: provider.clients.isEmpty
                            ? _buildEmptyState(context, 'No clients yet', 'Add your first client to get started')
                            : ListView.builder(
                                itemCount: provider.clients.length,
                                itemBuilder: (context, index) {
                                  final client = provider.clients[index];
                                  final isSelected = provider.selectedClient?.id == client.id;
                                  return _ClientProfileCard(
                                    client: client,
                                    isSelected: isSelected,
                                    onTap: () => provider.selectClient(client),
                                    onEdit: () => _showClientDialog(context, client: client),
                                    onDelete: () => _confirmDelete(context, client),
                                    onPreview: () => _launchClientPreview(context, client),
                                    onAnalytics: onViewAnalytics != null ? () => onViewAnalytics!(client) : null,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(width: 1, color: vc.border),

            // Client details / users
            Expanded(
              child: provider.selectedClient == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 64, color: vc.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'Select a client',
                            style: TextStyle(color: vc.textPrimary, fontSize: 18),
                          ),
                          Text(
                            'View and manage their users',
                            style: TextStyle(color: vc.textMuted),
                          ),
                        ],
                      ),
                    )
                  : _ClientDetail(client: provider.selectedClient!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    final vc = context.vividColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 64, color: vc.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: vc.textPrimary, fontSize: 16)),
          Text(subtitle, style: TextStyle(color: vc.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  void _showClientDialog(BuildContext context, {Client? client}) {
    if (client != null) {
      // Edit mode — use existing dialog
      showDialog(
        context: context,
        builder: (context) => _ClientDialog(client: client),
      );
    } else {
      // Create mode — use onboarding wizard
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _ClientOnboardingWizard(),
      );
    }
  }

  void _confirmDelete(BuildContext context, Client client) {
    final vc = context.vividColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vc.surface,
        title: Text('Delete Client', style: TextStyle(color: vc.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${client.name}"? This will also delete all their users.',
          style: TextStyle(color: vc.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AdminProvider>().deleteClient(client.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CLIENT CARD
// ============================================

class _ClientProfileCard extends StatefulWidget {
  final Client client;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPreview;
  final VoidCallback? onAnalytics;

  const _ClientProfileCard({
    required this.client,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPreview,
    this.onAnalytics,
  });

  @override
  State<_ClientProfileCard> createState() => _ClientProfileCardState();
}

class _ClientProfileCardState extends State<_ClientProfileCard> {
  bool _isHovered = false;

  static Color _healthColor(int status) {
    switch (status) {
      case 0: return VividColors.statusSuccess;
      case 1: return VividColors.statusWarning;
      default: return VividColors.statusUrgent;
    }
  }

  static Color _featureChipColor(String feature) {
    switch (feature) {
      case 'whatsapp_templates': return Colors.green;
      case 'media': return Colors.blue;
      case 'labels': return Colors.amber;
      case 'broadcasts': return Colors.orange;
      case 'analytics': return VividColors.brightBlue;
      case 'manager_chat': return Colors.purple;
      default: return VividColors.cyan;
    }
  }

  static String _featureLabel(String feature) {
    switch (feature) {
      case 'whatsapp_templates': return 'Templates';
      case 'media': return 'Media';
      case 'labels': return 'Labels';
      case 'broadcasts': return 'Broadcasts';
      case 'analytics': return 'Analytics';
      case 'manager_chat': return 'AI Chat';
      case 'conversations': return 'Convos';
      default: return feature;
    }
  }

  /// Check if a feature has its required config set up
  static bool _isFeatureConfigured(Client client, String feature) {
    switch (feature) {
      case 'conversations':
        return client.conversationsPhone != null && client.conversationsPhone!.isNotEmpty;
      case 'broadcasts':
        return (client.broadcastsWebhookUrl != null && client.broadcastsWebhookUrl!.isNotEmpty) ||
               (client.broadcastsPhone != null && client.broadcastsPhone!.isNotEmpty);
      case 'whatsapp_templates':
        return client.templatesTable != null && client.templatesTable!.isNotEmpty;
      case 'manager_chat':
        return client.managerChatWebhookUrl != null && client.managerChatWebhookUrl!.isNotEmpty;
      case 'analytics':
        return _isFeatureConfigured(client, 'conversations') || _isFeatureConfigured(client, 'broadcasts');
      case 'media':
      case 'labels':
        return true; // Flag-only features
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final client = widget.client;
    final adminProvider = context.watch<AdminProvider>();
    final userCount = adminProvider.allUsers.where((u) => u['client_id'] == client.id).length;
    final healthStatus = adminProvider.getHealthStatus(client.id);
    final healthLabel = adminProvider.getLastLoginLabel(client.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? VividColors.brightBlue.withValues(alpha: 0.08)
                : vc.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected ? VividColors.cyan : (_isHovered ? vc.border : Colors.transparent),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? Colors.black.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──
              Row(
                children: [
                  // Avatar with health dot
                  Tooltip(
                    message: healthLabel,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [VividColors.brightBlue, VividColors.cyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                getInitials(client.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                          // Health status dot
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _healthColor(healthStatus),
                                shape: BoxShape.circle,
                                border: Border.all(color: vc.surface, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: _healthColor(healthStatus).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + slug
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: TextStyle(
                            color: vc.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              client.slug,
                              style: TextStyle(color: vc.textMuted, fontSize: 12),
                            ),
                            if (client.hasAiConversations && client.enabledFeatures.contains('conversations')) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.smart_toy, size: 13, color: VividColors.cyan),
                              const SizedBox(width: 3),
                              Text('AI', style: TextStyle(color: VividColors.cyan, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 3-dot menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: vc.textMuted, size: 20),
                    color: vc.surface,
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit();
                      if (value == 'delete') widget.onDelete();
                      if (value == 'preview') widget.onPreview();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 16, color: VividColors.statusWarning),
                            const SizedBox(width: 8),
                            Text('Preview', style: TextStyle(color: vc.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: vc.textSecondary),
                            const SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: vc.textPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Stats Row ──
              Row(
                children: [
                  _buildStatBox(vc, Icons.people_outline, '$userCount', 'Users'),
                  const SizedBox(width: 8),
                  _buildStatBox(vc, Icons.extension_outlined, '${client.enabledFeatures.where((f) => const ['conversations', 'broadcasts', 'manager_chat'].contains(f)).length}/3', 'Features'),
                  const SizedBox(width: 8),
                  if (client.businessPhone != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: vc.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone, size: 12, color: vc.textMuted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                client.businessPhone!,
                                style: TextStyle(color: vc.textSecondary, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildStatBox(vc, Icons.phone_disabled, '—', 'Phone'),
                ],
              ),

              const SizedBox(height: 12),

              // ── Feature Chips with status dots ──
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Core features (filled chips)
                  ...client.enabledFeatures
                      .where((f) => const ['conversations', 'broadcasts', 'manager_chat'].contains(f))
                      .map((f) {
                    final color = _featureChipColor(f);
                    final configured = _isFeatureConfigured(client, f);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: configured
                                  ? VividColors.statusSuccess
                                  : VividColors.statusWarning,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _featureLabel(f),
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Add-on features (outlined, muted chips)
                  ...client.enabledFeatures
                      .where((f) => !const ['conversations', 'broadcasts', 'manager_chat'].contains(f))
                      .map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: vc.border),
                      ),
                      child: Text(
                        _featureLabel(f),
                        style: TextStyle(color: vc.textMuted, fontSize: 10, fontWeight: FontWeight.w400),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 14),

              // ── Quick Actions Row ──
              Row(
                children: [
                  _buildActionButton(
                    vc,
                    icon: Icons.visibility_outlined,
                    label: 'Preview',
                    color: VividColors.statusWarning,
                    onTap: widget.onPreview,
                  ),
                  const SizedBox(width: 8),
                  if (widget.onAnalytics != null)
                    _buildActionButton(
                      vc,
                      icon: Icons.insights,
                      label: 'Analytics',
                      color: VividColors.brightBlue,
                      onTap: widget.onAnalytics!,
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: VividColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(VividColorScheme vc, IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: vc.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: vc.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(color: vc.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(label, style: TextStyle(color: vc.textMuted, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(VividColorScheme vc, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// CLIENT DETAIL (shows users)
// ============================================

class _ClientDetail extends StatefulWidget {
  final Client client;

  const _ClientDetail({required this.client});

  @override
  State<_ClientDetail> createState() => _ClientDetailState();
}

class _ClientDetailState extends State<_ClientDetail> {
  // Track which feature is currently being toggled (for loading indicator)
  String? _togglingFeature;

  static const _allFeatures = ['conversations', 'broadcasts', 'analytics', 'manager_chat'];

  static const _featureNames = {
    'conversations': 'Conversations',
    'broadcasts': 'Broadcasts',
    'analytics': 'Analytics',
    'manager_chat': 'AI Assistant',
  };

  static const _featureIcons = {
    'conversations': Icons.chat_bubble_outline,
    'broadcasts': Icons.campaign,
    'analytics': Icons.insights,
    'manager_chat': Icons.smart_toy,
  };

  static Color _featureColor(String feature) {
    switch (feature) {
      case 'conversations': return VividColors.cyan;
      case 'broadcasts': return Colors.orange;
      case 'analytics': return VividColors.brightBlue;
      case 'manager_chat': return Colors.purple;
      default: return VividColors.cyan;
    }
  }

  /// Check if a feature's phone/webhook is fully configured.
  static bool _isConfigured(Client client, String feature) {
    bool notEmpty(String? v) => v != null && v.isNotEmpty;
    switch (feature) {
      case 'conversations':
        return notEmpty(client.conversationsPhone) && notEmpty(client.conversationsWebhookUrl);
      case 'broadcasts':
        return notEmpty(client.broadcastsPhone) && notEmpty(client.broadcastsWebhookUrl);
      case 'manager_chat':
        return notEmpty(client.managerChatWebhookUrl);
      default:
        return true; // analytics, etc. have no config
    }
  }

  /// Whether this feature has configurable fields at all.
  static bool _hasConfig(String feature) =>
      feature != 'analytics';

  Future<void> _toggleFeature(String feature, bool enable) async {
    final client = widget.client;
    setState(() => _togglingFeature = feature);

    final newFeatures = List<String>.from(client.enabledFeatures);
    if (enable) {
      if (!newFeatures.contains(feature)) newFeatures.add(feature);
    } else {
      newFeatures.remove(feature);
    }

    await context.read<AdminProvider>().updateClient(
      clientId: client.id,
      enabledFeatures: newFeatures,
    );

    if (mounted) setState(() => _togglingFeature = null);
  }

  Future<void> _toggleAi(bool value) async {
    setState(() => _togglingFeature = '_ai');
    await context.read<AdminProvider>().updateClient(
      clientId: widget.client.id,
      hasAiConversations: value,
    );
    if (mounted) setState(() => _togglingFeature = null);
  }

  void _openEditDialog() {
    showDialog(
      context: context,
      builder: (context) => _ClientDialog(client: widget.client),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<AdminProvider>();
    // Use fresh client from provider so toggles reflect immediately
    final client = provider.clients.firstWhere(
      (c) => c.id == widget.client.id,
      orElse: () => widget.client,
    );
    final users = provider.selectedClientUsers;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: vc.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(
                bottom: BorderSide(color: vc.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: VividColors.brightBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                  ),
                  child: Icon(Icons.business, color: VividColors.cyan, size: isMobile ? 20 : 28),
                ),
                SizedBox(width: isMobile ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slug: ${client.slug} ${client.businessPhone != null ? "• Phone: ${client.businessPhone}" : ""}',
                        style: TextStyle(color: vc.textMuted, fontSize: isMobile ? 11 : 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Features section
          _buildFeaturesSection(vc, client, isMobile),

          // Users section
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Row(
              children: [
                Text(
                  'Users',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: VividColors.brightBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${users.length}',
                    style: const TextStyle(color: VividColors.cyan, fontSize: 12),
                  ),
                ),
                const Spacer(),
                isMobile
                    ? IconButton(
                        onPressed: () => _showUserDialog(context, client.id),
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        style: IconButton.styleFrom(backgroundColor: VividColors.brightBlue),
                        tooltip: 'Add User',
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _showUserDialog(context, client.id),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VividColors.brightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add, size: 48, color: vc.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('No users yet', style: TextStyle(color: vc.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _UserTile(
                        user: user,
                        onEdit: () => _showUserDialog(context, client.id, user: user),
                        onToggleBlock: () => _confirmToggleBlock(context, user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Feature toggle dashboard ───────────────────────

  Widget _buildFeaturesSection(VividColorScheme vc, Client client, bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        isMobile ? 12 : 16,
        isMobile ? 12 : 20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Features',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: VividColors.brightBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${client.enabledFeatures.length}/${_allFeatures.length}',
                  style: const TextStyle(color: VividColors.cyan, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final feature in _allFeatures)
                _buildFeatureCard(vc, client, feature, isMobile),
              // AI Conversations toggle (only when conversations is enabled)
              if (client.enabledFeatures.contains('conversations'))
                _buildAiToggleCard(vc, client, isMobile),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: vc.border),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(VividColorScheme vc, Client client, String feature, bool isMobile) {
    final isEnabled = client.enabledFeatures.contains(feature);
    final color = _featureColor(feature);
    final isToggling = _togglingFeature == feature;
    final configured = isEnabled && _hasConfig(feature) && _isConfigured(client, feature);
    final cardWidth = isMobile ? 150.0 : 160.0;

    return Container(
      width: cardWidth,
      height: 120,
      decoration: BoxDecoration(
        color: isEnabled ? vc.surface : vc.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isEnabled ? color : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Icon(
              _featureIcons[feature] ?? Icons.extension,
              size: 24,
              color: isEnabled ? color : vc.textMuted,
            ),
            const SizedBox(height: 6),
            // Name
            Text(
              _featureNames[feature] ?? feature,
              style: TextStyle(
                color: isEnabled ? vc.textPrimary : vc.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Config status + toggle
            Row(
              children: [
                // Config indicator
                if (isEnabled && _hasConfig(feature))
                  Expanded(
                    child: configured
                        ? Row(
                            children: [
                              Icon(Icons.check_circle, size: 12, color: VividColors.statusSuccess),
                              const SizedBox(width: 3),
                              Text(
                                'Configured',
                                style: TextStyle(color: VividColors.statusSuccess, fontSize: 9),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: _openEditDialog,
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, size: 12, color: VividColors.statusWarning),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Configure',
                                    style: TextStyle(
                                      color: VividColors.statusWarning,
                                      fontSize: 9,
                                      decoration: TextDecoration.underline,
                                      decorationColor: VividColors.statusWarning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  )
                else
                  const Spacer(),
                // Toggle
                if (isToggling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
                  )
                else
                  SizedBox(
                    height: 24,
                    child: Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: isEnabled,
                        onChanged: (val) => _toggleFeature(feature, val),
                        activeColor: color,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiToggleCard(VividColorScheme vc, Client client, bool isMobile) {
    final isEnabled = client.hasAiConversations;
    final isToggling = _togglingFeature == '_ai';
    final cardWidth = isMobile ? 150.0 : 160.0;

    return Container(
      width: cardWidth,
      height: 120,
      decoration: BoxDecoration(
        color: isEnabled ? vc.surface : vc.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isEnabled ? VividColors.cyan : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 24,
              color: isEnabled ? VividColors.cyan : vc.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              'AI Conversations',
              style: TextStyle(
                color: isEnabled ? vc.textPrimary : vc.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEnabled ? 'AI replies on' : 'Manual only',
                    style: TextStyle(
                      color: isEnabled ? VividColors.cyan : vc.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ),
                if (isToggling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
                  )
                else
                  SizedBox(
                    height: 24,
                    child: Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: isEnabled,
                        onChanged: _toggleAi,
                        activeColor: VividColors.cyan,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, String clientId, {AppUser? user}) {
    showDialog(
      context: context,
      builder: (context) => _UserDialog(clientId: clientId, user: user),
    );
  }

  void _confirmToggleBlock(BuildContext context, AppUser user) {
    final vc = context.vividColors;
    final isBlocking = !user.isBlocked;
    final newStatus = isBlocking ? 'blocked' : 'active';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: vc.surface,
        title: Text(
          isBlocking ? 'Block User' : 'Unblock User',
          style: TextStyle(color: vc.textPrimary),
        ),
        content: Text(
          isBlocking
              ? 'Block "${user.name}"? They will no longer be able to log in.'
              : 'Unblock "${user.name}"? They will be able to log in again.',
          style: TextStyle(color: vc.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final success = await context.read<AdminProvider>().toggleUserStatus(user.id, newStatus);

              if (context.mounted) {
                VividToast.show(context,
                  message: success
                      ? 'User "${user.name}" ${isBlocking ? "blocked" : "unblocked"} successfully'
                      : 'Failed to ${isBlocking ? "block" : "unblock"} user.',
                  type: success ? ToastType.success : ToastType.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlocking ? Colors.red : VividColors.statusSuccess,
            ),
            child: Text(isBlocking ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// USER TILE (with role badge)
// ============================================

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onToggleBlock;

  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onToggleBlock,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: VividColors.brightBlue.withOpacity(0.2),
            child: Text(
              _getInitials(user.name),
              style: const TextStyle(
                color: VividColors.cyan,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
                        user.name,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: user.role.value),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (user.isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Blocked',
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            color: vc.textMuted,
          ),
          IconButton(
            onPressed: onToggleBlock,
            icon: Icon(user.isBlocked ? Icons.lock_open : Icons.block, size: 18),
            color: user.isBlocked ? VividColors.statusSuccess : Colors.red.withOpacity(0.7),
            tooltip: user.isBlocked ? 'Unblock' : 'Block',
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) => getInitials(name);
}

// ============================================
// ROLE BADGE
// ============================================

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final config = _getRoleConfig(context, role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config.color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 10, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _RoleConfig _getRoleConfig(BuildContext context, String role) {
    final vc = context.vividColors;
    switch (role.toLowerCase()) {
      case 'admin':
        return _RoleConfig(
          label: 'Admin',
          color: VividColors.cyan,
          icon: Icons.admin_panel_settings,
        );
      case 'manager':
        return _RoleConfig(
          label: 'Manager',
          color: Colors.purple,
          icon: Icons.manage_accounts,
        );
      case 'agent':
        return _RoleConfig(
          label: 'Agent',
          color: Colors.green,
          icon: Icons.support_agent,
        );
      case 'viewer':
        return _RoleConfig(
          label: 'Viewer',
          color: Colors.orange,
          icon: Icons.visibility,
        );
      default:
        return _RoleConfig(
          label: role,
          color: vc.textMuted,
          icon: Icons.person,
        );
    }
  }
}

class _RoleConfig {
  final String label;
  final Color color;
  final IconData icon;

  _RoleConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}

// ============================================
// USERS TAB (All users view)
// ============================================

class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<AdminProvider>();
    final users = provider.allUsers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'All Users (${users.length})',
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Table header (desktop only)
            if (!isMobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: vc.surface,
                  border: Border(
                    bottom: BorderSide(color: vc.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('Name', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600))),
                    Expanded(flex: 3, child: Text('Email', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text('Role', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Client', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600))),
                    SizedBox(width: 90, child: Text('Actions', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),

            // Users list
            Expanded(
              child: users.isEmpty
                      ? Center(child: Text('No users found', style: TextStyle(color: vc.textMuted)))
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final clientName = user['clients']?['name'] ?? 'No Client';
                            final role = user['role'] ?? 'unknown';

                            if (isMobile) {
                              return _buildMobileUserCard(context, user, clientName, role, provider);
                            }
                            return _buildDesktopUserRow(context, user, clientName, role, provider);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileUserCard(
    BuildContext context,
    Map<String, dynamic> user,
    String clientName,
    String role,
    AdminProvider provider,
  ) {
    final vc = context.vividColors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + role badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user['name'] ?? '',
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: role),
                  ],
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  user['email'] ?? '',
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Client name
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: VividColors.brightBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    clientName,
                    style: const TextStyle(color: VividColors.cyan, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          _buildUserActions(context, user, provider),
        ],
      ),
    );
  }

  Widget _buildDesktopUserRow(
    BuildContext context,
    Map<String, dynamic> user,
    String clientName,
    String role,
    AdminProvider provider,
  ) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: vc.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              user['name'] ?? '',
              style: TextStyle(color: vc.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              user['email'] ?? '',
              style: TextStyle(color: vc.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: _RoleBadge(role: role),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: VividColors.brightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                clientName,
                style: const TextStyle(color: VividColors.cyan, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _buildUserActions(context, user, provider),
        ],
      ),
    );
  }

  Widget _buildUserActions(
    BuildContext context,
    Map<String, dynamic> user,
    AdminProvider provider,
  ) {
    final vc = context.vividColors;
    return SizedBox(
      width: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => _showResetPasswordDialog(
              context,
              user['id'] as String,
              user['name'] as String? ?? 'User',
              provider,
            ),
            icon: const Icon(Icons.lock_reset, size: 18),
            color: VividColors.cyan,
            tooltip: 'Reset Password',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () async {
              final userId = user['id'] as String;
              final userName = user['name'] as String? ?? 'User';
              final currentStatus = user['status'] as String? ?? 'active';
              final isBlocking = currentStatus != 'blocked';
              final newStatus = isBlocking ? 'blocked' : 'active';

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: vc.surface,
                  title: Text(
                    isBlocking ? 'Block User' : 'Unblock User',
                    style: TextStyle(color: vc.textPrimary),
                  ),
                  content: Text(
                    isBlocking
                        ? 'Block "$userName"? They will no longer be able to log in.'
                        : 'Unblock "$userName"? They will be able to log in again.',
                    style: TextStyle(color: vc.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBlocking ? Colors.red : VividColors.statusSuccess,
                      ),
                      child: Text(isBlocking ? 'Block' : 'Unblock'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                final success = await provider.toggleUserStatus(userId, newStatus);

                if (context.mounted) {
                  VividToast.show(context,
                    message: success
                        ? 'User "$userName" ${isBlocking ? "blocked" : "unblocked"}'
                        : 'Failed to ${isBlocking ? "block" : "unblock"} user.',
                    type: success ? ToastType.success : ToastType.error,
                  );
                }
              }
            },
            icon: Icon(
              (user['status'] as String? ?? 'active') == 'blocked'
                  ? Icons.lock_open
                  : Icons.block,
              size: 18,
            ),
            color: (user['status'] as String? ?? 'active') == 'blocked'
                ? VividColors.statusSuccess
                : Colors.red.withOpacity(0.7),
            tooltip: (user['status'] as String? ?? 'active') == 'blocked'
                ? 'Unblock'
                : 'Block',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    String userId,
    String userName,
    AdminProvider provider,
  ) {
    final vc = context.vividColors;
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showPassword = false;
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: vc.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.lock_reset, color: VividColors.cyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset Password for $userName',
                    style: TextStyle(color: vc.textPrimary, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width < 600
                  ? MediaQuery.of(ctx).size.width * 0.9
                  : 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    style: TextStyle(color: vc.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(color: vc.textMuted, fontSize: 12),
                      hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.lock, color: vc.textMuted, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility_off : Icons.visibility,
                          color: vc.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setDialogState(() => showPassword = !showPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: vc.popupBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: VividColors.cyan),
                      ),
                      filled: true,
                      fillColor: vc.surfaceAlt,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !showPassword,
                    style: TextStyle(color: vc.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(color: vc.textMuted, fontSize: 12),
                      hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.lock, color: vc.textMuted, size: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: vc.popupBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: VividColors.cyan),
                      ),
                      filled: true,
                      fillColor: vc.surfaceAlt,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        final password = passwordController.text;
                        final confirm = confirmPasswordController.text;

                        if (password.isEmpty || password.length < 8) {
                          VividToast.show(ctx,
                            message: 'Password must be at least 8 characters',
                            type: ToastType.error,
                          );
                          return;
                        }

                        if (password != confirm) {
                          VividToast.show(ctx,
                            message: 'Passwords do not match',
                            type: ToastType.error,
                          );
                          return;
                        }

                        setDialogState(() => isResetting = true);

                        final success = await provider.resetUserPassword(
                          userId: userId,
                          newPassword: password,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (context.mounted) {
                          VividToast.show(context,
                            message: success
                                ? 'Password reset for "$userName"'
                                : 'Failed to reset password',
                            type: success ? ToastType.success : ToastType.error,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
                child: isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Reset Password'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// CLIENT DIALOG
// ============================================

// ============================================
// CLIENT ONBOARDING WIZARD (for new clients)
// ============================================

class _ClientOnboardingWizard extends StatefulWidget {
  const _ClientOnboardingWizard();

  @override
  State<_ClientOnboardingWizard> createState() => _ClientOnboardingWizardState();
}

class _ClientOnboardingWizardState extends State<_ClientOnboardingWizard> {
  int _currentStep = 0;
  static const _totalSteps = 5;
  final _formKeys = List.generate(_totalSteps, (_) => GlobalKey<FormState>());

  // Step 1 — Basic Info
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  bool _slugManuallyEdited = false;

  // Step 2 — Features
  final Set<String> _selectedFeatures = {};
  bool _hasAiConversations = true;

  // Step 3 — Configuration
  final _conversationsPhoneController = TextEditingController();
  final _conversationsWebhookController = TextEditingController();
  final _broadcastsPhoneController = TextEditingController();
  final _broadcastsWebhookController = TextEditingController();
  final _remindersPhoneController = TextEditingController();
  final _remindersWebhookController = TextEditingController();
  final _managerChatWebhookController = TextEditingController();
  // Step 4 — First User
  bool _createUser = false;
  final _userNameController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPasswordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _conversationsPhoneController.dispose();
    _conversationsWebhookController.dispose();
    _broadcastsPhoneController.dispose();
    _broadcastsWebhookController.dispose();
    _remindersPhoneController.dispose();
    _remindersWebhookController.dispose();
    _managerChatWebhookController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();
    super.dispose();
  }

  void _autoSlug(String name) {
    if (!_slugManuallyEdited) {
      _slugController.text = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    }
  }

  bool get _canAdvance {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().isNotEmpty && _slugController.text.trim().isNotEmpty;
      case 1:
        return _selectedFeatures.isNotEmpty;
      case 2:
        return true; // Config is optional
      case 3:
        if (!_createUser) return true;
        return _userNameController.text.trim().isNotEmpty &&
            _userEmailController.text.trim().isNotEmpty &&
            _userPasswordController.text.trim().length >= 6;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      final key = _formKeys[_currentStep];
      if (key.currentState?.validate() ?? true) {
        setState(() => _currentStep++);
      }
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final provider = context.read<AdminProvider>();

    final slug = _slugController.text.trim();

    // Auto-compute table names based on enabled features
    final messagesTable = _selectedFeatures.contains('conversations') ? '${slug}_messages' : null;
    final broadcastsTable = _selectedFeatures.contains('broadcasts') ? '${slug}_broadcasts' : null;
    final broadcastRecipientsTable = _selectedFeatures.contains('broadcasts') ? '${slug}_broadcast_recipients' : null;
    final managerChatsTable = _selectedFeatures.contains('manager_chat') ? '${slug}_manager_chats' : null;
    final templatesTable = (_selectedFeatures.contains('whatsapp_templates') || _selectedFeatures.contains('broadcasts')) ? '${slug}_whatsapp_templates' : null;
    final aiSettingsTable = '${slug}_ai_chat_settings';

    final success = await provider.createClient(
      name: _nameController.text.trim(),
      slug: slug,
      enabledFeatures: _selectedFeatures.toList(),
      hasAiConversations: _hasAiConversations,
      messagesTable: messagesTable,
      broadcastsTable: broadcastsTable,
      templatesTable: templatesTable,
      managerChatsTable: managerChatsTable,
      broadcastRecipientsTable: broadcastRecipientsTable,
      aiSettingsTable: aiSettingsTable,
      conversationsPhone: _conversationsPhoneController.text.trim().isEmpty ? null : _conversationsPhoneController.text.trim(),
      conversationsWebhookUrl: _conversationsWebhookController.text.trim().isEmpty ? null : _conversationsWebhookController.text.trim(),
      broadcastsPhone: _broadcastsPhoneController.text.trim().isEmpty ? null : _broadcastsPhoneController.text.trim(),
      broadcastsWebhookUrl: _broadcastsWebhookController.text.trim().isEmpty ? null : _broadcastsWebhookController.text.trim(),
      remindersPhone: _remindersPhoneController.text.trim().isEmpty ? null : _remindersPhoneController.text.trim(),
      remindersWebhookUrl: _remindersWebhookController.text.trim().isEmpty ? null : _remindersWebhookController.text.trim(),
      managerChatWebhookUrl: _managerChatWebhookController.text.trim().isEmpty ? null : _managerChatWebhookController.text.trim(),
    );

    if (!success) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        VividToast.show(context,
          message: provider.error ?? 'Failed to create client',
          type: ToastType.error,
        );
      }
      return;
    }

    // Optionally create first user
    if (_createUser && _userNameController.text.trim().isNotEmpty) {
      final newClient = provider.clients.firstWhere(
        (c) => c.slug == _slugController.text.trim(),
        orElse: () => provider.clients.first,
      );
      await provider.createUser(
        clientId: newClient.id,
        name: _userNameController.text.trim(),
        email: _userEmailController.text.trim(),
        password: _userPasswordController.text.trim(),
        role: 'admin',
      );
    }

    if (mounted) {
      Navigator.pop(context);
      VividToast.show(context,
        message: 'Client "${_nameController.text.trim()}" created successfully',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      backgroundColor: vc.background,
      shape: isMobile
          ? const RoundedRectangleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isMobile ? screenWidth : 700,
        height: isMobile ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: vc.background,
          borderRadius: isMobile ? null : BorderRadius.circular(20),
          border: isMobile ? null : Border.all(color: vc.border),
        ),
        child: Column(
          children: [
            _buildWizardHeader(vc, isMobile),
            _buildStepIndicator(vc, isMobile),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentStep(vc, isMobile),
              ),
            ),
            _buildNavBar(vc, isMobile),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────

  Widget _buildWizardHeader(VividColorScheme vc, bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 12 : 16, 8, isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(bottom: BorderSide(color: vc.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: VividColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_business, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Client',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _stepSubtitles[_currentStep],
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: vc.textMuted),
          ),
        ],
      ),
    );
  }

  static const _stepTitles = ['Basic Info', 'Features', 'Configuration', 'First User', 'Review'];
  static const _stepSubtitles = [
    'Step 1 of 5 — Name & slug',
    'Step 2 of 5 — Enable features',
    'Step 3 of 5 — Configure webhooks',
    'Step 4 of 5 — Optional admin user',
    'Step 5 of 5 — Review & create',
  ];

  // ── Step Indicator ──────────────────────────────────

  Widget _buildStepIndicator(VividColorScheme vc, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      color: vc.surface,
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepBefore = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepBefore < _currentStep ? VividColors.cyan : vc.border,
              ),
            );
          }
          final step = i ~/ 2;
          final isActive = step == _currentStep;
          final isCompleted = step < _currentStep;
          return GestureDetector(
            onTap: step < _currentStep ? () => setState(() => _currentStep = step) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? VividColors.cyan
                        : isActive
                            ? VividColors.cyan.withOpacity(0.2)
                            : vc.surfaceAlt,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? VividColors.cyan : (isCompleted ? VividColors.cyan : vc.border),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${step + 1}',
                            style: TextStyle(
                              color: isActive ? VividColors.cyan : vc.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 4),
                  Text(
                    _stepTitles[step],
                    style: TextStyle(
                      color: isActive ? VividColors.cyan : vc.textMuted,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step Content ────────────────────────────────────

  Widget _buildCurrentStep(VividColorScheme vc, bool isMobile) {
    Widget content;
    switch (_currentStep) {
      case 0:
        content = _buildStep1BasicInfo(vc, isMobile);
      case 1:
        content = _buildStep2Features(vc, isMobile);
      case 2:
        content = _buildStep3Config(vc, isMobile);
      case 3:
        content = _buildStep4User(vc, isMobile);
      case 4:
        content = _buildStep5Review(vc, isMobile);
      default:
        content = const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: ValueKey(_currentStep),
      child: content,
    );
  }

  // ── Step 1: Basic Info ──────────────────────────────

  Widget _buildStep1BasicInfo(VividColorScheme vc, bool isMobile) {
    final slug = _slugController.text.trim();
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Identity', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Choose a name and slug for the new client.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            _buildWizardField(
              vc,
              controller: _nameController,
              label: 'Client Name',
              hint: 'e.g., Karisma Beauty Lounge',
              icon: Icons.business,
              required: true,
              onChanged: (v) {
                _autoSlug(v);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _buildWizardField(
              vc,
              controller: _slugController,
              label: 'Slug',
              hint: 'e.g., karisma',
              icon: Icons.tag,
              required: true,
              onChanged: (v) {
                _slugManuallyEdited = v.isNotEmpty;
                setState(() {});
              },
            ),
            const SizedBox(height: 24),
            if (slug.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VividColors.cyan.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.table_chart, color: VividColors.cyan, size: 16),
                        const SizedBox(width: 8),
                        Text('Tables will be auto-created:', style: TextStyle(color: VividColors.cyan, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Based on enabled features in the next step.', style: TextStyle(color: vc.textMuted, fontSize: 11)),
                    const SizedBox(height: 8),
                    Text('${slug}_messages', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
                    Text('${slug}_broadcasts', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
                    Text('${slug}_broadcast_recipients', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
                    Text('${slug}_manager_chats', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
                    Text('${slug}_whatsapp_templates', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Features ────────────────────────────────

  static const _coreFeatureOptions = [
    ('conversations', Icons.forum, 'Conversations', 'WhatsApp customer conversations'),
    ('broadcasts', Icons.campaign, 'Broadcasts', 'Send bulk WhatsApp campaigns'),
    ('manager_chat', Icons.smart_toy, 'AI Assistant', 'Manager AI chatbot'),
  ];

  static const _addonOptions = [
    ('labels', Icons.label, 'Labels', 'Works with Conversations'),
    ('whatsapp_templates', Icons.article_outlined, 'Templates', 'Works with Broadcasts'),
    ('media', Icons.perm_media, 'Media', 'Works with Conversations'),
  ];

  /// Auto-enable analytics when any core feature is on, auto-disable when none are.
  void _syncAnalytics() {
    final hasCoreFeature = _selectedFeatures.any((f) => const ['conversations', 'broadcasts', 'manager_chat'].contains(f));
    if (hasCoreFeature && !_selectedFeatures.contains('analytics')) {
      _selectedFeatures.add('analytics');
    } else if (!hasCoreFeature) {
      _selectedFeatures.remove('analytics');
    }
  }

  Widget _buildStep2Features(VividColorScheme vc, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Core Features
            Text('Core Features', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('The main features for this client.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = isMobile ? 2 : 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _coreFeatureOptions.map((opt) {
                    final (key, icon, title, desc) = opt;
                    final isSelected = _selectedFeatures.contains(key);
                    final cardWidth = (constraints.maxWidth - (crossCount - 1) * 12) / crossCount;
                    return SizedBox(
                      width: cardWidth,
                      child: _buildFeatureCard(vc, key, icon, title, desc, isSelected),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            // Analytics auto-enabled note
            if (_selectedFeatures.contains('analytics'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VividColors.brightBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VividColors.brightBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 16, color: VividColors.brightBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Analytics auto-enabled for all core features', style: TextStyle(color: VividColors.brightBlue, fontSize: 12))),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Add-ons
            Text('Add-ons', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Extras that enhance core features.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = isMobile ? 2 : 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _addonOptions.map((opt) {
                    final (key, icon, title, desc) = opt;
                    final isSelected = _selectedFeatures.contains(key);
                    final cardWidth = (constraints.maxWidth - (crossCount - 1) * 12) / crossCount;
                    return SizedBox(
                      width: cardWidth,
                      child: _buildFeatureCard(vc, key, icon, title, desc, isSelected),
                    );
                  }).toList(),
                );
              },
            ),
            // Feature dependency notes
            ..._buildFeatureDependencyNotes(vc),

            if (_selectedFeatures.contains('conversations')) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vc.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: vc.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('AI-Powered Conversations', style: TextStyle(color: vc.textPrimary, fontSize: 14)),
                  subtitle: Text(
                    _hasAiConversations
                        ? 'AI handles customer messages automatically'
                        : 'All messages go directly to managers',
                    style: TextStyle(color: vc.textMuted, fontSize: 12),
                  ),
                  secondary: Icon(Icons.smart_toy, color: _hasAiConversations ? VividColors.cyan : vc.textMuted, size: 20),
                  value: _hasAiConversations,
                  onChanged: (val) => setState(() => _hasAiConversations = val),
                  activeTrackColor: VividColors.cyan.withOpacity(0.3),
                ),
              ),
            ],

            // Label configuration section
            if (_selectedFeatures.contains('labels')) ...[
              const SizedBox(height: 20),
              _buildLabelConfigSection(vc),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(VividColorScheme vc, String key, IconData icon, String title, String desc, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFeatures.remove(key);
          } else {
            _selectedFeatures.add(key);
          }
          _syncAnalytics();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? VividColors.cyan.withOpacity(0.08) : vc.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? VividColors.cyan.withOpacity(0.6) : vc.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? VividColors.cyan : vc.textMuted, size: 22),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: VividColors.cyan,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: isSelected ? VividColors.cyan : vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: vc.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatureDependencyNotes(VividColorScheme vc) {
    final notes = <Widget>[];
    if (_selectedFeatures.contains('whatsapp_templates') && !_selectedFeatures.contains('broadcasts')) {
      notes.add(const SizedBox(height: 12));
      notes.add(_buildDependencyNote(vc, Icons.info_outline, Colors.orange, 'WhatsApp Templates requires the Broadcasts feature to send template messages.'));
    }
    if (_selectedFeatures.contains('labels')) {
      notes.add(const SizedBox(height: 12));
      notes.add(_buildDependencyNote(vc, Icons.label_outline, Colors.amber, 'Labels works with Conversations to auto-tag messages based on trigger words.'));
    }
    if (_selectedFeatures.contains('media')) {
      notes.add(const SizedBox(height: 12));
      notes.add(_buildDependencyNote(vc, Icons.image_outlined, Colors.blue, 'Media Support enables photo/PDF sharing in conversations.'));
    }
    return notes;
  }

  Widget _buildDependencyNote(VividColorScheme vc, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: vc.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildLabelConfigSection(VividColorScheme vc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('Label Configuration', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Labels can be auto-applied based on trigger words in messages. Configure trigger words after the client is created.',
            style: TextStyle(color: vc.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: null, // Configured after creation
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Configure Label Triggers'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Configuration ───────────────────────────

  Widget _buildStep3Config(VividColorScheme vc, bool isMobile) {
    final hasSomething = _selectedFeatures.intersection({'conversations', 'broadcasts', 'manager_chat'}).isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuration', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              hasSomething ? 'Configure phone numbers and webhooks for selected features.' : 'No features require configuration.',
              style: TextStyle(color: vc.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (_selectedFeatures.contains('conversations'))
              _buildConfigSection(vc, Icons.chat_bubble, 'Conversations', Colors.blue,
                  phoneController: _conversationsPhoneController,
                  phoneHint: 'WhatsApp number for conversations',
                  webhookController: _conversationsWebhookController,
                  webhookHint: 'n8n webhook for customer messages'),
            if (_selectedFeatures.contains('broadcasts'))
              _buildConfigSection(vc, Icons.campaign, 'Broadcasts', Colors.orange,
                  phoneController: _broadcastsPhoneController,
                  phoneHint: 'WhatsApp number for broadcasts',
                  webhookController: _broadcastsWebhookController,
                  webhookHint: 'n8n webhook for broadcast messages'),
            if (_selectedFeatures.contains('manager_chat'))
              _buildConfigSection(vc, Icons.smart_toy, 'Manager Chat (AI)', Colors.purple,
                  webhookController: _managerChatWebhookController,
                  webhookHint: 'n8n webhook for AI assistant'),
            if (!hasSomething)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: vc.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.settings_outlined, size: 40, color: vc.textMuted.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text('Selected features don\'t need additional config.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
                      Text('You can proceed to the next step.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(
    VividColorScheme vc,
    IconData icon,
    String title,
    Color color, {
    TextEditingController? phoneController,
    String? phoneHint,
    required TextEditingController webhookController,
    required String webhookHint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 14),
            if (phoneController != null) ...[
              _buildWizardField(vc, controller: phoneController, label: 'Phone', hint: phoneHint ?? '', icon: Icons.phone, required: false),
              const SizedBox(height: 10),
            ],
            _buildWizardField(vc, controller: webhookController, label: 'Webhook URL', hint: webhookHint, icon: Icons.webhook, required: false),
          ],
        ),
      ),
    );
  }

  // ── Step 4: First User ──────────────────────────────

  Widget _buildStep4User(VividColorScheme vc, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('First User (Optional)', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Optionally create an admin user who can log in for this client.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vc.border),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Create an admin user for this client?', style: TextStyle(color: vc.textPrimary, fontSize: 14)),
                subtitle: Text('Role will be set to admin automatically.', style: TextStyle(color: vc.textMuted, fontSize: 12)),
                secondary: Icon(Icons.person_add, color: _createUser ? VividColors.cyan : vc.textMuted, size: 22),
                value: _createUser,
                onChanged: (val) => setState(() => _createUser = val),
                activeTrackColor: VividColors.cyan.withOpacity(0.3),
              ),
            ),
            if (_createUser) ...[
              const SizedBox(height: 20),
              _buildWizardField(vc, controller: _userNameController, label: 'Full Name', hint: 'Admin user name', icon: Icons.person, required: true),
              const SizedBox(height: 12),
              _buildWizardField(vc, controller: _userEmailController, label: 'Email', hint: 'admin@example.com', icon: Icons.email, required: true),
              const SizedBox(height: 12),
              _buildWizardField(vc, controller: _userPasswordController, label: 'Password', hint: 'Minimum 6 characters', icon: Icons.lock, required: true, obscure: true),
            ],
          ],
        ),
      ),
    );
  }

  // ── Step 5: Review ──────────────────────────────────

  Widget _buildStep5Review(VividColorScheme vc, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Form(
        key: _formKeys[4],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review & Create', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Confirm everything looks correct.', style: TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            // Client info
            _buildReviewSection(vc, Icons.business, 'Client', [
              ('Name', _nameController.text.trim()),
              ('Slug', _slugController.text.trim()),
            ]),
            const SizedBox(height: 16),
            // Features
            _buildReviewSection(vc, Icons.extension, 'Features', [
              for (final f in _selectedFeatures) (f.replaceAll('_', ' '), ''),
            ], isChips: true),
            if (_selectedFeatures.contains('conversations') && _hasAiConversations) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, size: 14, color: VividColors.cyan),
                    const SizedBox(width: 6),
                    Text('AI-Powered Conversations enabled', style: TextStyle(color: VividColors.cyan, fontSize: 12)),
                  ],
                ),
              ),
            ],
            // Configuration summary
            ..._buildConfigReviewItems(vc),
            // User
            if (_createUser) ...[
              const SizedBox(height: 16),
              _buildReviewSection(vc, Icons.person_add, 'First User', [
                ('Name', _userNameController.text.trim()),
                ('Email', _userEmailController.text.trim()),
                ('Role', 'admin'),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfigReviewItems(VividColorScheme vc) {
    final items = <(String, String)>[];
    if (_conversationsPhoneController.text.trim().isNotEmpty) items.add(('Conv. Phone', _conversationsPhoneController.text.trim()));
    if (_conversationsWebhookController.text.trim().isNotEmpty) items.add(('Conv. Webhook', _conversationsWebhookController.text.trim()));
    if (_broadcastsPhoneController.text.trim().isNotEmpty) items.add(('Broadcast Phone', _broadcastsPhoneController.text.trim()));
    if (_broadcastsWebhookController.text.trim().isNotEmpty) items.add(('Broadcast Webhook', _broadcastsWebhookController.text.trim()));
    if (_remindersPhoneController.text.trim().isNotEmpty) items.add(('Reminders Phone', _remindersPhoneController.text.trim()));
    if (_remindersWebhookController.text.trim().isNotEmpty) items.add(('Reminders Webhook', _remindersWebhookController.text.trim()));
    if (_managerChatWebhookController.text.trim().isNotEmpty) items.add(('Manager Chat Webhook', _managerChatWebhookController.text.trim()));
    final widgets = <Widget>[];
    if (items.isNotEmpty) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildReviewSection(vc, Icons.settings, 'Configuration', items));
    }

    // Auto-computed tables summary
    final slug = _slugController.text.trim();
    if (slug.isNotEmpty) {
      final tableItems = <(String, String)>[];
      if (_selectedFeatures.contains('conversations')) tableItems.add(('Messages', '${slug}_messages'));
      if (_selectedFeatures.contains('broadcasts')) {
        tableItems.add(('Broadcasts', '${slug}_broadcasts'));
        tableItems.add(('Recipients', '${slug}_broadcast_recipients'));
      }
      if (_selectedFeatures.contains('manager_chat')) tableItems.add(('Manager Chats', '${slug}_manager_chats'));
      if (_selectedFeatures.contains('whatsapp_templates') || _selectedFeatures.contains('broadcasts')) {
        tableItems.add(('Templates', '${slug}_whatsapp_templates'));
      }
      if (tableItems.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildReviewSection(vc, Icons.table_chart, 'Auto-Configured Tables', tableItems));
      }
    }

    return widgets;
  }

  Widget _buildReviewSection(VividColorScheme vc, IconData icon, String title, List<(String, String)> items, {bool isChips = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              Icon(icon, color: VividColors.cyan, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          if (isChips)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: VividColors.cyan, size: 14),
                      const SizedBox(width: 4),
                      Text(item.$1, style: const TextStyle(color: VividColors.cyan, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(item.$1, style: TextStyle(color: vc.textMuted, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: TextStyle(color: vc.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Navigation Bar ──────────────────────────────────

  Widget _buildNavBar(VividColorScheme vc, bool isMobile) {
    final isLastStep = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(top: BorderSide(color: vc.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(foregroundColor: vc.textMuted),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: (_isSubmitting || !_canAdvance) ? null : (isLastStep ? _submit : _next),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastStep ? VividColors.statusSuccess : VividColors.brightBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: vc.surfaceAlt,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isLastStep ? 'Create Client' : 'Next'),
                      if (!isLastStep) ...[const SizedBox(width: 4), const Icon(Icons.arrow_forward, size: 18)],
                      if (isLastStep) ...[const SizedBox(width: 4), const Icon(Icons.check, size: 18)],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Shared Field Builder ────────────────────────────

  Widget _buildWizardField(
    VividColorScheme vc, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = true,
    bool obscure = false,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: vc.textPrimary),
      onChanged: (v) {
        onChanged?.call(v);
        setState(() {}); // Refresh _canAdvance
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: vc.textMuted, size: 20),
        labelStyle: TextStyle(color: vc.textMuted),
        hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: vc.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VividColors.statusUrgent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VividColors.statusUrgent),
        ),
        filled: true,
        fillColor: vc.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return '$label is required';
              if (label == 'Password' && v.trim().length < 6) return 'Minimum 6 characters';
              return null;
            }
          : null,
    );
  }
}

// ============================================
// CLIENT DIALOG (for editing existing clients)
// ============================================

class _ClientDialog extends StatefulWidget {
  final Client? client;

  const _ClientDialog({this.client});

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic info controllers
  late TextEditingController _nameController;
  late TextEditingController _slugController;
  // Per-feature controllers
  late TextEditingController _conversationsPhoneController;
  late TextEditingController _conversationsWebhookController;
  late TextEditingController _broadcastsPhoneController;
  late TextEditingController _broadcastsWebhookController;
  late TextEditingController _remindersPhoneController;
  late TextEditingController _remindersWebhookController;
  late TextEditingController _managerChatWebhookController;
  
  List<String> _selectedFeatures = [];
  bool _hasAiConversations = true;
  bool _isLoading = false;

  void _syncAnalytics() {
    final hasCoreFeature = _selectedFeatures.any((f) => const ['conversations', 'broadcasts', 'manager_chat'].contains(f));
    if (hasCoreFeature && !_selectedFeatures.contains('analytics')) {
      _selectedFeatures.add('analytics');
    } else if (!hasCoreFeature) {
      _selectedFeatures.remove('analytics');
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _slugController = TextEditingController(text: widget.client?.slug ?? '');
    // Per-feature initialization
    _conversationsPhoneController = TextEditingController(text: widget.client?.conversationsPhone ?? '');
    _conversationsWebhookController = TextEditingController(text: widget.client?.conversationsWebhookUrl ?? '');
    _broadcastsPhoneController = TextEditingController(text: widget.client?.broadcastsPhone ?? '');
    _broadcastsWebhookController = TextEditingController(text: widget.client?.broadcastsWebhookUrl ?? '');
    _remindersPhoneController = TextEditingController(text: widget.client?.remindersPhone ?? '');
    _remindersWebhookController = TextEditingController(text: widget.client?.remindersWebhookUrl ?? '');
    _managerChatWebhookController = TextEditingController(text: widget.client?.managerChatWebhookUrl ?? '');

    _selectedFeatures = List.from(widget.client?.enabledFeatures ?? []);
    _hasAiConversations = widget.client?.hasAiConversations ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _conversationsPhoneController.dispose();
    _conversationsWebhookController.dispose();
    _broadcastsPhoneController.dispose();
    _broadcastsWebhookController.dispose();
    _remindersPhoneController.dispose();
    _remindersWebhookController.dispose();
    _managerChatWebhookController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isEdit = widget.client != null;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AlertDialog(
      backgroundColor: vc.surface,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(
        isEdit ? 'Edit Client' : 'Add Client',
        style: TextStyle(color: vc.textPrimary),
      ),
      content: SizedBox(
        width: isMobile ? screenWidth : 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info Section
                _buildSectionHeader(context, Icons.business, 'Basic Information'),
                const SizedBox(height: 12),
                _buildTextField(context, _nameController, 'Client Name', 'Enter client name'),
                const SizedBox(height: 12),
                _buildTextField(context, _slugController, 'Slug', 'e.g., 3bs, karisma'),
                const SizedBox(height: 12),
                // Core Features
                Text('Core Features', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['conversations', 'broadcasts', 'manager_chat'].map((feature) {
                    final isSelected = _selectedFeatures.contains(feature);
                    return FilterChip(
                      label: Text(_formatFeatureName(feature)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFeatures.add(feature);
                          } else {
                            _selectedFeatures.remove(feature);
                          }
                          _syncAnalytics();
                        });
                      },
                      selectedColor: VividColors.brightBlue.withOpacity(0.3),
                      checkmarkColor: VividColors.cyan,
                      labelStyle: TextStyle(color: isSelected ? VividColors.cyan : vc.textMuted),
                      backgroundColor: vc.surfaceAlt,
                    );
                  }).toList(),
                ),
                if (_selectedFeatures.contains('analytics'))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Analytics auto-enabled', style: TextStyle(color: VividColors.brightBlue, fontSize: 11)),
                  ),
                const SizedBox(height: 16),
                // Add-ons
                Text('Add-ons', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['labels', 'whatsapp_templates', 'media'].map((feature) {
                    final isSelected = _selectedFeatures.contains(feature);
                    return FilterChip(
                      label: Text(_formatFeatureName(feature)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFeatures.add(feature);
                          } else {
                            _selectedFeatures.remove(feature);
                          }
                        });
                      },
                      selectedColor: VividColors.brightBlue.withOpacity(0.3),
                      checkmarkColor: VividColors.cyan,
                      labelStyle: TextStyle(color: isSelected ? VividColors.cyan : vc.textMuted),
                      backgroundColor: vc.surfaceAlt,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Feature dependency notes
                if (_selectedFeatures.contains('whatsapp_templates') && !_selectedFeatures.contains('broadcasts'))
                  _buildDialogDependencyNote(vc, Icons.info_outline, Colors.orange, 'Requires Broadcasts feature'),
                if (_selectedFeatures.contains('labels'))
                  _buildDialogDependencyNote(vc, Icons.label_outline, Colors.amber, 'Works with Conversations to auto-tag messages'),
                if (_selectedFeatures.contains('media'))
                  _buildDialogDependencyNote(vc, Icons.image_outlined, Colors.blue, 'Enables photo/PDF sharing in conversations'),

                const SizedBox(height: 8),

                // AI Conversations toggle
                if (_selectedFeatures.contains('conversations'))
                  SwitchListTile(
                    title: Text(
                      'AI-Powered Conversations',
                      style: TextStyle(color: vc.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      _hasAiConversations
                          ? 'AI handles customer messages automatically'
                          : 'All messages go directly to managers',
                      style: TextStyle(color: vc.textMuted, fontSize: 12),
                    ),
                    value: _hasAiConversations,
                    onChanged: (val) => setState(() => _hasAiConversations = val),
                    activeTrackColor: VividColors.cyan.withOpacity(0.3),
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.smart_toy,
                      color: _hasAiConversations ? VividColors.cyan : vc.textMuted,
                      size: 20,
                    ),
                  ),

                // Label configuration section
                if (_selectedFeatures.contains('labels')) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.label, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text('Label Configuration', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Labels can be auto-applied based on trigger words in messages.',
                          style: TextStyle(color: vc.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.tune, size: 14),
                          label: const Text('Configure Label Triggers'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Feature Configuration Sections
                // Only show config for enabled features
                if (_selectedFeatures.contains('conversations')) ...[
                  _buildFeatureConfigSection(
                    context,
                    icon: Icons.chat_bubble,
                    title: 'Conversations',
                    color: Colors.blue,
                    phoneController: _conversationsPhoneController,
                    webhookController: _conversationsWebhookController,
                    phoneHint: 'WhatsApp number for conversations',
                    webhookHint: 'n8n webhook for customer messages',
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedFeatures.contains('broadcasts')) ...[
                  _buildFeatureConfigSection(
                    context,
                    icon: Icons.campaign,
                    title: 'Broadcasts',
                    color: Colors.orange,
                    phoneController: _broadcastsPhoneController,
                    webhookController: _broadcastsWebhookController,
                    phoneHint: 'WhatsApp number for broadcasts',
                    webhookHint: 'n8n webhook for broadcast messages',
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedFeatures.contains('manager_chat')) ...[
                  _buildFeatureConfigSection(
                    context,
                    icon: Icons.smart_toy,
                    title: 'Manager Chat (AI)',
                    color: Colors.purple,
                    phoneController: null, // No phone needed
                    webhookController: _managerChatWebhookController,
                    webhookHint: 'n8n webhook for AI assistant',
                  ),
                  const SizedBox(height: 16),
                ],

                // Show configured table names (read-only) for existing clients
                if (widget.client != null) ...[
                  const SizedBox(height: 8),
                  _buildSectionHeader(context, Icons.table_chart, 'Configured Tables'),
                  const SizedBox(height: 8),
                  _buildReadOnlyTables(context),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    final vc = context.vividColors;
    return Row(
      children: [
        Icon(icon, color: VividColors.cyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: vc.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureConfigSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    TextEditingController? phoneController,
    required TextEditingController webhookController,
    String? phoneHint,
    required String webhookHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (phoneController != null) ...[
            _buildTextField(
              context,
              phoneController,
              'Phone',
              phoneHint ?? 'WhatsApp number',
              required: false,
            ),
            const SizedBox(height: 10),
          ],
          _buildTextField(
            context,
            webhookController,
            'Webhook URL',
            webhookHint,
            required: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
  }) {
    final vc = context.vividColors;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: vc.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: vc.textMuted),
        hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: vc.popupBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: vc.surfaceAlt,
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }

  Widget _buildDialogDependencyNote(VividColorScheme vc, IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildReadOnlyTables(BuildContext context) {
    final vc = context.vividColors;
    final c = widget.client!;
    final tables = <(String, String?)>[
      ('Messages', c.messagesTable),
      ('Broadcasts', c.broadcastsTable),
      ('Recipients', c.broadcastRecipientsTable),
      ('Manager Chats', c.managerChatsTable),
      ('Templates', c.templatesTable),
    ];
    final configured = tables.where((t) => t.$2 != null && t.$2!.isNotEmpty).toList();
    if (configured.isEmpty) {
      return Text('No tables configured', style: TextStyle(color: vc.textMuted, fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: configured.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(t.$1, style: TextStyle(color: vc.textMuted, fontSize: 12)),
                ),
                Expanded(
                  child: Text(
                    t.$2!,
                    style: TextStyle(color: vc.textSecondary, fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<AdminProvider>();
    bool success;

    final editSlug = _slugController.text.trim();

    if (widget.client != null) {
      // Edit mode: don't auto-overwrite existing table names
      success = await provider.updateClient(
        clientId: widget.client!.id,
        name: _nameController.text.trim(),
        slug: editSlug,
        enabledFeatures: _selectedFeatures,
        hasAiConversations: _hasAiConversations,
        conversationsPhone: _conversationsPhoneController.text.trim().isEmpty ? null : _conversationsPhoneController.text.trim(),
        conversationsWebhookUrl: _conversationsWebhookController.text.trim().isEmpty ? null : _conversationsWebhookController.text.trim(),
        broadcastsPhone: _broadcastsPhoneController.text.trim().isEmpty ? null : _broadcastsPhoneController.text.trim(),
        broadcastsWebhookUrl: _broadcastsWebhookController.text.trim().isEmpty ? null : _broadcastsWebhookController.text.trim(),
        remindersPhone: _remindersPhoneController.text.trim().isEmpty ? null : _remindersPhoneController.text.trim(),
        remindersWebhookUrl: _remindersWebhookController.text.trim().isEmpty ? null : _remindersWebhookController.text.trim(),
        managerChatWebhookUrl: _managerChatWebhookController.text.trim().isEmpty ? null : _managerChatWebhookController.text.trim(),
      );
    } else {
      // Create mode: auto-compute all table names from slug
      final messagesTable = _selectedFeatures.contains('conversations') ? '${editSlug}_messages' : null;
      final broadcastsTable = _selectedFeatures.contains('broadcasts') ? '${editSlug}_broadcasts' : null;
      final broadcastRecipientsTable = _selectedFeatures.contains('broadcasts') ? '${editSlug}_broadcast_recipients' : null;
      final managerChatsTable = _selectedFeatures.contains('manager_chat') ? '${editSlug}_manager_chats' : null;
      final templatesTable = (_selectedFeatures.contains('whatsapp_templates') || _selectedFeatures.contains('broadcasts')) ? '${editSlug}_whatsapp_templates' : null;
      final aiSettingsTable = '${editSlug}_ai_chat_settings';

      success = await provider.createClient(
        name: _nameController.text.trim(),
        slug: editSlug,
        enabledFeatures: _selectedFeatures,
        hasAiConversations: _hasAiConversations,
        messagesTable: messagesTable,
        broadcastsTable: broadcastsTable,
        templatesTable: templatesTable,
        managerChatsTable: managerChatsTable,
        broadcastRecipientsTable: broadcastRecipientsTable,
        aiSettingsTable: aiSettingsTable,
        conversationsPhone: _conversationsPhoneController.text.trim().isEmpty ? null : _conversationsPhoneController.text.trim(),
        conversationsWebhookUrl: _conversationsWebhookController.text.trim().isEmpty ? null : _conversationsWebhookController.text.trim(),
        broadcastsPhone: _broadcastsPhoneController.text.trim().isEmpty ? null : _broadcastsPhoneController.text.trim(),
        broadcastsWebhookUrl: _broadcastsWebhookController.text.trim().isEmpty ? null : _broadcastsWebhookController.text.trim(),
        remindersPhone: _remindersPhoneController.text.trim().isEmpty ? null : _remindersPhoneController.text.trim(),
        remindersWebhookUrl: _remindersWebhookController.text.trim().isEmpty ? null : _remindersWebhookController.text.trim(),
        managerChatWebhookUrl: _managerChatWebhookController.text.trim().isEmpty ? null : _managerChatWebhookController.text.trim(),
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  String _formatFeatureName(String feature) {
    switch (feature) {
      case 'conversations':
        return 'Conversations';
      case 'broadcasts':
        return 'Broadcasts';
      case 'whatsapp_templates':
        return 'Templates';
      case 'analytics':
        return 'Analytics';
      case 'manager_chat':
        return 'AI Assistant';
      case 'media':
        return 'Media';
      case 'labels':
        return 'Labels';
      default:
        return feature;
    }
  }
}

// ============================================
// USER DIALOG (with role dropdown)
// ============================================

class _UserDialog extends StatefulWidget {
  final String clientId;
  final AppUser? user;

  const _UserDialog({required this.clientId, this.user});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  String _selectedRole = 'manager';
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showCustomPermissions = false;
  
  // Custom permission overrides
  Set<Permission> _customPermissions = {};
  Set<Permission> _revokedPermissions = {};

  final List<Map<String, dynamic>> _roles = [
    {'value': 'admin', 'label': 'Admin', 'description': 'Full access + user management', 'icon': Icons.admin_panel_settings, 'color': VividColors.cyan},
    {'value': 'manager', 'label': 'Manager', 'description': 'All features except user management', 'icon': Icons.manage_accounts, 'color': Colors.purple},
    {'value': 'agent', 'label': 'Agent', 'description': 'Conversations only', 'icon': Icons.support_agent, 'color': Colors.green},
    {'value': 'viewer', 'label': 'Viewer', 'description': 'Read-only access', 'icon': Icons.visibility, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedRole = widget.user?.role.value ?? 'manager';
    
    // Load existing custom permissions
    if (widget.user != null) {
      _customPermissions = Set.from(widget.user!.customPermissions ?? {});
      _revokedPermissions = Set.from(widget.user!.revokedPermissions ?? {});
      _showCustomPermissions = _customPermissions.isNotEmpty || _revokedPermissions.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Get role default permissions
  Set<Permission> get _rolePermissions {
    final role = UserRole.fromString(_selectedRole);
    return Permissions.getPermissions(role);
  }

  /// Get effective permissions (role + custom - revoked)
  Set<Permission> get _effectivePermissions {
    Set<Permission> perms = Set.from(_rolePermissions);
    perms.addAll(_customPermissions);
    perms.removeAll(_revokedPermissions);
    return perms;
  }

  /// Check if permission is from role default
  bool _isRoleDefault(Permission permission) {
    return _rolePermissions.contains(permission);
  }

  /// Check if permission is custom granted (not in role)
  bool _isCustomGranted(Permission permission) {
    return _customPermissions.contains(permission);
  }

  /// Check if permission is revoked
  bool _isRevoked(Permission permission) {
    return _revokedPermissions.contains(permission);
  }

  /// Toggle permission
  void _togglePermission(Permission permission) {
    setState(() {
      if (_isRevoked(permission)) {
        // Currently revoked -> enable it (remove from revoked)
        _revokedPermissions.remove(permission);
      } else if (_effectivePermissions.contains(permission)) {
        // Currently enabled
        if (_isRoleDefault(permission)) {
          // It's a role default -> revoke it
          _revokedPermissions.add(permission);
          _customPermissions.remove(permission);
        } else {
          // It's custom granted -> remove the grant
          _customPermissions.remove(permission);
        }
      } else {
        // Currently disabled -> grant it
        _customPermissions.add(permission);
        _revokedPermissions.remove(permission);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isEdit = widget.user != null;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AlertDialog(
      backgroundColor: vc.surface,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(
        isEdit ? 'Edit User' : 'Add User',
        style: TextStyle(color: vc.textPrimary),
      ),
      content: SizedBox(
        width: isMobile ? screenWidth : 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(context, _nameController, 'Name', 'User\'s name'),
                const SizedBox(height: 16),
                _buildTextField(context, _emailController, 'Email', 'login@email.com'),
                const SizedBox(height: 16),
                _buildPasswordField(
                  context,
                  _passwordController,
                  isEdit ? 'New Password (optional)' : 'Password',
                  'Enter password',
                  required: !isEdit,
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    context,
                    _confirmPasswordController,
                    'Confirm Password',
                    'Re-enter password',
                    required: true,
                  ),
                ],
                const SizedBox(height: 20),
                
                // Role selection
                Text(
                  'Role',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: vc.popupBorder),
                  ),
                  child: Column(
                    children: _roles.map((role) {
                      final isSelected = _selectedRole == role['value'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRole = role['value'];
                            // Clear custom permissions when role changes
                            if (!_showCustomPermissions) {
                              _customPermissions.clear();
                              _revokedPermissions.clear();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? (role['color'] as Color).withOpacity(0.15) : null,
                            border: _roles.last != role 
                                ? Border(bottom: BorderSide(color: vc.border))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? role['color'] as Color : vc.textMuted,
                                    width: 2,
                                  ),
                                  color: isSelected ? role['color'] as Color : Colors.transparent,
                                ),
                                child: isSelected 
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                role['icon'] as IconData,
                                size: 18,
                                color: isSelected ? role['color'] as Color : vc.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role['label'] as String,
                                      style: TextStyle(
                                        color: isSelected ? vc.textPrimary : vc.textMuted,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      role['description'] as String,
                                      style: TextStyle(
                                        color: vc.textMuted.withOpacity(0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Info note for admin role
                if (_selectedRole == 'admin') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VividColors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VividColors.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: VividColors.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This user will be a Client Admin (not Vivid Admin) since they belong to a client.',
                            style: TextStyle(
                              color: VividColors.cyan.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Custom Permissions Toggle
                InkWell(
                  onTap: () => setState(() => _showCustomPermissions = !_showCustomPermissions),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showCustomPermissions 
                          ? Colors.purple.withOpacity(0.1) 
                          : vc.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showCustomPermissions 
                            ? Colors.purple.withOpacity(0.3) 
                            : vc.popupBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showCustomPermissions 
                              ? Icons.tune 
                              : Icons.tune_outlined,
                          size: 18,
                          color: _showCustomPermissions 
                              ? Colors.purple 
                              : vc.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom Permissions',
                                style: TextStyle(
                                  color: _showCustomPermissions 
                                      ? vc.textPrimary 
                                      : vc.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _showCustomPermissions
                                    ? 'Override role defaults'
                                    : 'Use role defaults',
                                style: TextStyle(
                                  color: vc.textMuted.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _showCustomPermissions 
                              ? Icons.keyboard_arrow_up 
                              : Icons.keyboard_arrow_down,
                          color: vc.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),

                // Custom Permissions List
                if (_showCustomPermissions) ...[
                  const SizedBox(height: 12),
                  _buildPermissionsSection(context),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(BuildContext context) {
    final vc = context.vividColors;
    // Group permissions by category
    final Map<String, List<Permission>> grouped = {};
    for (final perm in Permission.values) {
      final cat = perm.category;
      grouped.putIfAbsent(cat, () => []).add(perm);
    }

    return Container(
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        children: grouped.entries.map((entry) {
          return _buildPermissionCategory(context, entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildPermissionCategory(BuildContext context, String category, List<Permission> permissions) {
    final vc = context.vividColors;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: vc.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              category,
              style: TextStyle(
                color: vc.textMuted.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...permissions.map((perm) => _buildPermissionTile(context, perm)),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(BuildContext context, Permission permission) {
    final vc = context.vividColors;
    final isEnabled = _effectivePermissions.contains(permission);
    final isRoleDefault = _isRoleDefault(permission);
    final isCustom = _isCustomGranted(permission);
    final isRevoked = _isRevoked(permission);

    // Determine badge
    String? badge;
    Color? badgeColor;
    if (isRevoked) {
      badge = 'REVOKED';
      badgeColor = Colors.red;
    } else if (isCustom) {
      badge = 'CUSTOM';
      badgeColor = Colors.purple;
    } else if (isRoleDefault && isEnabled) {
      badge = 'DEFAULT';
      badgeColor = vc.textMuted;
    }

    return InkWell(
      onTap: () => _togglePermission(permission),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isEnabled 
                      ? VividColors.cyan 
                      : isRevoked 
                          ? Colors.red.withOpacity(0.5)
                          : vc.textMuted.withOpacity(0.3),
                  width: 2,
                ),
                color: isEnabled 
                    ? VividColors.cyan 
                    : isRevoked
                        ? Colors.red.withOpacity(0.1)
                        : Colors.transparent,
              ),
              child: isEnabled
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : isRevoked
                      ? Icon(Icons.close, size: 14, color: Colors.red.withOpacity(0.7))
                      : null,
            ),
            const SizedBox(width: 10),
            
            // Permission name
            Expanded(
              child: Text(
                permission.displayName,
                style: TextStyle(
                  color: isRevoked 
                      ? vc.textMuted.withOpacity(0.5)
                      : isEnabled 
                          ? vc.textPrimary 
                          : vc.textMuted,
                  fontSize: 13,
                  decoration: isRevoked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            
            // Badge
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
    bool required = true,
  }) {
    final vc = context.vividColors;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: vc.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: vc.textMuted),
        hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: vc.popupBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: vc.surfaceAlt,
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }

  Widget _buildPasswordField(
    BuildContext context,
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
  }) {
    final vc = context.vividColors;
    return TextFormField(
      controller: controller,
      obscureText: !_showPassword,
      style: TextStyle(color: vc.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: vc.textMuted),
        hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
        prefixIcon: Icon(Icons.lock, color: vc.textMuted, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: vc.textMuted,
            size: 18,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: vc.popupBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: vc.surfaceAlt,
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    final isEdit = widget.user != null;

    // Password validation for new users
    if (!isEdit) {
      if (password.length < 8) {
        VividToast.show(context,
          message: 'Password must be at least 8 characters',
          type: ToastType.error,
        );
        return;
      }

      if (password != _confirmPasswordController.text) {
        VividToast.show(context,
          message: 'Passwords do not match',
          type: ToastType.error,
        );
        return;
      }
    }

    // Password length check for edit mode (only if provided)
    if (isEdit && password.isNotEmpty && password.length < 8) {
      VividToast.show(context,
        message: 'Password must be at least 8 characters',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<AdminProvider>();
    bool success;

    // Prepare custom permissions (only if enabled and modified)
    List<String>? customPerms;
    List<String>? revokedPerms;
    
    if (_showCustomPermissions) {
      if (_customPermissions.isNotEmpty) {
        customPerms = Permission.toStringList(_customPermissions);
      }
      if (_revokedPermissions.isNotEmpty) {
        revokedPerms = Permission.toStringList(_revokedPermissions);
      }
    }

    if (widget.user != null) {
      success = await provider.updateUser(
        userId: widget.user!.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        role: _selectedRole,
        customPermissions: customPerms,
        revokedPermissions: revokedPerms,
      );
    } else {
      success = await provider.createUser(
        clientId: widget.clientId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        customPermissions: customPerms,
        revokedPermissions: revokedPerms,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      VividToast.show(context,
        message: widget.user != null
            ? 'User updated successfully'
            : 'User created successfully',
        type: ToastType.success,
      );
    }
  }
}

// ============================================
// ANALYTICS TAB
// ============================================

class _AnalyticsTab extends StatefulWidget {
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  Client? _selectedClient;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            if (isMobile) {
              // Mobile: full-screen list or detail
              if (_selectedClient != null) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: vc.surface,
                        border: Border(
                          bottom: BorderSide(color: vc.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _selectedClient = null),
                            icon: Icon(Icons.arrow_back, color: vc.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _selectedClient!.name,
                              style: TextStyle(
                                color: vc.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: ClientAnalyticsView(client: _selectedClient!)),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Select Client',
                      style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: VividColors.tealBlue, height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: provider.clients.length,
                      itemBuilder: (context, index) {
                        final client = provider.clients[index];
                        final isSelected = _selectedClient?.id == client.id;
                        return _ClientListItem(
                          client: client,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedClient = client);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            // Desktop: side-by-side
            return Row(
              children: [
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: vc.surface,
                    border: Border(
                      right: BorderSide(color: vc.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Client',
                              style: TextStyle(
                                color: vc.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View internal metrics',
                              style: TextStyle(
                                color: vc.textMuted.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: VividColors.tealBlue, height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: provider.clients.length,
                          itemBuilder: (context, index) {
                            final client = provider.clients[index];
                            final isSelected = _selectedClient?.id == client.id;
                            return _ClientListItem(
                              client: client,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() => _selectedClient = client);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _selectedClient == null
                      ? _buildEmptyState(context)
                      : ClientAnalyticsView(client: _selectedClient!),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final vc = context.vividColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insights_outlined,
            size: 64,
            color: vc.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a client to view analytics',
            style: TextStyle(
              color: vc.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from the list on the left',
            style: TextStyle(
              color: vc.textMuted.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientListItem extends StatelessWidget {
  final Client client;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClientListItem({
    required this.client,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? VividColors.brightBlue.withOpacity(0.15) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? VividColors.cyan : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected 
                    ? VividColors.cyan.withOpacity(0.2) 
                    : vc.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                client.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: isSelected ? VividColors.cyan : vc.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: TextStyle(
                      color: isSelected ? vc.textPrimary : vc.textMuted,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        client.hasFeature('conversations') 
                            ? Icons.chat_bubble_outline 
                            : Icons.campaign_outlined,
                        size: 12,
                        color: vc.textMuted.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        client.hasFeature('conversations') 
                            ? 'Conversations' 
                            : 'Broadcasts',
                        style: TextStyle(
                          color: vc.textMuted.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.chevron_right,
              color: isSelected ? VividColors.cyan : vc.textMuted.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// CLIENT PREVIEW SCREEN
// ============================================

class _ClientPreviewScreen extends StatelessWidget {
  const _ClientPreviewScreen();

  Future<void> _exitImpersonation(BuildContext context) async {
    await ImpersonateService.stopImpersonation();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final clientName = ImpersonateService.targetClient?.name
        ?? ClientConfig.currentClient?.name
        ?? 'Client';
    final adminName = ImpersonateService.originalAdmin?.name ?? '';

    return Scaffold(
      backgroundColor: vc.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Impersonation banner
              Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      VividColors.statusWarning.withValues(alpha: 0.2),
                      VividColors.statusWarning.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(color: VividColors.statusWarning.withValues(alpha: 0.4)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 16, color: VividColors.statusWarning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Viewing as ',
                              style: TextStyle(color: VividColors.statusWarning.withValues(alpha: 0.8), fontSize: 12),
                            ),
                            TextSpan(
                              text: clientName,
                              style: const TextStyle(color: VividColors.statusWarning, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            if (adminName.isNotEmpty) ...[
                              TextSpan(
                                text: '  ·  Logged in as $adminName',
                                style: TextStyle(color: VividColors.statusWarning.withValues(alpha: 0.6), fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: VividColors.statusWarning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'READ-ONLY',
                        style: TextStyle(
                          color: VividColors.statusWarning,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _exitImpersonation(context),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Exit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VividColors.statusWarning,
                        side: const BorderSide(color: VividColors.statusWarning),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Client dashboard
              const Expanded(child: MainScaffold()),
            ],
          ),
          // Read-only watermark
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -0.3,
                  child: Text(
                    'PREVIEW',
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      color: vc.textMuted.withValues(alpha: 0.05),
                      letterSpacing: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}