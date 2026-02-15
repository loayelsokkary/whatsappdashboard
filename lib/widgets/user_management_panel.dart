import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_management_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

/// User Management Panel - For client admins to manage their team
class UserManagementPanel extends StatefulWidget {
  const UserManagementPanel({super.key});

  @override
  State<UserManagementPanel> createState() => _UserManagementPanelState();
}

class _UserManagementPanelState extends State<UserManagementPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementProvider>().fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VividColors.darkNavy,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
              gradient: VividColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage team members for ${ClientConfig.businessName}',
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VividColors.brightBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<UserManagementProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: VividColors.cyan),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  provider.error!,
                  style: const TextStyle(color: VividColors.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.fetchUsers(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.users.isEmpty) {
          return _buildEmptyState();
        }

        return _buildUsersList(provider);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: VividColors.brightBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: VividColors.brightBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No team members yet',
            style: TextStyle(
              color: VividColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add users to give them access to the dashboard',
            style: TextStyle(color: VividColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add First User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VividColors.brightBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(UserManagementProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              _buildStatCard(
                'Total Users',
                provider.users.length.toString(),
                Icons.people,
                VividColors.brightBlue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Admins',
                provider.users.where((u) => u.role == UserRole.admin).length.toString(),
                Icons.admin_panel_settings,
                VividColors.cyan,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Managers',
                provider.users.where((u) => u.role == UserRole.manager).length.toString(),
                Icons.manage_accounts,
                VividColors.tealBlue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Agents',
                provider.users.where((u) => u.role == UserRole.agent).length.toString(),
                Icons.support_agent,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Users table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: VividColors.navy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: VividColors.deepBlue,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(flex: 2, child: Text('User', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
                        const Expanded(flex: 2, child: Text('Email', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
                        if (ClientConfig.isClientAdmin)
                          const Expanded(flex: 2, child: Text('Password', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
                        const Expanded(flex: 1, child: Text('Role', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
                        const Expanded(flex: 1, child: Text('Status', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 100, child: Text('Actions', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),

                  // Users list
                  Expanded(
                    child: ListView.separated(
                      itemCount: provider.users.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: VividColors.tealBlue.withOpacity(0.1),
                      ),
                      itemBuilder: (context, index) {
                        final user = provider.users[index];
                        final isCurrentUser = user.id == ClientConfig.currentUser?.id;

                        return _UserRow(
                          user: user,
                          isCurrentUser: isCurrentUser,
                          onEdit: () => _showEditUserDialog(context, user),
                          onToggleBlock: isCurrentUser ? null : () => _confirmToggleBlock(context, user),
                        );
                      },
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _UserDialog(),
    );
  }

  void _showEditUserDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => _UserDialog(user: user),
    );
  }

  void _confirmToggleBlock(BuildContext context, AppUser user) {
    final isBlocking = !user.isBlocked;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VividColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isBlocking ? 'Block User' : 'Unblock User',
          style: const TextStyle(color: VividColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBlocking
                  ? 'Block "${user.name}"? They will no longer be able to log in.'
                  : 'Unblock "${user.name}"? They will be able to log in again.',
              style: const TextStyle(color: VividColors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isBlocking ? Colors.red : VividColors.statusSuccess).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isBlocking ? Colors.red : VividColors.statusSuccess).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(isBlocking ? Icons.block : Icons.check_circle, color: isBlocking ? Colors.red : VividColors.statusSuccess, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBlocking
                          ? 'This user will be blocked from accessing the dashboard.'
                          : 'This user will regain access to the dashboard.',
                      style: TextStyle(color: isBlocking ? Colors.red : VividColors.statusSuccess, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<UserManagementProvider>();
              final success = await provider.toggleUserStatus(user.id);

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
                            : 'Failed to ${isBlocking ? "block" : "unblock"} user'),
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
              foregroundColor: Colors.white,
            ),
            child: Text(isBlocking ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// USER ROW
// ============================================

class _UserRow extends StatefulWidget {
  final AppUser user;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback? onToggleBlock;

  const _UserRow({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    this.onToggleBlock,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _isPasswordRevealed = false;

  @override
  Widget build(BuildContext context) {
    final showPasswordColumn = ClientConfig.isClientAdmin;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: widget.isCurrentUser ? VividColors.brightBlue.withOpacity(0.05) : null,
      child: Row(
        children: [
          // User info
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getRoleColor(widget.user.role).withOpacity(0.2),
                  child: Text(
                    _getInitials(widget.user.name),
                    style: TextStyle(
                      color: _getRoleColor(widget.user.role),
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
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              color: VividColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: VividColors.cyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: VividColors.cyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Email
          Expanded(
            flex: 2,
            child: Text(
              widget.user.email,
              style: const TextStyle(color: VividColors.textMuted, fontSize: 13),
            ),
          ),

          // Password (client admin only)
          if (showPasswordColumn)
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isPasswordRevealed
                          ? (widget.user.password ?? '—')
                          : '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                      style: TextStyle(
                        color: _isPasswordRevealed
                            ? VividColors.textPrimary
                            : VividColors.textMuted,
                        fontSize: 13,
                        fontFamily: _isPasswordRevealed ? null : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.user.password != null)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: () => setState(() => _isPasswordRevealed = !_isPasswordRevealed),
                        icon: Icon(
                          _isPasswordRevealed ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                        ),
                        color: _isPasswordRevealed ? VividColors.cyan : VividColors.textMuted,
                        tooltip: _isPasswordRevealed ? 'Hide password' : 'Show password',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),

          // Role
          Expanded(
            flex: 1,
            child: _RoleBadge(role: widget.user.role),
          ),

          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (widget.user.isBlocked ? Colors.red : VividColors.statusSuccess).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.user.isBlocked ? Colors.red : VividColors.statusSuccess,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.user.isBlocked ? 'Blocked' : 'Active',
                    style: TextStyle(
                      color: widget.user.isBlocked ? Colors.red : VividColors.statusSuccess,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  color: VividColors.textMuted,
                  tooltip: 'Edit',
                ),
                if (ClientConfig.isClientAdmin)
                  IconButton(
                    onPressed: widget.onToggleBlock,
                    icon: Icon(widget.user.isBlocked ? Icons.lock_open : Icons.block, size: 18),
                    color: widget.onToggleBlock != null
                        ? (widget.user.isBlocked ? VividColors.statusSuccess : Colors.red.withOpacity(0.7))
                        : VividColors.textMuted.withOpacity(0.3),
                    tooltip: widget.isCurrentUser
                        ? 'Cannot block yourself'
                        : (widget.user.isBlocked ? 'Unblock' : 'Block'),
                  ),
              ],
            ),
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

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return VividColors.cyan;
      case UserRole.manager:
        return VividColors.brightBlue;
      case UserRole.agent:
        return Colors.green;
      case UserRole.viewer:
        return VividColors.textMuted;
    }
  }
}

// ============================================
// ROLE BADGE
// ============================================

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            role.displayName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (role) {
      case UserRole.admin:
        return VividColors.cyan;
      case UserRole.manager:
        return VividColors.brightBlue;
      case UserRole.agent:
        return Colors.green;
      case UserRole.viewer:
        return VividColors.textMuted;
    }
  }

  IconData _getIcon() {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.agent:
        return Icons.support_agent;
      case UserRole.viewer:
        return Icons.visibility;
    }
  }
}

// ============================================
// USER DIALOG
// ============================================

class _UserDialog extends StatefulWidget {
  final AppUser? user;

  const _UserDialog({this.user});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late UserRole _selectedRole;
  bool _isLoading = false;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _selectedRole = widget.user?.role ?? UserRole.agent;
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
    return Dialog(
      backgroundColor: VividColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VividColors.brightBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.person_add,
                      color: VividColors.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit User' : 'Add New User',
                    style: const TextStyle(
                      color: VividColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name field
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter user\'s name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Email field
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'user@company.com',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password field
              _buildTextField(
                controller: _passwordController,
                label: isEdit ? 'New Password (optional)' : 'Password',
                hint: 'Enter password',
                icon: Icons.lock,
                obscure: true,
                required: !isEdit,
              ),
              const SizedBox(height: 20),

              // Role selector
              const Text(
                'Role',
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildRoleSelector(),
              const SizedBox(height: 12),

              // Role description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VividColors.deepBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: VividColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedRole.description,
                        style: const TextStyle(
                          color: VividColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VividColors.brightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Add User'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: VividColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: VividColors.textMuted, size: 20),
        labelStyle: const TextStyle(color: VividColors.textMuted),
        hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: VividColors.deepBlue,
      ),
      validator: required
          ? (v) => v?.isEmpty == true ? '$label is required' : null
          : null,
    );
  }

  Widget _buildRoleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: UserRole.values.map((role) {
        final isSelected = _selectedRole == role;
        final color = _getRoleColor(role);

        return InkWell(
          onTap: () => setState(() => _selectedRole = role),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : VividColors.deepBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : VividColors.tealBlue.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRoleIcon(role),
                  size: 18,
                  color: isSelected ? color : VividColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  role.displayName,
                  style: TextStyle(
                    color: isSelected ? color : VividColors.textMuted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return VividColors.cyan;
      case UserRole.manager:
        return VividColors.brightBlue;
      case UserRole.agent:
        return Colors.green;
      case UserRole.viewer:
        return VividColors.textMuted;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.agent:
        return Icons.support_agent;
      case UserRole.viewer:
        return Icons.visibility;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<UserManagementProvider>();
    bool success;

    if (isEdit) {
      success = await provider.updateUser(
        userId: widget.user!.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );
    } else {
      success = await provider.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
        password: _passwordController.text,
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
              Text(isEdit ? 'User updated successfully' : 'User created successfully'),
            ],
          ),
          backgroundColor: VividColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(provider.error ?? 'Operation failed'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}