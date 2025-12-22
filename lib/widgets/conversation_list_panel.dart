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
              const Spacer(),
              IconButton(
                onPressed: () => provider.fetchConversations(),
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VividColors.cyan,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 20),
                color: VividColors.textMuted,
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
        ],
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
        Row(
          children: [
            _buildStatusBadge(),
            const SizedBox(width: 8),
            _buildAiBadge(aiEnabled),
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