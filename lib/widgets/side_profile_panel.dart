import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';
import '../utils/initials_helper.dart';

/// Side Profile Panel — shows per-customer stats in a 296px collapsible panel.
class SideProfilePanel extends StatefulWidget {
  final String customerPhone;
  final String? customerName;
  final SupabaseService service;

  const SideProfilePanel({
    super.key,
    required this.customerPhone,
    this.customerName,
    required this.service,
  });

  @override
  State<SideProfilePanel> createState() => _SideProfilePanelState();
}

class _SideProfilePanelState extends State<SideProfilePanel> {
  CustomerProfileStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SideProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerPhone != widget.customerPhone) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.service
          .fetchCustomerProfileStats(widget.customerPhone);
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      width: 296,
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(
          left: BorderSide(color: vc.border),
        ),
      ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VividColors.cyan,
              ),
            )
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    final vc = context.vividColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: VividColors.statusUrgent, size: 32),
            const SizedBox(height: 12),
            Text(
              'Could not load profile',
              style: TextStyle(
                color: vc.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(color: VividColors.cyan)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final stats = _stats!;
    final name = widget.customerName ?? widget.customerPhone;
    final initials = getInitials(name);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      children: [
        _buildProfileHeader(name, initials),
        const SizedBox(height: 20),
        _buildStatsRow(stats),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Messages',
          child: _buildMessagesBreakdown(stats),
        ),
        const SizedBox(height: 16),
        if (stats.labelsHistory.isNotEmpty) ...[
          _buildSection(
            title: 'Topics Discussed',
            child: _buildTopics(stats.labelsHistory),
          ),
          const SizedBox(height: 16),
        ],
        if (stats.lastCampaignAt != null) ...[
          _buildSection(
            title: 'Last Campaign',
            child: _buildLastCampaign(stats),
          ),
          const SizedBox(height: 16),
        ],
        if (stats.lastHandledBy != null) ...[
          _buildSection(
            title: 'Last Handled By',
            child: _buildLastHandledBy(stats.lastHandledBy!),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileHeader(String name, String initials) {
    final vc = context.vividColors;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: VividColors.brightBlue.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              initials,
              textDirection: isArabicText(initials) ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                color: VividColors.brightBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: vc.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 2),
        Text(
          widget.customerPhone,
          style: TextStyle(color: vc.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatsRow(CustomerProfileStats stats) {
    final lastContacted = stats.lastContactedAt;
    final lastContactedStr = lastContacted != null
        ? _formatDate(lastContacted)
        : '—';

    final responseRate = stats.broadcastCount > 0
        ? '${(stats.broadcastResponseRate * 100).toStringAsFixed(0)}%'
        : '—';

    return Row(
      children: [
        _buildStatChip(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Messages',
          value: stats.totalExchanges.toString(),
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          icon: Icons.schedule_rounded,
          label: 'Last Active',
          value: lastContactedStr,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          icon: Icons.campaign_outlined,
          label: 'Response',
          value: responseRate,
          highlight: stats.broadcastCount > 0,
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final vc = context.vividColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: vc.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight
                ? VividColors.cyan.withValues(alpha:0.3)
                : vc.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14,
                color: highlight ? VividColors.cyan : vc.textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: highlight ? VividColors.cyan : vc.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: vc.textMuted,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    final vc = context.vividColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: vc.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: vc.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: vc.border,
            ),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildMessagesBreakdown(CustomerProfileStats stats) {
    final total = stats.customerMessageCount + stats.agentMessageCount;
    final customerRatio = total > 0 ? stats.customerMessageCount / total : 0.5;

    return Column(
      children: [
        Row(
          children: [
            _buildMsgCountTile(
              icon: Icons.person_outline_rounded,
              label: 'Customer',
              count: stats.customerMessageCount,
              color: VividColors.statusSuccess,
            ),
            const SizedBox(width: 12),
            _buildMsgCountTile(
              icon: Icons.support_agent_rounded,
              label: 'Agent',
              count: stats.agentMessageCount,
              color: VividColors.brightBlue,
            ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Flexible(
                  flex: (customerRatio * 100).round(),
                  child: Container(
                    height: 4,
                    color: VividColors.statusSuccess,
                  ),
                ),
                Flexible(
                  flex: ((1 - customerRatio) * 100).round(),
                  child: Container(
                    height: 4,
                    color: VividColors.brightBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMsgCountTile({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    final vc = context.vividColors;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopics(List<String> labels) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) {
        final (color, icon) = _labelStyle(context, label);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha:0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                _capitalize(label),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLastCampaign(CustomerProfileStats stats) {
    final vc = context.vividColors;
    final dateStr = _formatDate(stats.lastCampaignAt!);
    final responseRate = stats.broadcastCount > 0
        ? '${(stats.broadcastResponseRate * 100).toStringAsFixed(0)}% replied'
        : null;

    return Row(
      children: [
        const Icon(Icons.campaign_outlined, size: 16, color: VividColors.cyan),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (responseRate != null)
                Text(
                  responseRate,
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Text(
          '${stats.broadcastCount} sent',
          style: TextStyle(
            color: vc.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLastHandledBy(String handledBy) {
    final vc = context.vividColors;
    final initials = getInitials(handledBy);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: VividColors.purpleBlue.withValues(alpha:0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: vc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _capitalize(handledBy),
          style: TextStyle(
            color: vc.textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  (Color, IconData) _labelStyle(BuildContext context, String label) {
    final l = label.toLowerCase();
    if (l.contains('payment') || l.contains('paid')) {
      return (VividColors.cyan, Icons.payments_outlined);
    }
    if (l.contains('appointment') || l.contains('booking')) {
      return (VividColors.statusSuccess, Icons.event_available_outlined);
    }
    if (l.contains('pricing') || l.contains('price')) {
      return (VividColors.statusWarning, Icons.attach_money_rounded);
    }
    if (l.contains('enquiry') || l.contains('inquiry') || l.contains('question')) {
      return (VividColors.brightBlue, Icons.help_outline_rounded);
    }
    if (l.contains('sent')) {
      return (VividColors.statusAI, Icons.send_outlined);
    }
    if (l.contains('replied')) {
      return (VividColors.statusSuccess, Icons.reply_outlined);
    }
    if (l.contains('needs') || l.contains('urgent')) {
      return (VividColors.statusUrgent, Icons.priority_high_rounded);
    }
    return (context.vividColors.textSecondary, Icons.label_outline_rounded);
  }
}

/// Animated wrapper that slides the panel in from the right.
class AnimatedSideProfilePanel extends StatelessWidget {
  final bool isOpen;
  final String customerPhone;
  final String? customerName;
  final SupabaseService service;

  const AnimatedSideProfilePanel({
    super.key,
    required this.isOpen,
    required this.customerPhone,
    this.customerName,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isOpen ? 296 : 0,
      child: isOpen
          ? OverflowBox(
              minWidth: 296,
              maxWidth: 296,
              alignment: Alignment.centerRight,
              child: SideProfilePanel(
                customerPhone: customerPhone,
                customerName: customerName,
                service: service,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
