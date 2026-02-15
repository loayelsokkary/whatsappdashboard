import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/ai_settings_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/time_utils.dart';

class ConversationListPanel extends StatelessWidget {
  final VoidCallback? onConversationTap;

  const ConversationListPanel({super.key, this.onConversationTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 280),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          right: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildConversationList(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final provider = context.watch<ConversationsProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Conversations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: VividColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.conversations.length.toString(),
                  style: const TextStyle(
                    color: VividColors.darkNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (value) => provider.setSearchQuery(value),
            style: const TextStyle(color: VividColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by phone or name...',
              prefixIcon: const Icon(
                Icons.search,
                color: VividColors.textMuted,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: VividColors.darkNavy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: VividColors.tealBlue.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: VividColors.tealBlue.withOpacity(0.3),
                ),
              ),
            ),
          ),

          // Needs Reply filter chip
          if (provider.needsReplyCount > 0) ...[
            const SizedBox(height: 12),
            _buildNeedsReplyChip(context, provider),
          ],

          // Label filter chips (only when labels feature is enabled)
          if (ClientConfig.enabledFeatures.contains('labels') &&
              provider.availableLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildLabelFilterChip(context, provider, null, 'All'),
                  ...provider.availableLabels.map(
                    (label) => _buildLabelFilterChip(context, provider, label, label),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNeedsReplyChip(BuildContext context, ConversationsProvider provider) {
    final isActive = provider.statusFilter == ConversationStatus.needsReply;
    final count = provider.needsReplyCount;

    return GestureDetector(
      onTap: () => provider.setStatusFilter(
        isActive ? null : ConversationStatus.needsReply,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? VividColors.statusUrgent.withOpacity(0.15)
              : VividColors.darkNavy,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? VividColors.statusUrgent
                : VividColors.tealBlue.withOpacity(0.3),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.reply,
              size: 12,
              color: isActive ? VividColors.statusUrgent : VividColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Needs Reply',
              style: TextStyle(
                color: isActive ? VividColors.statusUrgent : VividColors.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: VividColors.statusUrgent.withOpacity(isActive ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: VividColors.statusUrgent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelFilterChip(
    BuildContext context,
    ConversationsProvider provider,
    String? value,
    String display,
  ) {
    final isActive = provider.labelFilter == value;
    final color = value != null ? _ConversationCard._getLabelColor(value) : VividColors.cyan;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => provider.setLabelFilter(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.2) : VividColors.darkNavy,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? color : VividColors.tealBlue.withOpacity(0.3),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(
            display,
            style: TextStyle(
              color: isActive ? color : VividColors.textMuted,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    final provider = context.watch<ConversationsProvider>();

    if (provider.isLoading && provider.conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: VividColors.cyan),
            SizedBox(height: 16),
            Text(
              'Connecting to Supabase...',
              style: TextStyle(color: VividColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (provider.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VividColors.deepBlue.withOpacity(0.3),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 40,
                color: VividColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: VividColors.textMuted,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Messages will appear here when\ncustomers start chatting',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VividColors.textMuted.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.conversations.length,
      itemBuilder: (context, index) {
        final conversation = provider.conversations[index];
        final isSelected = provider.selectedConversation?.id == conversation.id;

        return _ConversationCard(
          conversation: conversation,
          isSelected: isSelected,
          onTap: () {
            provider.selectConversation(conversation);
            onConversationTap?.call();
          },
        );
      },
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Watch the AI settings provider for real-time updates
    final aiSettingsProvider = context.watch<AiSettingsProvider>();
    final aiEnabled = aiSettingsProvider.isAiEnabled(conversation.customerPhone);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? VividColors.brightBlue.withOpacity(0.1)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? VividColors.cyan : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: VividColors.tealBlue.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(child: _buildContent(context, aiEnabled)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getAvatarColor(),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              _getInitials(),
              style: const TextStyle(
                color: VividColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
              border: Border.all(
                color: VividColors.navy,
                width: 2,
              ),
            ),
            child: Icon(
              _getStatusIcon(),
              size: 10,
              color: VividColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool aiEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Time
        Row(
          children: [
            Expanded(
              child: Text(
                conversation.displayName,
                style: TextStyle(
                  color: VividColors.textPrimary,
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              TimeUtils.formatRelativeTime(conversation.lastMessageAt),
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? VividColors.cyan
                    : VividColors.textMuted,
                fontSize: 11,
                fontWeight:
                    conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),

        // Phone number (if name is shown)
        if (conversation.customerName != null) ...[
          const SizedBox(height: 2),
          Text(
            conversation.customerPhone,
            style: const TextStyle(
              color: VividColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],

        const SizedBox(height: 6),

        // Last message preview
        Row(
          children: [
            Expanded(
              child: Text(
                conversation.lastMessage,
                style: TextStyle(
                  color: conversation.unreadCount > 0
                      ? VividColors.textSecondary
                      : VividColors.textMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  gradient: VividColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: VividColors.darkNavy,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Status badges row
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildStatusBadge(),
            if (ClientConfig.hasAiConversations)
              _buildAiBadge(aiEnabled),
            if (ClientConfig.enabledFeatures.contains('labels') &&
                conversation.label != null &&
                conversation.label!.isNotEmpty)
              _buildLabelBadge(conversation.label!),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    String label;
    Color color;
    IconData icon;

    switch (conversation.status) {
      case ConversationStatus.needsReply:
        label = 'Needs Reply';
        color = VividColors.statusUrgent;
        icon = Icons.priority_high;
        break;
      case ConversationStatus.replied:
        label = 'Replied';
        color = VividColors.statusSuccess;
        icon = Icons.check;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBadge(bool aiEnabled) {
    final color = aiEnabled ? VividColors.cyan : const Color(0xFFFF9800);
    final label = aiEnabled ? 'AI On' : 'AI Off';
    final icon = aiEnabled ? Icons.smart_toy : Icons.person;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelBadge(String label) {
    final color = _getLabelColor(label);
    final icon = _getLabelIcon(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Color _getLabelColor(String label) {
    switch (label) {
      case 'Booking':
        return const Color(0xFF10B981);
      case 'Pricing':
        return const Color(0xFFF59E0B);
      case 'Enquiry':
        return const Color(0xFF8B5CF6);
      case 'Location':
        return const Color(0xFFEC4899);
      case 'Working Hours':
        return const Color(0xFF06B6D4);
      case 'Reschedule':
        return const Color(0xFFEF4444);
      case 'Cancel':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static IconData _getLabelIcon(String label) {
    switch (label) {
      case 'Booking':
        return Icons.event;
      case 'Pricing':
        return Icons.attach_money;
      case 'Enquiry':
        return Icons.help_outline;
      case 'Location':
        return Icons.location_on;
      case 'Working Hours':
        return Icons.schedule;
      case 'Reschedule':
        return Icons.update;
      case 'Cancel':
        return Icons.cancel_outlined;
      default:
        return Icons.label;
    }
  }

  Color _getAvatarColor() {
    final colors = [
      VividColors.brightBlue,
      VividColors.purpleBlue,
      VividColors.cyanBlue,
      VividColors.tealBlue,
      VividColors.deepBlue,
    ];
    final hash = conversation.customerPhone.hashCode.abs();
    return colors[hash % colors.length];
  }

  Color _getStatusColor() {
    switch (conversation.status) {
      case ConversationStatus.needsReply:
        return VividColors.statusUrgent;
      case ConversationStatus.replied:
        return VividColors.statusSuccess;
    }
  }

  IconData _getStatusIcon() {
    switch (conversation.status) {
      case ConversationStatus.needsReply:
        return Icons.priority_high;
      case ConversationStatus.replied:
        return Icons.check;
    }
  }

  String _getInitials() {
    final name = conversation.customerName ?? conversation.customerPhone;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}