import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/agent_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

class Sidebar extends StatelessWidget {
  final bool compact;

  const Sidebar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final conversationsProvider = context.watch<ConversationsProvider>();
    final agentProvider = context.watch<AgentProvider>();
    final agent = agentProvider.agent;

    final sidebarWidth = compact ? 60.0 : 72.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: VividColors.darkGradient,
        border: Border(
          right: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: compact ? 12 : 20),

          // Logo with connection indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              VividWidgets.icon(size: 44),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conversationsProvider.isConnected
                        ? VividColors.statusSuccess
                        : VividColors.statusUrgent,
                    border: Border.all(
                      color: VividColors.darkNavy,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Navigation Items
          _NavItem(
            icon: Icons.forum,
            label: 'All',
            isSelected: conversationsProvider.statusFilter == null,
            badge: conversationsProvider.totalCount,
            onTap: () => conversationsProvider.setStatusFilter(null),
          ),
          _NavItem(
            icon: Icons.priority_high,
            label: 'Needs Reply',
            isSelected: conversationsProvider.statusFilter == ConversationStatus.needsReply,
            badge: conversationsProvider.needsReplyCount,
            color: VividColors.statusUrgent,
            onTap: () => conversationsProvider.setStatusFilter(ConversationStatus.needsReply),
          ),
          _NavItem(
            icon: Icons.check_circle,
            label: 'Replied',
            isSelected: conversationsProvider.statusFilter == ConversationStatus.replied,
            badge: conversationsProvider.repliedCount,
            color: VividColors.statusSuccess,
            onTap: () => conversationsProvider.setStatusFilter(ConversationStatus.replied),
          ),

          const Spacer(),

          // Agent Avatar & Menu
          _buildAgentAvatar(context, agent, agentProvider),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAgentAvatar(
    BuildContext context,
    Agent? agent,
    AgentProvider agentProvider,
  ) {
    return PopupMenuButton<String>(
      offset: const Offset(72, 0),
      color: VividColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agent?.name ?? 'Manager',
                style: const TextStyle(
                  color: VividColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                agent?.email ?? '',
                style: const TextStyle(
                  color: VividColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: agent?.isOnline == true
                      ? VividColors.statusSuccess
                      : VividColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                agent?.isOnline == true ? 'Online' : 'Offline',
                style: const TextStyle(color: VividColors.textSecondary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
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
        } else if (value == 'status') {
          agentProvider.updateOnlineStatus(!agent!.isOnline);
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: VividColors.deepBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: agent?.isOnline == true
                ? VividColors.statusSuccess.withOpacity(0.5)
                : VividColors.tealBlue.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            agent?.initials ?? 'MG',
            style: const TextStyle(
              color: VividColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badge;
  final Color? color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.badge,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? (isSelected ? VividColors.cyan : VividColors.textMuted);

    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? VividColors.cyan : Colors.transparent,
                width: 3,
              ),
            ),
            color: isSelected
                ? VividColors.brightBlue.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: itemColor,
                size: 24,
              ),
              if (badge > 0)
                Positioned(
                  right: 14,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color ?? VividColors.cyan,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      style: TextStyle(
                        color: color != null ? VividColors.white : VividColors.darkNavy,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}