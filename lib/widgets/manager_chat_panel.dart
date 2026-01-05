import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/manager_chat_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

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
    return Container(
      color: VividColors.darkNavy,
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
          // Avatar - Vivid AI logo style
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: VividColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Consumer<ManagerChatProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vivid AI',
                      style: TextStyle(
                        color: VividColors.textPrimary,
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
                          style: const TextStyle(
                            color: VividColors.textMuted,
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
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: VividColors.cyan),
          );
        }

        final messages = provider.messages;
        
        // Auto-scroll when messages change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: messages.isEmpty 
              ? 1 
              : messages.length + (provider.isWaitingForResponse ? 1 : 0),
          itemBuilder: (context, index) {
            // Welcome message if empty
            if (messages.isEmpty && index == 0) {
              return _buildWelcomeMessage();
            }

            // Typing indicator
            if (provider.isWaitingForResponse && index == messages.length) {
              return _buildTypingIndicator();
            }

            return _MessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    return _buildAiBubble(
      "Hi! I'm Vivid AI, your business assistant. Ask me anything about appointments, customers, or business insights!",
      DateTime.now(),
    );
  }

  Widget _buildAiBubble(String text, DateTime time) {
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
                // Label
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
                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: VividColors.deepBlue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          color: VividColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(time),
                        style: TextStyle(
                          color: VividColors.textPrimary.withOpacity(0.5),
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
                    Icon(Icons.chat_bubble_rounded, size: 12, color: VividColors.cyan),
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
                  color: VividColors.deepBlue,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
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
        final isSending = provider.isWaitingForResponse;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VividColors.navy,
            border: Border(
              top: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: VividColors.darkNavy,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: !isSending,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(color: VividColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: isSending ? 'Waiting for response...' : 'Type a message...',
                      hintStyle: const TextStyle(color: VividColors.textMuted),
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
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ============================================
// MESSAGE BUBBLE
// ============================================

class _MessageBubble extends StatelessWidget {
  final ManagerChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

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
                // Label for AI messages
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

                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? VividColors.brightBlue.withOpacity(0.15) 
                        : VividColors.deepBlue,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser 
                          ? VividColors.brightBlue.withOpacity(0.3) 
                          : VividColors.tealBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.message,
                        style: const TextStyle(
                          color: VividColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: VividColors.textPrimary.withOpacity(0.5),
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
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
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
              color: VividColors.cyan.withOpacity(0.6 + 0.4 * _animation.value),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}