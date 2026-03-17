import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/ai_settings_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/time_utils.dart';
import '../utils/initials_helper.dart';
import 'side_profile_panel.dart' show phonesWithNotes, ensurePhonesWithNotesInitialized;

class ConversationListPanel extends StatefulWidget {
  final VoidCallback? onConversationTap;

  const ConversationListPanel({super.key, this.onConversationTap});

  @override
  State<ConversationListPanel> createState() => _ConversationListPanelState();
}

class _ConversationListPanelState extends State<ConversationListPanel> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<MessageSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    ensurePhonesWithNotesInitialized();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _isSearchActive = false;
      });
      return;
    }
    setState(() {
      _isSearchActive = true;
      _isSearching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final provider = context.read<ConversationsProvider>();
      final results = await provider.searchMessages(query.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _searchResults = [];
      _isSearching = false;
      _isSearchActive = false;
    });
  }

  void _selectSearchResult(MessageSearchResult result) {
    final provider = context.read<ConversationsProvider>();
    // Find or create the conversation for this phone
    final conv = provider.conversations.where(
      (c) => c.customerPhone == result.customerPhone,
    ).firstOrNull;
    if (conv != null) {
      provider.selectConversation(conv);
      provider.setHighlightedExchange(result.exchangeId);
    }
    _clearSearch();
    widget.onConversationTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width < 600 ? 0 : 280),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(
          right: BorderSide(
            color: VividColors.tealBlue.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isSearchActive
                ? _buildSearchResults()
                : _buildConversationList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<ConversationsProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: vc.border,
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
                  style: TextStyle(
                    color: vc.background,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inline search field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: vc.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search messages, names, phones...',
              hintStyle: TextStyle(color: vc.textMuted.withValues(alpha: 0.6)),
              prefixIcon: Icon(Icons.search, color: vc.textMuted, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: vc.textMuted, size: 18),
                      onPressed: _clearSearch,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: vc.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: vc.popupBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: vc.popupBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: VividColors.cyan),
              ),
            ),
          ),

          // Needs Reply filter chip (only when not searching)
          if (!_isSearchActive && provider.needsReplyCount > 0) ...[
            const SizedBox(height: 12),
            _buildNeedsReplyChip(context, provider),
          ],

          // Label filter chips (only when not searching)
          if (!_isSearchActive &&
              ClientConfig.enabledFeatures.contains('labels') &&
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

  Widget _buildSearchResults() {
    final vc = context.vividColors;
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No results',
            style: TextStyle(color: vc.textMuted.withValues(alpha: 0.6), fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Messages',
              style: TextStyle(
                color: vc.textMuted.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        final result = _searchResults[index - 1];
        return _SearchResultRow(
          result: result,
          query: _searchController.text.trim().toLowerCase(),
          onTap: () => _selectSearchResult(result),
        );
      },
    );
  }

  Widget _buildNeedsReplyChip(BuildContext context, ConversationsProvider provider) {
    final vc = context.vividColors;
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
              ? VividColors.statusUrgent.withValues(alpha: 0.15)
              : vc.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? VividColors.statusUrgent
                : vc.popupBorder,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.reply,
              size: 12,
              color: isActive ? VividColors.statusUrgent : vc.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Needs Reply',
              style: TextStyle(
                color: isActive ? VividColors.statusUrgent : vc.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: VividColors.statusUrgent.withValues(alpha: isActive ? 0.3 : 0.15),
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
    final vc = context.vividColors;
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
            color: isActive ? color.withValues(alpha: 0.2) : vc.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? color : vc.popupBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(
            display,
            style: TextStyle(
              color: isActive ? color : vc.textMuted,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<ConversationsProvider>();

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
                color: vc.surfaceAlt.withValues(alpha: 0.3),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: vc.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: vc.textMuted,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Messages will appear here when\ncustomers start chatting',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: vc.textMuted.withValues(alpha: 0.7),
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
            widget.onConversationTap?.call();
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
    final vc = context.vividColors;
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
                ? VividColors.brightBlue.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? VividColors.cyan : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: vc.borderSubtle,
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(vc),
              const SizedBox(width: 14),
              Expanded(child: _buildContent(context, aiEnabled, vc)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(VividColorScheme vc) {
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
            child: Builder(builder: (context) {
              final initials = _getInitials();
              return Text(
                initials,
                textDirection: isArabicText(initials) ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  color: VividColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              );
            }),
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
                color: vc.surface,
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

  Widget _buildContent(BuildContext context, bool aiEnabled, VividColorScheme vc) {
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
                  color: vc.textPrimary,
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ValueListenableBuilder<Set<String>>(
              valueListenable: phonesWithNotes,
              builder: (_, phones, __) {
                if (!phones.contains(conversation.customerPhone)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0x263B82F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.note_alt_outlined,
                          size: 12,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Text(
              TimeUtils.formatRelativeTime(conversation.lastMessageAt),
              style: TextStyle(
                color: conversation.unreadCount > 0
                    ? VividColors.cyan
                    : vc.textMuted,
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
            style: TextStyle(
              color: vc.textMuted,
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
                      ? vc.textSecondary
                      : vc.textMuted,
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
                  style: TextStyle(
                    color: vc.background,
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
            if (conversation.broadcastLifecycleLabel != null)
              _buildBroadcastLifecycleBadge(conversation.broadcastLifecycleLabel!)
            else
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
        color: color.withValues(alpha: 0.15),
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

  Widget _buildBroadcastLifecycleBadge(String lifecycleLabel) {
    final Color color;
    final IconData icon;
    switch (lifecycleLabel) {
      case 'Sent':
        color = const Color(0xFFF59E0B);
        icon = Icons.send;
        break;
      case 'Needs Reply':
        color = const Color(0xFFEF4444);
        icon = Icons.reply;
        break;
      case 'Replied':
      default:
        color = const Color(0xFF10B981);
        icon = Icons.done_all;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            lifecycleLabel,
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
        color: color.withValues(alpha: 0.15),
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
        color: color.withValues(alpha: 0.15),
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
      case 'Appointment Booked':
        return const Color(0xFF10B981);
      case 'Payment Done':
        return const Color(0xFF06B6D4);
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
      case 'Appointment Booked':
        return Icons.event_available;
      case 'Payment Done':
        return Icons.payments;
      default:
        return Icons.label;
    }
  }

  Color _getAvatarColor() {
    final colors = [
      VividColors.brightBlue,
      VividColors.purpleBlue,
      VividColors.cyan,
      VividColors.tealBlue,
      VividColors.purpleBlue,
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
    return getInitials(conversation.customerName ?? conversation.customerPhone);
  }
}

// ============================================
// SEARCH RESULT ROW
// ============================================

class _SearchResultRow extends StatelessWidget {
  final MessageSearchResult result;
  final String query;
  final VoidCallback onTap;

  const _SearchResultRow({
    required this.result,
    required this.query,
    required this.onTap,
  });

  bool get _isNameMatch => result.matchedField == 'name' || result.matchedField == 'phone';

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name (highlighted if name match) + date on right
            Row(
              children: [
                Expanded(
                  child: _isNameMatch
                      ? _buildHighlightedText(
                          result.displayName,
                          query,
                          TextStyle(
                            color: vc.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          result.displayName,
                          style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSearchDate(result.date),
                  style: TextStyle(color: vc.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Message preview
            _buildSnippet(vc),
          ],
        ),
      ),
    );
  }

  Widget _buildSnippet(VividColorScheme vc) {
    if (_isNameMatch) {
      // Name/phone match: show last message as plain preview (no highlight)
      final preview = result.matchedText;
      return Text(
        preview.length > 80 ? '${preview.substring(0, 80)}...' : preview,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Message content match: show the actual message text with highlight
    final isOutbound = result.matchedField == 'manager_response';
    final text = result.matchedText;
    final snippet = _truncateSnippet(text, query);

    if (isOutbound) {
      // Prefix "You: " for outbound messages
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You: ',
            style: TextStyle(color: vc.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: _buildHighlightedText(
              snippet,
              query,
              const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      );
    }

    return _buildHighlightedText(
      snippet,
      query,
      const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }

  String _truncateSnippet(String text, String q) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) return text.length > 80 ? '${text.substring(0, 80)}...' : text;

    const window = 30;
    int start = (idx - window).clamp(0, text.length);
    int end = (idx + q.length + window).clamp(0, text.length);
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    return snippet;
  }

  Widget _buildHighlightedText(String text, String q, TextStyle baseStyle) {
    if (q.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      start = idx + q.length;
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatSearchDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
