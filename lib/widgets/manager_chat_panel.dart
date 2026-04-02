import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/manager_chat_provider.dart';
import '../providers/broadcasts_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/date_formatter.dart';
import '../services/impersonate_service.dart';
import '../services/supabase_service.dart';
import 'broadcasts_panel.dart' show ComposeBroadcastDialog;

/// Manager Chatbot Panel with ChatGPT-style session history sidebar
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
    // Restore draft message from provider
    final draft = context.read<ManagerChatProvider>().draftMessage;
    if (draft.isNotEmpty) {
      _messageController.text = draft;
      _messageController.selection =
          TextSelection.collapsed(offset: draft.length);
    }
    _messageController.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    context.read<ManagerChatProvider>().draftMessage =
        _messageController.text;
  }

  void _initializeChat() {
    final user = ClientConfig.currentUser;
    final agentId = ClientConfig.currentClient?.id ?? 'default';
    final managerPhoneNumber = user?.email ?? 'manager@default.com';

    Future.microtask(() {
      if (!mounted) return;
      context.read<ManagerChatProvider>().initialize(
            agentId: agentId,
            managerPhoneNumber: managerPhoneNumber,
          );
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onDraftChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (ImpersonateService.isImpersonating) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    context.read<ManagerChatProvider>().clearDraft();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Container(
          color: vc.background,
          child: Row(
            children: [
              // ── Session history sidebar (desktop only) ───────
              if (!isMobile) ...[
                _SessionSidebar(
                  onSessionSelected: (sessionId) =>
                      context.read<ManagerChatProvider>().switchToSession(sessionId),
                  onNewChat: () =>
                      context.read<ManagerChatProvider>().startNewSession(),
                ),
                Container(width: 1, color: vc.border),
              ],
              // ── Chat area ────────────────────────────────────
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildMessages()),
                    _buildInput(),
                  ],
                ),
              ),
              // ── Prediction panel (HOB only, desktop only) ────
              if (!isMobile && ClientConfig.customerPredictionsTable != null) ...[
                Container(width: 1, color: vc.border),
                SizedBox(
                  width: 280,
                  child: _PredictionInsightsPanel(
                    onPrefillChat: (text) {
                      _messageController.text = text;
                      _focusNode.requestFocus();
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(bottom: BorderSide(color: vc.border)),
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

        final displayItems = <_ChatDisplayItem>[];
        const _broadcastRe = r'\[BROADCAST: ([^\]]+)\]';
        for (final msg in messages) {
          if (msg.userMessage != null && msg.userMessage!.isNotEmpty) {
            displayItems.add(_ChatDisplayItem(
              text: msg.userMessage!,
              isUser: true,
              createdAt: msg.createdAt,
            ));
          }
          if (msg.aiResponse != null && msg.aiResponse!.isNotEmpty) {
            final raw = msg.aiResponse!;
            final match = RegExp(_broadcastRe).firstMatch(raw);
            final cleanText = raw.replaceAll(RegExp(_broadcastRe), '').trim();
            displayItems.add(_ChatDisplayItem(
              text: cleanText.isNotEmpty ? cleanText : raw,
              isUser: false,
              createdAt: msg.createdAt,
              broadcastInstruction: match?.group(1),
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
                  _buildDateDivider(
                      DateFormatter.formatChatDate(item.createdAt)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    return _WelcomeBubble();
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
                    const Icon(Icons.chat_bubble_rounded,
                        size: 12, color: VividColors.cyan),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: vc.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: vc.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TypingDot(delay: 0),
                    SizedBox(width: 4),
                    _TypingDot(delay: 150),
                    SizedBox(width: 4),
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

        if (ImpersonateService.isImpersonating)
          return Container(
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
          );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: vc.surface,
            border: Border(top: BorderSide(color: vc.border)),
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
                      hintText: isSending
                          ? 'Waiting for response...'
                          : 'Type a message...',
                      hintStyle: TextStyle(color: vc.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Schedule a broadcast',
                child: GestureDetector(
                  onTap: isSending
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (_) => const ComposeBroadcastDialog(
                              initiallyScheduled: true,
                            ),
                          ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSending
                          ? vc.surfaceAlt
                          : Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: isSending
                            ? vc.border
                            : Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.schedule,
                        color: isSending ? vc.textMuted : Colors.amber.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    boxShadow: isSending
                        ? null
                        : [
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
}

// ============================================================
// SESSION SIDEBAR
// ============================================================

class _SessionSidebar extends StatelessWidget {
  final ValueChanged<String?> onSessionSelected;
  final VoidCallback onNewChat;

  const _SessionSidebar({
    required this.onSessionSelected,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Consumer<ManagerChatProvider>(
      builder: (context, provider, _) {
        final sessions = provider.sessions;
        final currentId = provider.currentSessionId;

        return Container(
          width: 250,
          color: vc.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 12, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: vc.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded,
                        color: VividColors.cyan, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat History',
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // New Chat button
              Padding(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: onNewChat,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: VividColors.cyan.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: VividColors.cyan, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'New Chat',
                          style: TextStyle(
                            color: VividColors.cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Session list
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: VividColors.cyan, strokeWidth: 2))
                    : sessions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No previous chats',
                              style: TextStyle(
                                color: vc.textMuted,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: sessions.length,
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final isActive = session.id == currentId ||
                                  (currentId == null && session.isLegacy);
                              return _SessionTile(
                                session: session,
                                isActive: isActive,
                                onTap: () => onSessionSelected(session.id),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? VividColors.cyan.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: VividColors.cyan.withOpacity(0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview text
            Text(
              session.isLegacy ? 'Legacy Messages' : session.preview,
              style: TextStyle(
                color: isActive ? VividColors.cyan : vc.textPrimary,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Date + count
            Row(
              children: [
                Text(
                  _formatDate(session.lastMessageAt),
                  style: TextStyle(color: vc.textMuted, fontSize: 11),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? VividColors.cyan.withOpacity(0.2)
                        : vc.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${session.messageCount}',
                    style: TextStyle(
                      color: isActive ? VividColors.cyan : vc.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}

// ============================================================
// WELCOME BUBBLE
// ============================================================

class _WelcomeBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 4, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_rounded,
                          size: 12, color: VividColors.cyan),
                      SizedBox(width: 4),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                  child: Text(
                    "Hi! I'm Vivid AI, your business assistant. Ask me anything about appointments, customers, or business insights!",
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
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
}

// ============================================================
// DISPLAY ITEM
// ============================================================

class _ChatDisplayItem {
  final String text;
  final bool isUser;
  final DateTime createdAt;
  final String? broadcastInstruction; // extracted from [BROADCAST: ...] in AI response

  _ChatDisplayItem({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.broadcastInstruction,
  });
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

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
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isUser) const Spacer(flex: 1),
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_rounded,
                            size: 12, color: VividColors.cyan),
                        SizedBox(width: 4),
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
                        const Icon(Icons.support_agent,
                            size: 12, color: VividColors.brightBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Manager',
                          style: const TextStyle(
                            color: VividColors.brightBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF2563EB)
                        : vc.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: vc.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        item.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : vc.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(item.createdAt),
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : vc.textPrimary.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      // Broadcast action buttons — only appears on AI messages with [BROADCAST: ...] marker
                      if (!isUser && item.broadcastInstruction != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Send Now
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ComposeBroadcastDialog(
                                    initialInstruction: item.broadcastInstruction,
                                    initiallyScheduled: false,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: VividColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: VividColors.cyan.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_rounded, size: 13, color: VividColors.cyan),
                                    SizedBox(width: 6),
                                    Text(
                                      'Confirm & Send',
                                      style: TextStyle(
                                        color: VividColors.cyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Schedule for Later
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ComposeBroadcastDialog(
                                    initialInstruction: item.broadcastInstruction,
                                    initiallyScheduled: true,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule, size: 13, color: Colors.amber.shade600),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Schedule for Later',
                                      style: TextStyle(
                                        color: Colors.amber.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

// ============================================================
// TYPING DOT ANIMATION
// ============================================================

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
              color: VividColors.cyan
                  .withValues(alpha: 0.6 + 0.4 * _animation.value),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// PREDICTION INSIGHTS PANEL  (HOB only — shown when
// ClientConfig.customerPredictionsTable != null)
// ============================================================

class _PredictionInsightsPanel extends StatefulWidget {
  final void Function(String) onPrefillChat;

  const _PredictionInsightsPanel({required this.onPrefillChat});

  @override
  State<_PredictionInsightsPanel> createState() => _PredictionInsightsPanelState();
}

class _PredictionInsightsPanelState extends State<_PredictionInsightsPanel> {
  PredictionStats? _stats;
  List<Map<String, dynamic>> _approvedTemplates = [];
  bool _loading = true;
  bool _refreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (isRefresh && mounted) setState(() => _refreshing = true);
    try {
      final stats = await SupabaseService.fetchPredictionStats();
      final templatesTable = ClientConfig.templatesTable;
      List<Map<String, dynamic>> templates = [];
      if (templatesTable != null && templatesTable.isNotEmpty) {
        final res = await SupabaseService.adminClient
            .from(templatesTable)
            .select('template_name, display_name')
            .eq('status', 'APPROVED');
        templates = (res as List).cast<Map<String, dynamic>>();
      }
      if (mounted) {
        setState(() {
          _stats = stats;
          _approvedTemplates = templates;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _refreshing = false; });
    }
  }

  void _showBroadcastModal(
    BuildContext context, {
    required String label,
    required int count,
    required String audienceDescription,
  }) {
    String? selectedTemplate;
    bool sending = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send Broadcast to $count $label customers?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_approvedTemplates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No approved templates found. Sync templates first.',
                      style: TextStyle(color: Colors.amber.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  value: selectedTemplate,
                  dropdownColor: const Color(0xFF1A1F2E),
                  decoration: InputDecoration(
                    labelText: 'Select Template',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: VividColors.cyan),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  hint: Text('Choose a template', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                  items: _approvedTemplates.map((t) {
                    final display = (t['display_name'] as String?)?.isNotEmpty == true
                        ? t['display_name'] as String
                        : t['template_name'] as String;
                    return DropdownMenuItem(
                      value: t['template_name'] as String,
                      child: Text(display),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => selectedTemplate = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedTemplate == null || sending)
                        ? null
                        : () async {
                            final instruction =
                                'Send $selectedTemplate to all customers who are $audienceDescription for a visit';
                            final messenger = ScaffoldMessenger.of(context);
                            final provider = context.read<BroadcastsProvider>();
                            setModalState(() => sending = true);
                            final success = await provider.sendBroadcast(instruction, templateName: selectedTemplate);
                            setModalState(() => sending = false);
                            if (context.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              messenger.showSnackBar(SnackBar(
                                content: Text(success
                                    ? 'Broadcast queued for $count customers'
                                    : 'Broadcast failed — check configuration or monthly limit'),
                                backgroundColor: success
                                    ? const Color(0xFF38A169)
                                    : const Color(0xFFE53E3E),
                                duration: Duration(seconds: success ? 2 : 4),
                              ));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VividColors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Send Broadcast', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Silently hide panel on any error / null stats
    if (!_loading && _stats == null) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFF0F1623),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1623),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                VividWidgets.icon(size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Broadcast Intelligence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Live prediction data',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Content ───────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionLabel('PRIORITY TARGETS'),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          context,
                          icon: Icons.warning_rounded,
                          iconColor: const Color(0xFFF87171),
                          label: 'Overdue',
                          count: _stats!.overdueCount,
                          subtitle: 'Past predicted visit date',
                          countColor: const Color(0xFFF87171),
                          audienceDescription: 'overdue',
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          context,
                          icon: Icons.schedule_rounded,
                          iconColor: const Color(0xFFFBBF24),
                          label: 'Due This Week',
                          count: _stats!.thisWeekCount,
                          subtitle: 'Predicted in next 7 days',
                          countColor: const Color(0xFFFBBF24),
                          audienceDescription: 'due this week',
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          context,
                          icon: Icons.calendar_month_rounded,
                          iconColor: VividColors.cyan,
                          label: 'Due This Month',
                          count: _stats!.thisMonthCount,
                          subtitle: 'Predicted in 8–30 days',
                          countColor: VividColors.cyan,
                          audienceDescription: 'due this month',
                        ),
                        const SizedBox(height: 16),
                        if (_stats!.serviceBreakdown.isNotEmpty) ...[
                          _buildSectionLabel('SERVICE BREAKDOWN'),
                          const SizedBox(height: 8),
                          _buildServiceBreakdown(),
                          const SizedBox(height: 16),
                        ],
                        _buildSectionLabel('QUICK ACTIONS'),
                        const SizedBox(height: 8),
                        _buildQuickAction(
                          context,
                          icon: Icons.send_rounded,
                          label: 'Send to Overdue Customers',
                          onTap: () => _showBroadcastModal(
                            context,
                            label: 'overdue',
                            count: _stats!.overdueCount,
                            audienceDescription: 'overdue',
                          ),
                        ),
                        if (_stats!.thisWeekCount > 0) ...[
                          const SizedBox(height: 6),
                          _buildQuickAction(
                            context,
                            icon: Icons.calendar_today_outlined,
                            label: 'Send to Due This Week',
                            onTap: () => _showBroadcastModal(
                              context,
                              label: 'due this week',
                              count: _stats!.thisWeekCount,
                              audienceDescription: 'due this week',
                            ),
                          ),
                        ],
                        if (_stats!.thisMonthCount > 0) ...[
                          const SizedBox(height: 6),
                          _buildQuickAction(
                            context,
                            icon: Icons.calendar_month_outlined,
                            label: 'Send to Due This Month',
                            onTap: () => _showBroadcastModal(
                              context,
                              label: 'due this month',
                              count: _stats!.thisMonthCount,
                              audienceDescription: 'due this month',
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          context,
                          icon: Icons.bar_chart_rounded,
                          label: 'Get Prediction Summary',
                          onTap: () => widget.onPrefillChat(
                            'Give me a summary of this week\'s customer predictions and who I should broadcast to',
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          context,
                          icon: Icons.refresh_rounded,
                          label: _refreshing
                              ? (ClientConfig.predictionsRefreshWebhookUrl != null
                                  ? 'Recalculating... (~14s)'
                                  : 'Refreshing...')
                              : 'Refresh Data',
                          onTap: _refreshing
                              ? null
                              : () async {
                                  setState(() => _refreshing = true);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final webhookUrl =
                                      ClientConfig.predictionsRefreshWebhookUrl;
                                  final table =
                                      ClientConfig.customerPredictionsTable;
                                  final clientId =
                                      ClientConfig.currentClient?.id;
                                  final clientName =
                                      ClientConfig.currentClient?.name;
                                  if (webhookUrl != null &&
                                      table != null &&
                                      clientId != null &&
                                      clientName != null) {
                                    await SupabaseService.refreshPredictions(
                                      webhookUrl: webhookUrl,
                                      predictionsTable: table,
                                      clientId: clientId,
                                      clientName: clientName,
                                    );
                                    await Future.delayed(
                                        const Duration(seconds: 14));
                                  }
                                  await _loadData(isRefresh: true);
                                  if (mounted) {
                                    setState(() => _refreshing = false);
                                    messenger.showSnackBar(const SnackBar(
                                      content: Text('Predictions updated'),
                                      backgroundColor: Color(0xFF38A169),
                                      duration: Duration(seconds: 2),
                                    ));
                                  }
                                },
                          loading: _refreshing,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Future<void> _showCustomerListDialog(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String audienceDescription,
  }) async {
    final table = ClientConfig.customerPredictionsTable;
    if (table == null || table.isEmpty) return;

    final rows = await SupabaseService.adminClient
        .from(table)
        .select()
        .order('days_until_predicted', ascending: true);

    final all = (rows as List)
        .map((r) => CustomerPrediction.fromJson(r as Map<String, dynamic>))
        .toList();

    // Filter by category
    final List<CustomerPrediction> filtered;
    switch (audienceDescription) {
      case 'overdue':
        filtered = all.where((c) => c.daysUntilPredicted < 0).toList()
          ..sort((a, b) => a.daysUntilPredicted.compareTo(b.daysUntilPredicted));
      case 'due this week':
        filtered = all
            .where((c) => c.daysUntilPredicted >= 0 && c.daysUntilPredicted <= 7)
            .toList()
          ..sort((a, b) => a.daysUntilPredicted.compareTo(b.daysUntilPredicted));
      case 'due this month':
        filtered = all
            .where((c) => c.daysUntilPredicted >= 8 && c.daysUntilPredicted <= 30)
            .toList()
          ..sort((a, b) => a.daysUntilPredicted.compareTo(b.daysUntilPredicted));
      default:
        filtered = all;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => _PriorityCustomerListDialog(
        title: title,
        icon: icon,
        iconColor: iconColor,
        customers: filtered,
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required int count,
    required String subtitle,
    required Color countColor,
    required String audienceDescription,
  }) {
    return GestureDetector(
      onTap: count > 0
          ? () => _showCustomerListDialog(
                context,
                title: label,
                icon: icon,
                iconColor: iconColor,
                audienceDescription: audienceDescription,
              )
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                ],
              ),
            ),
            Text(
              '$count',
              style: TextStyle(color: countColor, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceBreakdown() {
    final entries = _stats!.serviceBreakdown.entries.toList();
    final maxCount = entries.isEmpty ? 1 : entries.first.value;

    return Column(
      children: entries.map((e) {
        final fraction = maxCount > 0 ? e.value / maxCount : 0.0;
        return GestureDetector(
          onTap: () => widget.onPrefillChat('How many ${e.key} customers are overdue?'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${e.value}',
                      style: const TextStyle(
                        color: VividColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(VividColors.cyan),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: VividColors.cyan),
              )
            else
              Icon(icon, size: 14, color: VividColors.cyan),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Priority Customer List Dialog ───────────────────────────────

class _PriorityCustomerListDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<CustomerPrediction> customers;

  const _PriorityCustomerListDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.customers,
  });

  @override
  State<_PriorityCustomerListDialog> createState() =>
      _PriorityCustomerListDialogState();
}

class _PriorityCustomerListDialogState
    extends State<_PriorityCustomerListDialog> {
  String _search = '';
  static final _dateFmt = DateFormat('MMM d, yyyy');

  List<CustomerPrediction> get _filtered {
    if (_search.isEmpty) return widget.customers;
    final q = _search.toLowerCase();
    return widget.customers.where((c) {
      final name = c.customerName?.toLowerCase() ?? '';
      final phone = c.phone.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final items = _filtered;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AlertDialog(
      backgroundColor: vc.surface,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: vc.border)),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: widget.iconColor, size: 20),
            const SizedBox(width: 8),
            Text(widget.title,
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${widget.customers.length}',
                  style: TextStyle(
                      color: widget.iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: vc.textMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: isMobile ? screenWidth : 620,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                style: TextStyle(color: vc.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone…',
                  hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: vc.textMuted),
                  filled: true,
                  fillColor: vc.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VividColors.cyan),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('No customers found',
                          style:
                              TextStyle(color: vc.textMuted, fontSize: 13)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          _buildCustomerTile(vc, items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTile(VividColorScheme vc, CustomerPrediction c) {
    final daysVal = c.daysUntilPredicted;
    final String daysLabel;
    final Color daysColor;

    if (daysVal < 0) {
      daysLabel = '${daysVal.abs()}d overdue';
      daysColor = const Color(0xFFF87171);
    } else if (daysVal == 0) {
      daysLabel = 'Due today';
      daysColor = const Color(0xFFFBBF24);
    } else {
      daysLabel = 'In ${daysVal}d';
      daysColor = VividColors.cyan;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.customerName ?? 'Unknown',
                  style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: daysColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: daysColor.withValues(alpha: 0.3)),
                ),
                child: Text(daysLabel,
                    style: TextStyle(
                        color: daysColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone, size: 12, color: vc.textMuted),
              const SizedBox(width: 4),
              Text(c.phone,
                  style: TextStyle(color: vc.textMuted, fontSize: 12)),
              if (c.primaryService != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.spa, size: 12, color: vc.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(c.primaryService!,
                      style: TextStyle(color: vc.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.history, size: 12, color: vc.textMuted),
              const SizedBox(width: 4),
              Text(
                c.lastVisit != null
                    ? 'Last: ${_dateFmt.format(c.lastVisit!)}'
                    : 'No visit recorded',
                style: TextStyle(color: vc.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Icon(Icons.event, size: 12, color: vc.textMuted),
              const SizedBox(width: 4),
              Text(
                c.predictedNextVisit != null
                    ? 'Predicted: ${_dateFmt.format(c.predictedNextVisit!)}'
                    : '—',
                style: TextStyle(color: vc.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
