import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/ai_settings_provider.dart';
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
  final FocusNode _focusNode = FocusNode();
  int _previousMessageCount = 0;
  Set<String> _seenMessageIds = {};
  
  // AI Toggle loading state only
  bool _aiToggleLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _scrollToBottom(animate: false);
    });
  }

  @override
  void didUpdateWidget(ConversationDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No need to load AI status - provider handles it
  }

  Future<void> _toggleAi(bool value) async {
    setState(() => _aiToggleLoading = true);
    
    final aiProvider = context.read<AiSettingsProvider>();
    final success = await aiProvider.toggleAi(widget.conversation.customerPhone, value);
    
    if (mounted) {
      setState(() => _aiToggleLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(success 
                  ? 'AI ${value ? "enabled" : "disabled"} for this customer'
                  : 'Failed to update AI status'),
            ],
          ),
          backgroundColor: success ? VividColors.statusSuccess : VividColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
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

          // AI Toggle
          _buildAiToggle(),
        ],
      ),
    );
  }

  Widget _buildAiToggle() {
    // Watch the provider for real-time updates
    final aiProvider = context.watch<AiSettingsProvider>();
    final aiEnabled = aiProvider.isAiEnabled(widget.conversation.customerPhone);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VividColors.darkNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aiEnabled 
              ? VividColors.cyan.withOpacity(0.3)
              : VividColors.statusUrgent.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_rounded,
            size: 18,
            color: aiEnabled ? VividColors.cyan : VividColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            'AI',
            style: TextStyle(
              color: aiEnabled ? VividColors.cyan : VividColors.textMuted,
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
                activeTrackColor: VividColors.cyan.withOpacity(0.3),
                inactiveThumbColor: VividColors.textMuted,
                inactiveTrackColor: VividColors.deepBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        
        // Check if this is a new message we haven't seen
        final isNew = !_seenMessageIds.contains(msg.id);
        if (isNew) {
          _seenMessageIds.add(msg.id);
        }
        
        return _AnimatedMessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isPending: isPending,
          animate: isNew && isPending, // Only animate new pending messages
        );
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
// ANIMATED MESSAGE BUBBLE WRAPPER
// ============================================

class _AnimatedMessageBubble extends StatefulWidget {
  final Message message;
  final bool isPending;
  final bool animate;

  const _AnimatedMessageBubble({
    super.key,
    required this.message,
    this.isPending = false,
    this.animate = false,
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

  const _MessageBubble({required this.message, this.isPending = false});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

  @override
  Widget build(BuildContext context) {
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
                          isManager ? 'Manager' : 'Vivid AI',
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

                // Bubble
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
                        color: widget.isPending 
                            ? VividColors.brightBlue.withOpacity(0.2)
                            : Colors.black.withOpacity(0.12),
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

                      // Text
                      Text(
                        widget.message.content,
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
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              widget.isPending ? 'Sending...' : _formatTime(widget.message.createdAt),
                              key: ValueKey(widget.isPending ? 'pending' : 'sent'),
                              style: TextStyle(
                                color: VividColors.textPrimary.withOpacity(0.5),
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
                                color: VividColors.cyan.withOpacity(0.7),
                              ),
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

  Color _bubbleColor() {
    switch (widget.message.senderType) {
      case SenderType.customer:
        return VividColors.deepBlue;
      case SenderType.ai:
        return VividColors.tealBlue.withOpacity(0.6);
      case SenderType.manager:
        return VividColors.brightBlue.withOpacity(widget.isPending ? 0.6 : 0.8);
    }
  }

  TextDirection _textDirection() {
    final text = widget.message.content;
    if (text.isEmpty) return TextDirection.ltr;
    final firstChar = text.trim().characters.first;
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(firstChar) ? TextDirection.rtl : TextDirection.ltr;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
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
                    color: VividColors.cyan.withOpacity(0.5 + (0.5 * bounce)),
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