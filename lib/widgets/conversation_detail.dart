import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/time_utils.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ConversationsProvider>();
    final success = await provider.sendMessage(widget.conversation.id, text);

    if (success) {
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationsProvider>();
    final messages = provider.messages;

    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        return Container(
          color: VividColors.darkNavy,
          child: Column(
            children: [
              _buildHeader(isNarrow),
              Expanded(
                child: _buildMessageList(messages, provider.isLoadingMessages, isNarrow),
              ),
              _buildComposer(isNarrow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader([bool isNarrow = false]) {
    final statusInfo = _getStatusInfo(widget.conversation.status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: isNarrow ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          bottom: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Customer Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.conversation.displayName,
                        style: TextStyle(
                          color: VividColors.textPrimary,
                          fontSize: isNarrow ? 15 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status chip
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 6 : 10,
                        vertical: isNarrow ? 2 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.15),
                        border: Border.all(
                          color: statusInfo['color'].withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusInfo['icon'],
                            size: isNarrow ? 12 : 14,
                            color: statusInfo['color'],
                          ),
                          if (!isNarrow) ...[
                            const SizedBox(width: 6),
                            Text(
                              statusInfo['label'],
                              style: TextStyle(
                                color: statusInfo['color'],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: VividColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.conversation.customerPhone,
                      style: const TextStyle(
                        color: VividColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, bool isLoading, [bool isNarrow = false]) {
    if (isLoading && messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: VividColors.cyan),
            SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(color: VividColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: isNarrow ? 48 : 64,
              color: VividColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: VividColors.textMuted,
                fontSize: isNarrow ? 14 : 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: 16,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _MessageBubble(message: messages[index]);
      },
    );
  }

  Widget _buildComposer([bool isNarrow = false]) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 10 : 16),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          top: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: VividColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: VividColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: VividColors.darkNavy,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isNarrow ? 10 : 14,
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: VividColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _handleSendMessage,
              icon: Icon(
                Icons.send,
                color: VividColors.darkNavy,
                size: isNarrow ? 18 : 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(ConversationStatus status) {
    switch (status) {
      case ConversationStatus.needsReply:
        return {
          'label': 'Needs Reply',
          'color': VividColors.statusUrgent,
          'icon': Icons.priority_high,
        };
      case ConversationStatus.replied:
        return {
          'label': 'Replied',
          'color': VividColors.statusSuccess,
          'icon': Icons.check,
        };
    }
  }
}

/// Message Bubble Widget
class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isCustomer = message.senderType == SenderType.customer;
    final isAI = message.senderType == SenderType.ai;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCustomer) const Spacer(flex: 1),
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment:
                  isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // Sender label for non-customer messages
                if (!isCustomer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAI ? Icons.smart_toy : Icons.person,
                          size: 12,
                          color: isAI ? VividColors.cyan : VividColors.brightBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAI ? 'Vivid AI' : 'Agent',
                          style: TextStyle(
                            color: isAI ? VividColors.cyan : VividColors.brightBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _getBubbleColor(),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCustomer ? 4 : 16),
                      bottomRight: Radius.circular(isCustomer ? 16 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Customer name if available
                      if (isCustomer && message.senderName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.senderName!,
                            style: TextStyle(
                              color: VividColors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // Message text
                      Text(
                        message.content,
                        style: const TextStyle(
                          color: VividColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textDirection: _detectTextDirection(message.content),
                      ),

                      const SizedBox(height: 6),

                      // Timestamp
                      Text(
                        TimeUtils.formatTime(message.createdAt),
                        style: TextStyle(
                          color: VividColors.textPrimary.withOpacity(0.6),
                          fontSize: 10,
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
  }

  Color _getBubbleColor() {
    switch (message.senderType) {
      case SenderType.customer:
        return VividColors.deepBlue;
      case SenderType.ai:
        return VividColors.tealBlue.withOpacity(0.6);
      case SenderType.humanAgent:
        return VividColors.brightBlue;
    }
  }

  TextDirection _detectTextDirection(String text) {
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    if (arabicPattern.hasMatch(text)) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }
}