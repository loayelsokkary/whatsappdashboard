import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/manager_chat_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/date_formatter.dart';

/// Manager Chatbot Panel - styled like conversation detail
class ManagerChatPanel extends StatefulWidget {
  const ManagerChatPanel({super.key});

  @override
  State<ManagerChatPanel> createState() => _ManagerChatPanelState();
}

class _ManagerChatPanelState extends State<ManagerChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    final user = ClientConfig.currentUser;
    final agentId = ClientConfig.currentClient?.id ?? 'default';
    final managerPhoneNumber = user?.email ?? 'manager@default.com';

    Future.microtask(() {
      context.read<ManagerChatProvider>().initialize(
        agentId: agentId,
        managerPhoneNumber: managerPhoneNumber,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _focusNode.requestFocus();
    context.read<ManagerChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      color: vc.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessages()),
          _buildInput(),
        ],
      ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: VividWidgets.icon(size: 56),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Consumer<ManagerChatProvider>(
              builder: (context, provider, _) {
                final vc = context.vividColors;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vivid AI',
                      style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: provider.isWaitingForResponse
                                ? Colors.orange
                                : VividColors.statusSuccess,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          provider.isWaitingForResponse
                              ? 'Thinking...'
                              : 'Online',
                          style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Consumer<ManagerChatProvider>(
      builder: (context, provider, _) {
        final messages = provider.messages;

        // Build display items: each message can have user + AI response
        final displayItems = <_ChatDisplayItem>[];
        for (final msg in messages) {
          if (msg.userMessage != null && msg.userMessage!.isNotEmpty) {
            displayItems.add(_ChatDisplayItem(
              text: msg.userMessage!,
              isUser: true,
              createdAt: msg.createdAt,
            ));
          }
          if (msg.aiResponse != null && msg.aiResponse!.isNotEmpty) {
            displayItems.add(_ChatDisplayItem(
              text: msg.aiResponse!,
              isUser: false,
              createdAt: msg.createdAt,
            ));
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: displayItems.isEmpty
              ? 1
              : displayItems.length + (provider.isWaitingForResponse ? 1 : 0),
          itemBuilder: (context, index) {
            if (displayItems.isEmpty && index == 0) {
              return _buildWelcomeMessage();
            }

            if (provider.isWaitingForResponse && index == displayItems.length) {
              return _buildTypingIndicator();
            }

            final item = displayItems[index];
            final showDateDivider = index == 0 ||
                DateFormatter.isDifferentDay(
                  item.createdAt, displayItems[index - 1].createdAt);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDateDivider)
                  _buildDateDivider(DateFormatter.formatChatDate(item.createdAt)),
                _MessageBubble(item: item),
              ],
            );
          },
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

  Widget _buildWelcomeMessage() {
    return _buildAiBubble(
      "Hi! I'm Vivid AI, your business assistant. Ask me anything about appointments, customers, or business insights!",
      DateTime.now(),
    );
  }

  Widget _buildAiBubble(String text, DateTime time) {
    final vc = context.vividColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_rounded,
                        size: 12,
                        color: VividColors.cyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vivid AI',
                        style: TextStyle(
                          color: VividColors.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: vc.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(time),
                        style: TextStyle(
                          color: vc.textPrimary.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final vc = context.vividColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_rounded,
                      size: 12,
                      color: VividColors.cyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vivid AI',
                      style: TextStyle(
                        color: VividColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: vc.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: vc.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TypingDot(delay: 0),
                    const SizedBox(width: 4),
                    _TypingDot(delay: 150),
                    const SizedBox(width: 4),
                    _TypingDot(delay: 300),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Consumer<ManagerChatProvider>(
      builder: (context, provider, _) {
        final vc = context.vividColors;
        final isSending = provider.isWaitingForResponse;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: vc.surface,
            border: Border(
              top: BorderSide(color: vc.border),
            ),
          ),
          child: Row(
            children: [
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
                    enabled: !isSending,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(color: vc.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: isSending ? 'Waiting for response...' : 'Type a message...',
                      hintStyle: TextStyle(color: vc.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isSending ? null : _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: isSending ? null : VividColors.primaryGradient,
                    color: isSending ? vc.surfaceAlt : null,
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: isSending ? null : [
                      BoxShadow(
                        color: VividColors.brightBlue.withValues(alpha: 0.3),
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
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final bh = time.toUtc().add(const Duration(hours: 3));
    final hour = bh.hour.toString().padLeft(2, '0');
    final minute = bh.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ============================================
// DISPLAY ITEM - represents one bubble
// ============================================

class _ChatDisplayItem {
  final String text;
  final bool isUser;
  final DateTime createdAt;

  _ChatDisplayItem({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });
}

// ============================================
// MESSAGE BUBBLE
// ============================================

class _MessageBubble extends StatelessWidget {
  final _ChatDisplayItem item;

  const _MessageBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isUser = item.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isUser) const Spacer(flex: 1),

          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 12,
                          color: VividColors.cyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Vivid AI',
                          style: TextStyle(
                            color: VividColors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 12,
                          color: VividColors.brightBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Manager',
                          style: TextStyle(
                            color: VividColors.brightBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? VividColors.brightBlue
                        : vc.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(
                      color: vc.border,
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
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        item.text,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(item.createdAt),
                        style: TextStyle(
                          color: vc.textPrimary.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!isUser) const Spacer(flex: 1),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final bh = time.toUtc().add(const Duration(hours: 3));
    final hour = bh.hour.toString().padLeft(2, '0');
    final minute = bh.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ============================================
// TYPING DOT ANIMATION
// ============================================

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: VividColors.cyan.withValues(alpha: 0.6 + 0.4 * _animation.value),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}
