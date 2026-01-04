import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/manager_chat_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

/// Manager Chatbot Panel - Internal AI assistant for managers
/// Connects to Supabase + n8n for real AI responses
class ManagerChatPanel extends StatefulWidget {
  const ManagerChatPanel({super.key});

  @override
  State<ManagerChatPanel> createState() => _ManagerChatPanelState();
}

class _ManagerChatPanelState extends State<ManagerChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // Get agent_id from current user config
    // For Karisma, we use the client ID or a specific identifier
    final user = ClientConfig.currentUser;
    final agentId = ClientConfig.currentClient?.id ?? 'karisma';
    
    // Use user email or phone as identifier
    // You can change this to actual phone number if available
    final managerPhoneNumber = user?.email ?? 'manager@karisma.com';

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
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    context.read<ManagerChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _askQuickQuestion(String question) {
    _messageController.text = question;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VividColors.darkNavy,
            VividColors.navy,
          ],
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VividColors.navy,
        border: Border(
          bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VividColors.cyan, VividColors.brightBlue],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: VividColors.cyan.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vivid AI',
                  style: TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Consumer<ManagerChatProvider>(
                  builder: (context, provider, _) {
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: provider.isWaitingForResponse 
                                ? Colors.orange 
                                : Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          provider.isWaitingForResponse 
                              ? 'Thinking...' 
                              : 'Online • Ready to help',
                          style: TextStyle(
                            color: VividColors.textMuted.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Quick actions only - no refresh button
          _QuickActionButton(
            icon: Icons.calendar_today,
            tooltip: "Today's schedule",
            onTap: () => _askQuickQuestion("How many appointments do we have today?"),
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            icon: Icons.trending_up,
            tooltip: 'Business insights',
            onTap: () => _askQuickQuestion("Give me a summary of this week's performance"),
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            icon: Icons.people,
            tooltip: 'Customer stats',
            onTap: () => _askQuickQuestion("Who are our top customers this month?"),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ManagerChatProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: VividColors.cyan),
                SizedBox(height: 16),
                Text(
                  'Loading chat history...',
                  style: TextStyle(color: VividColors.textMuted),
                ),
              ],
            ),
          );
        }

        // Build message list with welcome message if empty
        final messages = provider.messages;
        final showWelcome = messages.isEmpty;

        // Auto-scroll when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: (showWelcome ? 1 : messages.length) + (provider.isWaitingForResponse ? 1 : 0),
          itemBuilder: (context, index) {
            // Welcome message
            if (showWelcome && index == 0) {
              return _buildWelcomeMessage();
            }

            // Typing indicator at the end
            if (provider.isWaitingForResponse && index == (showWelcome ? 1 : messages.length)) {
              return _buildTypingIndicator();
            }

            // Actual messages
            final messageIndex = showWelcome ? index - 1 : index;
            if (messageIndex < 0 || messageIndex >= messages.length) {
              return const SizedBox.shrink();
            }
            
            final message = messages[messageIndex];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VividColors.cyan, VividColors.brightBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const Text(
                    "Hi! I'm Vivid AI, your business assistant. You can ask me questions like:\n\n"
                    "• \"How many appointments do we have tomorrow?\"\n"
                    "• \"Show me this week's bookings\"\n"
                    "• \"Who are our most frequent customers?\"\n"
                    "• \"What's our busiest day?\"\n\n"
                    "How can I help you today?",
                    style: TextStyle(
                      color: VividColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(DateTime.now()),
                    style: TextStyle(
                      color: VividColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ManagerChatMessage message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [VividColors.cyan, VividColors.brightBlue],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? VividColors.brightBlue : VividColors.deepBlue,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.message,
                    style: TextStyle(
                      color: isUser ? Colors.white : VividColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withOpacity(0.6)
                          : VividColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: VividColors.tealBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VividColors.cyan, VividColors.brightBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  Widget _buildInputArea() {
    return Consumer<ManagerChatProvider>(
      builder: (context, provider, _) {
        final isDisabled = provider.isWaitingForResponse;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: VividColors.navy,
            border: Border(
              top: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.error != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: VividColors.deepBlue,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        enabled: !isDisabled,
                        style: const TextStyle(color: VividColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: isDisabled 
                              ? 'Waiting for response...' 
                              : 'Ask me anything about your business...',
                          hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.6)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: isDisabled ? null : (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: isDisabled 
                          ? null 
                          : LinearGradient(
                              colors: [VividColors.cyan, VividColors.brightBlue],
                            ),
                      color: isDisabled ? VividColors.deepBlue : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isDisabled ? null : [
                        BoxShadow(
                          color: VividColors.cyan.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isDisabled ? null : _sendMessage,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.send_rounded,
                            color: isDisabled 
                                ? VividColors.textMuted 
                                : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
// HELPER WIDGETS
// ============================================

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VividColors.deepBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              color: VividColors.cyan,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
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
      if (mounted) {
        _controller.repeat(reverse: true);
      }
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