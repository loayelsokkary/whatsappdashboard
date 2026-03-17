import 'dart:js_interop';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../providers/conversations_provider.dart';
import '../providers/ai_settings_provider.dart';
import '../utils/toast_service.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/time_utils.dart';
import '../utils/date_formatter.dart';
import '../utils/audio_controller.dart';
import 'voice_message_bubble.dart';
import '../utils/initials_helper.dart';
import '../services/impersonate_service.dart';
import 'side_profile_panel.dart';

/// Set to true from outside (e.g. conversation list note icon) to open the
/// side profile panel for whichever conversation is currently shown.
final ValueNotifier<bool> openSideProfileNotifier = ValueNotifier(false);

class ConversationDetailPanel extends StatefulWidget {
  final Conversation conversation;

  const ConversationDetailPanel({
    super.key,
    required this.conversation,
  });

  @override
  State<ConversationDetailPanel> createState() => _ConversationDetailPanelState();
}

class _ConversationDetailPanelState extends State<ConversationDetailPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  int _previousMessageCount = 0;
  Set<String> _seenMessageIds = {};

  bool _showSideProfile = false;
  bool _avatarHovered = false;

  // AI Toggle loading state only
  bool _aiToggleLoading = false;
  bool _isUploading = false;
  bool _showEmojiPicker = false;
  bool _showCopied = false;
  String? _lastScrolledToHighlight;
  Message? _replyingTo;

  @override
  void initState() {
    super.initState();
    openSideProfileNotifier.addListener(_onOpenSideProfileRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _scrollToBottom(animate: false);
    });
  }

  void _onOpenSideProfileRequest() {
    if (openSideProfileNotifier.value && mounted) {
      openSideProfileNotifier.value = false;
      setState(() => _showSideProfile = true);
    }
  }

  @override
  void didUpdateWidget(ConversationDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      AudioController.instance.stop();
      if (_showSideProfile) setState(() => _showSideProfile = false);
    }
  }

  Future<void> _toggleAi(bool value) async {
    setState(() => _aiToggleLoading = true);

    final aiProvider = context.read<AiSettingsProvider>();
    final success = await aiProvider.toggleAi(widget.conversation.customerPhone, value);

    if (mounted) {
      setState(() => _aiToggleLoading = false);

      VividToast.show(context,
        message: success
            ? 'AI ${value ? "enabled" : "disabled"} for this customer'
            : 'Failed to update AI status',
        type: success ? ToastType.success : ToastType.error,
      );
    }
  }

  @override
  void dispose() {
    openSideProfileNotifier.removeListener(_onOpenSideProfileRequest);
    AudioController.instance.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    });
  }

  /// Scroll to a specific message by its exchange ID prefix
  void _scrollToHighlightedMessage(String exchangeId, List<Message> visibleMessages) {
    final index = visibleMessages.indexWhere((m) => m.id.startsWith(exchangeId));
    if (index < 0 || !_scrollController.hasClients) return;

    // Estimate position: each message ~80px average height
    final estimatedOffset = (index * 80.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleSend() async {
    if (ImpersonateService.isImpersonating) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ConversationsProvider>();
    final replyTo = _replyingTo;

    // Clear immediately
    _messageController.clear();
    setState(() => _replyingTo = null);
    _focusNode.requestFocus();

    // Send
    final success = await provider.sendMessage(
      widget.conversation.id,
      text,
      replyToMessage: replyTo,
    );

    if (!success && mounted) {
      VividToast.show(context,
        message: provider.error ?? 'Failed to send',
        type: ToastType.error,
      );
    }

    // Re-request focus after the next frame so it survives any rebuild
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
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
          VividToast.show(context,
            message: 'Could not read file',
            type: ToastType.error,
          );
        }
        return;
      }

      // Show caption dialog
      final caption = await _showCaptionDialog(file.name, file.extension?.toLowerCase());
      if (caption == null || !mounted) return; // User cancelled

      setState(() => _isUploading = true);

      final provider = context.read<ConversationsProvider>();
      final url = await provider.uploadMedia(bytes, file.name);

      if (url == null) {
        if (mounted) {
          setState(() => _isUploading = false);
          VividToast.show(context,
            message: 'Upload failed',
            type: ToastType.error,
          );
        }
        return;
      }

      // Determine media type from extension
      final ext = file.extension?.toLowerCase();
      final mediaType = (ext == 'jpg' || ext == 'jpeg' || ext == 'png')
          ? 'image'
          : 'document';

      await provider.sendMessage(
        widget.conversation.id,
        caption,
        mediaUrl: url,
        mediaType: mediaType,
        mediaFilename: file.name,
      );
    } catch (e) {
      if (mounted) {
        VividToast.show(context,
          message: 'Error: $e',
          type: ToastType.error,
        );
      }
    }

    if (mounted) {
      setState(() => _isUploading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isImage ? Icons.image : Icons.picture_as_pdf,
                color: isImage ? VividColors.cyan : const Color(0xFFEF4444),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Send File',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filename
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vc.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: vc.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: vc.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filename,
                        style: TextStyle(
                          color: vc.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Caption input
              TextField(
                controller: captionController,
                autofocus: true,
                maxLines: 3,
                style: TextStyle(color: vc.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Caption (optional)',
                  labelStyle: TextStyle(color: vc.textMuted),
                  hintText: 'Add a message...',
                  hintStyle: TextStyle(color: vc.textMuted.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: vc.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.popupBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.popupBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VividColors.cyan),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              style: TextButton.styleFrom(foregroundColor: vc.textMuted),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, captionController.text.trim()),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VividColors.brightBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<ConversationsProvider>();
    final messages = provider.messages;

    // Auto-scroll on new messages
    if (messages.length != _previousMessageCount) {
      _previousMessageCount = messages.length;
      _scrollToBottom();
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            color: vc.background,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessages(messages, provider.isLoadingMessages)),
                _buildInput(provider.isSending),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: _showSideProfile ? 296 : 0,
          child: ClipRect(
            child: SideProfilePanel(
              customerPhone: widget.conversation.customerPhone,
              customerName: widget.conversation.displayName,
              onClose: () => setState(() => _showSideProfile = false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(
          bottom: BorderSide(color: vc.border),
        ),
      ),
      child: Row(
        children: [
          // Avatar — tap to toggle side profile
          GestureDetector(
            onTap: () => setState(() => _showSideProfile = !_showSideProfile),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _avatarHovered = true),
              onExit: (_) => setState(() => _avatarHovered = false),
              child: AnimatedScale(
                scale: _avatarHovered ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _avatarHovered
                      ? VividColors.cyan.withValues(alpha: 0.25)
                      : _showSideProfile
                          ? VividColors.brightBlue.withValues(alpha: 0.35)
                          : VividColors.brightBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: _showSideProfile
                      ? Border.all(color: VividColors.brightBlue, width: 1.5)
                      : _avatarHovered
                          ? Border.all(color: VividColors.cyan, width: 1.5)
                          : null,
                ),
                child: Center(
                  child: Builder(builder: (context) {
                    final initials = _getInitials();
                    return Text(
                      initials,
                      textDirection: isArabicText(initials) ? TextDirection.rtl : TextDirection.ltr,
                      style: const TextStyle(
                        color: VividColors.brightBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    );
                  }),
                ),
              ),
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
                  widget.conversation.displayName,
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.conversation.customerPhone,
                        style: TextStyle(
                          color: vc.textMuted,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: vc.textMuted,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: widget.conversation.customerPhone,
                          ));
                          setState(() => _showCopied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _showCopied = false);
                          });
                        },
                      ),
                    ),
                    if (_showCopied) ...[
                      const SizedBox(width: 4),
                      const Text('Copied!', style: TextStyle(color: Colors.green, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Label button
          _buildLabelButton(),

          const SizedBox(width: 4),

          // Profile panel toggle
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Customer profile',
              icon: Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: _showSideProfile ? VividColors.cyan : vc.textMuted,
              ),
              onPressed: () => setState(() => _showSideProfile = !_showSideProfile),
            ),
          ),

          // AI Toggle (only for AI-enabled clients)
          if (ClientConfig.hasAiConversations) ...[
            const SizedBox(width: 4),
            _buildAiToggle(),
          ],
        ],
      ),
    );
  }

  Widget _buildLabelButton() {
    final vc = context.vividColors;
    final currentLabel = widget.conversation.label;
    final hasRevenueLabel = currentLabel == 'Appointment Booked' || currentLabel == 'Payment Done';

    return PopupMenuButton<String>(
      tooltip: 'Label conversation',
      color: vc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: vc.border),
      ),
      offset: const Offset(0, 40),
      onSelected: (label) {
        final provider = context.read<ConversationsProvider>();
        if (label == '_clear') {
          provider.setConversationLabel(widget.conversation.customerPhone, '');
        } else {
          provider.setConversationLabel(widget.conversation.customerPhone, label);
        }
      },
      itemBuilder: (_) => [
        _labelMenuItem('Appointment Booked', Icons.event_available, const Color(0xFF10B981),
            isActive: currentLabel == 'Appointment Booked'),
        _labelMenuItem('Payment Done', Icons.payments, const Color(0xFF06B6D4),
            isActive: currentLabel == 'Payment Done'),
        if (hasRevenueLabel) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: '_clear',
            child: Row(children: [
              Icon(Icons.close, size: 16, color: vc.textMuted),
              const SizedBox(width: 10),
              Text('Clear Label', style: TextStyle(color: vc.textMuted, fontSize: 13)),
            ]),
          ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasRevenueLabel
              ? (currentLabel == 'Appointment Booked'
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFF06B6D4).withValues(alpha: 0.15))
              : vc.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasRevenueLabel
                ? (currentLabel == 'Appointment Booked'
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : const Color(0xFF06B6D4).withValues(alpha: 0.4))
                : vc.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasRevenueLabel
                  ? (currentLabel == 'Appointment Booked' ? Icons.event_available : Icons.payments)
                  : Icons.label_outline,
              size: 16,
              color: hasRevenueLabel
                  ? (currentLabel == 'Appointment Booked' ? const Color(0xFF10B981) : const Color(0xFF06B6D4))
                  : vc.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              hasRevenueLabel ? currentLabel! : 'Label',
              style: TextStyle(
                color: hasRevenueLabel
                    ? (currentLabel == 'Appointment Booked' ? const Color(0xFF10B981) : const Color(0xFF06B6D4))
                    : vc.textMuted,
                fontSize: 12,
                fontWeight: hasRevenueLabel ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _labelMenuItem(String label, IconData icon, Color color, {bool isActive = false}) {
    final vc = context.vividColors;
    return PopupMenuItem(
      value: label,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: vc.textPrimary, fontSize: 13)),
        if (isActive) ...[
          const Spacer(),
          Icon(Icons.check, size: 16, color: color),
        ],
      ]),
    );
  }

  Widget _buildAiToggle() {
    final vc = context.vividColors;
    // Watch the provider for real-time updates
    final aiProvider = context.watch<AiSettingsProvider>();
    final aiEnabled = aiProvider.isAiEnabled(widget.conversation.customerPhone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: vc.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aiEnabled
              ? VividColors.cyan.withValues(alpha: 0.3)
              : VividColors.statusUrgent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_rounded,
            size: 18,
            color: aiEnabled ? VividColors.cyan : vc.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            'AI',
            style: TextStyle(
              color: aiEnabled ? VividColors.cyan : vc.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          if (_aiToggleLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VividColors.cyan,
              ),
            )
          else
            SizedBox(
              width: 40,
              height: 24,
              child: Switch(
                value: aiEnabled,
                onChanged: _toggleAi,
                activeColor: VividColors.cyan,
                activeTrackColor: VividColors.cyan.withValues(alpha: 0.3),
                inactiveThumbColor: vc.textMuted,
                inactiveTrackColor: vc.surfaceAlt,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessages(List<Message> messages, bool isLoading) {
    final vc = context.vividColors;
    if (isLoading && messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: VividColors.cyan),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: vc.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No messages yet', style: TextStyle(color: vc.textMuted)),
          ],
        ),
      );
    }

    // Filter out empty messages (keep media-only messages)
    final visibleMessages = messages.where((m) =>
        (m.content.isNotEmpty && m.content.trim().isNotEmpty) || m.hasMedia).toList();

    // Scroll to highlighted message from search
    final hlId = context.read<ConversationsProvider>().highlightedExchangeId;
    if (hlId != null && hlId != _lastScrolledToHighlight) {
      _lastScrolledToHighlight = hlId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlightedMessage(hlId, visibleMessages);
      });
    } else if (hlId == null) {
      _lastScrolledToHighlight = null;
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: visibleMessages.length,
      itemBuilder: (context, index) {
        final msg = visibleMessages[index];
        final isPending = msg.id.startsWith('pending_');

        // Check if this is a new message we haven't seen
        final isNew = !_seenMessageIds.contains(msg.id);
        if (isNew) {
          _seenMessageIds.add(msg.id);
        }

        // Show date divider if first message or different day from previous
        final showDateDivider = index == 0 ||
            DateFormatter.isDifferentDay(
              msg.createdAt, visibleMessages[index - 1].createdAt);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDateDivider)
              _buildDateDivider(DateFormatter.formatChatDate(msg.createdAt)),
            Builder(builder: (context) {
              final provider = context.watch<ConversationsProvider>();
              final hlId = provider.highlightedExchangeId;
              final isHighlighted = hlId != null && msg.id.startsWith(hlId);
              return _AnimatedMessageBubble(
                key: ValueKey(msg.id),
                message: msg,
                isPending: isPending,
                animate: isNew && isPending,
                isHighlighted: isHighlighted,
                onReply: (message) => setState(() {
                  _replyingTo = message;
                  _focusNode.requestFocus();
                }),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    final vc = context.vividColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: vc.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: vc.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: vc.border),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: vc.border, height: 1)),
        ],
      ),
    );
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursorPos = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final newText = text.substring(0, cursorPos) + emoji.emoji + text.substring(cursorPos);
    _messageController.text = newText;
    final newCursor = cursorPos + emoji.emoji.length;
    _messageController.selection = TextSelection.collapsed(offset: newCursor);
  }

  Color _replyBorderColor(SenderType type) {
    switch (type) {
      case SenderType.customer:
        return context.vividColors.surfaceAlt;
      case SenderType.ai:
        return VividColors.cyan;
      case SenderType.manager:
        return VividColors.brightBlue;
    }
  }

  String _replySenderName(Message msg) {
    switch (msg.senderType) {
      case SenderType.customer:
        return msg.senderName ?? widget.conversation.customerName ?? 'Customer';
      case SenderType.ai:
        return 'Vivid AI';
      case SenderType.manager:
        return ClientConfig.currentUserName;
    }
  }

  Widget _buildInput(bool isSending) {
    final vc = context.vividColors;
    final busy = isSending || _isUploading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji picker panel (above input bar)
        if (_showEmojiPicker)
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(
                top: BorderSide(color: vc.border),
              ),
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
                  noRecents: Text(
                    'No Recents',
                    style: TextStyle(fontSize: 16, color: vc.textMuted),
                  ),
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
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
          ),

        // Reply preview bar
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(
                top: BorderSide(color: vc.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _replyBorderColor(_replyingTo!.senderType),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _replySenderName(_replyingTo!),
                        style: TextStyle(
                          color: _replyBorderColor(_replyingTo!.senderType),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyingTo!.content.length > 50
                            ? '${_replyingTo!.content.substring(0, 50)}...'
                            : _replyingTo!.content,
                        style: TextStyle(
                          color: vc.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _replyingTo = null),
                  icon: Icon(Icons.close, size: 18, color: vc.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

        if (ImpersonateService.isImpersonating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: VividColors.statusWarning.withValues(alpha: 0.08),
              border: Border(top: BorderSide(color: VividColors.statusWarning.withValues(alpha: 0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 16, color: VividColors.statusWarning),
                const SizedBox(width: 8),
                Text(
                  'Read-only preview — messages cannot be sent',
                  style: TextStyle(color: VividColors.statusWarning, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: vc.surface,
            border: _replyingTo != null ? null : Border(
              top: BorderSide(color: vc.border),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upload progress indicator
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VividColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Uploading...',
                          style: TextStyle(color: vc.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attach button
                    GestureDetector(
                      onTap: busy ? null : _pickAndUploadFile,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: vc.background,
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(
                            color: vc.popupBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.attach_file,
                          color: busy ? vc.textMuted : VividColors.cyan,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Emoji button
                    GestureDetector(
                      onTap: busy ? null : () {
                        setState(() => _showEmojiPicker = !_showEmojiPicker);
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
                            _showEmojiPicker ? '⌨️' : '😊',
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
                          border: Border.all(
                            color: vc.popupBorder,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          enabled: !busy,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() => _showEmojiPicker = false);
                            }
                          },
                          style: TextStyle(color: vc.textPrimary, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: _isUploading
                                ? 'Uploading...'
                                : isSending
                                    ? 'Sending...'
                                    : 'Type a message...',
                            hintStyle: TextStyle(color: vc.textMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Send button
                    GestureDetector(
                      onTap: busy ? null : _handleSend,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: busy ? null : VividColors.primaryGradient,
                          color: busy ? vc.surfaceAlt : null,
                          borderRadius: BorderRadius.circular(23),
                          boxShadow: busy ? null : [
                            BoxShadow(
                              color: VividColors.brightBlue.withValues(alpha: 0.3),
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
                              : Icon(
                                  Icons.send_rounded,
                                  color: vc.background,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials() {
    return getInitials(widget.conversation.customerName ?? widget.conversation.customerPhone);
  }
}

// ============================================
// ANIMATED MESSAGE BUBBLE WRAPPER
// ============================================

class _AnimatedMessageBubble extends StatefulWidget {
  final Message message;
  final bool isPending;
  final bool animate;
  final bool isHighlighted;
  final ValueChanged<Message>? onReply;

  const _AnimatedMessageBubble({
    super.key,
    required this.message,
    this.isPending = false,
    this.animate = false,
    this.isHighlighted = false,
    this.onReply,
  });

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Animate in if this is a new message
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate when transitioning from pending to confirmed
    if (oldWidget.isPending && !widget.isPending) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOutbound = widget.message.senderType != SenderType.customer;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            isOutbound ? _slideAnimation.value : -_slideAnimation.value,
            0,
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: _MessageBubble(
        message: widget.message,
        isPending: widget.isPending,
        isHighlighted: widget.isHighlighted,
        onReply: widget.onReply,
      ),
    );
  }
}

// ============================================
// MESSAGE BUBBLE
// ============================================

class _MessageBubble extends StatefulWidget {
  final Message message;
  final bool isPending;
  final bool isHighlighted;
  final ValueChanged<Message>? onReply;

  const _MessageBubble({required this.message, this.isPending = false, this.isHighlighted = false, this.onReply});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;
  double _swipeOffset = 0;
  bool _showCopiedBubble = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isPending) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPending && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isPending && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onMenuSelected(String value) {
    if (value == 'reply') {
      widget.onReply?.call(widget.message);
    } else if (value == 'copy') {
      Clipboard.setData(ClipboardData(text: widget.message.content));
      setState(() => _showCopiedBubble = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showCopiedBubble = false);
      });
    }
  }

  void _handleSwipeReply() {
    if (widget.onReply != null) {
      widget.onReply!(widget.message);
    }
  }

  Widget _buildDropdownMenu() {
    final vc = context.vividColors;
    final hasText = widget.message.content.trim().isNotEmpty;
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        onSelected: _onMenuSelected,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: vc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: vc.popupBorder),
        ),
        icon: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _bubbleColor(vc).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: vc.textMuted,
          ),
        ),
        itemBuilder: (_) => [
          if (widget.onReply != null)
            PopupMenuItem<String>(
              value: 'reply',
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply, size: 16, color: vc.textPrimary),
                  const SizedBox(width: 8),
                  Text('Reply', style: TextStyle(color: vc.textPrimary, fontSize: 13)),
                ],
              ),
            ),
          if (hasText)
            PopupMenuItem<String>(
              value: 'copy',
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 16, color: vc.textPrimary),
                  const SizedBox(width: 8),
                  Text('Copy', style: TextStyle(color: vc.textPrimary, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isCustomer = widget.message.senderType == SenderType.customer;
    final isManager = widget.message.senderType == SenderType.manager;

    Widget bubble = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCustomer) const Spacer(flex: 1),

          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // Label for outbound messages
                if (!isCustomer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isManager ? Icons.support_agent : Icons.smart_toy,
                          size: 12,
                          color: isManager ? VividColors.brightBlue : VividColors.cyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isManager
                              ? (widget.message.senderName?.isNotEmpty == true ? widget.message.senderName! : ClientConfig.currentUserName)
                              : (ClientConfig.hasAiConversations ? 'Vivid AI' : 'System'),
                          style: TextStyle(
                            color: isManager ? VividColors.brightBlue : VividColors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.isPending) ...[
                          const SizedBox(width: 6),
                          _SendingIndicator(),
                        ],
                      ],
                    ),
                  ),

                // Bubble with swipe-to-reply + hover dropdown
                GestureDetector(
                  onHorizontalDragUpdate: widget.onReply != null ? (details) {
                    setState(() {
                      _swipeOffset = (_swipeOffset + details.delta.dx).clamp(0, 60);
                    });
                  } : null,
                  onHorizontalDragEnd: widget.onReply != null ? (details) {
                    if (_swipeOffset > 40) _handleSwipeReply();
                    setState(() => _swipeOffset = 0);
                  } : null,
                  onHorizontalDragCancel: widget.onReply != null ? () {
                    setState(() => _swipeOffset = 0);
                  } : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Reply icon behind the bubble during swipe
                      if (_swipeOffset > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Opacity(
                              opacity: (_swipeOffset / 40).clamp(0, 1),
                              child: Icon(
                                Icons.reply_rounded,
                                size: 20,
                                color: VividColors.cyan.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),

                      // The actual bubble
                      Transform.translate(
                        offset: Offset(_swipeOffset, 0),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isHovered = true),
                          onExit: (_) => setState(() => _isHovered = false),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: widget.isHighlighted
                                      ? Color.alphaBlend(Colors.amber.withValues(alpha: 0.25), _bubbleColor(vc))
                                      : _bubbleColor(vc),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isCustomer ? 4 : 16),
                                    bottomRight: Radius.circular(isCustomer ? 16 : 4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.isPending
                                          ? VividColors.brightBlue.withValues(alpha: 0.2)
                                          : Colors.black.withValues(alpha: 0.12),
                                      blurRadius: widget.isPending ? 8 : 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    // Customer name
                                    if (isCustomer && widget.message.senderName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          widget.message.senderName!,
                                          style: const TextStyle(
                                            color: VividColors.cyan,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                    // Quoted reply
                                    if (widget.message.replyToMessage != null)
                                      _buildQuotedReply(widget.message.replyToMessage!, vc),

                                    // Voice message player (replaces text for voice messages)
                                    if (isCustomer && widget.message.isVoiceMessage)
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(minWidth: 220),
                                        child: VoiceMessageBubble(message: widget.message),
                                      )
                                    else ...[
                                      // Media
                                      if (widget.message.hasMedia)
                                        _buildMediaContent(vc),
                                      if (widget.message.hasMedia && widget.message.content.trim().isNotEmpty)
                                        const SizedBox(height: 8),

                                      // Text (selectable for copy/highlight)
                                      if (widget.message.content.trim().isNotEmpty)
                                        SelectableText(
                                          widget.message.content,
                                          style: TextStyle(
                                            color: isManager ? vc.agentBubbleText : vc.textPrimary,
                                            fontSize: 15,
                                            height: 1.4,
                                          ),
                                          textDirection: _textDirection(),
                                        ),
                                    ],

                                    const SizedBox(height: 4),

                                    // Time + status + voice indicator
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: Text(
                                            widget.isPending ? 'Sending...' : _formatTime(widget.message.createdAt),
                                            key: ValueKey(widget.isPending ? 'pending' : 'sent'),
                                            style: TextStyle(
                                              color: isManager
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : vc.textPrimary.withValues(alpha: 0.5),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        if (!isCustomer && !widget.isPending) ...[
                                          const SizedBox(width: 4),
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: const Duration(milliseconds: 300),
                                            builder: (context, value, child) {
                                              return Transform.scale(
                                                scale: value,
                                                child: Opacity(
                                                  opacity: value,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: Icon(
                                              Icons.done_all,
                                              size: 14,
                                              color: VividColors.cyan.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // "Copied!" feedback overlay
                              if (_showCopiedBubble)
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Copied!',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),

                              // Dropdown arrow button (visible on hover / always on mobile)
                              if (widget.message.content.trim().isNotEmpty || widget.onReply != null)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: AnimatedOpacity(
                                    opacity: _isHovered ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: _buildDropdownMenu(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isCustomer) const Spacer(flex: 1),
        ],
      ),
    );

    // Wrap with pulse animation if pending
    if (widget.isPending) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnimation.value,
            child: child,
          );
        },
        child: bubble,
      );
    }

    return bubble;
  }

  Widget _buildQuotedReply(Message replied, VividColorScheme vc) {
    Color borderColor;
    String senderName;
    switch (replied.senderType) {
      case SenderType.customer:
        borderColor = vc.surfaceAlt;
        senderName = replied.senderName ?? 'Customer';
      case SenderType.ai:
        borderColor = VividColors.cyan;
        senderName = 'Vivid AI';
      case SenderType.manager:
        borderColor = VividColors.brightBlue;
        senderName = ClientConfig.currentUserName;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            style: TextStyle(
              color: borderColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replied.content.length > 50
                ? '${replied.content.substring(0, 50)}...'
                : replied.content,
            style: TextStyle(
              color: vc.textPrimary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _bubbleColor(VividColorScheme vc) {
    switch (widget.message.senderType) {
      case SenderType.customer:
        return vc.surfaceAlt;
      case SenderType.ai:
        return vc.aiBubble;
      case SenderType.manager:
        return Color(widget.isPending ? 0xCC2563EB : 0xFF2563EB);
    }
  }

  TextDirection _textDirection() {
    final text = widget.message.content;
    if (text.isEmpty) return TextDirection.ltr;
    final firstChar = text.trim().characters.first;
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(firstChar) ? TextDirection.rtl : TextDirection.ltr;
  }

  Widget _buildMediaContent(VividColorScheme vc) {
    final msg = widget.message;

    if (msg.isImage) {
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
                      strokeWidth: 2,
                      color: VividColors.cyan,
                    ),
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
                    child: Icon(Icons.broken_image, color: vc.textMuted, size: 32),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (msg.isDocument) {
      return GestureDetector(
        onTap: () => _downloadFile(msg.mediaUrl!),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: vc.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: vc.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg.mediaFilename ?? 'Document',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.download, size: 18, color: VividColors.cyan),
            ],
          ),
        ),
      );
    }

    // Generic media fallback
    return GestureDetector(
      onTap: () => _downloadFile(msg.mediaUrl!),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: vc.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: vc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, color: VividColors.cyan, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                msg.mediaFilename ?? 'Attachment',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, size: 18, color: VividColors.cyan),
          ],
        ),
      ),
    );
  }

  void _openFullscreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: VividColors.cyan),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _downloadFile(url),
                    icon: const Icon(Icons.download, color: Colors.white, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
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
      VividToast.show(context,
        message: 'Downloading...',
        type: ToastType.info,
        duration: const Duration(seconds: 2),
      );

      // Fetch file bytes
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      // Extract filename from URL path
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      String filename = segments.isNotEmpty ? segments.last : 'download';
      filename = filename.split('?').first; // Remove query params

      // Determine MIME type
      final ext = filename.toLowerCase().split('.').last;
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

      // Create blob and trigger download
      final blob = web.Blob(
        [response.bodyBytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      final blobUrl = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = blobUrl
        ..download = filename
        ..style.display = 'none';

      web.document.body!.append(anchor);
      anchor.click();

      // Cleanup
      Future.delayed(const Duration(milliseconds: 150), () {
        anchor.remove();
        web.URL.revokeObjectURL(blobUrl);
      });

      if (mounted) {
        VividToast.show(context,
          message: 'Downloaded: $filename',
          type: ToastType.success,
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        VividToast.show(context,
          message: 'Download failed: $e',
          type: ToastType.error,
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final hour = bh.hour;
    final minute = bh.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }
}

// ============================================
// SENDING INDICATOR (animated dots)
// ============================================

class _SendingIndicator extends StatefulWidget {
  @override
  State<_SendingIndicator> createState() => _SendingIndicatorState();
}

class _SendingIndicatorState extends State<_SendingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final bounce = (progress < 0.5)
                ? progress * 2
                : 2 - (progress * 2);

            return Container(
              margin: EdgeInsets.only(left: index > 0 ? 2 : 0),
              child: Transform.translate(
                offset: Offset(0, -2 * bounce),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withValues(alpha: 0.5 + (0.5 * bounce)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
