import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversations_provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/conversation_list.dart';
import '../widgets/conversation_detail.dart';
import '../theme/vivid_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showMobileList = true; // For mobile: show list or detail

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationsProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: VividColors.darkGradient,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Breakpoints
            final isCompact = constraints.maxWidth < 600;
            final isMedium = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

            if (isCompact) {
              return _buildCompactLayout();
            } else if (isMedium) {
              return _buildMediumLayout(constraints);
            } else {
              return _buildLargeLayout(constraints);
            }
          },
        ),
      ),
    );
  }

  // Mobile layout: bottom nav or slide between panels
  Widget _buildCompactLayout() {
    final conversationsProvider = context.watch<ConversationsProvider>();
    final hasSelection = conversationsProvider.selectedConversation != null;

    return Column(
      children: [
        // Header bar with logo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: VividColors.navy,
            border: Border(
              bottom: BorderSide(
                color: VividColors.tealBlue.withOpacity(0.2),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (hasSelection && !_showMobileList)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: VividColors.textPrimary,
                    onPressed: () {
                      setState(() => _showMobileList = true);
                      conversationsProvider.clearSelection();
                    },
                  ),
                VividWidgets.icon(size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Vivid Dashboard',
                  style: TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Connection indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conversationsProvider.isConnected
                        ? VividColors.statusSuccess
                        : VividColors.statusUrgent,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: _showMobileList || !hasSelection
              ? ConversationListPanel(
                  onConversationTap: () {
                    setState(() => _showMobileList = false);
                  },
                )
              : ConversationDetailPanel(
                  conversation: conversationsProvider.selectedConversation!,
                ),
        ),
      ],
    );
  }

  // Tablet layout: sidebar collapsed or hidden, list + detail
  Widget _buildMediumLayout(BoxConstraints constraints) {
    final conversationsProvider = context.watch<ConversationsProvider>();
    final listWidth = constraints.maxWidth * 0.4; // 40% for list

    return Row(
      children: [
        // Slim sidebar
        const Sidebar(compact: true),
        // Conversation list - flexible width
        SizedBox(
          width: listWidth.clamp(280, 360),
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

  // Desktop layout: full sidebar + list + detail
  Widget _buildLargeLayout(BoxConstraints constraints) {
    final conversationsProvider = context.watch<ConversationsProvider>();

    // Calculate responsive widths
    final availableWidth = constraints.maxWidth - 72; // minus sidebar
    final listWidth = (availableWidth * 0.3).clamp(300.0, 420.0);
    return Row(
      children: [
        // Full sidebar
        const Sidebar(),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 500;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: isSmall ? 100 : 140,
                    height: isSmall ? 100 : 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VividColors.navy,
                      border: Border.all(
                        color: VividColors.tealBlue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: VividWidgets.icon(size: isSmall ? 50 : 70),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Select a conversation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: isSmall ? 18 : 22,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a conversation from the list',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VividColors.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Stats Cards - wrap on small screens
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildStatCard(
                        icon: Icons.priority_high,
                        label: 'Needs Reply',
                        count: provider.needsReplyCount,
                        color: VividColors.statusUrgent,
                        compact: isSmall,
                      ),
                      _buildStatCard(
                        icon: Icons.check_circle,
                        label: 'Replied',
                        count: provider.repliedCount,
                        color: VividColors.statusSuccess,
                        compact: isSmall,
                      ),
                      _buildStatCard(
                        icon: Icons.forum,
                        label: 'Total',
                        count: provider.totalCount,
                        color: VividColors.cyan,
                        compact: isSmall,
                      ),
                    ],
                  ),

                  // Connection Status
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isConnected
                              ? VividColors.statusSuccess
                              : VividColors.statusUrgent,
                          boxShadow: [
                            BoxShadow(
                              color: (provider.isConnected
                                      ? VividColors.statusSuccess
                                      : VividColors.statusUrgent)
                                  .withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.isConnected ? 'Connected' : 'Connecting...',
                        style: const TextStyle(
                          color: VividColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    bool compact = false,
  }) {
    return Container(
      width: compact ? 100 : 120,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: VividColors.navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: compact ? 20 : 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: VividColors.textMuted,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}