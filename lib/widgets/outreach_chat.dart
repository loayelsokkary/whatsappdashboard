import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/outreach_models.dart';
import '../providers/outreach_provider.dart';
import '../theme/vivid_theme.dart';

/// Split-view conversation widget for Vivid Outreach.
/// Left panel: contact list with last message preview.
/// Right panel: chat bubbles + message input.
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
        return _ContactListPanel();
      }

      return Row(
        children: [
          SizedBox(
            width: _listWidth.clamp(240, constraints.maxWidth * 0.4),
            child: _ContactListPanel(),
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
                  child: Container(
                    width: 1,
                    color: vc.border,
                  ),
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

class _ContactListPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();
    final contacts = provider.allContacts;

    return Container(
      color: vc.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: vc.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat, size: 18, color: VividColors.cyan),
                    const SizedBox(width: 8),
                    Text('Conversations',
                        style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: VividColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${contacts.length}',
                          style: TextStyle(
                              color: VividColors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Contact list
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text('No contacts yet',
                        style: TextStyle(color: vc.textMuted, fontSize: 13)))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final isSelected =
                          provider.selectedContact?.id == contact.id;
                      return _ContactChatTile(
                        contact: contact,
                        isSelected: isSelected,
                        onTap: () => provider.selectContact(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactChatTile extends StatelessWidget {
  final OutreachContact contact;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContactChatTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? VividColors.cyan.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? VividColors.cyan : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: vc.border.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: contact.status.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(contact.displayName),
                  style: TextStyle(
                    color: contact.status.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + company
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.companyName,
                    style: TextStyle(color: vc.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: contact.status.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
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
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    return Container(
      color: vc.background,
      child: Column(
        children: [
          _buildChatHeader(context, vc, contact, provider),
          Expanded(child: _buildMessageList(context, vc, provider)),
          _buildInputArea(context, vc, provider),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context, VividColorScheme vc,
      OutreachContact contact, OutreachProvider provider) {
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: contact.status.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(contact.displayName),
                style: TextStyle(
                  color: contact.status.color,
                  fontSize: 13,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('${contact.companyName} • ${contact.phone}',
                    style: TextStyle(color: vc.textMuted, fontSize: 11)),
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
          if (!provider.hasWebhook) ...[
            const SizedBox(width: 8),
            Tooltip(
              message:
                  'Webhook not configured — messages saved but not sent via WhatsApp',
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _MessageBubble(message: msg);
      },
    );
  }

  Widget _buildInputArea(
      BuildContext context, VividColorScheme vc, OutreachProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(top: BorderSide(color: vc.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: vc.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: vc.border),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: vc.textPrimary, fontSize: 13),
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(provider),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: VividColors.cyan,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isSending ? null : () => _sendMessage(provider),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
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

class _MessageBubble extends StatelessWidget {
  final OutreachMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isOutbound = message.isOutbound;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                          message.sentBy == 'ai'
                              ? Icons.smart_toy
                              : Icons.person,
                          size: 11,
                          color: message.sentBy == 'ai'
                              ? VividColors.cyan
                              : VividColors.brightBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          message.sentBy == 'ai' ? 'Vivid AI' : 'Manager',
                          style: TextStyle(
                            color: message.sentBy == 'ai'
                                ? VividColors.cyan
                                : VividColors.brightBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOutbound
                        ? const Color(0xFF2563EB)
                        : vc.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOutbound ? 16 : 4),
                      bottomRight: Radius.circular(isOutbound ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
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
                          message.customerName != null &&
                          message.customerName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.customerName!,
                            style: TextStyle(
                              color: VividColors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      // Message text
                      SelectableText(
                        message.displayText,
                        style: TextStyle(
                          color:
                              isOutbound ? Colors.white : vc.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      // Timestamp
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: isOutbound
                              ? Colors.white.withValues(alpha: 0.6)
                              : vc.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isOutbound) const Spacer(flex: 1),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }
}
