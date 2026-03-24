import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/broadcasts_provider.dart';
import '../services/supabase_service.dart';
import '../providers/agent_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../widgets/vivid_company_analytics_view.dart';
import '../providers/roi_analytics_provider.dart' hide CampaignPerformance;
import '../providers/roi_analytics_provider.dart' as roiLib show CampaignPerformance;
import '../providers/broadcast_analytics_provider.dart';
import 'analytics_screen.dart' as client_analytics;
import '../utils/initials_helper.dart';
import '../widgets/activity_logs_panel.dart';
import '../widgets/command_center_tab.dart';
import '../widgets/settings_tab.dart';
import '../main.dart';
import '../utils/toast_service.dart';
import '../services/impersonate_service.dart';
import 'outreach_panel.dart';
import 'financials_tab.dart';

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final tabContent = TabBarView(
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
            _tabController.animateTo(4);
          },
        ),
        _UsersTab(),
        const _AdminTemplatesTab(),
        _AnalyticsTab(),
        const VividCompanyAnalyticsView(),
        const FinancialsTab(),
        const ActivityLogsPanel(isAdmin: true),
        const OutreachPanel(),
        const SettingsTab(),
      ],
    );

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: vc.background,
        drawer: _buildDrawer(),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: tabContent),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: vc.background,
      body: Row(
        children: [
          _buildSidebar(vc),
          Expanded(child: tabContent),
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
              // Hamburger menu (mobile only)
              if (isMobile) ...[
                IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: Icon(Icons.menu, color: vc.textPrimary),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
              ],
              // Logo
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: VividColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset('assets/images/vivid_icon.png', width: 28, height: 28),
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

  // ── Sidebar (desktop) ───────────────────────────────

  Widget _buildSidebar(VividColorScheme vc) {
    final agent = context.watch<AgentProvider>().agent;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          // Logo + title
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(color: Color(0x14FFFFFF)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/vivid_logo_full.png',
                  width: 160,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 4),
                const Text('Admin Dashboard',
                    style: TextStyle(color: Color(0x66FFFFFF), fontSize: 10, letterSpacing: 0.8)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  _sidebarItem(0, Icons.dashboard, 'Home'),
                  _sidebarItem(1, Icons.business, 'Clients'),
                  _sidebarItem(2, Icons.people, 'Users'),
                  _sidebarItem(3, Icons.description, 'Templates'),
                  _sidebarItem(4, Icons.insights, 'Client Analytics'),
                  _sidebarItem(5, Icons.auto_graph, 'Vivid Analytics'),
                  _sidebarItem(6, Icons.account_balance_wallet, 'Financials'),
                  _sidebarItem(7, Icons.history, 'Activity Logs'),
                  _sidebarItem(8, Icons.rocket_launch, 'Outreach'),
                  _sidebarItem(9, Icons.settings, 'Settings'),
                ],
              ),
            ),
          ),
          // Preview + user info + logout
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildPreviewButton(false),
                if (agent != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: VividColors.brightBlue.withOpacity(0.2),
                        child: Text(
                          agent.initials,
                          style: const TextStyle(color: VividColors.cyan, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          agent.name,
                          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.read<AgentProvider>().logout(),
                        icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Drawer (mobile) ─────────────────────────────────

  Widget _buildDrawer() {
    final agent = context.watch<AgentProvider>().agent;
    return Drawer(
      backgroundColor: const Color(0xFF0A1628),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0A1628)),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/vivid_logo_full.png',
                  width: 160,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 4),
                const Text('Admin Dashboard',
                    style: TextStyle(color: Color(0x66FFFFFF), fontSize: 10, letterSpacing: 0.8)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  _sidebarItem(0, Icons.dashboard, 'Home'),
                  _sidebarItem(1, Icons.business, 'Clients'),
                  _sidebarItem(2, Icons.people, 'Users'),
                  _sidebarItem(3, Icons.description, 'Templates'),
                  _sidebarItem(4, Icons.insights, 'Client Analytics'),
                  _sidebarItem(5, Icons.auto_graph, 'Vivid Analytics'),
                  _sidebarItem(6, Icons.account_balance_wallet, 'Financials'),
                  _sidebarItem(7, Icons.history, 'Activity Logs'),
                  _sidebarItem(8, Icons.rocket_launch, 'Outreach'),
                  _sidebarItem(9, Icons.settings, 'Settings'),
                ],
              ),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          if (agent != null)
            ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: VividColors.brightBlue.withOpacity(0.2),
                child: Text(agent.initials, style: const TextStyle(color: VividColors.cyan, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              title: Text(agent.name, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
              trailing: IconButton(
                onPressed: () => context.read<AgentProvider>().logout(),
                icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Sidebar item ─────────────────────────────────────

  Widget _sidebarItem(int index, IconData icon, String label) {
    final isSelected = _tabController.index == index;
    const teal = Color(0xFF22D3EE);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _tabController.animateTo(index);
            Scaffold.maybeOf(context)?.closeDrawer();
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected ? teal.withValues(alpha: 0.08) : Colors.transparent,
              border: isSelected
                  ? const Border(left: BorderSide(color: teal, width: 2))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18,
                    color: isSelected ? teal : Colors.white.withValues(alpha: 0.45)),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.45),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
              ],
            ),
          ),
        ),
      ),
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

  static String _featureLabel(String feature) {
    switch (feature) {
      case 'whatsapp_templates': return 'Templates';
      case 'media': return 'Media';
      case 'labels': return 'Labels';
      case 'broadcasts': return 'Broadcasts';
      case 'analytics': return 'Analytics';
      case 'manager_chat': return 'AI Chat';
      case 'conversations': return 'Convos';
      case 'predictive_intelligence': return 'Predictions';
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
      case 'predictive_intelligence':
        return client.customerPredictionsTable != null && client.customerPredictionsTable!.isNotEmpty;
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(20),
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
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _healthColor(healthStatus).withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(color: vc.surface, width: 1.5),
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

              const SizedBox(height: 12),

              // ── Stats Row ──
              Row(
                children: [
                  _buildStatBox(vc, Icons.people_outline, '$userCount'),
                  const SizedBox(width: 6),
                  _buildStatBox(vc, Icons.extension_outlined, '${client.enabledFeatures.where((f) => const ['conversations', 'broadcasts', 'manager_chat'].contains(f)).length}/3'),
                  const SizedBox(width: 6),
                  _buildStatBox(
                    vc,
                    client.businessPhone != null ? Icons.phone : Icons.phone_disabled,
                    client.businessPhone ?? '—',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Feature Chips with status dots ──
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Core features (filled chips)
                  // All enabled features — subtle pill, colored dot = configured
                  ...client.enabledFeatures.map((f) {
                    final isCore = const ['conversations', 'broadcasts', 'manager_chat'].contains(f);
                    final configured = isCore ? _isFeatureConfigured(client, f) : true;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: vc.border.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCore)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: configured
                                    ? VividColors.statusSuccess
                                    : VividColors.statusWarning,
                              ),
                            ),
                          Text(
                            _featureLabel(f),
                            style: TextStyle(
                              color: vc.textMuted.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 12),

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
                  if (widget.client.customerPredictionsTable != null &&
                      widget.client.predictionsRefreshWebhookUrl != null) ...[
                    const SizedBox(width: 8),
                    _RefreshPredictionsButton(client: widget.client),
                  ],
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

  Widget _buildStatBox(VividColorScheme vc, IconData icon, String value) {
    return Expanded(
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: vc.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                value,
                style: TextStyle(color: vc.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
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
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: vc.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: vc.textMuted),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              color: vc.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
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

  static const _allFeatures = ['conversations', 'broadcasts', 'analytics', 'manager_chat', 'predictive_intelligence'];

  static const _featureNames = {
    'conversations': 'Conversations',
    'broadcasts': 'Broadcasts',
    'analytics': 'Analytics',
    'manager_chat': 'AI Assistant',
    'predictive_intelligence': 'Predictions',
  };

  static const _featureIcons = {
    'conversations': Icons.chat_bubble_outline,
    'broadcasts': Icons.campaign,
    'analytics': Icons.insights,
    'manager_chat': Icons.smart_toy,
    'predictive_intelligence': Icons.auto_graph,
  };

  static Color _featureColor(String feature) {
    switch (feature) {
      case 'conversations': return VividColors.cyan;
      case 'broadcasts': return Colors.orange;
      case 'analytics': return VividColors.brightBlue;
      case 'manager_chat': return Colors.purple;
      case 'predictive_intelligence': return Colors.teal;
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
      case 'predictive_intelligence':
        return notEmpty(client.customerPredictionsTable);
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

class _UserTile extends StatefulWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onToggleBlock;

  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onToggleBlock,
  });

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final user = widget.user;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 4),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white.withValues(alpha: 0.04) : vc.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vc.border.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: VividColors.brightBlue.withValues(alpha: 0.15),
              child: Text(
                getInitials(user.name),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.email,
                          style: TextStyle(color: vc.textMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!user.isBlocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (user.isBlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Blocked',
                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            IconButton(
              onPressed: widget.onEdit,
              icon: Icon(Icons.edit, size: 18,
                  color: vc.textMuted.withValues(alpha: _isHovered ? 1.0 : 0.4)),
            ),
            IconButton(
              onPressed: widget.onToggleBlock,
              icon: Icon(
                user.isBlocked ? Icons.lock_open : Icons.block,
                size: 18,
                color: (user.isBlocked ? VividColors.statusSuccess : Colors.red)
                    .withValues(alpha: _isHovered ? 0.9 : 0.4),
              ),
              tooltip: user.isBlocked ? 'Unblock' : 'Block',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ROLE BADGE
// ============================================

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final config = _getRoleConfig(context, role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
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

class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _searchQuery = '';
  String? _roleFilter;
  String? _clientFilter;
  String? _statusFilter;
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> users) {
    var filtered = users;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((u) =>
        (u['name'] as String? ?? '').toLowerCase().contains(q) ||
        (u['email'] as String? ?? '').toLowerCase().contains(q)
      ).toList();
    }
    if (_roleFilter != null) {
      filtered = filtered.where((u) => u['role'] == _roleFilter).toList();
    }
    if (_clientFilter != null) {
      filtered = filtered.where((u) => u['client_id'] == _clientFilter).toList();
    }
    if (_statusFilter != null) {
      filtered = filtered.where((u) => (u['status'] ?? 'active') == _statusFilter).toList();
    }
    return filtered;
  }

  void _toggleSelectAll(List<Map<String, dynamic>> filteredUsers) {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
        _selectAll = false;
      } else {
        _selectedIds.clear();
        for (final u in filteredUsers) {
          _selectedIds.add(u['id'] as String);
        }
        _selectAll = true;
      }
    });
  }

  void _toggleUser(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectAll = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectAll = false;
    });
  }

  // ── CSV Export ──────────────────────────────────────
  void _exportCsv(List<Map<String, dynamic>> users) {
    final buffer = StringBuffer();
    buffer.writeln('Name,Email,Role,Status,Client');
    for (final u in users) {
      final name = (u['name'] ?? '').toString().replaceAll(',', ' ');
      final email = (u['email'] ?? '').toString();
      final role = (u['role'] ?? '').toString();
      final status = (u['status'] ?? 'active').toString();
      final client = (u['clients']?['name'] ?? '').toString().replaceAll(',', ' ');
      buffer.writeln('$name,$email,$role,$status,$client');
    }
    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = 'users_export_${DateTime.now().millisecondsSinceEpoch}.csv'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      VividToast.show(context,
        message: 'Exported ${users.length} users to CSV',
        type: ToastType.success,
      );
    }
  }

  // ── CSV Import Dialog ──────────────────────────────
  void _showImportDialog(BuildContext context, AdminProvider provider) {
    final vc = context.vividColors;
    List<Map<String, String>>? parsedRows;
    List<String> headers = [];
    bool isParsing = false;
    bool isImporting = false;
    int? importedCount;
    List<String>? importErrors;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: vc.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.upload_file, color: VividColors.cyan, size: 20),
                const SizedBox(width: 10),
                Text('Import Users from CSV', style: TextStyle(color: vc.textPrimary, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: File selection
                  if (parsedRows == null && importedCount == null) ...[
                    Text(
                      'CSV must have columns: name, email, password, role, client_id',
                      style: TextStyle(color: vc.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Roles: admin, manager, agent, viewer',
                      style: TextStyle(color: vc.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: isParsing ? null : () {
                          final input = html.FileUploadInputElement()..accept = '.csv';
                          input.click();
                          input.onChange.listen((event) {
                            final file = input.files?.first;
                            if (file == null) return;
                            setDialogState(() => isParsing = true);
                            final reader = html.FileReader();
                            reader.readAsText(file);
                            reader.onLoadEnd.listen((_) {
                              final content = reader.result as String;
                              final lines = const LineSplitter().convert(content);
                              if (lines.isEmpty) {
                                setDialogState(() => isParsing = false);
                                return;
                              }
                              headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
                              final rows = <Map<String, String>>[];
                              for (int i = 1; i < lines.length; i++) {
                                final vals = lines[i].split(',');
                                if (vals.length < headers.length) continue;
                                final row = <String, String>{};
                                for (int j = 0; j < headers.length; j++) {
                                  row[headers[j]] = vals[j].trim();
                                }
                                if (row['email']?.isNotEmpty == true) rows.add(row);
                              }
                              setDialogState(() {
                                parsedRows = rows;
                                isParsing = false;
                              });
                            });
                          });
                        },
                        icon: isParsing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.file_open, size: 18),
                        label: Text(isParsing ? 'Reading...' : 'Select CSV File'),
                        style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
                      ),
                    ),
                  ],
                  // Step 2: Preview
                  if (parsedRows != null && importedCount == null) ...[
                    Text(
                      '${parsedRows!.length} users found in CSV',
                      style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: vc.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: vc.border),
                      ),
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(vc.surface),
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 40,
                            columnSpacing: 16,
                            columns: headers.map((h) => DataColumn(
                              label: Text(h, style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 11)),
                            )).toList(),
                            rows: parsedRows!.take(20).map((row) => DataRow(
                              cells: headers.map((h) => DataCell(
                                Text(
                                  h == 'password' ? '••••••••' : (row[h] ?? ''),
                                  style: TextStyle(color: vc.textPrimary, fontSize: 12),
                                ),
                              )).toList(),
                            )).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (parsedRows!.length > 20)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '... and ${parsedRows!.length - 20} more rows',
                          style: TextStyle(color: vc.textMuted, fontSize: 11),
                        ),
                      ),
                    if (isImporting)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(
                          backgroundColor: vc.border,
                          valueColor: const AlwaysStoppedAnimation(VividColors.cyan),
                        ),
                      ),
                  ],
                  // Step 3: Results
                  if (importedCount != null) ...[
                    Icon(
                      importErrors!.isEmpty ? Icons.check_circle : Icons.warning_amber,
                      color: importErrors!.isEmpty ? VividColors.statusSuccess : VividColors.statusWarning,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$importedCount of ${parsedRows!.length} users imported successfully',
                      style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    if (importErrors!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: importErrors!.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(e, style: const TextStyle(color: Colors.red, fontSize: 11)),
                          )).toList(),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(importedCount != null ? 'Done' : 'Cancel'),
              ),
              if (parsedRows != null && importedCount == null)
                ElevatedButton(
                  onPressed: isImporting ? null : () async {
                    setDialogState(() => isImporting = true);
                    final result = await provider.importUsersFromCsv(parsedRows!);
                    setDialogState(() {
                      isImporting = false;
                      importedCount = result.success;
                      importErrors = result.errors;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
                  child: isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Import ${parsedRows!.length} Users'),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Bulk Actions ───────────────────────────────────
  Future<void> _bulkBlock(AdminProvider provider) async {
    final vc = context.vividColors;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: vc.surface,
        title: Text('Block $count Users', style: TextStyle(color: vc.textPrimary)),
        content: Text('Block $count selected users? They will no longer be able to log in.', style: TextStyle(color: vc.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await provider.bulkToggleStatus(_selectedIds.toList(), 'blocked');
    _clearSelection();
    if (mounted) {
      VividToast.show(context, message: 'Blocked $result of $count users', type: ToastType.success);
    }
  }

  Future<void> _bulkUnblock(AdminProvider provider) async {
    final count = _selectedIds.length;
    final result = await provider.bulkToggleStatus(_selectedIds.toList(), 'active');
    _clearSelection();
    if (mounted) {
      VividToast.show(context, message: 'Unblocked $result of $count users', type: ToastType.success);
    }
  }

  Future<void> _bulkChangeRole(AdminProvider provider) async {
    final vc = context.vividColors;
    final count = _selectedIds.length;
    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: vc.surface,
        title: Text('Change Role for $count Users', style: TextStyle(color: vc.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['admin', 'manager', 'agent', 'viewer'].map((role) => ListTile(
            title: Text(role[0].toUpperCase() + role.substring(1), style: TextStyle(color: vc.textPrimary)),
            leading: Icon(
              role == 'admin' ? Icons.admin_panel_settings :
              role == 'manager' ? Icons.supervisor_account :
              role == 'agent' ? Icons.headset_mic : Icons.visibility,
              color: VividColors.cyan,
              size: 20,
            ),
            onTap: () => Navigator.pop(ctx, role),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            hoverColor: VividColors.brightBlue.withOpacity(0.1),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (newRole == null || !mounted) return;
    final result = await provider.bulkChangeRole(_selectedIds.toList(), newRole);
    _clearSelection();
    if (mounted) {
      VividToast.show(context,
        message: 'Changed role to ${newRole[0].toUpperCase()}${newRole.substring(1)} for $result of $count users',
        type: ToastType.success,
      );
    }
  }

  Future<void> _bulkDelete(AdminProvider provider) async {
    final vc = context.vividColors;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: vc.surface,
        title: Text('Delete $count Users', style: TextStyle(color: vc.textPrimary)),
        content: Text(
          'Permanently delete $count selected users? This cannot be undone.',
          style: TextStyle(color: vc.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await provider.bulkDeleteUsers(_selectedIds.toList());
    _clearSelection();
    if (mounted) {
      VividToast.show(context, message: 'Deleted $result of $count users', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<AdminProvider>();
    final allUsers = provider.allUsers;
    final filteredUsers = _applyFilters(allUsers);

    // Build unique client list for filter dropdown
    final clientMap = <String, String>{};
    for (final u in allUsers) {
      final cid = u['client_id'] as String?;
      final cname = u['clients']?['name'] as String?;
      if (cid != null && cname != null) clientMap[cid] = cname;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          children: [
            // ── Toolbar ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Row 1: Title + CSV buttons
                  Row(
                    children: [
                      Text(
                        'All Users (${filteredUsers.length}${filteredUsers.length != allUsers.length ? ' of ${allUsers.length}' : ''})',
                        style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      // Import CSV
                      IconButton(
                        onPressed: () => _showImportDialog(context, provider),
                        icon: const Icon(Icons.upload_file, size: 18),
                        color: VividColors.cyan,
                        tooltip: 'Import CSV',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Export CSV
                      IconButton(
                        onPressed: filteredUsers.isEmpty ? null : () => _exportCsv(filteredUsers),
                        icon: const Icon(Icons.download, size: 18),
                        color: VividColors.cyan,
                        tooltip: 'Export CSV',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: Search + Filters
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Search
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        height: 36,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(color: vc.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search name or email...',
                            hintStyle: TextStyle(color: vc.textMuted, fontSize: 12),
                            prefixIcon: Icon(Icons.search, size: 18, color: vc.textMuted),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: vc.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: VividColors.cyan),
                            ),
                            filled: true,
                            fillColor: vc.surfaceAlt,
                          ),
                        ),
                      ),
                      // Role filter
                      _FilterChip(
                        label: _roleFilter != null ? _roleFilter![0].toUpperCase() + _roleFilter!.substring(1) : 'Role',
                        isActive: _roleFilter != null,
                        onClear: () => setState(() => _roleFilter = null),
                        items: ['admin', 'manager', 'agent', 'viewer']
                            .map((r) => PopupMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1))))
                            .toList(),
                        onSelected: (v) => setState(() => _roleFilter = v),
                      ),
                      // Client filter
                      _FilterChip(
                        label: _clientFilter != null ? (clientMap[_clientFilter] ?? 'Client') : 'Client',
                        isActive: _clientFilter != null,
                        onClear: () => setState(() => _clientFilter = null),
                        items: clientMap.entries
                            .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onSelected: (v) => setState(() => _clientFilter = v),
                      ),
                      // Status filter
                      _FilterChip(
                        label: _statusFilter != null ? _statusFilter![0].toUpperCase() + _statusFilter!.substring(1) : 'Status',
                        isActive: _statusFilter != null,
                        onClear: () => setState(() => _statusFilter = null),
                        items: ['active', 'blocked']
                            .map((s) => PopupMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1))))
                            .toList(),
                        onSelected: (v) => setState(() => _statusFilter = v),
                      ),
                      // Clear all filters
                      if (_searchQuery.isNotEmpty || _roleFilter != null || _clientFilter != null || _statusFilter != null)
                        ActionChip(
                          label: const Text('Clear', style: TextStyle(fontSize: 12)),
                          avatar: const Icon(Icons.clear, size: 14),
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _roleFilter = null;
                            _clientFilter = null;
                            _statusFilter = null;
                          }),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: vc.surfaceAlt,
                          labelStyle: TextStyle(color: vc.textMuted),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Bulk Action Bar ──────────────────────
            if (_selectedIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: VividColors.brightBlue.withOpacity(0.1),
                  border: Border(
                    top: BorderSide(color: VividColors.cyan.withOpacity(0.3)),
                    bottom: BorderSide(color: VividColors.cyan.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: const TextStyle(color: VividColors.cyan, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    _BulkActionButton(
                      icon: Icons.block,
                      label: 'Block',
                      color: Colors.red,
                      onPressed: () => _bulkBlock(provider),
                    ),
                    const SizedBox(width: 6),
                    _BulkActionButton(
                      icon: Icons.lock_open,
                      label: 'Unblock',
                      color: VividColors.statusSuccess,
                      onPressed: () => _bulkUnblock(provider),
                    ),
                    const SizedBox(width: 6),
                    _BulkActionButton(
                      icon: Icons.swap_horiz,
                      label: 'Change Role',
                      color: VividColors.cyan,
                      onPressed: () => _bulkChangeRole(provider),
                    ),
                    const SizedBox(width: 6),
                    _BulkActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: Colors.red,
                      onPressed: () => _bulkDelete(provider),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Clear Selection', style: TextStyle(color: VividColors.cyan, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // ── Table header (desktop) ───────────────
            if (!isMobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: vc.surface,
                  border: Border(bottom: BorderSide(color: vc.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Checkbox(
                        value: _selectAll && _selectedIds.length == filteredUsers.length && filteredUsers.isNotEmpty,
                        onChanged: (_) => _toggleSelectAll(filteredUsers),
                        activeColor: VividColors.cyan,
                        side: BorderSide(color: vc.textMuted),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Expanded(flex: 2, child: Text('Name', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                    Expanded(flex: 3, child: Text('Email', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                    Expanded(flex: 1, child: Text('Role', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                    Expanded(flex: 1, child: Text('Status', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                    Expanded(flex: 2, child: Text('Client', style: TextStyle(color: vc.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 90, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  ],
                ),
              ),

            // ── Users list ───────────────────────────
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(child: Text('No users found', style: TextStyle(color: vc.textMuted)))
                  : ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final clientName = user['clients']?['name'] ?? 'No Client';
                        final role = user['role'] ?? 'unknown';
                        final userId = user['id'] as String;
                        final isSelected = _selectedIds.contains(userId);

                        if (isMobile) {
                          return _buildMobileUserCard(context, user, clientName, role, provider, isSelected);
                        }
                        return _buildDesktopUserRow(context, user, clientName, role, provider, isSelected);
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
    bool isSelected,
  ) {
    final vc = context.vividColors;
    final userId = user['id'] as String;
    final status = user['status'] as String? ?? 'active';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? VividColors.brightBlue.withOpacity(0.1) : vc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: VividColors.cyan.withOpacity(0.4)) : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleUser(userId),
            activeColor: VividColors.cyan,
            side: BorderSide(color: vc.textMuted),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user['name'] ?? '', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: role),
                    if (status == 'blocked') ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Blocked', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(user['email'] ?? '', style: TextStyle(color: vc.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: VividColors.brightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text(clientName, style: const TextStyle(color: VividColors.cyan, fontSize: 11), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
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
    bool isSelected,
  ) {
    final vc = context.vividColors;
    final userId = user['id'] as String;
    final status = user['status'] as String? ?? 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? VividColors.brightBlue.withOpacity(0.06) : null,
        border: Border(bottom: BorderSide(color: vc.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleUser(userId),
              activeColor: VividColors.cyan,
              side: BorderSide(color: vc.textMuted),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Expanded(flex: 2, child: Text(user['name'] ?? '', style: TextStyle(color: vc.textPrimary), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(user['email'] ?? '', style: TextStyle(color: vc.textMuted), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: _RoleBadge(role: role)),
          Expanded(
            flex: 1,
            child: _StatusBadge(status: status),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: VividColors.brightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Text(clientName, style: const TextStyle(color: VividColors.cyan, fontSize: 12), overflow: TextOverflow.ellipsis),
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

// ── Helper widgets for _UsersTab ─────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isBlocked = status == 'blocked';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isBlocked ? Colors.red : VividColors.statusSuccess).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isBlocked ? 'Blocked' : 'Active',
        style: TextStyle(
          color: isBlocked ? Colors.red : VividColors.statusSuccess,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onClear;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onClear,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => items,
      color: vc.surface,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? VividColors.brightBlue.withOpacity(0.15) : vc.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? VividColors.cyan.withOpacity(0.5) : vc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isActive ? VividColors.cyan : vc.textMuted, fontSize: 12)),
            const SizedBox(width: 4),
            if (isActive)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: VividColors.cyan),
              )
            else
              Icon(Icons.arrow_drop_down, size: 16, color: vc.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _BulkActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        visualDensity: VisualDensity.compact,
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
  final List<Map<String, dynamic>> _pendingTriggers = [];

  // Step 3 — Configuration
  final _conversationsPhoneController = TextEditingController();
  final _conversationsWebhookController = TextEditingController();
  final _broadcastsPhoneController = TextEditingController();
  final _broadcastsWebhookController = TextEditingController();
  final _remindersPhoneController = TextEditingController();
  final _remindersWebhookController = TextEditingController();
  final _managerChatWebhookController = TextEditingController();
  final _wabaIdController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _broadcastLimitController = TextEditingController(text: '500');
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
    _wabaIdController.dispose();
    _accessTokenController.dispose();
    _broadcastLimitController.dispose();
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
    final customerPredictionsTable = _selectedFeatures.contains('predictive_intelligence') ? '${slug}_customer_predictions' : null;

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
      customerPredictionsTable: customerPredictionsTable,
      conversationsPhone: _conversationsPhoneController.text.trim().isEmpty ? null : _conversationsPhoneController.text.trim(),
      conversationsWebhookUrl: _conversationsWebhookController.text.trim().isEmpty ? null : _conversationsWebhookController.text.trim(),
      broadcastsPhone: _broadcastsPhoneController.text.trim().isEmpty ? null : _broadcastsPhoneController.text.trim(),
      broadcastsWebhookUrl: _broadcastsWebhookController.text.trim().isEmpty ? null : _broadcastsWebhookController.text.trim(),
      remindersPhone: _remindersPhoneController.text.trim().isEmpty ? null : _remindersPhoneController.text.trim(),
      remindersWebhookUrl: _remindersWebhookController.text.trim().isEmpty ? null : _remindersWebhookController.text.trim(),
      managerChatWebhookUrl: _managerChatWebhookController.text.trim().isEmpty ? null : _managerChatWebhookController.text.trim(),
      wabaId: _wabaIdController.text.trim().isEmpty ? null : _wabaIdController.text.trim(),
      metaAccessToken: _accessTokenController.text.trim().isEmpty ? null : _accessTokenController.text.trim(),
      broadcastLimit: int.tryParse(_broadcastLimitController.text.trim()),
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

    // Create per-client Supabase tables
    try {
      final features = <String>[..._selectedFeatures];
      // The wizard stores AI conversations as a separate bool, but the RPC expects 'ai_conversations' in the array
      if (_hasAiConversations) {
        features.add('ai_conversations');
      }

      await SupabaseService.adminClient.rpc('create_client_tables', params: {
        'p_slug': slug.toLowerCase(),
        'p_features': features,
      });

      debugPrint('✅ Client tables created for $slug');
    } catch (e) {
      debugPrint('⚠️ Table creation failed: $e');
      // Show warning but don't block wizard completion — tables can be created manually
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Warning: Table creation failed. Tables may need manual setup. Error: $e')),
        );
      }
    }

    // Find the newly created client
    final newClient = provider.clients.firstWhere(
      (c) => c.slug == _slugController.text.trim(),
      orElse: () => provider.clients.first,
    );

    // Optionally create first user
    if (_createUser && _userNameController.text.trim().isNotEmpty) {
      await provider.createUser(
        clientId: newClient.id,
        name: _userNameController.text.trim(),
        email: _userEmailController.text.trim(),
        password: _userPasswordController.text.trim(),
        role: 'admin',
      );
    }

    // Create pending label triggers
    for (final trigger in _pendingTriggers) {
      await provider.createLabelTrigger(
        clientId: newClient.id,
        label: trigger['label'] as String,
        triggerWords: List<String>.from(trigger['trigger_words'] as List),
        color: trigger['color'] as String? ?? '#38BEC9',
        autoApply: trigger['auto_apply'] as bool? ?? true,
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
                    Text('${slug}_ai_chat_settings', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
                    Text('${slug}_customer_predictions', style: TextStyle(color: vc.textSecondary, fontSize: 13, fontFamily: 'monospace')),
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
    ('predictive_intelligence', Icons.auto_graph, 'Predictive Intelligence', 'AI-powered customer return predictions'),
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
              Expanded(
                child: Text('Label Triggers', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              OutlinedButton.icon(
                onPressed: () => _showPendingTriggerDialog(vc),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_pendingTriggers.isEmpty)
            Text(
              'No label triggers yet. Add triggers to auto-label incoming messages.',
              style: TextStyle(color: vc.textMuted, fontSize: 12),
            )
          else
            ..._pendingTriggers.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final color = _hexToColorStatic(t['color'] as String? ?? '#38BEC9');
              final words = (t['trigger_words'] as List<dynamic>?) ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['label'] as String? ?? '', style: TextStyle(color: vc.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                            if (words.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4, runSpacing: 4,
                                children: words.map((w) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(w.toString(), style: TextStyle(color: color, fontSize: 11)),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 16, color: vc.textMuted),
                        onPressed: () => _showPendingTriggerDialog(vc, index: i),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: VividColors.statusUrgent),
                        onPressed: () => setState(() => _pendingTriggers.removeAt(i)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showPendingTriggerDialog(VividColorScheme vc, {int? index}) {
    final existing = index != null ? _pendingTriggers[index] : null;
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _PendingLabelTriggerDialog(existing: existing),
    ).then((result) {
      if (result != null) {
        setState(() {
          if (index != null) {
            _pendingTriggers[index] = result;
          } else {
            _pendingTriggers.add(result);
          }
        });
      }
    });
  }

  static Color _hexToColorStatic(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
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
            // WhatsApp Business Configuration (always visible)
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VividColors.cyan.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VividColors.cyan.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business_center, color: VividColors.cyan, size: 18),
                      const SizedBox(width: 8),
                      Text('WhatsApp Business Configuration', style: TextStyle(color: VividColors.cyan, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('(Optional)', style: TextStyle(color: VividColors.cyan.withOpacity(0.6), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildWizardField(
                    vc,
                    controller: _wabaIdController,
                    label: 'WhatsApp Business Account ID',
                    hint: 'From Meta Business Manager (e.g., 4194190724181657)',
                    icon: Icons.account_balance,
                    required: false,
                  ),
                  const SizedBox(height: 10),
                  _buildWizardField(
                    vc,
                    controller: _accessTokenController,
                    label: 'Meta Access Token',
                    hint: 'Leave empty if using shared Vivid Systems token',
                    icon: Icons.vpn_key,
                    required: false,
                    obscure: true,
                  ),
                  const SizedBox(height: 10),
                  _buildWizardField(
                    vc,
                    controller: _broadcastLimitController,
                    label: 'Monthly Broadcast Limit',
                    hint: 'e.g., 500',
                    icon: Icons.send,
                    required: false,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
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
    if (_wabaIdController.text.trim().isNotEmpty) items.add(('WABA ID', _wabaIdController.text.trim()));
    if (_broadcastLimitController.text.trim().isNotEmpty) items.add(('Broadcast Limit', _broadcastLimitController.text.trim()));
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
      if (_hasAiConversations) tableItems.add(('AI Settings', '${slug}_ai_chat_settings'));
      if (_selectedFeatures.contains('predictive_intelligence')) tableItems.add(('Predictions', '${slug}_customer_predictions'));
      if (tableItems.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildReviewSection(vc, Icons.table_chart, 'Tables to Create', tableItems));
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
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
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

  // Label triggers (for edit mode — live from DB)
  List<Map<String, dynamic>> _labelTriggers = [];
  bool _isLoadingTriggers = false;

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

    // Load label triggers for existing clients with labels enabled
    if (widget.client != null && _selectedFeatures.contains('labels')) {
      _fetchLabelTriggers();
    }
  }

  Future<void> _fetchLabelTriggers() async {
    if (widget.client == null) return;
    setState(() => _isLoadingTriggers = true);
    final provider = context.read<AdminProvider>();
    await provider.fetchLabelTriggers(widget.client!.id);
    if (mounted) {
      setState(() {
        _labelTriggers = List.from(provider.labelTriggers);
        _isLoadingTriggers = false;
      });
    }
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
                  _buildInlineLabelTriggers(vc),
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
      ('Predictions', c.customerPredictionsTable),
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

  Widget _buildInlineLabelTriggers(VividColorScheme vc) {
    final isEdit = widget.client != null;

    return Container(
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
              const Icon(Icons.label, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Label Triggers', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              OutlinedButton.icon(
                onPressed: () => _showTriggerDialog(vc),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                  textStyle: const TextStyle(fontSize: 11),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingTriggers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan))),
            )
          else if (isEdit && _labelTriggers.isEmpty)
            Text('No label triggers configured.', style: TextStyle(color: vc.textMuted, fontSize: 12))
          else if (!isEdit)
            Text('Save the client first, then add label triggers.', style: TextStyle(color: vc.textMuted, fontSize: 12))
          else
            ..._labelTriggers.map((t) {
              final color = _hexToColorLocal(t['color'] as String? ?? '#38BEC9');
              final words = (t['trigger_words'] as List<dynamic>?) ?? [];
              final id = t['id'] as String;
              final label = t['label'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: TextStyle(color: vc.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                            if (words.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 4, runSpacing: 3,
                                children: words.map((w) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: Text(w.toString(), style: TextStyle(color: color, fontSize: 10)),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 14, color: vc.textMuted),
                        onPressed: () => _showTriggerDialog(vc, existing: t),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 14, color: VividColors.statusUrgent),
                        onPressed: () async {
                          final provider = context.read<AdminProvider>();
                          await provider.deleteLabelTrigger(id, widget.client!.id);
                          if (mounted) await _fetchLabelTriggers();
                        },
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showTriggerDialog(VividColorScheme vc, {Map<String, dynamic>? existing}) {
    if (widget.client == null) return; // Can't add triggers without a client
    showDialog(
      context: context,
      builder: (ctx) => _LabelTriggerDialog(clientId: widget.client!.id, existing: existing),
    ).then((_) {
      if (mounted) _fetchLabelTriggers();
    });
  }

  static Color _hexToColorLocal(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
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
                    Expanded(child: _ClientAnalyticsWrapper(key: ValueKey(_selectedClient!.id), client: _selectedClient!)),
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
                      : _ClientAnalyticsWrapper(key: ValueKey(_selectedClient!.id), client: _selectedClient!),
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

// ─────────────────────────────────────────────────────────────────────────────
// Client Analytics Wrapper — renders the EXACT client-facing AnalyticsScreen
// by temporarily setting ClientConfig to the selected client.
// ─────────────────────────────────────────────────────────────────────────────
class _ClientAnalyticsWrapper extends StatefulWidget {
  final Client client;
  const _ClientAnalyticsWrapper({super.key, required this.client});

  @override
  State<_ClientAnalyticsWrapper> createState() =>
      _ClientAnalyticsWrapperState();
}

class _ClientAnalyticsWrapperState extends State<_ClientAnalyticsWrapper> {
  bool _showVividInsights = false;

  @override
  void initState() {
    super.initState();
    _enterPreview(widget.client);
  }

  @override
  void didUpdateWidget(_ClientAnalyticsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.id != widget.client.id) {
      ClientConfig.exitPreview(clientId: oldWidget.client.id);
      _enterPreview(widget.client);
    }
  }

  @override
  void dispose() {
    // Pass clientId so that if a new wrapper already called enterPreview()
    // before this dispose() runs (Flutter lifecycle), we don't null out the
    // newly-set client context.
    ClientConfig.exitPreview(clientId: widget.client.id);
    super.dispose();
  }

  void _enterPreview(Client client) {
    final adminUser = ClientConfig.currentUser;
    final tempUser = adminUser != null
        ? AppUser(
            id: adminUser.id,
            email: adminUser.email,
            name: '${adminUser.name} (viewing ${client.name})',
            role: UserRole.admin,
            clientId: client.id,
            createdAt: adminUser.createdAt,
          )
        : AppUser(
            id: 'admin',
            email: 'admin@vivid.com',
            name: 'Admin',
            role: UserRole.admin,
            clientId: client.id,
            createdAt: DateTime.now(),
          );
    ClientConfig.enterPreview(client, tempUser);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (client.conversationsPhone?.isNotEmpty == true) {
        context.read<ConversationsProvider>().initializePreview();
      }
      if (client.broadcastsPhone?.isNotEmpty == true ||
          client.broadcastsWebhookUrl?.isNotEmpty == true) {
        context.read<BroadcastsProvider>().fetchBroadcasts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    // isVividAdmin is false here because _enterPreview() sets tempUser.clientId = client.id,
    // which makes isVividAdmin (requires clientId == null) return false.
    // Use isPreviewMode instead — it's only true when an admin has entered preview.
    final isAdmin = ClientConfig.isPreviewMode;

    return Column(
      children: [
        // ── "Viewing as" banner ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: VividColors.cyan.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 14, color: VividColors.cyan),
              const SizedBox(width: 6),
              Text(
                'Viewing as: ${widget.client.name}',
                style: const TextStyle(
                    color: VividColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: VividColors.cyan.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _showVividInsights ? 'Vivid Insights' : 'Client View',
                  style: const TextStyle(
                      color: VividColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // ── Outer tab bar (Vivid Admin only) ────────────────────────────
        if (isAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(bottom: BorderSide(color: vc.border)),
            ),
            child: Row(
              children: [
                _outerTab(
                  context,
                  label: 'Client View',
                  icon: Icons.visibility_outlined,
                  isSelected: !_showVividInsights,
                  onTap: () => setState(() => _showVividInsights = false),
                ),
                const SizedBox(width: 4),
                _outerTab(
                  context,
                  label: 'Vivid Insights',
                  imageAsset: 'assets/images/vivid_icon.png',
                  isSelected: _showVividInsights,
                  onTap: () => setState(() => _showVividInsights = true),
                ),
              ],
            ),
          ),

        // ── Content — both tabs kept alive with IndexedStack ─────────────
        Expanded(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => RoiAnalyticsProvider()),
              ChangeNotifierProvider(create: (_) => BroadcastAnalyticsProvider()),
            ],
            child: IndexedStack(
              index: _showVividInsights ? 1 : 0,
              children: [
                const client_analytics.AnalyticsScreen(),
                _VividInsightsPanel(client: widget.client),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _outerTab(
    BuildContext context, {
    required String label,
    IconData? icon,
    String? imageAsset,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final inactiveColor = Colors.white.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? VividColors.cyan.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: VividColors.cyan.withValues(alpha: 0.6))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null)
              Image.asset(imageAsset, width: 13, height: 13,
                  color: isSelected ? VividColors.cyan : inactiveColor)
            else if (icon != null)
              Icon(icon, size: 13,
                  color: isSelected ? VividColors.cyan : inactiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? VividColors.cyan : inactiveColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
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
                      for (final f in client.enabledFeatures.take(3)) ...[
                        Icon(
                          f == 'conversations' ? Icons.chat_bubble_outline
                              : f == 'broadcasts' ? Icons.campaign_outlined
                              : f == 'manager_chat' ? Icons.smart_toy
                              : f == 'labels' ? Icons.label_outline
                              : f == 'predictive_intelligence' ? Icons.auto_graph
                              : Icons.extension,
                          size: 12,
                          color: vc.textMuted.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${client.enabledFeatures.length} features',
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
// ============================================
// VIVID INSIGHTS PANEL
// Internal-only analytics panel shown to Vivid admins when viewing a client.
// ============================================

class _VividInsightsPanel extends StatefulWidget {
  final Client client;
  const _VividInsightsPanel({required this.client});

  @override
  State<_VividInsightsPanel> createState() => _VividInsightsPanelState();
}

class _VividInsightsPanelState extends State<_VividInsightsPanel> {
  // The 7 platform features we track adoption against.
  static const _platformFeatures = [
    'conversations',
    'broadcasts',
    'analytics',
    'manager_chat',
    'whatsapp_templates',
    'predictive_intelligence',
    'media',
  ];

  static String _featureDisplayName(String f) {
    switch (f) {
      case 'conversations': return 'Conversations';
      case 'broadcasts': return 'Broadcasts';
      case 'analytics': return 'Analytics';
      case 'manager_chat': return 'AI Chat';
      case 'whatsapp_templates': return 'Templates';
      case 'predictive_intelligence': return 'Predictions';
      case 'media': return 'Media';
      default: return f;
    }
  }

  @override
  void initState() {
    super.initState();
    // Trigger broadcast analytics fetch for this client.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BroadcastAnalyticsProvider>().fetchAnalytics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roi = context.watch<RoiAnalyticsProvider>();
    final broadcast = context.watch<BroadcastAnalyticsProvider>();
    final data = roi.data;
    final broadcastData = broadcast.analytics;

    // ── Card 1: Feature Adoption ──────────────────────────────────────
    final activeFeatures = widget.client.enabledFeatures;
    final activeCount =
        _platformFeatures.where((f) => activeFeatures.contains(f)).length;
    final inactiveFeatures =
        _platformFeatures.where((f) => !activeFeatures.contains(f)).toList();

    // ── Card 2: Broadcast ROI ─────────────────────────────────────────
    final campaigns = broadcastData?.recentCampaigns ?? [];
    final sortedByRead = [...campaigns]
      ..sort((a, b) => b.readRate.compareTo(a.readRate));
    final bestCampaign = sortedByRead.isEmpty ? null : sortedByRead.first;

    // ── Card 3: Response Time Signal ─────────────────────────────────
    final avgResponseSecs = data?.current.avgResponseTimeSeconds ?? 0.0;
    final avgResponseMins = avgResponseSecs / 60;

    // ── Card 4: Customer Return Rate ─────────────────────────────────
    final inboundCustomers = data?.inboundCustomers ?? [];
    final totalUnique = inboundCustomers.length;
    final returningCount =
        inboundCustomers.where((c) => c.messageCount > 1).length;
    final returnRate =
        totalUnique > 0 ? returningCount / totalUnique * 100 : 0.0;

    // ── Card 5: Optimal Broadcast Time ───────────────────────────────
    final replyHourCounts = <int, int>{};
    for (final ec in data?.engagedCustomers ?? []) {
      final h = ec.date.hour;
      replyHourCounts[h] = (replyHourCounts[h] ?? 0) + 1;
    }
    int? peakReplyHour;
    int peakReplyCount = 0;
    for (final e in replyHourCounts.entries) {
      if (e.value > peakReplyCount) {
        peakReplyCount = e.value;
        peakReplyHour = e.key;
      }
    }
    final totalReplyCustomers =
        replyHourCounts.values.fold(0, (a, b) => a + b);
    // Top 3 most active reply hours
    final sortedReplyHours = replyHourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3Hours = sortedReplyHours.take(3).toList();

    // ── Card 6: Conversation Engagement Rate ─────────────────────────
    final engagementRate = data?.current.engagementRate ?? 0.0;
    final messagesReceived = data?.current.messagesReceived ?? 0;
    final messagesSent = data?.current.messagesSent ?? 0;
    final engagedCount = data?.engagedCustomers.length ?? 0;

    // ── Card 7: Broadcast Intelligence ───────────────────────────────
    final roiCampaigns = data?.campaigns ?? [];
    final sortedByEngagement = [...roiCampaigns]
      ..sort((a, b) => b.engagementRate.compareTo(a.engagementRate));
    final bestRoiCampaign =
        sortedByEngagement.isEmpty ? null : sortedByEngagement.first;
    final worstCampaign = roiCampaigns
        .where((c) => c.responded == 0 && c.sent > 0)
        .toList()
      ..sort((a, b) => (a.sentAt ?? DateTime(0))
          .compareTo(b.sentAt ?? DateTime(0)));
    final zeroReplyCampaign = worstCampaign.isEmpty ? null : worstCampaign.last;

    // Build intelligence recommendations dynamically
    final recommendations = <String>[];
    if (roiCampaigns.isEmpty) {
      recommendations.add(
          'No engagement data yet. Send your first broadcast and return here for timing insights.');
    } else {
      if (bestRoiCampaign != null &&
          bestRoiCampaign.engagementRate > 0 &&
          bestRoiCampaign.sentAt != null) {
        final t = bestRoiCampaign.sentAt!;
        final timeStr =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        recommendations.add(
            'Best broadcast: "${bestRoiCampaign.name}" sent at $timeStr achieved ${bestRoiCampaign.engagementRate.toStringAsFixed(1)}% engagement. Replicate this timing.');
      }
      if (zeroReplyCampaign != null && zeroReplyCampaign.sentAt != null) {
        final t = zeroReplyCampaign.sentAt!;
        final timeStr =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        recommendations.add(
            '"${zeroReplyCampaign.name}" sent at $timeStr received no replies. Avoid this time slot.');
      }
      if (peakReplyHour != null && totalReplyCustomers >= 3) {
        final windowStart = peakReplyHour < 1 ? 23 : peakReplyHour - 1;
        final optimalStr =
            '${windowStart.toString().padLeft(2, '0')}:00';
        final peakStr = '${peakReplyHour.toString().padLeft(2, '0')}:00';
        recommendations.add(
            'Customers reply most around $peakStr. Schedule broadcasts at $optimalStr to maximise visibility.');
      } else if (recommendations.isEmpty) {
        recommendations.add(
            'Not enough engagement data yet. Send more broadcasts to unlock timing insights.');
      }
    }

    final isLoading = roi.isLoading || broadcast.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Image.asset('assets/images/vivid_icon.png',
                  width: 20, height: 20),
              const SizedBox(width: 8),
              Text(
                'Vivid Insights — ${widget.client.name}',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: VividColors.cyan.withValues(alpha: 0.4)),
                ),
                child: const Text('Admin Only',
                    style: TextStyle(
                        color: VividColors.cyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Internal metrics and growth opportunities for this client.',
            style: TextStyle(color: vc.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),

          if (isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    color: VividColors.cyan, strokeWidth: 2),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 500;

                // ── Card 1: Feature Adoption ─────────────────────────
                final card1 = _insightCard(
                  context: context,
                  accentColor: VividColors.cyan,
                  icon: Icons.extension_outlined,
                  title: 'Feature Adoption',
                  headline: '$activeCount / ${_platformFeatures.length} features active',
                  headlineColor: VividColors.cyan,
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeFeatures.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _platformFeatures
                              .where((f) => activeFeatures.contains(f))
                              .map((f) => _featureChip(f, VividColors.cyan, isDark: isDark))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (inactiveFeatures.isNotEmpty) ...[
                        Text('Growth opportunities:',
                            style: TextStyle(
                                color: vc.textMuted.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: inactiveFeatures
                              .map((f) => _featureChip(f,
                                  const Color(0xFFF59E0B),
                                  isDark: isDark, outlined: true))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _showFeatureAdoptionSheet(context, activeFeatures, inactiveFeatures, activeCount),
                );

                // ── Card 2: Broadcast ROI ────────────────────────────
                final card2 = _insightCard(
                  context: context,
                  accentColor: const Color(0xFF8B5CF6),
                  icon: Icons.campaign_outlined,
                  title: 'Broadcast ROI',
                  headline: broadcastData == null
                      ? 'No broadcast data'
                      : bestCampaign == null
                          ? 'No campaigns yet'
                          : '${bestCampaign.readRate.toStringAsFixed(1)}% read rate',
                  headlineColor: broadcastData != null && bestCampaign != null
                      ? const Color(0xFF8B5CF6)
                      : vc.textMuted,
                  body: broadcastData == null
                      ? Text('Run a broadcast to see ROI metrics.',
                          style: TextStyle(color: vc.textMuted.withValues(alpha: 0.5), fontSize: 11))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${broadcastData.totalCampaigns} campaigns · ${broadcastData.deliveryRate.toStringAsFixed(1)}% delivery',
                              style: TextStyle(color: vc.textMuted.withValues(alpha: 0.5), fontSize: 11),
                            ),
                            if (sortedByRead.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...sortedByRead.map((c) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(c.name,
                                              style: TextStyle(
                                                  color: vc.textPrimary.withValues(alpha: 0.7),
                                                  fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${c.readRate.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                                color: Color(0xFF8B5CF6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                  onTap: () => _showBroadcastROISheet(context, sortedByRead, bestCampaign),
                );

                // ── Card 3: Response Time Signal ─────────────────────
                final card3 = _insightCard(
                  context: context,
                  accentColor: const Color(0xFFF59E0B),
                  icon: Icons.timer_outlined,
                  title: 'Response Time Signal',
                  headline: data == null
                      ? 'No data'
                      : avgResponseSecs == 0
                          ? 'No response data'
                          : avgResponseMins > 60
                              ? 'Avg ${avgResponseMins.toStringAsFixed(0)} min'
                              : 'Strong — ${avgResponseMins < 1 ? '<1 min' : '${avgResponseMins.toStringAsFixed(0)} min'} avg',
                  headlineColor: data != null && avgResponseSecs > 0
                      ? (avgResponseMins > 60
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981))
                      : vc.textMuted,
                  body: data == null
                      ? Text('Load analytics to see response times.',
                          style: TextStyle(color: vc.textMuted.withValues(alpha: 0.5), fontSize: 11))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              avgResponseSecs == 0
                                  ? 'No response time data recorded yet.'
                                  : avgResponseMins > 60
                                      ? 'AI conversations could accelerate response time.'
                                      : 'Strong — keep it up.',
                              style: TextStyle(color: vc.textMuted.withValues(alpha: 0.5), fontSize: 11),
                            ),
                            if (data.current.employeeAvgResponseTime.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...data.current.employeeAvgResponseTime.entries
                                  .where((e) =>
                                      e.key.isNotEmpty &&
                                      e.key.toLowerCase() != 'broadcast')
                                  .take(4)
                                  .map((e) {
                                final mins = e.value / 60;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(e.key,
                                            style: TextStyle(
                                                color: vc.textMuted
                                                    .withValues(alpha: 0.6),
                                                fontSize: 10),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      Text(
                                        mins < 1
                                            ? '<1 min'
                                            : '${mins.toStringAsFixed(0)} min',
                                        style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                  onTap: () => _showResponseTimeSheet(context, avgResponseSecs, avgResponseMins),
                );

                // ── Card 4: Customer Return Rate ─────────────────────
                final card4 = _insightCard(
                  context: context,
                  accentColor: const Color(0xFF10B981),
                  icon: Icons.people_outline,
                  title: 'Customer Return Rate',
                  headline: totalUnique == 0
                      ? 'No data'
                      : '${returnRate.toStringAsFixed(1)}% returning',
                  headlineColor: totalUnique > 0 ? const Color(0xFF10B981) : vc.textMuted,
                  body: totalUnique == 0
                      ? Text('No conversation data available.',
                          style: TextStyle(color: vc.textMuted.withValues(alpha: 0.5), fontSize: 11))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('$returningCount returning',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.3),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(
                                  '${totalUnique - returningCount} first-time',
                                  style: const TextStyle(
                                      color: Color(0x80FFFFFF),
                                      fontSize: 12)),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                              returnRate >= 50
                                  ? 'Strong retention — customers keep coming back.'
                                  : returnRate >= 25
                                      ? 'Good start — growing a loyal base.'
                                      : 'Opportunity to boost repeat engagement.',
                              style: TextStyle(
                                  color: vc.textMuted.withValues(alpha: 0.4),
                                  fontSize: 11),
                            ),
                          ],
                        ),
                  onTap: () => _showReturnRateSheet(context, totalUnique, returningCount, returnRate),
                );

                // ── Card 5: Optimal Broadcast Time ───────────────────
                final card5 = _insightCard(
                  context: context,
                  accentColor: const Color(0xFF06B6D4),
                  icon: Icons.schedule_outlined,
                  title: 'Optimal Broadcast Time',
                  headline: peakReplyHour == null
                      ? 'No data yet'
                      : 'Best: ${peakReplyHour.toString().padLeft(2, '0')}:00',
                  headlineColor: peakReplyHour != null
                      ? const Color(0xFF06B6D4)
                      : const Color(0x80FFFFFF),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (top3Hours.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: top3Hours.asMap().entries.map((e) {
                            final rank = e.key;
                            final hour = e.value.key;
                            final count = e.value.value;
                            final rankColor = rank == 0
                                ? const Color(0xFF06B6D4)
                                : rank == 1
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.35);
                            final rankLabel =
                                rank == 0 ? '1st' : rank == 1 ? '2nd' : '3rd';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: rankColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(rankLabel,
                                      style: TextStyle(
                                          color: rankColor.withValues(alpha: 0.6),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  Text(
                                      '${hour.toString().padLeft(2, '0')}:00',
                                      style: TextStyle(
                                          color: rankColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 5),
                                  Text('($count)',
                                      style: TextStyle(
                                          color: rankColor.withValues(alpha: 0.5),
                                          fontSize: 9)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ] else
                        const Text('Not enough reply data yet.',
                            style: TextStyle(
                                color: Color(0x80FFFFFF), fontSize: 11)),
                      if (peakReplyHour != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Based on $totalReplyCustomers customer ${totalReplyCustomers == 1 ? 'reply' : 'replies'}.',
                          style: const TextStyle(
                              color: Color(0x66FFFFFF), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _showBroadcastTimingSheet(
                      context, data?.campaigns ?? [], top3Hours, peakReplyHour,
                      bestRoiCampaign),
                );

                // ── Card 6: Conversation Engagement Rate ──────────────
                final engColor = engagementRate >= 5
                    ? VividColors.cyan
                    : engagementRate >= 2
                        ? const Color(0xFFF59E0B)
                        : const Color(0x80FFFFFF);
                final card6 = _insightCard(
                  context: context,
                  accentColor: engColor,
                  icon: Icons.forum_outlined,
                  title: 'Conversation Engagement',
                  headline: data == null
                      ? 'No data'
                      : '${engagementRate.toStringAsFixed(1)}% engaged',
                  headlineColor: data != null ? engColor : const Color(0x80FFFFFF),
                  body: data == null
                      ? const Text('Load analytics to see engagement data.',
                          style: TextStyle(color: Color(0x80FFFFFF), fontSize: 11))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: VividColors.cyan,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('$messagesReceived inbound replies',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.3),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('$messagesSent outbound sent',
                                  style: const TextStyle(
                                      color: Color(0x80FFFFFF),
                                      fontSize: 12)),
                            ]),
                          ],
                        ),
                  onTap: () => _showEngagementSheet(
                      context, engagementRate, messagesReceived, messagesSent,
                      engagedCount, data?.campaigns ?? []),
                );

                if (wide) {
                  return Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: card1),
                            const SizedBox(width: 16),
                            Expanded(child: card2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: card3),
                            const SizedBox(width: 16),
                            Expanded(child: card4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: card5),
                            const SizedBox(width: 16),
                            Expanded(child: card6),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    card1,
                    const SizedBox(height: 16),
                    card2,
                    const SizedBox(height: 16),
                    card3,
                    const SizedBox(height: 16),
                    card4,
                    const SizedBox(height: 16),
                    card5,
                    const SizedBox(height: 16),
                    card6,
                  ],
                );
              },
            ),

          // ── Card 7: Broadcast Intelligence (full width) ───────────────
          const SizedBox(height: 16),
          _insightCard(
            context: context,
            accentColor: VividColors.cyan,
            icon: Icons.auto_awesome,
            title: 'Broadcast Intelligence',
            headline: roiCampaigns.isEmpty
                ? 'No broadcasts yet'
                : '${roiCampaigns.length} broadcast${roiCampaigns.length == 1 ? '' : 's'} analysed',
            headlineColor: roiCampaigns.isEmpty
                ? const Color(0x80FFFFFF)
                : VividColors.cyan,
            backgroundColor: Colors.white.withValues(alpha: 0.03),
            body: recommendations.isEmpty
                ? const Text('Not enough data yet.',
                    style: TextStyle(color: Color(0x80FFFFFF), fontSize: 11))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recommendations.asMap().entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.only(
                            top: e.key == 0 ? 0 : 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              decoration: const BoxDecoration(
                                color: VividColors.cyan,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF),
                                    fontSize: 12,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard({
    required BuildContext context,
    required Color accentColor,
    required IconData icon,
    required String title,
    required String headline,
    required Color headlineColor,
    required Widget body,
    VoidCallback? onTap,
    Color backgroundColor = Colors.transparent,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accentColor.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Color(0x80FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: TextStyle(
              color: headlineColor,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  // ── Sheet helpers ────────────────────────────────────────────────

  Widget _sheetDragHandle() {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _sheetFeatureRow(String feature, Color color, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(active ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              color: color, size: 16),
          const SizedBox(width: 10),
          Text(_featureDisplayName(feature),
              style: TextStyle(
                  color: active ? Colors.white : const Color(0x99FFFFFF),
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _sheetStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showFeatureAdoptionSheet(
    BuildContext context,
    List<String> activeFeatures,
    List<String> inactiveFeatures,
    int activeCount,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Center(child: _sheetDragHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.extension_outlined, color: VividColors.cyan, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Feature Adoption',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VividColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$activeCount / ${_platformFeatures.length}',
                        style: const TextStyle(
                            color: VividColors.cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (activeFeatures.isNotEmpty) ...[
                    const Text('Active Features',
                        style: TextStyle(
                            color: Color(0x80FFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._platformFeatures
                        .where((f) => activeFeatures.contains(f))
                        .map((f) => _sheetFeatureRow(f, VividColors.cyan, true)),
                    const SizedBox(height: 16),
                  ],
                  if (inactiveFeatures.isNotEmpty) ...[
                    const Text('Growth Opportunities',
                        style: TextStyle(
                            color: Color(0x80FFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...inactiveFeatures
                        .map((f) => _sheetFeatureRow(f, const Color(0x66FFFFFF), false)),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBroadcastROISheet(
    BuildContext context,
    List<CampaignPerformance> campaigns,
    CampaignPerformance? bestCampaign,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Center(child: _sheetDragHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined,
                      color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Broadcast ROI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text('${campaigns.length} campaigns',
                      style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12)),
                ],
              ),
            ),
            campaigns.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text('No campaigns yet.',
                          style: TextStyle(color: Color(0x80FFFFFF), fontSize: 13)),
                    ),
                  )
                : Expanded(
                    child: ListView.separated(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: campaigns.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withValues(alpha: 0.06),
                        height: 1,
                      ),
                      itemBuilder: (_, i) {
                        final c = campaigns[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.recipients} recipients · ${c.deliveryRate.toStringAsFixed(1)}% delivered',
                                      style: const TextStyle(
                                          color: Color(0x80FFFFFF), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('${c.readRate.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showResponseTimeSheet(
    BuildContext context,
    double avgResponseSecs,
    double avgResponseMins,
  ) {
    final hasData = avgResponseSecs > 0;
    final isStrong = hasData && avgResponseMins <= 60;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        maxChildSize: 0.7,
        expand: false,
        builder: (_, sc) => SingleChildScrollView(
          controller: sc,
          child: Column(
            children: [
              Center(child: _sheetDragHandle()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 20),
                        SizedBox(width: 8),
                        Text('Response Time Signal',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        hasData
                            ? (avgResponseMins < 1
                                ? '<1 min'
                                : '${avgResponseMins.toStringAsFixed(0)} min')
                            : '—',
                        style: TextStyle(
                          color: hasData
                              ? (isStrong
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B))
                              : const Color(0x80FFFFFF),
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        hasData ? 'average response time' : 'no data recorded',
                        style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        hasData
                            ? (isStrong
                                ? 'Response time is excellent. Customers are getting quick replies — keep it up.'
                                : 'Response time is above 1 hour. Enabling AI conversations could significantly reduce wait times.')
                            : 'No response time data has been recorded yet. Start responding to conversations to track this metric.',
                        style: const TextStyle(
                            color: Color(0x99FFFFFF), fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReturnRateSheet(
    BuildContext context,
    int totalUnique,
    int returningCount,
    double returnRate,
  ) {
    final firstTimeCount = totalUnique - returningCount;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.75,
        expand: false,
        builder: (_, sc) => SingleChildScrollView(
          controller: sc,
          child: Column(
            children: [
              Center(child: _sheetDragHandle()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people_outline, color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 8),
                        Text('Customer Return Rate',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        totalUnique > 0
                            ? '${returnRate.toStringAsFixed(1)}%'
                            : '—',
                        style: TextStyle(
                          color: totalUnique > 0
                              ? const Color(0xFF10B981)
                              : const Color(0x80FFFFFF),
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text('return rate',
                          style: TextStyle(color: Color(0x80FFFFFF), fontSize: 12)),
                    ),
                    const SizedBox(height: 24),
                    _sheetStatRow(
                        'Returning customers', '$returningCount', const Color(0xFF10B981)),
                    Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                    _sheetStatRow(
                        'First-time customers', '$firstTimeCount', const Color(0x80FFFFFF)),
                    Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                    _sheetStatRow('Total unique customers', '$totalUnique', Colors.white),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        totalUnique == 0
                            ? 'No conversation data available yet.'
                            : returnRate >= 50
                                ? 'Strong retention — more than half of customers come back for repeat conversations.'
                                : returnRate >= 25
                                    ? 'Good start — a growing base of loyal customers. Keep engaging them.'
                                    : 'Opportunity to boost repeat engagement through follow-ups and broadcasts.',
                        style: const TextStyle(
                            color: Color(0x99FFFFFF), fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastTimingSheet(
    BuildContext context,
    List<roiLib.CampaignPerformance> campaigns,
    List<MapEntry<int, int>> top3Hours,
    int? peakReplyHour,
    roiLib.CampaignPerformance? bestCampaign,
  ) {
    String fmt(DateTime? dt) {
      if (dt == null) return '—';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Center(child: _sheetDragHandle()),
            const Row(
              children: [
                Icon(Icons.schedule_outlined, color: Color(0xFF06B6D4), size: 20),
                SizedBox(width: 8),
                Text('Optimal Broadcast Time',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 20),
            if (campaigns.isNotEmpty) ...[
              const Text('When you sent broadcasts',
                  style: TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...campaigns.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(fmt(c.sentAt),
                                  style: const TextStyle(
                                      color: Color(0x80FFFFFF), fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('${c.engagementRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: c.engagementRate > 0
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0x80FFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 24),
            ],
            if (top3Hours.isNotEmpty) ...[
              const Text('When customers reply',
                  style: TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...top3Hours.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text('${e.key.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: top3Hours.first.value > 0
                                ? e.value / top3Hours.first.value
                                : 0,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            color: const Color(0xFF06B6D4),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${e.value}',
                            style: const TextStyle(
                                color: Color(0x80FFFFFF), fontSize: 11)),
                      ],
                    ),
                  )),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                peakReplyHour == null && campaigns.isEmpty
                    ? 'No data yet. Send your first broadcast to unlock timing insights.'
                    : bestCampaign != null && bestCampaign.sentAt != null
                        ? 'Your most engaged broadcast was sent at ${fmt(bestCampaign.sentAt)}. '
                            '${peakReplyHour != null ? 'Customers reply most around ${peakReplyHour.toString().padLeft(2, '0')}:00. Recommend scheduling next broadcast at ${(peakReplyHour > 0 ? peakReplyHour - 1 : 23).toString().padLeft(2, '0')}:00.' : 'Keep replicating this timing.'}'
                        : peakReplyHour != null
                            ? 'Customers reply most around ${peakReplyHour.toString().padLeft(2, '0')}:00. Schedule broadcasts 30–60 min before this window for best visibility.'
                            : 'Not enough engagement data yet to make a recommendation.',
                style: const TextStyle(
                    color: Color(0x99FFFFFF), fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEngagementSheet(
    BuildContext context,
    double engagementRate,
    int messagesReceived,
    int messagesSent,
    int engagedCount,
    List<roiLib.CampaignPerformance> campaigns,
  ) {
    final withReplies = campaigns.where((c) => c.responded > 0).length;
    final withoutReplies = campaigns.where((c) => c.responded == 0 && c.sent > 0).length;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, sc) => SingleChildScrollView(
          controller: sc,
          child: Column(
            children: [
              Center(child: _sheetDragHandle()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.forum_outlined,
                            color: engagementRate >= 5
                                ? VividColors.cyan
                                : engagementRate >= 2
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0x80FFFFFF),
                            size: 20),
                        const SizedBox(width: 8),
                        const Text('Conversation Engagement',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '${engagementRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: engagementRate >= 5
                              ? VividColors.cyan
                              : engagementRate >= 2
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0x80FFFFFF),
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text('inbound replies per outbound message',
                          style:
                              TextStyle(color: Color(0x80FFFFFF), fontSize: 12)),
                    ),
                    const SizedBox(height: 24),
                    _sheetStatRow('Inbound replies', '$messagesReceived',
                        VividColors.cyan),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.06), height: 1),
                    _sheetStatRow('Outbound messages', '$messagesSent',
                        const Color(0x80FFFFFF)),
                    Divider(
                        color: Colors.white.withValues(alpha: 0.06), height: 1),
                    _sheetStatRow('Customers who engaged', '$engagedCount',
                        VividColors.cyan),
                    if (campaigns.isNotEmpty) ...[
                      Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1),
                      _sheetStatRow('Broadcasts with replies', '$withReplies',
                          const Color(0xFF10B981)),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1),
                      _sheetStatRow('Broadcasts with no replies',
                          '$withoutReplies', const Color(0x80FFFFFF)),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        engagementRate >= 5
                            ? 'Excellent engagement. Customers are actively responding to outbound messages.'
                            : engagementRate >= 2
                                ? 'Moderate engagement. Consider refining message content or timing to drive more replies.'
                                : engagementRate > 0
                                    ? 'Low engagement rate. Focus on sending more targeted, personalised messages.'
                                    : 'No engagement data recorded yet.',
                        style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureChip(String feature, Color color,
      {required bool isDark, bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _featureDisplayName(feature),
        style: TextStyle(
          color: color.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
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

// ============================================
// PENDING LABEL TRIGGER DIALOG (for create wizard — returns Map, no DB)
// ============================================

class _PendingLabelTriggerDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _PendingLabelTriggerDialog({this.existing});

  @override
  State<_PendingLabelTriggerDialog> createState() => _PendingLabelTriggerDialogState();
}

class _PendingLabelTriggerDialogState extends State<_PendingLabelTriggerDialog> {
  late TextEditingController _labelCtrl;
  late TextEditingController _wordCtrl;
  late List<String> _triggerWords;
  late String _selectedColor;
  late bool _autoApply;

  static const _presetColors = [
    '#38BEC9', '#34B869', '#DC4444', '#D4A528',
    '#9333EA', '#0550B8', '#F59E0B', '#EC4899',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?['label'] as String? ?? '');
    _wordCtrl = TextEditingController();
    _triggerWords = (e?['trigger_words'] as List<dynamic>?)?.map((w) => w.toString()).toList() ?? [];
    _selectedColor = e?['color'] as String? ?? '#38BEC9';
    _autoApply = e?['auto_apply'] as bool? ?? true;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _wordCtrl.dispose();
    super.dispose();
  }

  void _addWord() {
    final word = _wordCtrl.text.trim();
    if (word.isNotEmpty && !_triggerWords.contains(word)) {
      setState(() { _triggerWords.add(word); _wordCtrl.clear(); });
    }
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: vc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(isEdit ? Icons.edit : Icons.new_label, color: VividColors.cyan, size: 20),
        const SizedBox(width: 8),
        Text(isEdit ? 'Edit Label Trigger' : 'Add Label Trigger', style: TextStyle(color: vc.textPrimary, fontSize: 18)),
      ]),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Label Name', style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _labelCtrl,
                style: TextStyle(color: vc.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Appointment Booked',
                  hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                  filled: true, fillColor: vc.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: vc.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: vc.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: VividColors.cyan)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Color', style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _presetColors.map((hex) {
                  final color = _hexToColor(hex);
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                        boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Trigger Words', style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _wordCtrl,
                    style: TextStyle(color: vc.textPrimary, fontSize: 14),
                    onSubmitted: (_) => _addWord(),
                    decoration: InputDecoration(
                      hintText: 'Type a word and press Enter',
                      hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                      filled: true, fillColor: vc.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: vc.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: vc.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: VividColors.cyan)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _addWord, icon: const Icon(Icons.add_circle, color: VividColors.cyan), tooltip: 'Add word'),
              ]),
              const SizedBox(height: 8),
              if (_triggerWords.isNotEmpty)
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _triggerWords.map((w) {
                    final color = _hexToColor(_selectedColor);
                    return Chip(
                      label: Text(w, style: TextStyle(color: color, fontSize: 12)),
                      backgroundColor: vc.surfaceAlt,
                      deleteIconColor: vc.textMuted,
                      onDeleted: () => setState(() => _triggerWords.remove(w)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              Row(children: [
                Switch(value: _autoApply, onChanged: (v) => setState(() => _autoApply = v), activeColor: VividColors.cyan),
                const SizedBox(width: 8),
                Expanded(child: Text('Auto-apply when message contains any trigger word', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel', style: TextStyle(color: vc.textMuted))),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Label name is required'), backgroundColor: VividColors.statusUrgent),
              );
              return;
            }
            Navigator.of(context).pop(<String, dynamic>{
              'label': label,
              'trigger_words': List<String>.from(_triggerWords),
              'color': _selectedColor,
              'auto_apply': _autoApply,
            });
          },
          style: FilledButton.styleFrom(backgroundColor: VividColors.cyan, foregroundColor: Colors.white),
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ============================================
// LABEL TRIGGER DIALOG
// ============================================

class _LabelTriggerDialog extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic>? existing;

  const _LabelTriggerDialog({required this.clientId, this.existing});

  @override
  State<_LabelTriggerDialog> createState() => _LabelTriggerDialogState();
}

class _LabelTriggerDialogState extends State<_LabelTriggerDialog> {
  late TextEditingController _labelCtrl;
  late TextEditingController _wordCtrl;
  late List<String> _triggerWords;
  late String _selectedColor;
  late bool _autoApply;
  bool _saving = false;

  static const _presetColors = [
    '#38BEC9', // cyan
    '#34B869', // green
    '#DC4444', // red
    '#D4A528', // orange
    '#9333EA', // purple
    '#0550B8', // blue
    '#F59E0B', // amber
    '#EC4899', // pink
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?['label'] as String? ?? '');
    _wordCtrl = TextEditingController();
    _triggerWords = (e?['trigger_words'] as List<dynamic>?)
            ?.map((w) => w.toString())
            .toList() ??
        [];
    _selectedColor = e?['color'] as String? ?? '#38BEC9';
    _autoApply = e?['auto_apply'] as bool? ?? true;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _wordCtrl.dispose();
    super.dispose();
  }

  void _addWord() {
    final word = _wordCtrl.text.trim();
    if (word.isNotEmpty && !_triggerWords.contains(word)) {
      setState(() {
        _triggerWords.add(word);
        _wordCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: vc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit : Icons.new_label,
            color: VividColors.cyan,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isEdit ? 'Edit Label Trigger' : 'Add Label Trigger',
            style: TextStyle(color: vc.textPrimary, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label name
              Text('Label Name', style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _labelCtrl,
                style: TextStyle(color: vc.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Appointment Booked',
                  hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: vc.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: VividColors.cyan),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Color picker
              Text('Color', style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetColors.map((hex) {
                  final color = _hexToColor(hex);
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Trigger words
              Text('Trigger Words', style: TextStyle(color: vc.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _wordCtrl,
                      style: TextStyle(color: vc.textPrimary, fontSize: 14),
                      onSubmitted: (_) => _addWord(),
                      decoration: InputDecoration(
                        hintText: 'Type a word and press Enter',
                        hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: vc.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: vc.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: vc.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: VividColors.cyan),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addWord,
                    icon: const Icon(Icons.add_circle, color: VividColors.cyan),
                    tooltip: 'Add word',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_triggerWords.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _triggerWords.map((w) {
                    final color = _hexToColor(_selectedColor);
                    return Chip(
                      label: Text(w, style: TextStyle(color: color, fontSize: 12)),
                      backgroundColor: vc.surfaceAlt,
                      deleteIconColor: vc.textMuted,
                      onDeleted: () => setState(() => _triggerWords.remove(w)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // Auto-apply toggle
              Row(
                children: [
                  Switch(
                    value: _autoApply,
                    onChanged: (v) => setState(() => _autoApply = v),
                    activeColor: VividColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-apply when message contains any trigger word',
                      style: TextStyle(color: vc.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: VividColors.cyan,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label name is required'), backgroundColor: VividColors.statusUrgent),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<AdminProvider>();

    String? err;
    if (widget.existing != null) {
      err = await provider.updateLabelTrigger(
        widget.existing!['id'] as String,
        {
          'label': label,
          'trigger_words': _triggerWords,
          'color': _selectedColor,
          'auto_apply': _autoApply,
        },
        widget.clientId,
      );
    } else {
      err = await provider.createLabelTrigger(
        clientId: widget.clientId,
        label: label,
        triggerWords: _triggerWords,
        color: _selectedColor,
        autoApply: _autoApply,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err'), backgroundColor: VividColors.statusUrgent),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADMIN TEMPLATES TAB
// ═══════════════════════════════════════════════════════════════════

class _AdminTemplatesTab extends StatefulWidget {
  const _AdminTemplatesTab();

  @override
  State<_AdminTemplatesTab> createState() => _AdminTemplatesTabState();
}

class _AdminTemplatesTabState extends State<_AdminTemplatesTab> {
  Client? _selectedTemplateClient;
  List<Map<String, dynamic>> _clientTemplates = [];
  bool _isLoadingTemplates = false;
  String? _templateError;
  String _search = '';
  String? _statusFilter;
  String? _categoryFilter;
  Map<String, dynamic>? _selected;
  bool _isDeleting = false;
  bool _isSyncingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clients = context.read<AdminProvider>().clients;
      if (clients.isNotEmpty) _loadClientTemplates(clients.first);
    });
  }

  /// Fetch templates from Meta API for a given WABA. Returns raw JSON maps.
  Future<List<Map<String, dynamic>>> _fetchMetaTemplates(
      String wabaId, String token) async {
    final baseUrl =
        'https://graph.facebook.com/${SupabaseService.metaApiVersion}';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final all = <Map<String, dynamic>>[];
    String? nextUrl =
        '$baseUrl/$wabaId/message_templates?limit=100&fields=id,name,status,language,category,components';
    while (nextUrl != null) {
      final response = await http.get(Uri.parse(nextUrl), headers: headers);
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final err = body['error'] as Map<String, dynamic>?;
        throw Exception(err?['message'] ?? 'HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      for (final item in data) {
        all.add(item as Map<String, dynamic>);
      }
      final paging = body['paging'] as Map<String, dynamic>?;
      final next = paging?['next'] as String?;
      nextUrl = (next != null && next.isNotEmpty) ? next : null;
    }
    return all;
  }

  /// Load templates for a client from its Supabase table.
  Future<void> _loadClientTemplates(Client client) async {
    setState(() {
      _selectedTemplateClient = client;
      _isLoadingTemplates = true;
      _templateError = null;
      _selected = null;
    });

    final table = client.templatesTable;
    if (table == null || table.isEmpty) {
      setState(() {
        _clientTemplates = [];
        _isLoadingTemplates = false;
        _templateError = 'No templates table configured for ${client.name}';
      });
      return;
    }

    try {
      final response = await SupabaseService.adminClient
          .from(table)
          .select()
          .order('template_name');

      final templates = (response as List).cast<Map<String, dynamic>>();
      debugPrint(
          'ADMIN_TEMPLATES: loaded ${templates.length} templates from $table');

      // Debug cross-client template contamination (generic for all clients)
      final currentSlug = client.slug.toLowerCase();
      if (currentSlug.isNotEmpty) {
        const universalTemplates = {'hello_world', 'vivddemo'};
        final contaminated = templates.where((t) {
          final name = (t['template_name'] as String? ?? '').toLowerCase();
          return !name.startsWith(currentSlug) && !universalTemplates.contains(name);
        }).toList();
        if (contaminated.isNotEmpty) {
          debugPrint('[templates] WARNING: ${contaminated.length} potentially foreign templates in ${currentSlug}_whatsapp_templates: ${contaminated.map((t) => t['template_name']).join(', ')}');
        }
      }

      if (mounted) {
        setState(() {
          _clientTemplates = templates;
          _isLoadingTemplates = false;
        });
      }
    } catch (e) {
      debugPrint('ADMIN_TEMPLATES: load error: $e');
      if (mounted) {
        setState(() {
          _templateError = e.toString();
          _isLoadingTemplates = false;
        });
      }
    }
  }

  /// Fetch from Meta for this client's WABA, upsert into its table, then reload.
  Future<void> _refreshFromMeta(Client client) async {
    final table = client.templatesTable;
    if (table == null || table.isEmpty) {
      VividToast.show(context,
          message: 'No templates table for ${client.name}',
          type: ToastType.error);
      return;
    }

    setState(() => _isLoadingTemplates = true);
    try {
      final wabaId = client.wabaId ?? SupabaseService.metaWabaId;
      final token =
          client.metaAccessToken ?? SupabaseService.metaAccessToken;

      final metaTemplates = await _fetchMetaTemplates(wabaId, token);
      debugPrint(
          'ADMIN_TEMPLATES: fetched ${metaTemplates.length} from Meta for ${client.name}');

      final now = DateTime.now().toIso8601String();
      final toInsert = <Map<String, dynamic>>[];
      final toUpdate = <Map<String, dynamic>>[];

      for (final raw in metaTemplates) {
        final t = WhatsAppTemplate.fromJson(raw);
        final varCount =
            RegExp(r'\{\{\d+\}\}').allMatches(t.body).length;

        // Preserve existing labels/sources/image; non-null means row exists
        final existing = await SupabaseService.adminClient
            .from(table)
            .select(
                'body_variable_labels, body_variable_sources, offer_image_url')
            .eq('template_name', t.name)
            .eq('client_id', client.id)
            .maybeSingle();

        final existingLabels = existing?['body_variable_labels'];
        final hasLabels = existingLabels is List &&
            existingLabels.isNotEmpty &&
            existingLabels
                .any((l) => (l as String?)?.trim().isNotEmpty == true);
        final labels = hasLabels
            ? List<String>.from(existingLabels)
            : List.generate(varCount, (i) => 'Variable ${i + 1}');

        final existingSources = existing?['body_variable_sources'];
        final hasSources =
            existingSources is List && existingSources.isNotEmpty;
        final sources = hasSources
            ? List<String>.from(existingSources)
            : List.generate(varCount, (_) => 'customer_data');

        final existingImageUrl = existing?['offer_image_url'] as String?;
        final offerImageUrl = (existingImageUrl != null &&
                existingImageUrl.contains('supabase.co/storage') &&
                !existingImageUrl.contains('scontent'))
            ? existingImageUrl
            : null;

        final headerType =
            t.headerType.toLowerCase() == 'none' ? 'none' : t.headerType.toLowerCase();

        final row = {
          'meta_template_id': t.id,
          'client_id': client.id,
          'template_name': t.name,
          'display_name': t.name,
          'language_code': t.language,
          'category': t.category,
          'status': t.status,
          'header_type': headerType,
          'header_text': t.headerText,
          'header_media_url': null,
          'header_has_variable': false,
          'body_text': t.body,
          'body_variable_count': varCount,
          'body_variable_labels': labels,
          'body_variable_descriptions': labels,
          'body_variable_sources': sources,
          'buttons':
              t.buttons.map((b) => {'type': b.type, 'text': b.text}).toList(),
          'button_count': t.buttons.length,
          'is_active': t.status == 'APPROVED',
          'updated_at': now,
          'offer_image_url': offerImageUrl,
        };

        if (existing != null) {
          toUpdate.add(row);
        } else {
          toInsert.add(row);
        }
      }

      if (toInsert.isNotEmpty) {
        await SupabaseService.adminClient.from(table).insert(toInsert);
      }
      for (final row in toUpdate) {
        await SupabaseService.adminClient
            .from(table)
            .update(row)
            .eq('meta_template_id', row['meta_template_id'] as String);
      }

      await _loadClientTemplates(client);

      if (mounted) {
        VividToast.show(context,
            message:
                'Refreshed ${toInsert.length + toUpdate.length} templates for ${client.name}',
            type: ToastType.success);
      }
    } catch (e) {
      debugPrint('ADMIN_TEMPLATES: refresh error: $e');
      if (mounted) {
        setState(() => _isLoadingTemplates = false);
        VividToast.show(context,
            message: 'Refresh failed: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> t) async {
    final templateName = t['template_name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final vc = ctx.vividColors;
        return AlertDialog(
          backgroundColor: vc.surface,
          title: Text('Delete Template', style: TextStyle(color: vc.textPrimary)),
          content: Text(
            "Delete '$templateName'? This will remove it from your WhatsApp Business Account and the client table.",
            style: TextStyle(color: vc.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VividColors.statusUrgent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final wabaId =
          _selectedTemplateClient?.wabaId ?? SupabaseService.metaWabaId;
      final token = _selectedTemplateClient?.metaAccessToken ??
          SupabaseService.metaAccessToken;
      final baseUrl =
          'https://graph.facebook.com/${SupabaseService.metaApiVersion}';

      // Step 1: Delete from Meta API
      final uri = Uri.parse(
          '$baseUrl/$wabaId/message_templates?name=$templateName');
      final response = await http.delete(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (response.statusCode != 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final err = decoded['error'] as Map<String, dynamic>?;
        throw Exception(err?['message'] ?? 'Failed (${response.statusCode})');
      }

      // Step 2: Delete from current client's Supabase table
      final table = _selectedTemplateClient?.templatesTable;
      if (table != null && table.isNotEmpty) {
        await SupabaseService.adminClient
            .from(table)
            .delete()
            .eq('template_name', templateName);
      }

      debugPrint('ADMIN_TEMPLATES: deleted "$templateName"');
      if (mounted) {
        setState(() {
          _clientTemplates
              .removeWhere((x) => x['template_name'] == templateName);
          if (_selected?['template_name'] == templateName) _selected = null;
        });
        VividToast.show(context,
            message: 'Template "$templateName" deleted',
            type: ToastType.success);
      }
    } catch (e) {
      debugPrint('ADMIN_TEMPLATES: delete error: $e');
      if (mounted) {
        VividToast.show(context,
            message: 'Delete failed: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Sync all clients — each uses its own WABA.
  Future<void> _syncAllClients() async {
    setState(() => _isSyncingAll = true);
    try {
      final clients = context.read<AdminProvider>().clients;
      int synced = 0;

      for (final client in clients) {
        final table = client.templatesTable;
        if (table == null || table.isEmpty) continue;

        try {
          final wabaId = client.wabaId ?? SupabaseService.metaWabaId;
          final token =
              client.metaAccessToken ?? SupabaseService.metaAccessToken;

          final metaTemplates = await _fetchMetaTemplates(wabaId, token);
          final now = DateTime.now().toIso8601String();
          final rows = <Map<String, dynamic>>[];

          for (final raw in metaTemplates) {
            final t = WhatsAppTemplate.fromJson(raw);
            final varCount =
                RegExp(r'\{\{\d+\}\}').allMatches(t.body).length;
            final headerType = t.headerType.toLowerCase() == 'none'
                ? 'none'
                : t.headerType.toLowerCase();
            rows.add({
              'meta_template_id': t.id,
              'client_id': client.id,
              'template_name': t.name,
              'display_name': t.name,
              'language_code': t.language,
              'category': t.category,
              'status': t.status,
              'header_type': headerType,
              'header_text': t.headerText,
              'header_media_url': null,
              'header_has_variable': false,
              'body_text': t.body,
              'body_variable_count': varCount,
              'body_variable_labels':
                  List.generate(varCount, (i) => 'Variable ${i + 1}'),
              'body_variable_descriptions':
                  List.generate(varCount, (i) => 'Variable ${i + 1}'),
              'body_variable_sources':
                  List.generate(varCount, (_) => 'customer_data'),
              'buttons': t.buttons
                  .map((b) => {'type': b.type, 'text': b.text})
                  .toList(),
              'button_count': t.buttons.length,
              'is_active': t.status == 'APPROVED',
              'updated_at': now,
            });
          }

          if (rows.isNotEmpty) {
            final existingResponse = await SupabaseService.adminClient
                .from(table)
                .select('meta_template_id');
            final existingIds = (existingResponse as List)
                .map((r) => r['meta_template_id'] as String)
                .toSet();
            final toInsert = rows
                .where((r) => !existingIds.contains(r['meta_template_id']))
                .toList();
            final toUpdate = rows
                .where((r) => existingIds.contains(r['meta_template_id']))
                .toList();
            if (toInsert.isNotEmpty) {
              await SupabaseService.adminClient.from(table).insert(toInsert);
            }
            for (final row in toUpdate) {
              await SupabaseService.adminClient
                  .from(table)
                  .update(row)
                  .eq('meta_template_id', row['meta_template_id'] as String);
            }
            synced++;
          }
        } catch (e) {
          debugPrint(
              'ADMIN_TEMPLATES: sync error for ${client.name}: $e');
        }
      }

      // Reload current client
      if (_selectedTemplateClient != null && mounted) {
        await _loadClientTemplates(_selectedTemplateClient!);
      }

      if (mounted) {
        VividToast.show(context,
            message:
                'Synced all templates for $synced client${synced == 1 ? '' : 's'}',
            type: ToastType.success);
      }
    } catch (e) {
      debugPrint('ADMIN_TEMPLATES: sync all error: $e');
      if (mounted) {
        VividToast.show(context,
            message: 'Sync failed: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSyncingAll = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _clientTemplates;
    if (_statusFilter != null) {
      list = list
          .where((t) =>
              (t['status'] as String? ?? '').toUpperCase() == _statusFilter)
          .toList();
    }
    if (_categoryFilter != null) {
      list = list
          .where((t) =>
              (t['category'] as String? ?? '').toUpperCase() == _categoryFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((t) =>
              (t['template_name'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final clients = context.watch<AdminProvider>().clients;
    return Row(
      children: [
        _buildClientList(vc, clients),
        Container(width: 1, color: vc.border),
        Expanded(
          child: Column(
            children: [
              _buildHeader(vc),
              _buildFilters(vc),
              Expanded(
                child: _isLoadingTemplates
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: VividColors.cyan))
                    : _templateError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline,
                                    color: VividColors.statusUrgent, size: 40),
                                const SizedBox(height: 8),
                                Text(_templateError!,
                                    style: TextStyle(
                                        color: vc.textMuted, fontSize: 13)),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _selectedTemplateClient != null
                                      ? () => _loadClientTemplates(
                                          _selectedTemplateClient!)
                                      : null,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _selectedTemplateClient == null
                            ? Center(
                                child: Text(
                                  'Select a client to view templates',
                                  style: TextStyle(
                                      color: vc.textMuted, fontSize: 14),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(child: _buildGrid(vc)),
                                  if (_selected != null) _buildPreview(vc),
                                ],
                              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientList(VividColorScheme vc, List<Client> clients) {
    return Container(
      width: 200,
      color: vc.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'CLIENTS',
              style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: clients.length,
              itemBuilder: (context, i) {
                final client = clients[i];
                final isSelected =
                    _selectedTemplateClient?.id == client.id;
                return InkWell(
                  onTap: () => _loadClientTemplates(client),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? VividColors.cyan.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: isSelected
                              ? VividColors.cyan
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: TextStyle(
                            color: isSelected
                                ? VividColors.cyan
                                : vc.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        if (client.templatesTable != null)
                          Text(
                            client.templatesTable!,
                            style:
                                TextStyle(color: vc.textMuted, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VividColorScheme vc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // ── Left: title ──────────────────────────────────────────────
          Icon(Icons.description, color: VividColors.cyan, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _selectedTemplateClient != null
                  ? '${_selectedTemplateClient!.name} Templates'
                  : 'WhatsApp Templates',
              style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          if (!_isLoadingTemplates && _selectedTemplateClient != null)
            Text('${_clientTemplates.length} total',
                style: TextStyle(color: vc.textMuted, fontSize: 13)),

          const SizedBox(width: 12),

          // ── Right: search + action buttons ───────────────────────────
          // Search field shrinks when space is tight (no fixed width).
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: SizedBox(
                height: 36,
                child: TextField(
                  style: TextStyle(color: vc.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search templates…',
                    hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: vc.textMuted),
                    filled: true,
                    fillColor: vc.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: vc.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: vc.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: VividColors.cyan),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_selected != null)
            _isDeleting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.statusUrgent))
                : IconButton(
                    tooltip: 'Delete selected template',
                    icon: const Icon(Icons.delete_outline, color: VividColors.statusUrgent, size: 20),
                    onPressed: () => _deleteTemplate(_selected!),
                  ),
          _isSyncingAll
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan))
              : OutlinedButton.icon(
                  onPressed: _isLoadingTemplates ? null : _syncAllClients,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VividColors.statusSuccess,
                    side: const BorderSide(color: VividColors.statusSuccess),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
          const SizedBox(width: 6),
          if (_selectedTemplateClient != null)
            OutlinedButton.icon(
              onPressed: _isLoadingTemplates
                  ? null
                  : () => _refreshFromMeta(_selectedTemplateClient!),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: VividColors.cyan,
                side: const BorderSide(color: VividColors.cyan),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(VividColorScheme vc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          _filterChip(vc, 'All', _statusFilter == null, () => setState(() => _statusFilter = null)),
          const SizedBox(width: 6),
          _filterChip(vc, 'Approved', _statusFilter == 'APPROVED',
              () => setState(() => _statusFilter = _statusFilter == 'APPROVED' ? null : 'APPROVED'),
              color: VividColors.statusSuccess),
          const SizedBox(width: 6),
          _filterChip(vc, 'Pending', _statusFilter == 'PENDING',
              () => setState(() => _statusFilter = _statusFilter == 'PENDING' ? null : 'PENDING'),
              color: VividColors.statusWarning),
          const SizedBox(width: 6),
          _filterChip(vc, 'Rejected', _statusFilter == 'REJECTED',
              () => setState(() => _statusFilter = _statusFilter == 'REJECTED' ? null : 'REJECTED'),
              color: VividColors.statusUrgent),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: vc.border),
          const SizedBox(width: 16),
          _filterChip(vc, 'All Categories', _categoryFilter == null,
              () => setState(() => _categoryFilter = null)),
          const SizedBox(width: 6),
          _filterChip(vc, 'Marketing', _categoryFilter == 'MARKETING',
              () => setState(() => _categoryFilter = _categoryFilter == 'MARKETING' ? null : 'MARKETING')),
          const SizedBox(width: 6),
          _filterChip(vc, 'Utility', _categoryFilter == 'UTILITY',
              () => setState(() => _categoryFilter = _categoryFilter == 'UTILITY' ? null : 'UTILITY')),
          const SizedBox(width: 6),
          _filterChip(vc, 'Authentication', _categoryFilter == 'AUTHENTICATION',
              () => setState(() => _categoryFilter = _categoryFilter == 'AUTHENTICATION' ? null : 'AUTHENTICATION')),
        ],
      ),
    );
  }

  Widget _filterChip(VividColorScheme vc, String label, bool selected, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? VividColors.cyan).withValues(alpha: 0.15)
              : vc.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? (color ?? VividColors.cyan).withValues(alpha: 0.4)
                : vc.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (color ?? VividColors.cyan) : vc.textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(VividColorScheme vc) {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, color: vc.textMuted, size: 48),
            const SizedBox(height: 8),
            Text(
              _clientTemplates.isEmpty ? 'No templates found' : 'No templates match filters',
              style: TextStyle(color: vc.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1400
            ? 4
            : constraints.maxWidth > 1000
                ? 3
                : constraints.maxWidth > 640
                    ? 2
                    : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _buildCard(vc, items[i]),
        );
      },
    );
  }

  Widget _buildCard(VividColorScheme vc, Map<String, dynamic> t) {
    final name = t['template_name'] as String? ?? '';
    final status = t['status'] as String? ?? '';
    final language = t['language_code'] as String? ?? '';
    final category = t['category'] as String? ?? '';
    final body = t['body_text'] as String? ?? '';
    final headerType = (t['header_type'] as String? ?? '').toUpperCase();
    final offerImageUrl = t['offer_image_url'] as String?;
    final headerMediaUrl = t['header_media_url'] as String?;
    final imageUrl =
        (offerImageUrl != null && offerImageUrl.isNotEmpty)
            ? offerImageUrl
            : (headerMediaUrl != null && headerMediaUrl.isNotEmpty)
                ? headerMediaUrl
                : null;
    final isSelected =
        _selected?['meta_template_id'] == t['meta_template_id'];

    final (statusColor, statusLabel) = switch (status.toUpperCase()) {
      'APPROVED' => (VividColors.statusSuccess, 'Approved'),
      'PENDING' || 'PENDING_DELETION' => (VividColors.statusWarning, 'Pending'),
      'REJECTED' => (VividColors.statusUrgent, 'Rejected'),
      _ => (vc.textMuted, status),
    };

    return Material(
      color: vc.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selected = isSelected ? null : t),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: isSelected ? VividColors.cyan : vc.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image header
              if (imageUrl != null)
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: vc.surfaceAlt,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: vc.textMuted, size: 24),
                      ),
                    ),
                  ),
                ),
              // Content row with left accent bar
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? VividColors.cyan
                            : Colors.transparent,
                        borderRadius: imageUrl == null
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: vc.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                        color: statusColor
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(statusLabel,
                                      style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$language · $category',
                              style:
                                  TextStyle(color: vc.textMuted, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                body,
                                style: TextStyle(
                                    color: vc.textSecondary,
                                    fontSize: 12,
                                    height: 1.4),
                                maxLines: imageUrl != null ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (headerType.isNotEmpty &&
                                headerType != 'NONE' &&
                                imageUrl == null)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: vc.surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    headerType,
                                    style: TextStyle(
                                        color: vc.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(VividColorScheme vc) {
    final t = _selected!;
    final name = t['template_name'] as String? ?? '';
    final status = t['status'] as String? ?? '';
    final language = t['language_code'] as String? ?? '';
    final category = t['category'] as String? ?? '';
    final body = t['body_text'] as String? ?? '';
    final headerType = (t['header_type'] as String? ?? '').toUpperCase();
    final headerText = t['header_text'] as String?;
    final templateId =
        t['meta_template_id'] as String? ?? t['id'] as String? ?? '';
    final rawButtons = t['buttons'];
    final buttons = (rawButtons is List)
        ? rawButtons.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    final isApproved = status.toUpperCase() == 'APPROVED';
    final offerImageUrl = t['offer_image_url'] as String?;
    final headerMediaUrl = t['header_media_url'] as String?;
    final imageUrl =
        (offerImageUrl != null && offerImageUrl.isNotEmpty)
            ? offerImageUrl
            : (headerMediaUrl != null && headerMediaUrl.isNotEmpty)
                ? headerMediaUrl
                : null;

    final (statusColor, statusLabel) = switch (status.toUpperCase()) {
      'APPROVED' => (VividColors.statusSuccess, 'Approved'),
      'PENDING' || 'PENDING_DELETION' => (VividColors.statusWarning, 'Pending'),
      'REJECTED' => (VividColors.statusUrgent, 'Rejected'),
      _ => (vc.textMuted, status),
    };

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(left: BorderSide(color: vc.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: vc.textMuted),
                  onPressed: () => setState(() => _selected = null),
                ),
              ],
            ),
          ),
          Divider(color: vc.border, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offer image preview (above bubble)
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: vc.surfaceAlt,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: vc.textMuted, size: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // WhatsApp-style bubble
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? const Color(0xFF1A2E1A)
                          : vc.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isApproved
                            ? const Color(0xFF2D5A2D)
                            : vc.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (headerType == 'IMAGE')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 120,
                              width: double.infinity,
                              child: imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: vc.surfaceAlt,
                                        child: Center(
                                          child: Icon(Icons.image,
                                              color: vc.textMuted, size: 32),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: vc.surfaceAlt,
                                      child: Center(
                                        child: Icon(Icons.image,
                                            color: vc.textMuted, size: 32),
                                      ),
                                    ),
                            ),
                          ),
                        if (headerType == 'VIDEO')
                          Container(
                            height: 120,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: vc.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(Icons.play_circle_outline,
                                  color: vc.textMuted, size: 40),
                            ),
                          ),
                        if (headerType == 'DOCUMENT')
                          Container(
                            height: 50,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: vc.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.insert_drive_file,
                                    color: vc.textMuted, size: 20),
                                const SizedBox(width: 6),
                                Text('Document',
                                    style: TextStyle(
                                        color: vc.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        if (headerType == 'TEXT' && headerText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              headerText,
                              style: TextStyle(
                                  color: vc.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        _buildBodyWithVars(vc, body),
                      ],
                    ),
                  ),
                  if (buttons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...buttons.map((btn) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: vc.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: vc.border),
                            ),
                            child: Text(
                              btn['text'] as String? ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: VividColors.cyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        )),
                  ],
                  const SizedBox(height: 20),
                  _metaRow(vc, 'Status', statusLabel),
                  _metaRow(vc, 'Language', language),
                  _metaRow(vc, 'Category', category),
                  _metaRow(
                      vc, 'Header', headerType.isEmpty ? 'None' : headerType),
                  _metaRow(vc, 'ID', templateId),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isDeleting ? null : () => _deleteTemplate(t),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label:
                          Text(_isDeleting ? 'Deleting…' : 'Delete Template'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VividColors.statusUrgent,
                        side: const BorderSide(
                            color: VividColors.statusUrgent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyWithVars(VividColorScheme vc, String body) {
    final regex = RegExp(r'\{\{(\d+)\}\}');
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(body)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: body.substring(lastEnd, match.start),
          style: TextStyle(color: vc.textPrimary, fontSize: 13, height: 1.5),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
            color: VividColors.cyan, fontSize: 13, fontWeight: FontWeight.w700, height: 1.5),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < body.length) {
      spans.add(TextSpan(
        text: body.substring(lastEnd),
        style: TextStyle(color: vc.textPrimary, fontSize: 13, height: 1.5),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _metaRow(VividColorScheme vc, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: vc.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: vc.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REFRESH PREDICTIONS BUTTON
// ================================================================

class _RefreshPredictionsButton extends StatefulWidget {
  final Client client;
  const _RefreshPredictionsButton({required this.client});

  @override
  State<_RefreshPredictionsButton> createState() =>
      _RefreshPredictionsButtonState();
}

class _RefreshPredictionsButtonState extends State<_RefreshPredictionsButton> {
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final success = await SupabaseService.refreshPredictions(
      webhookUrl: widget.client.predictionsRefreshWebhookUrl!,
      predictionsTable: widget.client.customerPredictionsTable!,
      clientId: widget.client.id,
      clientName: widget.client.name,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '🔄 Predictions refreshing for ${widget.client.name} (~15s)'
            : 'Refresh failed — check webhook configuration'),
        backgroundColor:
            success ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
        duration: const Duration(seconds: 4),
      ));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh Predictions',
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF00BCD4)),
            )
          : InkWell(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF00BCD4).withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.refresh, size: 14, color: Color(0xFF00BCD4)),
                  const SizedBox(width: 4),
                  const Text('Refresh',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00BCD4),
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
    );
  }
}