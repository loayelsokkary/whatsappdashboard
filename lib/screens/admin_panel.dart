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
                        onDelete: () => _confirmDeleteUser(context, user),
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

  void _confirmDeleteUser(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VividColors.navy,
        title: const Text('Delete User', style: TextStyle(color: VividColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${user.name}"?',
          style: const TextStyle(color: VividColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AdminProvider>().deleteUser(user.id);
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
// USER TILE
// ============================================

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
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
                Text(
                  user.name,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(color: VividColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            color: VividColors.textMuted,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 18),
            color: Colors.red.withOpacity(0.7),
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
              Expanded(flex: 2, child: Text('Client', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
              SizedBox(width: 50, child: Text('Actions', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
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
                        final clientName = user['clients']?['name'] ?? 'Unknown';
                        
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
                                width: 50,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        provider.deleteUser(user['id']);
                                      },
                                      icon: const Icon(Icons.delete, size: 18),
                                      color: Colors.red.withOpacity(0.7),
                                      tooltip: 'Delete',
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
  late TextEditingController _nameController;
  late TextEditingController _slugController;
  late TextEditingController _webhookController;
  late TextEditingController _phoneController;
  List<String> _selectedFeatures = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _slugController = TextEditingController(text: widget.client?.slug ?? '');
    _webhookController = TextEditingController(text: widget.client?.webhookUrl ?? '');
    _phoneController = TextEditingController(text: widget.client?.businessPhone ?? '');
    _selectedFeatures = List.from(widget.client?.enabledFeatures ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _webhookController.dispose();
    _phoneController.dispose();
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
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(_nameController, 'Client Name', 'Enter client name'),
                const SizedBox(height: 16),
                _buildTextField(_slugController, 'Slug', 'e.g., 3bs, karisma'),
                const SizedBox(height: 16),
                _buildTextField(_webhookController, 'Webhook URL', 'n8n webhook URL', required: false),
                const SizedBox(height: 16),
                _buildTextField(_phoneController, 'Business Phone', 'WhatsApp number', required: false),
                const SizedBox(height: 20),
                
                const Text(
                  'Enabled Features',
                  style: TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['conversations', 'broadcasts', 'analytics', 'manager_chat'].map((feature) {
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
        webhookUrl: _webhookController.text.trim().isEmpty ? null : _webhookController.text.trim(),
        enabledFeatures: _selectedFeatures,
        businessPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );
    } else {
      success = await provider.createClient(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        webhookUrl: _webhookController.text.trim().isEmpty ? null : _webhookController.text.trim(),
        enabledFeatures: _selectedFeatures,
        businessPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
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
      default:
        return feature;
    }
  }
}

// ============================================
// USER DIALOG
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_nameController, 'Name', 'User\'s name'),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email', 'login@email.com'),
              const SizedBox(height: 16),
              _buildTextField(
                _passwordController,
                isEdit ? 'New Password (optional)' : 'Password',
                'Enter password',
                obscure: true,
                required: !isEdit,
              ),
            ],
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<AdminProvider>();
    bool success;

    if (widget.user != null) {
      success = await provider.updateUser(
        userId: widget.user!.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );
    } else {
      success = await provider.createUser(
        clientId: widget.clientId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
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