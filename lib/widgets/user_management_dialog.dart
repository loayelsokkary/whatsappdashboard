import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_management_provider.dart';
import '../../models/models.dart';
import '../../theme/vivid_theme.dart';

/// User Management Dialog - Opens from avatar menu for client admins
class UserManagementDialog extends StatefulWidget {
  const UserManagementDialog({super.key});

  @override
  State<UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<UserManagementDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementProvider>().fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: ClientConfig.isClientAdmin ? 1050 : 900,
        height: 650,
        decoration: BoxDecoration(
          color: VividColors.darkNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: VividColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage team members for ${ClientConfig.businessName}',
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Add User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VividColors.brightBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: VividColors.textMuted),
            tooltip: 'Close',
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VividColors.brightBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.people_outline,
              size: 48,
              color: VividColors.brightBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No team members yet',
            style: TextStyle(
              color: VividColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add users to give them access to the dashboard',
            style: TextStyle(color: VividColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add First User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VividColors.brightBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(UserManagementProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              _buildStatChip('Total', provider.users.length, VividColors.brightBlue),
              const SizedBox(width: 12),
              _buildStatChip('Admins', provider.users.where((u) => u.role == UserRole.admin).length, VividColors.cyan),
              const SizedBox(width: 12),
              _buildStatChip('Managers', provider.users.where((u) => u.role == UserRole.manager).length, VividColors.tealBlue),
              const SizedBox(width: 12),
              _buildStatChip('Agents', provider.users.where((u) => u.role == UserRole.agent).length, Colors.green),
            ],
          ),
          const SizedBox(height: 20),

          // Users table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: VividColors.navy,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: VividColors.deepBlue,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(flex: 2, child: Text('User', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                        const Expanded(flex: 2, child: Text('Email', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                        if (ClientConfig.isClientAdmin)
                          const Expanded(flex: 2, child: Text('Password', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                        const Expanded(flex: 1, child: Text('Role', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 100, child: Text('Permissions', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                        const SizedBox(width: 80, child: Text('Actions', style: TextStyle(color: VividColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12))),
                      ],
                    ),
                  ),

                  // Users list
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
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
                          onToggleBlock: isCurrentUser ? null : () => _confirmToggleBlock(context, user, provider),
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

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _UserFormDialog(),
    );
  }

  void _showEditUserDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => _UserFormDialog(user: user),
    );
  }

  void _confirmToggleBlock(BuildContext context, AppUser user, UserManagementProvider provider) {
    final isBlocking = !user.isBlocked;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VividColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.toggleUserStatus(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'User ${isBlocking ? "blocked" : "unblocked"}'
                        : 'Failed to ${isBlocking ? "block" : "unblock"} user'),
                    backgroundColor: success ? VividColors.statusSuccess : Colors.red,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: widget.isCurrentUser ? VividColors.brightBlue.withOpacity(0.05) : null,
      child: Row(
        children: [
          // User info
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getRoleColor(widget.user.role).withOpacity(0.2),
                  child: Text(
                    _getInitials(widget.user.name),
                    style: TextStyle(
                      color: _getRoleColor(widget.user.role),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.user.name,
                          style: const TextStyle(
                            color: VividColors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: VividColors.cyan.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(color: VividColors.cyan, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
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
              style: const TextStyle(color: VividColors.textMuted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Password (only for client admins)
          if (ClientConfig.isClientAdmin)
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isPasswordRevealed
                          ? (widget.user.password ?? 'N/A')
                          : '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                      style: TextStyle(
                        color: _isPasswordRevealed
                            ? VividColors.textPrimary
                            : VividColors.textMuted,
                        fontSize: 12,
                        fontFamily: _isPasswordRevealed ? null : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.user.password != null)
                    IconButton(
                      onPressed: () => setState(() => _isPasswordRevealed = !_isPasswordRevealed),
                      icon: Icon(
                        _isPasswordRevealed ? Icons.visibility_off : Icons.visibility,
                        size: 14,
                      ),
                      color: VividColors.textMuted,
                      tooltip: _isPasswordRevealed ? 'Hide password' : 'Show password',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
            ),

          // Role
          Expanded(
            flex: 1,
            child: _RoleBadge(role: widget.user.role),
          ),

          // Permissions indicator
          SizedBox(
            width: 100,
            child: _PermissionIndicator(user: widget.user),
          ),

          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  color: VividColors.textMuted,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
                if (ClientConfig.isClientAdmin)
                  IconButton(
                    onPressed: widget.onToggleBlock,
                    icon: Icon(widget.user.isBlocked ? Icons.lock_open : Icons.block, size: 16),
                    color: widget.onToggleBlock != null
                        ? (widget.user.isBlocked ? VividColors.statusSuccess : Colors.red.withOpacity(0.7))
                        : VividColors.textMuted.withOpacity(0.3),
                    tooltip: widget.isCurrentUser
                        ? 'Cannot block yourself'
                        : (widget.user.isBlocked ? 'Unblock' : 'Block'),
                    visualDensity: VisualDensity.compact,
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
// PERMISSION INDICATOR
// ============================================

class _PermissionIndicator extends StatelessWidget {
  final AppUser user;

  const _PermissionIndicator({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasCustom = user.customPermissions != null && user.customPermissions!.isNotEmpty;
    final hasRevoked = user.revokedPermissions != null && user.revokedPermissions!.isNotEmpty;

    if (!hasCustom && !hasRevoked) {
      return Text(
        'Default',
        style: TextStyle(
          color: VividColors.textMuted.withOpacity(0.6),
          fontSize: 11,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasCustom)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${user.customPermissions!.length}',
              style: const TextStyle(
                color: Colors.purple,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (hasRevoked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${user.revokedPermissions!.length}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
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
}

// ============================================
// USER FORM DIALOG (with Custom Permissions)
// ============================================

class _UserFormDialog extends StatefulWidget {
  final AppUser? user;

  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late UserRole _selectedRole;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showCustomPermissions = false;
  
  // Permission overrides
  Set<Permission> _customPermissions = {};
  Set<Permission> _revokedPermissions = {};

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedRole = widget.user?.role ?? UserRole.agent;
    
    // Load existing custom permissions
    if (widget.user != null) {
      _customPermissions = widget.user!.customPermissions ?? {};
      _revokedPermissions = widget.user!.revokedPermissions ?? {};
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

  /// Get default permissions for a role
  Set<Permission> _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Permission.values.toSet(); // All permissions
      case UserRole.manager:
        return {
          Permission.viewDashboard,
          Permission.viewAnalytics,
          Permission.viewConversations,
          Permission.sendMessages,
          Permission.viewBroadcasts,
          Permission.sendBroadcasts,
          Permission.viewManagerChat,
          Permission.useManagerChat,
          Permission.viewBookingReminders,
          Permission.viewActivityLogs,
        };
      case UserRole.agent:
        return {
          Permission.viewDashboard,
          Permission.viewConversations,
          Permission.sendMessages,
        };
      case UserRole.viewer:
        return {
          Permission.viewDashboard,
          Permission.viewAnalytics,
          Permission.viewConversations,
          Permission.viewBroadcasts,
          Permission.viewBookingReminders,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VividColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit : Icons.person_add,
                      color: VividColors.cyan,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Edit User' : 'Add New User',
                      style: const TextStyle(
                        color: VividColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      color: VividColors.textMuted,
                    ),
                  ],
                ),
              ),
              
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _buildField(_nameController, 'Full Name', 'Enter name', Icons.person),
                      const SizedBox(height: 12),

                      // Email
                      _buildField(_emailController, 'Email', 'user@company.com', Icons.email),
                      const SizedBox(height: 12),

                      // Password (only visible to admins)
                      if (ClientConfig.isAdmin) ...[
                        _buildPasswordField(
                          _passwordController,
                          isEdit ? 'New Password (optional)' : 'Password',
                          'Enter password',
                          required: !isEdit,
                        ),
                        // Confirm password (only for new users)
                        if (!isEdit) ...[
                          const SizedBox(height: 12),
                          _buildPasswordField(
                            _confirmPasswordController,
                            'Confirm Password',
                            'Re-enter password',
                            required: true,
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),

                      // Role
                      const Text('Role', style: TextStyle(color: VividColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 8),
                      _buildRoleSelector(),
                      const SizedBox(height: 8),
                      Text(
                        _selectedRole.description,
                        style: TextStyle(color: VividColors.textMuted.withOpacity(0.7), fontSize: 11),
                      ),
                      const SizedBox(height: 16),

                      // Custom Permissions Section
                      _buildCustomPermissionsSection(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VividColors.brightBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save' : 'Add User'),
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

  Widget _buildField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool obscure = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: VividColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: VividColors.textMuted, size: 18),
        labelStyle: const TextStyle(color: VividColors.textMuted, fontSize: 12),
        hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      style: const TextStyle(color: VividColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock, color: VividColors.textMuted, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: VividColors.textMuted,
            size: 18,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        labelStyle: const TextStyle(color: VividColors.textMuted, fontSize: 12),
        hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildRoleSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: UserRole.values.map((role) {
        final isSelected = _selectedRole == role;
        final color = _getRoleColor(role);

        return InkWell(
          onTap: () => setState(() {
            _selectedRole = role;
            // Clear custom permissions when role changes (user can re-add)
          }),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : VividColors.deepBlue,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? color : VividColors.tealBlue.withOpacity(0.3),
              ),
            ),
            child: Text(
              role.displayName,
              style: TextStyle(
                color: isSelected ? color : VividColors.textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomPermissionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Toggle header
          InkWell(
            onTap: () => setState(() => _showCustomPermissions = !_showCustomPermissions),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _showCustomPermissions ? Icons.expand_less : Icons.expand_more,
                    color: VividColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Custom Permissions',
                    style: TextStyle(
                      color: VividColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_customPermissions.isNotEmpty || _revokedPermissions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_customPermissions.length + _revokedPermissions.length} override${_customPermissions.length + _revokedPermissions.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _showCustomPermissions ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: VividColors.textMuted.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Permissions list
          if (_showCustomPermissions) ...[
            Divider(height: 1, color: VividColors.tealBlue.withOpacity(0.2)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Override default ${_selectedRole.displayName.toLowerCase()} permissions:',
                    style: TextStyle(
                      color: VividColors.textMuted.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionsList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionsList() {
    // Group permissions by category
    final categories = <String, List<Permission>>{};
    for (final perm in Permission.values) {
      final category = perm.category;
      categories.putIfAbsent(category, () => []).add(perm);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VividColors.tealBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    color: VividColors.tealBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Permissions in this category
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.value.map((perm) => _buildPermissionChip(perm)).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPermissionChip(Permission perm) {
    final roleDefaults = _getDefaultPermissions(_selectedRole);
    final isDefault = roleDefaults.contains(perm);
    final isCustom = _customPermissions.contains(perm);
    final isRevoked = _revokedPermissions.contains(perm);
    
    // Determine current state
    final bool isEnabled = (isDefault && !isRevoked) || isCustom;
    
    // Determine badge type
    String? badge;
    Color? badgeColor;
    if (isRevoked) {
      badge = 'REVOKED';
      badgeColor = Colors.red;
    } else if (isCustom) {
      badge = 'CUSTOM';
      badgeColor = Colors.purple;
    } else if (isDefault) {
      badge = 'DEFAULT';
      badgeColor = VividColors.textMuted;
    }

    return InkWell(
      onTap: () => _togglePermission(perm, isDefault),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isEnabled 
              ? (isCustom ? Colors.purple.withOpacity(0.1) : VividColors.brightBlue.withOpacity(0.1))
              : (isRevoked ? Colors.red.withOpacity(0.05) : VividColors.navy),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isEnabled
                ? (isCustom ? Colors.purple.withOpacity(0.3) : VividColors.brightBlue.withOpacity(0.3))
                : (isRevoked ? Colors.red.withOpacity(0.3) : VividColors.tealBlue.withOpacity(0.2)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 14,
              color: isEnabled
                  ? (isCustom ? Colors.purple : VividColors.brightBlue)
                  : (isRevoked ? Colors.red.withOpacity(0.5) : VividColors.textMuted.withOpacity(0.5)),
            ),
            const SizedBox(width: 6),
            Text(
              perm.displayName,
              style: TextStyle(
                color: isEnabled ? VividColors.textPrimary : VividColors.textMuted.withOpacity(0.6),
                fontSize: 11,
                decoration: isRevoked ? TextDecoration.lineThrough : null,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor!.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _togglePermission(Permission perm, bool isDefault) {
    setState(() {
      final isCustom = _customPermissions.contains(perm);
      final isRevoked = _revokedPermissions.contains(perm);

      if (isDefault) {
        // Default permission: toggle between default and revoked
        if (isRevoked) {
          _revokedPermissions.remove(perm); // Back to default
        } else {
          _revokedPermissions.add(perm); // Revoke it
        }
      } else {
        // Non-default permission: toggle between off and custom
        if (isCustom) {
          _customPermissions.remove(perm); // Turn off
        } else {
          _customPermissions.add(perm); // Grant custom
          _revokedPermissions.remove(perm); // Make sure not revoked
        }
      }
    });
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;

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

    // Password length check for edit mode (only if password is provided)
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

    final provider = context.read<UserManagementProvider>();
    bool success;

    // Convert to string lists for storage
    final customPermsList = _customPermissions.isNotEmpty 
        ? _customPermissions.map((p) => p.value).toList() 
        : <String>[];
    final revokedPermsList = _revokedPermissions.isNotEmpty 
        ? _revokedPermissions.map((p) => p.value).toList() 
        : <String>[];

    if (isEdit) {
      success = await provider.updateUser(
        userId: widget.user!.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        customPermissions: customPermsList,
        revokedPermissions: revokedPermsList,
      );
    } else {
      success = await provider.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
        password: _passwordController.text,
        customPermissions: customPermsList,
        revokedPermissions: revokedPermsList,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'User updated successfully' : 'User created successfully'),
          backgroundColor: VividColors.statusSuccess,
        ),
      );
    }
  }
}