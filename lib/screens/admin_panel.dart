import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/admin_analytics_provider.dart';
import '../providers/agent_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../widgets/client_analytics_view.dart';
import '../widgets/vivid_company_analytics_view.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      provider.fetchClients();
      provider.fetchAllUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VividColors.darkNavy,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ClientsTab(),
                _UsersTab(),
                _AnalyticsTab(),
                const VividCompanyAnalyticsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final agent = context.watch<AgentProvider>().agent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
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
          const SizedBox(width: 16),
          
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vivid Admin',
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Manage clients and users',
                style: TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  agent.name,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
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
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => context.read<AgentProvider>().logout(),
              icon: const Icon(Icons.logout, color: VividColors.textMuted),
              tooltip: 'Logout',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: VividColors.navy,
      child: TabBar(
        controller: _tabController,
        indicatorColor: VividColors.cyan,
        indicatorWeight: 3,
        labelColor: VividColors.cyan,
        unselectedLabelColor: VividColors.textMuted,
        tabs: const [
          Tab(
            icon: Icon(Icons.business),
            text: 'Clients',
          ),
          Tab(
            icon: Icon(Icons.people),
            text: 'Users',
          ),
          Tab(
            icon: Icon(Icons.insights),
            text: 'Client Analytics',
          ),
          Tab(
            icon: Icon(Icons.auto_graph),
            text: 'Vivid Analytics',
          ),
        ],
      ),
    );
  }
}

// ============================================
// CLIENTS TAB
// ============================================

class _ClientsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

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
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: VividColors.cyan))
                    : provider.clients.isEmpty
                        ? _buildEmptyState('No clients yet', 'Add your first client to get started')
                        : ListView.builder(
                            itemCount: provider.clients.length,
                            itemBuilder: (context, index) {
                              final client = provider.clients[index];
                              final isSelected = provider.selectedClient?.id == client.id;
                              return _ClientCard(
                                client: client,
                                isSelected: isSelected,
                                onTap: () => provider.selectClient(client),
                                onEdit: () => _showClientDialog(context, client: client),
                                onDelete: () => _confirmDelete(context, client),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        
        // Divider
        Container(width: 1, color: VividColors.tealBlue.withOpacity(0.2)),
        
        // Client details / users
        Expanded(
          child: provider.selectedClient == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 64, color: VividColors.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'Select a client',
                        style: TextStyle(color: VividColors.textPrimary, fontSize: 18),
                      ),
                      const Text(
                        'View and manage their users',
                        style: TextStyle(color: VividColors.textMuted),
                      ),
                    ],
                  ),
                )
              : _ClientDetail(client: provider.selectedClient!),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 64, color: VividColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: VividColors.textPrimary, fontSize: 16)),
          Text(subtitle, style: const TextStyle(color: VividColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  void _showClientDialog(BuildContext context, {Client? client}) {
    showDialog(
      context: context,
      builder: (context) => _ClientDialog(client: client),
    );
  }

  void _confirmDelete(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VividColors.navy,
        title: const Text('Delete Client', style: TextStyle(color: VividColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${client.name}"? This will also delete all their users.',
          style: const TextStyle(color: VividColors.textMuted),
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

class _ClientCard extends StatelessWidget {
  final Client client;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientCard({
    required this.client,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? VividColors.brightBlue.withOpacity(0.1) : VividColors.deepBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? VividColors.cyan : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    client.name,
                    style: const TextStyle(
                      color: VividColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: VividColors.textMuted, size: 20),
                  color: VividColors.navy,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: VividColors.textPrimary))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              client.slug,
              style: const TextStyle(color: VividColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            
            // Features
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: client.enabledFeatures.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: VividColors.brightBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  f,
                  style: const TextStyle(color: VividColors.cyan, fontSize: 11),
                ),
              )).toList(),
            ),
            
            // AI status
            if (client.enabledFeatures.contains('conversations'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      client.hasAiConversations ? Icons.smart_toy : Icons.smart_toy_outlined,
                      size: 14,
                      color: client.hasAiConversations ? VividColors.cyan : VividColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      client.hasAiConversations ? 'AI Enabled' : 'AI Disabled',
                      style: TextStyle(
                        fontSize: 11,
                        color: client.hasAiConversations ? VividColors.cyan : VividColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            if (client.businessPhone != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 12, color: VividColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    client.businessPhone!,
                    style: const TextStyle(color: VividColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
            
            if (client.bookingsTable != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_month, size: 12, color: VividColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    client.bookingsTable!,
                    style: const TextStyle(color: VividColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// CLIENT DETAIL (shows users)
// ============================================

class _ClientDetail extends StatelessWidget {
  final Client client;

  const _ClientDetail({required this.client});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final users = provider.selectedClientUsers;

    return Container(
      color: VividColors.darkNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VividColors.navy,
              border: Border(
                bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VividColors.brightBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, color: VividColors.cyan, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: const TextStyle(
                          color: VividColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slug: ${client.slug} ${client.businessPhone != null ? "• Phone: ${client.businessPhone}" : ""}',
                        style: const TextStyle(color: VividColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Users section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Users',
                  style: TextStyle(
                    color: VividColors.textPrimary,
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
                ElevatedButton.icon(
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
                        Icon(Icons.person_add, size: 48, color: VividColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('No users yet', style: TextStyle(color: VividColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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

  void _showUserDialog(BuildContext context, String clientId, {AppUser? user}) {
    showDialog(
      context: context,
      builder: (context) => _UserDialog(clientId: clientId, user: user),
    );
  }

  void _confirmToggleBlock(BuildContext context, AppUser user) {
    final isBlocking = !user.isBlocked;
    final newStatus = isBlocking ? 'blocked' : 'active';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VividColors.navy,
        title: Text(
          isBlocking ? 'Block User' : 'Unblock User',
          style: const TextStyle(color: VividColors.textPrimary),
        ),
        content: Text(
          isBlocking
              ? 'Block "${user.name}"? They will no longer be able to log in.'
              : 'Unblock "${user.name}"? They will be able to log in again.',
          style: const TextStyle(color: VividColors.textMuted),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(success
                            ? 'User "${user.name}" ${isBlocking ? "blocked" : "unblocked"} successfully'
                            : 'Failed to ${isBlocking ? "block" : "unblock"} user.'),
                      ],
                    ),
                    backgroundColor: success ? VividColors.statusSuccess : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
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
                        style: const TextStyle(
                          color: VividColors.textPrimary,
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
                  style: const TextStyle(color: VividColors.textMuted, fontSize: 12),
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
            color: VividColors.textMuted,
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

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
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
    final config = _getRoleConfig(role);
    
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

  _RoleConfig _getRoleConfig(String role) {
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
          color: VividColors.textMuted,
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
    final provider = context.watch<AdminProvider>();
    final users = provider.allUsers;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'All Users (${users.length})',
                style: const TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: VividColors.navy,
            border: Border(
              bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
            ),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Name', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('Email', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Role', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('Client', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
              SizedBox(width: 90, child: Text('Actions', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
            ],
          ),
        ),

        // Users list
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: VividColors.cyan))
              : users.isEmpty
                  ? const Center(child: Text('No users found', style: TextStyle(color: VividColors.textMuted)))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final clientName = user['clients']?['name'] ?? 'No Client';
                        final role = user['role'] ?? 'unknown';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.1)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  user['name'] ?? '',
                                  style: const TextStyle(color: VividColors.textPrimary),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  user['email'] ?? '',
                                  style: const TextStyle(color: VividColors.textMuted),
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
                              SizedBox(
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
                                            backgroundColor: VividColors.navy,
                                            title: Text(
                                              isBlocking ? 'Block User' : 'Unblock User',
                                              style: const TextStyle(color: VividColors.textPrimary),
                                            ),
                                            content: Text(
                                              isBlocking
                                                  ? 'Block "$userName"? They will no longer be able to log in.'
                                                  : 'Unblock "$userName"? They will be able to log in again.',
                                              style: const TextStyle(color: VividColors.textMuted),
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
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(
                                                      success ? Icons.check_circle : Icons.error,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(success
                                                        ? 'User "$userName" ${isBlocking ? "blocked" : "unblocked"}'
                                                        : 'Failed to ${isBlocking ? "block" : "unblock"} user.'),
                                                  ],
                                                ),
                                                backgroundColor: success ? VividColors.statusSuccess : Colors.red,
                                                behavior: SnackBarBehavior.floating,
                                              ),
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
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    String userId,
    String userName,
    AdminProvider provider,
  ) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showPassword = false;
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: VividColors.navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.lock_reset, color: VividColors.cyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset Password for $userName',
                    style: const TextStyle(color: VividColors.textPrimary, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    style: const TextStyle(color: VividColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: VividColors.textMuted, fontSize: 12),
                      hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.lock, color: VividColors.textMuted, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility_off : Icons.visibility,
                          color: VividColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setDialogState(() => showPassword = !showPassword),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: VividColors.cyan),
                      ),
                      filled: true,
                      fillColor: VividColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !showPassword,
                    style: const TextStyle(color: VividColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: VividColors.textMuted, fontSize: 12),
                      hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
                      prefixIcon: const Icon(Icons.lock, color: VividColors.textMuted, size: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: VividColors.cyan),
                      ),
                      filled: true,
                      fillColor: VividColors.deepBlue,
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
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Password must be at least 8 characters'),
                              backgroundColor: VividColors.statusUrgent,
                            ),
                          );
                          return;
                        }

                        if (password != confirm) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                              backgroundColor: VividColors.statusUrgent,
                            ),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    success ? Icons.check_circle : Icons.error,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(success
                                      ? 'Password reset for "$userName"'
                                      : 'Failed to reset password'),
                                ],
                              ),
                              backgroundColor: success ? VividColors.statusSuccess : Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
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
  late TextEditingController _bookingsTableController;
  
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _slugController = TextEditingController(text: widget.client?.slug ?? '');
    _bookingsTableController = TextEditingController(text: widget.client?.bookingsTable ?? '');

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
    _bookingsTableController.dispose();
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
    final isEdit = widget.client != null;

    return AlertDialog(
      backgroundColor: VividColors.navy,
      title: Text(
        isEdit ? 'Edit Client' : 'Add Client',
        style: const TextStyle(color: VividColors.textPrimary),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info Section
                _buildSectionHeader(Icons.business, 'Basic Information'),
                const SizedBox(height: 12),
                _buildTextField(_nameController, 'Client Name', 'Enter client name'),
                const SizedBox(height: 12),
                _buildTextField(_slugController, 'Slug', 'e.g., 3bs, karisma'),
                const SizedBox(height: 12),
                _buildTextField(_bookingsTableController, 'Bookings Table', 'e.g., bookings_demo_karisma', required: false),
                const SizedBox(height: 20),
                
                // Enabled Features
                const Text(
                  'Enabled Features',
                  style: TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['conversations', 'broadcasts', 'analytics', 'manager_chat', 'booking_reminders'].map((feature) {
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
                      labelStyle: TextStyle(
                        color: isSelected ? VividColors.cyan : VividColors.textMuted,
                      ),
                      backgroundColor: VividColors.deepBlue,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // AI Conversations toggle
                if (_selectedFeatures.contains('conversations'))
                  SwitchListTile(
                    title: const Text(
                      'AI-Powered Conversations',
                      style: TextStyle(color: VividColors.textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      _hasAiConversations
                          ? 'AI handles customer messages automatically'
                          : 'All messages go directly to managers',
                      style: const TextStyle(color: VividColors.textMuted, fontSize: 12),
                    ),
                    value: _hasAiConversations,
                    onChanged: (val) => setState(() => _hasAiConversations = val),
                    activeTrackColor: VividColors.cyan.withOpacity(0.3),
                    activeThumbColor: VividColors.cyan,
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.smart_toy,
                      color: _hasAiConversations ? VividColors.cyan : VividColors.textMuted,
                      size: 20,
                    ),
                  ),
                const SizedBox(height: 24),

                // Feature Configuration Sections
                // Only show config for enabled features
                if (_selectedFeatures.contains('conversations')) ...[
                  _buildFeatureConfigSection(
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
                
                if (_selectedFeatures.contains('booking_reminders')) ...[
                  _buildFeatureConfigSection(
                    icon: Icons.notifications_active,
                    title: 'Booking Reminders',
                    color: Colors.green,
                    phoneController: _remindersPhoneController,
                    webhookController: _remindersWebhookController,
                    phoneHint: 'Dedicated reminder WhatsApp number',
                    webhookHint: 'n8n webhook for manual reminders',
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (_selectedFeatures.contains('manager_chat')) ...[
                  _buildFeatureConfigSection(
                    icon: Icons.smart_toy,
                    title: 'Manager Chat (AI)',
                    color: Colors.purple,
                    phoneController: null, // No phone needed
                    webhookController: _managerChatWebhookController,
                    webhookHint: 'n8n webhook for AI assistant',
                  ),
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: VividColors.cyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: VividColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureConfigSection({
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
              phoneController,
              'Phone',
              phoneHint ?? 'WhatsApp number',
              required: false,
            ),
            const SizedBox(height: 10),
          ],
          _buildTextField(
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
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: VividColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: VividColors.textMuted),
        hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: VividColors.deepBlue,
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<AdminProvider>();
    bool success;

    if (widget.client != null) {
      success = await provider.updateClient(
        clientId: widget.client!.id,
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        enabledFeatures: _selectedFeatures,
        hasAiConversations: _hasAiConversations,
        bookingsTable: _bookingsTableController.text.trim().isEmpty ? null : _bookingsTableController.text.trim(),
        conversationsPhone: _conversationsPhoneController.text.trim().isEmpty ? null : _conversationsPhoneController.text.trim(),
        conversationsWebhookUrl: _conversationsWebhookController.text.trim().isEmpty ? null : _conversationsWebhookController.text.trim(),
        broadcastsPhone: _broadcastsPhoneController.text.trim().isEmpty ? null : _broadcastsPhoneController.text.trim(),
        broadcastsWebhookUrl: _broadcastsWebhookController.text.trim().isEmpty ? null : _broadcastsWebhookController.text.trim(),
        remindersPhone: _remindersPhoneController.text.trim().isEmpty ? null : _remindersPhoneController.text.trim(),
        remindersWebhookUrl: _remindersWebhookController.text.trim().isEmpty ? null : _remindersWebhookController.text.trim(),
        managerChatWebhookUrl: _managerChatWebhookController.text.trim().isEmpty ? null : _managerChatWebhookController.text.trim(),
      );
    } else {
      success = await provider.createClient(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        enabledFeatures: _selectedFeatures,
        hasAiConversations: _hasAiConversations,
        bookingsTable: _bookingsTableController.text.trim().isEmpty ? null : _bookingsTableController.text.trim(),
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
      case 'analytics':
        return 'Analytics';
      case 'manager_chat':
        return 'AI Assistant';
      case 'booking_reminders':
        return 'Booking Reminders';
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
    final isEdit = widget.user != null;

    return AlertDialog(
      backgroundColor: VividColors.navy,
      title: Text(
        isEdit ? 'Edit User' : 'Add User',
        style: const TextStyle(color: VividColors.textPrimary),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(_nameController, 'Name', 'User\'s name'),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', 'login@email.com'),
                const SizedBox(height: 16),
                _buildPasswordField(
                  _passwordController,
                  isEdit ? 'New Password (optional)' : 'Password',
                  'Enter password',
                  required: !isEdit,
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    _confirmPasswordController,
                    'Confirm Password',
                    'Re-enter password',
                    required: true,
                  ),
                ],
                const SizedBox(height: 20),
                
                // Role selection
                const Text(
                  'Role',
                  style: TextStyle(
                    color: VividColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: VividColors.deepBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
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
                                ? Border(bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)))
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
                                    color: isSelected ? role['color'] as Color : VividColors.textMuted,
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
                                color: isSelected ? role['color'] as Color : VividColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role['label'] as String,
                                      style: TextStyle(
                                        color: isSelected ? VividColors.textPrimary : VividColors.textMuted,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      role['description'] as String,
                                      style: TextStyle(
                                        color: VividColors.textMuted.withOpacity(0.7),
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
                          : VividColors.deepBlue,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showCustomPermissions 
                            ? Colors.purple.withOpacity(0.3) 
                            : VividColors.tealBlue.withOpacity(0.3),
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
                              : VividColors.textMuted,
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
                                      ? VividColors.textPrimary 
                                      : VividColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _showCustomPermissions
                                    ? 'Override role defaults'
                                    : 'Use role defaults',
                                style: TextStyle(
                                  color: VividColors.textMuted.withOpacity(0.7),
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
                          color: VividColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),

                // Custom Permissions List
                if (_showCustomPermissions) ...[
                  const SizedBox(height: 12),
                  _buildPermissionsSection(),
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

  Widget _buildPermissionsSection() {
    // Group permissions by category
    final Map<String, List<Permission>> grouped = {};
    for (final perm in Permission.values) {
      final cat = perm.category;
      grouped.putIfAbsent(cat, () => []).add(perm);
    }

    return Container(
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        children: grouped.entries.map((entry) {
          return _buildPermissionCategory(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildPermissionCategory(String category, List<Permission> permissions) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.1)),
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
                color: VividColors.textMuted.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...permissions.map((perm) => _buildPermissionTile(perm)),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(Permission permission) {
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
      badgeColor = VividColors.textMuted;
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
                          : VividColors.textMuted.withOpacity(0.3),
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
                      ? VividColors.textMuted.withOpacity(0.5)
                      : isEnabled 
                          ? VividColors.textPrimary 
                          : VividColors.textMuted,
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
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: VividColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: VividColors.textMuted),
        hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: VividColors.deepBlue,
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !_showPassword,
      style: const TextStyle(color: VividColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: VividColors.textMuted),
        hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.lock, color: VividColors.textMuted, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: VividColors.textMuted,
            size: 18,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: VividColors.deepBlue,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 8 characters'),
            backgroundColor: VividColors.statusUrgent,
          ),
        );
        return;
      }

      if (password != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: VividColors.statusUrgent,
          ),
        );
        return;
      }
    }

    // Password length check for edit mode (only if provided)
    if (isEdit && password.isNotEmpty && password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters'),
          backgroundColor: VividColors.statusUrgent,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(widget.user != null 
                  ? 'User updated successfully' 
                  : 'User created successfully'),
            ],
          ),
          backgroundColor: VividColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.clients.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: VividColors.cyan),
          );
        }

        return Row(
          children: [
            // Client list sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: VividColors.navy,
                border: Border(
                  right: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Client',
                          style: TextStyle(
                            color: VividColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View internal metrics',
                          style: TextStyle(
                            color: VividColors.textMuted.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: VividColors.tealBlue, height: 1),
                  
                  // Client list
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
            
            // Analytics content
            Expanded(
              child: _selectedClient == null
                  ? _buildEmptyState()
                  : ClientAnalyticsView(client: _selectedClient!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insights_outlined,
            size: 64,
            color: VividColors.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a client to view analytics',
            style: TextStyle(
              color: VividColors.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from the list on the left',
            style: TextStyle(
              color: VividColors.textMuted.withOpacity(0.7),
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
                    : VividColors.deepBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                client.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: isSelected ? VividColors.cyan : VividColors.textMuted,
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
                      color: isSelected ? VividColors.textPrimary : VividColors.textMuted,
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
                        color: VividColors.textMuted.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        client.hasFeature('conversations') 
                            ? 'Conversations' 
                            : 'Broadcasts',
                        style: TextStyle(
                          color: VividColors.textMuted.withOpacity(0.7),
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
              color: isSelected ? VividColors.cyan : VividColors.textMuted.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}