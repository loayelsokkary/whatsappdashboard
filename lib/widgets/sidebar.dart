import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/agent_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_management_provider.dart';
import '../providers/theme_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/initials_helper.dart';
import 'user_management_dialog.dart';

/// Navigation destinations
enum NavDestination {
  conversations,
  broadcasts,
  templates,
  analytics,
  managerChat,
  bookingReminders,
  activityLogs,
}

class Sidebar extends StatelessWidget {
  final NavDestination currentDestination;
  final Function(NavDestination) onDestinationChanged;

  const Sidebar({
    super.key,
    required this.currentDestination,
    required this.onDestinationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final conversationsProvider = context.watch<ConversationsProvider>();
    final agentProvider = context.watch<AgentProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final agent = agentProvider.agent;

    final expanded = themeProvider.sidebarExpanded;
    final sidebarWidth = expanded ? 200.0 : 64.0;
    final unreadNotifications = notificationProvider.unreadCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: VividColors.darkGradient,
        border: Border(
          right: BorderSide(
            color: VividColors.tealBlue.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Brand header ─────────────────────────────────────
          if (expanded) ...[
            // Expanded: full wordmark + collapse toggle in one row
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0x1AFFFFFF), // rgba white 10%
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Wordmark fills available width at 40px tall
                  Expanded(
                    child: Image.asset(
                      'assets/images/vivid_logo_full.png',
                      width: 164,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Collapse button
                  InkWell(
                    onTap: () => themeProvider.toggleSidebar(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.chevron_left,
                        color: VividColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Collapsed: hamburger expand button then diamond icon
            const SizedBox(height: 10),
            Center(
              child: InkWell(
                onTap: () => themeProvider.toggleSidebar(),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.menu,
                    color: VividColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: VividWidgets.icon(size: 36)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                color: Color(0x1AFFFFFF),
                height: 1,
                thickness: 1,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── Main navigation ─────────────────────────────────
          if (ClientConfig.hasFeature('conversations'))
            _NavItem(
              icon: Icons.forum,
              label: 'Conversations',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.conversations,
              badge: conversationsProvider.totalUnreadCount,
              badgeColor: VividColors.statusUrgent,
              pulse: conversationsProvider.totalUnreadCount > 0,
              onTap: () =>
                  onDestinationChanged(NavDestination.conversations),
            ),

          if (ClientConfig.hasFeature('broadcasts'))
            _NavItem(
              icon: Icons.campaign,
              label: 'Broadcasts',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.broadcasts,
              onTap: () =>
                  onDestinationChanged(NavDestination.broadcasts),
              isReadOnly:
                  !ClientConfig.canPerformAction('send_broadcast'),
            ),

          if (ClientConfig.hasFeature('broadcasts'))
            _NavItem(
              icon: Icons.article_outlined,
              label: 'Templates',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.templates,
              onTap: () =>
                  onDestinationChanged(NavDestination.templates),
            ),

          if (ClientConfig.hasFeature('booking_reminders'))
            _NavItem(
              icon: Icons.calendar_month,
              label: 'Bookings',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.bookingReminders,
              onTap: () =>
                  onDestinationChanged(NavDestination.bookingReminders),
            ),

          if (ClientConfig.hasFeature('analytics'))
            _NavItem(
              icon: Icons.analytics,
              label: 'Analytics',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.analytics,
              onTap: () =>
                  onDestinationChanged(NavDestination.analytics),
            ),

          if (ClientConfig.hasFeature('manager_chat'))
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Vivid AI',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.managerChat,
              onTap: () =>
                  onDestinationChanged(NavDestination.managerChat),
              isReadOnly:
                  !ClientConfig.canPerformAction('use_manager_chat'),
            ),

          if (ClientConfig.isClientAdmin)
            _NavItem(
              icon: Icons.history,
              label: 'Activity Logs',
              expanded: expanded,
              isSelected:
                  currentDestination == NavDestination.activityLogs,
              onTap: () =>
                  onDestinationChanged(NavDestination.activityLogs),
            ),

          const SizedBox(height: 16),

          // Divider
          Container(
            margin: EdgeInsets.symmetric(
                horizontal: expanded ? 16 : 12),
            height: 1,
            color: VividColors.tealBlue.withValues(alpha: 0.2),
          ),

          const SizedBox(height: 16),

          // ── Notifications ───────────────────────────────────
          _NavItem(
            icon: Icons.notifications,
            label: 'Alerts',
            expanded: expanded,
            isSelected: false,
            badge: unreadNotifications,
            badgeColor: VividColors.statusUrgent,
            pulse: unreadNotifications > 0,
            onTap: () =>
                _showNotificationsPanel(context, notificationProvider),
          ),

          const Spacer(),

          // ── Bottom utilities ────────────────────────────────
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => _UtilityButton(
              icon: tp.isDark ? Icons.light_mode : Icons.dark_mode,
              tooltip: tp.isDark ? 'Light Mode' : 'Dark Mode',
              expanded: expanded,
              label: tp.isDark ? 'Light Mode' : 'Dark Mode',
              onTap: () => tp.toggleTheme(),
            ),
          ),

          _UtilityButton(
            icon: notificationProvider.soundEnabled
                ? Icons.volume_up
                : Icons.volume_off,
            tooltip: notificationProvider.soundEnabled
                ? 'Sound On'
                : 'Sound Off',
            expanded: expanded,
            label: notificationProvider.soundEnabled
                ? 'Sound On'
                : 'Sound Off',
            iconColor: notificationProvider.soundEnabled
                ? VividColors.cyan
                : VividColors.textMuted,
            onTap: () {
              notificationProvider.toggleSound();
              conversationsProvider.toggleSound();
            },
          ),

          const SizedBox(height: 8),

          // ── Agent avatar & menu ─────────────────────────────
          _buildAgentAvatar(context, agent, agentProvider, expanded),

          const SizedBox(height: 20),
        ],
      ),
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

  void _showNotificationsPanel(
      BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _NotificationsDialog(provider: provider),
    );
  }

  Widget _buildAgentAvatar(
    BuildContext context,
    Agent? agent,
    AgentProvider agentProvider,
    bool expanded,
  ) {
    final currentUser = ClientConfig.currentUser;

    final avatar = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VividColors.tealBlue.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          agent?.initials ?? _getInitials(currentUser?.name ?? 'U'),
          style: const TextStyle(
            color: VividColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );

    final menu = PopupMenuButton<String>(
      offset: Offset(expanded ? 200 : 72, 0),
      color: VividColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: VividColors.tealBlue.withValues(alpha: 0.3)),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agent?.name ?? currentUser?.name ?? 'User',
                style: const TextStyle(
                  color: VividColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                agent?.email ?? currentUser?.email ?? '',
                style: const TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRoleColor(currentUser?.role ?? UserRole.viewer)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentUser?.role.displayName ?? 'User',
                  style: TextStyle(
                    color: _getRoleColor(
                        currentUser?.role ?? UserRole.viewer),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (ClientConfig.isClientAdmin)
          const PopupMenuItem(
            value: 'manage_users',
            child: Row(
              children: [
                Icon(Icons.people, color: VividColors.cyan, size: 20),
                SizedBox(width: 10),
                Text(
                  'Manage Users',
                  style: TextStyle(color: VividColors.textPrimary),
                ),
              ],
            ),
          ),
        if (ClientConfig.isClientAdmin) const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: VividColors.statusUrgent, size: 20),
              SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(color: VividColors.statusUrgent),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') {
          agentProvider.logout();
        } else if (value == 'manage_users') {
          _showUserManagement(context);
        }
      },
      child: expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent?.name ?? currentUser?.name ?? 'User',
                          style: const TextStyle(
                            color: VividColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentUser?.role.displayName ?? '',
                          style: const TextStyle(
                            color: VividColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : avatar,
    );

    return menu;
  }

  void _showUserManagement(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const UserManagementDialog(),
    );
  }

  String _getInitials(String name) => getInitials(name);
}

// ============================================================
// NAV ITEM
// ============================================================

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool isSelected;
  final int badge;
  final Color? badgeColor;
  final bool pulse;
  final bool isReadOnly;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.isSelected,
    this.badge = 0,
    this.badgeColor,
    this.pulse = false,
    this.isReadOnly = false,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
          parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.pulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const highlightColor = VividColors.cyan;
    final color = widget.isSelected ? highlightColor : VividColors.textMuted;
    final badgeColor = widget.badgeColor ?? VividColors.cyan;

    return Tooltip(
      message: widget.isReadOnly
          ? '${widget.label} (View Only)'
          : widget.expanded
              ? ''
              : widget.label,
      preferBelow: false,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: widget.expanded ? 10 : 14,
            horizontal: widget.expanded ? 16 : 0,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.isSelected
                    ? highlightColor
                    : Colors.transparent,
                width: 3,
              ),
            ),
            color: widget.isSelected
                ? highlightColor.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: widget.expanded
              ? _buildExpanded(color, badgeColor, highlightColor)
              : _buildCollapsed(color, badgeColor),
        ),
      ),
    );
  }

  /// Expanded: icon + label text (+ optional badge)
  Widget _buildExpanded(
      Color color, Color badgeColor, Color highlightColor) {
    return Row(
      children: [
        // Left border offset compensation
        const SizedBox(width: 2),
        Icon(widget.icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: widget.isSelected
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Badge
        if (widget.badge > 0)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.pulse ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: widget.pulse
                        ? [
                            BoxShadow(
                              color: badgeColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  constraints: const BoxConstraints(minWidth: 20),
                  child: Text(
                    widget.badge > 99 ? '99+' : widget.badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        // Read-only badge (expanded)
        if (widget.isReadOnly)
          Icon(Icons.visibility, size: 14, color: VividColors.textMuted),
      ],
    );
  }

  /// Collapsed: icon only (same as before)
  Widget _buildCollapsed(Color color, Color badgeColor) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icon, color: color, size: 24),
        if (widget.isReadOnly)
          Positioned(
            right: 14,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: VividColors.darkNavy,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.visibility,
                size: 10,
                color: VividColors.textMuted,
              ),
            ),
          ),
        if (widget.badge > 0)
          Positioned(
            right: 14,
            top: -4,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.pulse ? _pulseAnimation.value : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: widget.pulse
                          ? [
                              BoxShadow(
                                color: badgeColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text(
                      widget.badge > 99 ? '99+' : widget.badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ============================================================
// UTILITY BUTTON (theme toggle, sound toggle)
// ============================================================

class _UtilityButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String label;
  final bool expanded;
  final Color? iconColor;
  final VoidCallback onTap;

  const _UtilityButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? VividColors.textMuted;
    if (expanded) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
    );
  }
}

// ============================================================
// NOTIFICATIONS DIALOG
// ============================================================

class _NotificationsDialog extends StatelessWidget {
  final NotificationProvider provider;

  const _NotificationsDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VividColors.navy,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width < 400
            ? MediaQuery.of(context).size.width * 0.9
            : 360,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: VividColors.tealBlue.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: VividColors.cyan),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: VividColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (provider.notifications.isNotEmpty)
                    TextButton(
                      onPressed: () => provider.markAllAsRead(),
                      child: const Text(
                        'Mark all read',
                        style:
                            TextStyle(color: VividColors.cyan, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Notifications List
            Flexible(
              child: provider.notifications.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 48,
                            color: VividColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style:
                                TextStyle(color: VividColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.notifications.length,
                      itemBuilder: (context, index) {
                        final notification = provider.notifications[index];
                        return _NotificationTile(
                          notification: notification,
                          onTap: () {
                            provider.markAsRead(notification.id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: VividColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final ManagerNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : VividColors.brightBlue.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
                color: VividColors.tealBlue.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.isRead
                    ? Colors.transparent
                    : VividColors.statusUrgent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.displayName,
                    style: TextStyle(
                      color: VividColors.textPrimary,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: VividColors.textMuted,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
