import 'dart:html' as html;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/outreach_models.dart';
import '../providers/outreach_provider.dart';
import '../theme/vivid_theme.dart';

/// Split-view conversation widget for Vivid Outreach.
/// Left panel: contact list with search, filters, needs-reply, last message preview.
/// Right panel: chat bubbles + file sharing + emoji picker + message input.
class OutreachChat extends StatefulWidget {
  const OutreachChat({super.key});

  @override
  State<OutreachChat> createState() => _OutreachChatState();
}

class _OutreachChatState extends State<OutreachChat> {
  double _listWidth = 340;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      if (isMobile) {
        if (provider.selectedContact != null) {
          return _ChatPanel(
            onBack: () => provider.clearContactSelection(),
          );
        }
        return const _ContactListPanel();
      }

      return Row(
        children: [
          SizedBox(
            width: _listWidth.clamp(240, constraints.maxWidth * 0.4),
            child: const _ContactListPanel(),
          ),
          // Resizable divider
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _listWidth = (_listWidth + details.delta.dx)
                    .clamp(240, constraints.maxWidth * 0.5);
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                width: 6,
                color: Colors.transparent,
                child: Center(
                  child: Container(width: 1, color: vc.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: provider.selectedContact != null
                ? const _ChatPanel()
                : _buildEmptyState(vc),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyState(VividColorScheme vc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: vc.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Select a contact to start messaging',
              style: TextStyle(color: vc.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

// ============================================
// CONTACT LIST PANEL (left side)
// ============================================

class _ContactListPanel extends StatefulWidget {
  const _ContactListPanel();

  @override
  State<_ContactListPanel> createState() => _ContactListPanelState();
}

class _ContactListPanelState extends State<_ContactListPanel> {
  final _searchController = TextEditingController();
  bool _needsReplyFilter = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();
    final needsReplyIds = provider.needsReplyContactIds;
    var contacts = provider.contacts;

    // Apply needs-reply filter
    if (_needsReplyFilter) {
      contacts = contacts.where((c) => needsReplyIds.contains(c.id)).toList();
    }

    return Container(
      color: vc.surface,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Conversations',
                        style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: VividColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${provider.allContacts.length}',
                          style: TextStyle(
                              color: vc.background,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (q) => provider.setContactSearch(q),
                  style: TextStyle(color: vc.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle:
                        TextStyle(color: vc.textMuted.withValues(alpha: 0.6)),
                    prefixIcon:
                        Icon(Icons.search, color: vc.textMuted, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close,
                                color: vc.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setContactSearch('');
                            },
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

                // Needs Reply chip
                if (_searchController.text.isEmpty &&
                    provider.needsReplyCount > 0) ...[
                  const SizedBox(height: 10),
                  _buildNeedsReplyChip(vc, provider.needsReplyCount),
                ],

                // Status filter chips
                if (_searchController.text.isEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip(
                            context, provider, null, 'All',
                            provider.allContacts.length),
                        ...ContactStatus.values
                            .where(
                                (s) => (provider.contactCounts[s] ?? 0) > 0)
                            .map((s) => _buildFilterChip(context, provider,
                                s, s.label, provider.contactCounts[s] ?? 0)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: vc.border),
          // Contact list
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text('No contacts found',
                        style: TextStyle(color: vc.textMuted, fontSize: 13)))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final isSelected =
                          provider.selectedContact?.id == contact.id;
                      final lastMsg = provider.lastMessageFor(contact.id);
                      final needsReply =
                          needsReplyIds.contains(contact.id);
                      return _ContactChatTile(
                        contact: contact,
                        isSelected: isSelected,
                        lastMessage: lastMsg,
                        needsReply: needsReply,
                        onTap: () => provider.selectContact(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsReplyChip(VividColorScheme vc, int count) {
    const color = VividColors.statusUrgent;
    return GestureDetector(
      onTap: () => setState(() => _needsReplyFilter = !_needsReplyFilter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _needsReplyFilter
              ? color.withValues(alpha: 0.15)
              : vc.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _needsReplyFilter
                ? color.withValues(alpha: 0.5)
                : vc.popupBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, size: 14,
                color: _needsReplyFilter ? color : vc.textMuted),
            const SizedBox(width: 6),
            Text('Needs Reply',
                style: TextStyle(
                  color: _needsReplyFilter ? color : vc.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      _needsReplyFilter ? FontWeight.w600 : FontWeight.w500,
                )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, OutreachProvider provider,
      ContactStatus? status, String label, int count) {
    final vc = context.vividColors;
    final isActive = provider.contactFilter == status;
    final color = status?.color ?? VividColors.cyan;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          if (_needsReplyFilter) setState(() => _needsReplyFilter = false);
          provider.setContactFilter(status);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:
                isActive ? color.withValues(alpha: 0.15) : vc.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.4)
                  : vc.popupBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                    color: isActive ? color : vc.textSecondary,
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w500,
                  )),
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                    color: isActive
                        ? color.withValues(alpha: 0.8)
                        : vc.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// CONTACT TILE
// ============================================

const _avatarColors = [
  VividColors.brightBlue,
  VividColors.purpleBlue,
  VividColors.cyan,
  VividColors.tealBlue,
];

class _ContactChatTile extends StatelessWidget {
  final OutreachContact contact;
  final bool isSelected;
  final OutreachMessage? lastMessage;
  final bool needsReply;
  final VoidCallback onTap;

  const _ContactChatTile({
    required this.contact,
    required this.isSelected,
    this.lastMessage,
    this.needsReply = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;

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
              bottom: BorderSide(color: vc.borderSubtle, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(vc),
              const SizedBox(width: 14),
              Expanded(child: _buildContent(vc)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(VividColorScheme vc) {
    final colorIndex =
        contact.displayName.hashCode.abs() % _avatarColors.length;
    final color = _avatarColors[colorIndex];

    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              _initials(contact.displayName),
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
              color: contact.status.color,
              shape: BoxShape.circle,
              border: Border.all(color: vc.surface, width: 2),
            ),
            child: Center(
              child: Icon(
                _statusIcon(contact.status),
                size: 10,
                color: VividColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(VividColorScheme vc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + time row
        Row(
          children: [
            Expanded(
              child: Text(
                contact.displayName,
                style: TextStyle(
                  color: vc.textPrimary,
                  fontWeight: needsReply ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (needsReply) ...[
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: VividColors.statusUrgent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (lastMessage != null)
              Text(
                _formatRelativeTime(lastMessage!.createdAt),
                style: TextStyle(
                    color: needsReply
                        ? VividColors.statusUrgent
                        : vc.textMuted,
                    fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Phone
        Text(
          contact.phone,
          style: TextStyle(color: vc.textMuted, fontSize: 12),
          maxLines: 1,
        ),
        // Last message preview
        if (lastMessage != null) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              if (lastMessage!.isOutbound)
                Text('You: ',
                    style: TextStyle(
                        color: vc.textMuted, fontSize: 12,
                        fontWeight: FontWeight.w500)),
              Expanded(
                child: Text(
                  lastMessage!.mediaUrl != null &&
                          lastMessage!.mediaUrl!.isNotEmpty
                      ? (lastMessage!.mediaType == 'image'
                          ? '\uD83D\uDCF7 Photo'
                          : '\uD83D\uDCC4 Document')
                      : lastMessage!.displayText,
                  style: TextStyle(
                    color: vc.textMuted.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ] else if (contact.companyName.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            contact.companyName,
            style: TextStyle(
                color: vc.textMuted.withValues(alpha: 0.7), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  IconData _statusIcon(ContactStatus status) {
    return switch (status) {
      ContactStatus.lead => Icons.fiber_new,
      ContactStatus.contacted => Icons.chat_bubble_outline,
      ContactStatus.interested => Icons.star_outline,
      ContactStatus.meetingScheduled => Icons.calendar_today,
      ContactStatus.proposalSent => Icons.description_outlined,
      ContactStatus.client => Icons.check_circle_outline,
      ContactStatus.lost => Icons.cancel_outlined,
    };
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatRelativeTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return _formatTime12(local);
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday';
    }

    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}';
  }

  String _formatTime12(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }
}

// ============================================
// CHAT PANEL (right side)
// ============================================

class _ChatPanel extends StatefulWidget {
  final VoidCallback? onBack;

  const _ChatPanel({this.onBack});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  bool _isUploading = false;
  bool _showEmojiPicker = false;
  bool _showScrollToBottom = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final show = maxScroll - currentScroll > 200;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.baseOffset;
    final end = selection.extentOffset;

    if (start >= 0) {
      _messageController.text =
          text.substring(0, start) + emoji.emoji + text.substring(end);
      _messageController.selection =
          TextSelection.collapsed(offset: start + emoji.emoji.length);
    } else {
      _messageController.text = text + emoji.emoji;
      _messageController.selection =
          TextSelection.collapsed(offset: _messageController.text.length);
    }
  }

  Future<void> _pickAndUploadFile(OutreachProvider provider) async {
    if (provider.selectedContact == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result == null || !mounted) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      // Show caption dialog
      final caption = await _showCaptionDialog(file.name, file.extension?.toLowerCase());
      if (caption == null || !mounted) return;

      setState(() => _isUploading = true);

      final url = await provider.uploadMedia(bytes, file.name);
      if (url == null) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed')),
          );
        }
        return;
      }

      final ext = file.extension?.toLowerCase();
      final mediaType = (ext == 'jpg' || ext == 'jpeg' || ext == 'png')
          ? 'image'
          : 'document';

      await provider.sendMessage(
        provider.selectedContact!.id,
        caption,
        mediaUrl: url,
        mediaType: mediaType,
        mediaFilename: file.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isUploading = false);
      _scrollToBottom();
    }
  }

  Future<String?> _showCaptionDialog(String filename, String? ext) async {
    final captionController = TextEditingController();
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';

    return showDialog<String>(
      context: context,
      builder: (context) {
        final vc = context.vividColors;
        return AlertDialog(
          backgroundColor: vc.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isImage ? Icons.image : Icons.picture_as_pdf,
                color: isImage ? VividColors.cyan : const Color(0xFFEF4444),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(filename,
                    style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: captionController,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(color: vc.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a caption (optional)...',
                hintStyle: TextStyle(color: vc.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: vc.popupBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: VividColors.cyan),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Cancel', style: TextStyle(color: vc.textSecondary)),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, captionController.text.trim()),
              style: FilledButton.styleFrom(
                  backgroundColor: VividColors.cyan,
                  foregroundColor: Colors.white),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage(OutreachProvider provider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || provider.selectedContact == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final error =
        await provider.sendMessage(provider.selectedContact!.id, text);

    if (mounted) {
      setState(() => _isSending = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $error')),
        );
      } else {
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();
    final contact = provider.selectedContact;
    if (contact == null) return const SizedBox.shrink();

    final messages = provider.messages;
    if (messages.length != _previousMessageCount) {
      _previousMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Container(
      color: vc.background,
      child: Column(
        children: [
          _buildChatHeader(context, vc, contact, provider),
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(context, vc, provider),
                // Scroll-to-bottom button
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: VividColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: VividColors.brightBlue
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.keyboard_arrow_down,
                            color: vc.background, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildInputArea(context, vc, provider),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context, VividColorScheme vc,
      OutreachContact contact, OutreachProvider provider) {
    final colorIndex =
        contact.displayName.hashCode.abs() % _avatarColors.length;
    final avatarColor = _avatarColors[colorIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(bottom: BorderSide(color: vc.border)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: widget.onBack,
              color: vc.textSecondary,
            ),
            const SizedBox(width: 4),
          ],
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _initials(contact.displayName),
                style: TextStyle(
                  color: avatarColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.displayName,
                    style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(contact.phone,
                        style: TextStyle(color: vc.textMuted, fontSize: 12)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: contact.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phone copied!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Icon(Icons.copy_rounded,
                          size: 14, color: vc.textMuted),
                    ),
                    if (contact.companyName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(contact.companyName,
                            style: TextStyle(color: vc.textMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: contact.status.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(contact.status.label,
                style: TextStyle(
                    color: contact.status.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          if (!provider.hasSendWebhook) ...[
            const SizedBox(width: 8),
            Tooltip(
              message:
                  'Send webhook not configured — messages saved but not sent via WhatsApp',
              child: Icon(Icons.warning_amber_rounded,
                  size: 18, color: VividColors.statusWarning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList(
      BuildContext context, VividColorScheme vc, OutreachProvider provider) {
    if (provider.isLoadingMessages) {
      return const Center(
        child:
            CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
      );
    }

    final messages = provider.messages;
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.message_outlined,
                size: 40, color: vc.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No messages yet',
                style: TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Send a message to start the conversation',
                style: TextStyle(color: vc.textMuted, fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final showDateDivider = index == 0 ||
            !_isSameDay(messages[index - 1].createdAt.toLocal(),
                msg.createdAt.toLocal());
        return Column(
          children: [
            if (showDateDivider) _buildDateDivider(vc, msg.createdAt),
            _MessageBubble(message: msg),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateDivider(VividColorScheme vc, DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();

    String label;
    if (_isSameDay(local, now)) {
      label = 'Today';
    } else if (_isSameDay(local, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${months[local.month - 1]} ${local.day}, ${local.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: vc.borderSubtle)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: vc.borderSubtle)),
        ],
      ),
    );
  }

  Widget _buildInputArea(
      BuildContext context, VividColorScheme vc, OutreachProvider provider) {
    final busy = _isSending || _isUploading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upload indicator
        if (_isUploading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(top: BorderSide(color: vc.border)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: VividColors.cyan),
                ),
                const SizedBox(width: 8),
                Text('Uploading...',
                    style: TextStyle(color: vc.textMuted, fontSize: 13)),
              ],
            ),
          ),

        // Emoji picker
        if (_showEmojiPicker)
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(top: BorderSide(color: vc.border)),
            ),
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              config: Config(
                height: 300,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: vc.surface,
                  columns: 8,
                  emojiSizeMax: 28,
                  noRecents: Text('No Recents',
                      style: TextStyle(fontSize: 16, color: vc.textMuted)),
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: vc.surface,
                  iconColor: vc.textMuted,
                  iconColorSelected: VividColors.cyan,
                  indicatorColor: VividColors.cyan,
                  dividerColor: vc.border,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: vc.surface,
                  buttonIconColor: VividColors.cyan,
                  hintText: 'Search emoji...',
                ),
                bottomActionBarConfig:
                    const BottomActionBarConfig(enabled: false),
              ),
            ),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          decoration: BoxDecoration(
            color: vc.surface,
            border: Border(top: BorderSide(color: vc.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                GestureDetector(
                  onTap: busy ? null : () => _pickAndUploadFile(provider),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: vc.background,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: vc.popupBorder),
                    ),
                    child: Icon(Icons.attach_file,
                        color: busy ? vc.textMuted : VividColors.cyan,
                        size: 20),
                  ),
                ),
                const SizedBox(width: 6),

                // Emoji button
                GestureDetector(
                  onTap: busy
                      ? null
                      : () {
                          setState(
                              () => _showEmojiPicker = !_showEmojiPicker);
                          if (!_showEmojiPicker) _focusNode.requestFocus();
                        },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _showEmojiPicker
                          ? VividColors.cyan.withValues(alpha: 0.15)
                          : vc.background,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: _showEmojiPicker
                            ? VividColors.cyan.withValues(alpha: 0.5)
                            : vc.popupBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _showEmojiPicker ? '\u2328\uFE0F' : '\uD83D\uDE0A',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: vc.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: vc.popupBorder),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      enabled: !busy,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(provider),
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      style:
                          TextStyle(color: vc.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _isUploading
                            ? 'Uploading...'
                            : _isSending
                                ? 'Sending...'
                                : 'Type a message...',
                        hintStyle: TextStyle(color: vc.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Send button
                GestureDetector(
                  onTap: busy ? null : () => _sendMessage(provider),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: busy ? null : VividColors.primaryGradient,
                      color: busy ? vc.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: busy
                          ? null
                          : [
                              BoxShadow(
                                color: VividColors.brightBlue
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: VividColors.cyan,
                              ),
                            )
                          : Icon(Icons.send_rounded,
                              color: vc.background, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ============================================
// MESSAGE BUBBLE
// ============================================

class _MessageBubble extends StatefulWidget {
  final OutreachMessage message;

  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isHovered = false;

  TextDirection _textDirection() {
    final text = widget.message.displayText;
    if (text.isEmpty) return TextDirection.ltr;
    final firstChar = text.trim().characters.first;
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(firstChar) ? TextDirection.rtl : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isOutbound = widget.message.isOutbound;
    final hasMedia = widget.message.mediaUrl != null &&
        widget.message.mediaUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          mainAxisAlignment:
              isOutbound ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isOutbound) const Spacer(flex: 1),
            Flexible(
              flex: 3,
              child: Column(
                crossAxisAlignment: isOutbound
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender label
                  if (isOutbound)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.message.sentBy == 'ai'
                                ? Icons.smart_toy
                                : Icons.support_agent,
                            size: 11,
                            color: widget.message.sentBy == 'ai'
                                ? VividColors.cyan
                                : VividColors.brightBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.message.sentBy == 'ai'
                                ? 'Vivid AI'
                                : 'Manager',
                            style: TextStyle(
                              color: widget.message.sentBy == 'ai'
                                  ? VividColors.cyan
                                  : VividColors.brightBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Bubble with hover copy
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isOutbound
                              ? const Color(0xFF2563EB)
                              : vc.surfaceAlt,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(isOutbound ? 16 : 4),
                            bottomRight:
                                Radius.circular(isOutbound ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer name for inbound
                            if (!isOutbound &&
                                widget.message.customerName != null &&
                                widget.message.customerName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  widget.message.customerName!,
                                  style: TextStyle(
                                    color: VividColors.cyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            // Media content
                            if (hasMedia) ...[
                              _buildMediaContent(vc),
                              if (widget.message.displayText.isNotEmpty)
                                const SizedBox(height: 6),
                            ],
                            // Message text
                            if (widget.message.displayText.isNotEmpty)
                              SelectableText(
                                widget.message.displayText,
                                textDirection: _textDirection(),
                                style: TextStyle(
                                  color: isOutbound
                                      ? Colors.white
                                      : vc.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            // Timestamp
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(widget.message.createdAt),
                              style: TextStyle(
                                color: isOutbound
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : vc.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Copy button on hover
                      if (_isHovered)
                        Positioned(
                          top: -4,
                          right: isOutbound ? null : -4,
                          left: isOutbound ? -4 : null,
                          child: GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: widget.message.displayText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Message copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: vc.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.15),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(Icons.copy,
                                  size: 12, color: vc.textMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isOutbound) const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(VividColorScheme vc) {
    final msg = widget.message;
    final isOutbound = msg.isOutbound;

    if (msg.mediaType == 'image') {
      return GestureDetector(
        onTap: () => _openFullscreenImage(context, msg.mediaUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
            child: Image.network(
              msg.mediaUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: VividColors.cyan),
                  ),
                );
              },
              errorBuilder: (context, error, stack) {
                return Container(
                  width: 200,
                  height: 80,
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(Icons.broken_image,
                        color: vc.textMuted, size: 32),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // Document / generic media
    return GestureDetector(
      onTap: () => _downloadFile(msg.mediaUrl!),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isOutbound ? Colors.white : vc.background)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isOutbound
                  ? Colors.white.withValues(alpha: 0.2)
                  : vc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              msg.mediaType == 'document'
                  ? Icons.picture_as_pdf
                  : Icons.attach_file,
              color: msg.mediaType == 'document'
                  ? const Color(0xFFEF4444)
                  : VividColors.cyan,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                msg.mediaFilename ?? 'Document',
                style: TextStyle(
                  color: isOutbound ? Colors.white : vc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download, size: 18,
                color: isOutbound
                    ? Colors.white.withValues(alpha: 0.7)
                    : VividColors.cyan),
          ],
        ),
      ),
    );
  }

  void _openFullscreenImage(BuildContext context, String imageUrl) {
    final vc = context.vividColors;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _downloadFile(imageUrl),
                    icon: const Icon(Icons.download,
                        color: Colors.white, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String fileUrl) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode != 200) return;

      final filename =
          fileUrl.split('/').last.split('?').first;
      final ext = filename.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

      final blob = html.Blob([response.bodyBytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('OUTREACH: download error: $e');
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }
}
