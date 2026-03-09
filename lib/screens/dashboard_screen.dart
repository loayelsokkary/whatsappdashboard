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
  double? _listWidth;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Scaffold(
      backgroundColor: vc.background,
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
    final vc = context.vividColors;
    final conversationsProvider = context.watch<ConversationsProvider>();

    if (conversationsProvider.selectedConversation != null) {
      return Column(
        children: [
          // Back button header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(
                bottom: BorderSide(color: vc.border),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: vc.textPrimary),
                  onPressed: () => conversationsProvider.clearSelection(),
                ),
                Text(
                  'Back to Conversations',
                  style: TextStyle(color: vc.textPrimary),
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
    final defaultWidth = (constraints.maxWidth * 0.4).clamp(280.0, 360.0);
    final listW = (_listWidth ?? defaultWidth).clamp(220.0, constraints.maxWidth * 0.6);

    return Row(
      children: [
        SizedBox(
          width: listW,
          child: const ConversationListPanel(),
        ),
        _buildResizableHandle(constraints),
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
    final defaultWidth = (constraints.maxWidth * 0.3).clamp(300.0, 420.0);
    final listW = (_listWidth ?? defaultWidth).clamp(220.0, constraints.maxWidth * 0.6);

    return Row(
      children: [
        SizedBox(
          width: listW,
          child: const ConversationListPanel(),
        ),
        _buildResizableHandle(constraints),
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

  Widget _buildResizableHandle(BoxConstraints constraints) {
    final vc = context.vividColors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            final current = _listWidth ?? (constraints.maxWidth * 0.3).clamp(300.0, 420.0);
            _listWidth = (current + details.delta.dx).clamp(220.0, constraints.maxWidth * 0.6);
          });
        },
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: vc.popupBorder,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ConversationsProvider provider) {
    final vc = context.vividColors;
    return Container(
      color: vc.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: VividColors.brightBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: VividColors.brightBlue.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a conversation',
              style: TextStyle(
                color: vc.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${provider.totalCount} conversations available',
              style: TextStyle(
                color: vc.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
