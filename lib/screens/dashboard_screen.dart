import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../widgets/conversation_list_panel.dart';
import '../widgets/conversation_detail.dart';
import '../theme/vivid_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VividColors.darkNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive breakpoints
          if (constraints.maxWidth < 600) {
            return _buildMobileLayout();
          } else if (constraints.maxWidth < 900) {
            return _buildMediumLayout(constraints);
          } else {
            return _buildLargeLayout(constraints);
          }
        },
      ),
    );
  }

  // Mobile: show list OR detail (not both)
  Widget _buildMobileLayout() {
    final conversationsProvider = context.watch<ConversationsProvider>();

    if (conversationsProvider.selectedConversation != null) {
      return Column(
        children: [
          // Back button header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: VividColors.navy,
              border: Border(
                bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: VividColors.textPrimary),
                  onPressed: () => conversationsProvider.clearSelection(),
                ),
                const Text(
                  'Back to Conversations',
                  style: TextStyle(color: VividColors.textPrimary),
                ),
              ],
            ),
          ),
          // Detail panel
          Expanded(
            child: ConversationDetailPanel(
              conversation: conversationsProvider.selectedConversation!,
            ),
          ),
        ],
      );
    }

    return const ConversationListPanel();
  }

  // Medium: list + detail side by side
  Widget _buildMediumLayout(BoxConstraints constraints) {
    final conversationsProvider = context.watch<ConversationsProvider>();
    final listWidth = constraints.maxWidth.clamp(280.0, 360.0) * 0.4;

    return Row(
      children: [
        // Conversation list
        SizedBox(
          width: listWidth.clamp(280.0, 360.0),
          child: const ConversationListPanel(),
        ),
        // Detail or empty state
        Expanded(
          child: conversationsProvider.selectedConversation != null
              ? ConversationDetailPanel(
                  conversation: conversationsProvider.selectedConversation!,
                )
              : _buildEmptyState(conversationsProvider),
        ),
      ],
    );
  }

  // Large: list + detail with more space
  Widget _buildLargeLayout(BoxConstraints constraints) {
    final conversationsProvider = context.watch<ConversationsProvider>();
    final listWidth = (constraints.maxWidth * 0.3).clamp(300.0, 420.0);

    return Row(
      children: [
        // Conversation list
        SizedBox(
          width: listWidth,
          child: const ConversationListPanel(),
        ),
        // Detail panel
        Expanded(
          child: conversationsProvider.selectedConversation != null
              ? ConversationDetailPanel(
                  conversation: conversationsProvider.selectedConversation!,
                )
              : _buildEmptyState(conversationsProvider),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ConversationsProvider provider) {
    return Container(
      color: VividColors.darkNavy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: VividColors.brightBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: VividColors.brightBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a conversation',
              style: TextStyle(
                color: VividColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${provider.totalCount} conversations available',
              style: const TextStyle(
                color: VividColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}