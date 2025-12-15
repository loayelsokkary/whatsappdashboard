import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _scrollToBottom(animate: false);
    });
  }

  @override
  void dispose() {
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

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ConversationsProvider>();

    // Clear immediately
    _messageController.clear();
    _focusNode.requestFocus();

    // Send
    final success = await provider.sendMessage(widget.conversation.id, text);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(provider.error ?? 'Failed to send'),
            ],
          ),
          backgroundColor: VividColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationsProvider>();
    final messages = provider.messages;

    // Auto-scroll on new messages
    if (messages.length != _previousMessageCount) {
      _previousMessageCount = messages.length;
      _scrollToBottom();
    }

    return Container(
      color: VividColors.darkNavy,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessages(messages, provider.isLoadingMessages)),
          _buildInput(provider.isSending),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VividColors.brightBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: const TextStyle(
                  color: VividColors.brightBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.conversation.customerPhone,
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(List<Message> messages, bool isLoading) {
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
            Icon(Icons.chat_bubble_outline, size: 48, color: VividColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('No messages yet', style: TextStyle(color: VividColors.textMuted)),
          ],
        ),
      );
    }

    // Filter out empty messages
    final visibleMessages = messages.where((m) => 
        m.content.isNotEmpty && m.content.trim().isNotEmpty).toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: visibleMessages.length,
      itemBuilder: (context, index) {
        final msg = visibleMessages[index];
        final isPending = msg.id.startsWith('pending_');
        return _MessageBubble(message: msg, isPending: isPending);
      },
    );
  }

  Widget _buildInput(bool isSending) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          top: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: VividColors.darkNavy,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: VividColors.tealBlue.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  enabled: !isSending,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  style: const TextStyle(color: VividColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: isSending ? 'Sending...' : 'Type a message...',
                    hintStyle: const TextStyle(color: VividColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            
            // Send button
            GestureDetector(
              onTap: isSending ? null : _handleSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: isSending ? null : VividColors.primaryGradient,
                  color: isSending ? VividColors.deepBlue : null,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: isSending ? null : [
                    BoxShadow(
                      color: VividColors.brightBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VividColors.cyan,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: VividColors.darkNavy,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials() {
    final name = widget.conversation.customerName ?? widget.conversation.customerPhone;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ============================================
// MESSAGE BUBBLE
// ============================================

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isPending;

  const _MessageBubble({required this.message, this.isPending = false});

  @override
  Widget build(BuildContext context) {
    final isCustomer = message.senderType == SenderType.customer;
    final isManager = message.senderType == SenderType.manager;

    return Opacity(
      opacity: isPending ? 0.7 : 1.0,
      child: Padding(
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
                            isManager ? 'Manager' : 'Vivid AI',
                            style: TextStyle(
                              color: isManager ? VividColors.brightBlue : VividColors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 6),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: VividColors.cyan,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _bubbleColor(),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isCustomer ? 4 : 16),
                        bottomRight: Radius.circular(isCustomer ? 16 : 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                      children: [
                        // Customer name
                        if (isCustomer && message.senderName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              message.senderName!,
                              style: const TextStyle(
                                color: VividColors.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        // Text
                        Text(
                          message.content,
                          style: const TextStyle(
                            color: VividColors.textPrimary,
                            fontSize: 15,
                            height: 1.4,
                          ),
                          textDirection: _textDirection(),
                        ),

                        const SizedBox(height: 4),

                        // Time + status
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPending ? 'Sending...' : _formatTime(message.createdAt),
                              style: TextStyle(
                                color: VividColors.textPrimary.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            if (!isCustomer && !isPending) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: VividColors.cyan.withOpacity(0.7),
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
            
            if (isCustomer) const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Color _bubbleColor() {
    switch (message.senderType) {
      case SenderType.customer:
        return VividColors.deepBlue;
      case SenderType.ai:
        return VividColors.tealBlue.withOpacity(0.6);
      case SenderType.manager:
        return VividColors.brightBlue.withOpacity(0.8);
    }
  }

  TextDirection _textDirection() {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(message.content)) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}