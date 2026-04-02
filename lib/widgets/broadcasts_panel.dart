import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/broadcasts_provider.dart';
import '../providers/templates_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/initials_helper.dart';
import '../utils/toast_service.dart';
import '../services/impersonate_service.dart';

/// Broadcasts panel - shows campaign list and recipient details
class BroadcastsPanel extends StatefulWidget {
  const BroadcastsPanel({super.key});

  @override
  State<BroadcastsPanel> createState() => _BroadcastsPanelState();
}

class _BroadcastsPanelState extends State<BroadcastsPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BroadcastsProvider>().fetchBroadcasts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth < 900;

        if (isMobile) {
          return _buildMobileLayout();
        }

        final listWidth = isTablet
            ? constraints.maxWidth.clamp(240, 300).toDouble()
            : 360.0;

        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: _BroadcastsList(),
            ),
            Container(
              width: 1,
              color: vc.border,
            ),
            Expanded(
              child: _RecipientDetails(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    final vc = context.vividColors;
    final provider = context.watch<BroadcastsProvider>();

    if (provider.selectedBroadcast != null) {
      return Column(
        children: [
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
                  onPressed: () => provider.clearSelection(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    provider.selectedBroadcast!.campaignName ?? 'Broadcast',
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _RecipientDetails()),
        ],
      );
    }

    return _BroadcastsList();
  }
}

class _BroadcastsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<BroadcastsProvider>();

    return Container(
      color: vc.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: vc.border,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: VividColors.cyan, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Broadcasts',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: VividColors.brightBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${provider.broadcasts.length}',
                    style: const TextStyle(
                      color: VividColors.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!ImpersonateService.isImpersonating)
                GestureDetector(
                  onTap: provider.isAtLimit
                      ? null
                      : () => _showComposeBroadcastDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: provider.isAtLimit ? null : VividColors.primaryGradient,
                      color: provider.isAtLimit ? vc.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: provider.isAtLimit ? null : [
                        BoxShadow(
                          color: VividColors.brightBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: provider.isAtLimit ? vc.textMuted : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (provider.hasLimit) _buildMonthlyCounter(context, provider),
          Expanded(
            child: provider.broadcasts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: provider.broadcasts.length,
                        itemBuilder: (context, index) {
                          final broadcast = provider.broadcasts[index];
                          final isSelected =
                              provider.selectedBroadcast?.id == broadcast.id;
                          return _BroadcastCard(
                            broadcast: broadcast,
                            isSelected: isSelected,
                            onTap: () => provider.selectBroadcast(broadcast),
                            onEdit: broadcast.status == 'scheduled'
                                ? () => _showComposeBroadcastDialog(context, editBroadcast: broadcast)
                                : null,
                            onCancel: broadcast.status == 'scheduled'
                                ? () async {
                                    try {
                                      await provider.cancelScheduledBroadcast(broadcast.id);
                                      if (context.mounted) {
                                        VividToast.show(context,
                                          message: 'Broadcast cancelled',
                                          type: ToastType.success,
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        VividToast.show(context,
                                          message: 'Failed to cancel broadcast',
                                          type: ToastType.error,
                                        );
                                      }
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showComposeBroadcastDialog(BuildContext context, {Broadcast? editBroadcast}) {
    showDialog(
      context: context,
      builder: (context) => ComposeBroadcastDialog(editBroadcast: editBroadcast),
    );
  }

  Widget _buildMonthlyCounter(BuildContext context, BroadcastsProvider provider) {
    final vc = context.vividColors;
    final sent = provider.monthlySentCount;
    final limit = provider.monthlyLimit;
    final progress = limit > 0 ? (sent / limit).clamp(0.0, 1.0) : 0.0;
    final isAtLimit = provider.isAtLimit;

    final Color barColor;
    if (isAtLimit) {
      barColor = VividColors.statusUrgent;
    } else if (progress > 0.8) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = VividColors.cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isAtLimit
            ? VividColors.statusUrgent.withValues(alpha: 0.05)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: vc.border,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAtLimit ? Icons.warning_amber_rounded : Icons.bar_chart,
                size: 14,
                color: barColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Monthly Usage',
                style: TextStyle(
                  color: barColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$sent / $limit',
                style: TextStyle(
                  color: barColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: vc.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (isAtLimit) ...[
            const SizedBox(height: 6),
            const Text(
              'Monthly limit reached',
              style: TextStyle(
                color: VividColors.statusUrgent,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final vc = context.vividColors;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 64,
                color: vc.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No broadcasts yet',
                style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Campaigns will appear here',
                style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  final Broadcast broadcast;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;

  const _BroadcastCard({
    required this.broadcast,
    required this.isSelected,
    required this.onTap,
    this.onCancel,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final status = broadcast.status ?? 'sent';
    final isScheduled = status == 'scheduled';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? VividColors.brightBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? VividColors.cyan : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: vc.borderSubtle),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    broadcast.campaignName ?? 'Unnamed Campaign',
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            if (broadcast.messageContent != null)
              Text(
                broadcast.messageContent!,
                style: TextStyle(color: vc.textMuted, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: vc.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${broadcast.totalRecipients} recipients',
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                ),
                const Spacer(),
                if (isScheduled && broadcast.scheduledAt != null) ...[
                  Icon(Icons.schedule, size: 13, color: Colors.amber.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatScheduledDate(broadcast.scheduledAt!),
                    style: TextStyle(
                      color: Colors.amber.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else
                  Text(
                    _formatDate(broadcast.sentAt),
                    style: TextStyle(color: vc.textMuted, fontSize: 12),
                  ),
              ],
            ),
            if (isScheduled) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CardActionButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: VividColors.cyan,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _CardActionButton(
                    label: 'Cancel',
                    icon: Icons.cancel_outlined,
                    color: Colors.red.shade400,
                    onTap: onCancel,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatScheduledDate(DateTime dt) {
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final nowBh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(nowBh.year, nowBh.month, nowBh.day);
    final targetDay = DateTime(bh.year, bh.month, bh.day);

    final hour = bh.hour > 12 ? bh.hour - 12 : (bh.hour == 0 ? 12 : bh.hour);
    final minute = bh.minute.toString().padLeft(2, '0');
    final ampm = bh.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $ampm';

    if (targetDay == today) return 'Today $time';
    if (targetDay == today.add(const Duration(days: 1))) return 'Tomorrow $time';
    return '${_monthName(bh.month)} ${bh.day}, $time';
  }

  String _formatDate(DateTime dt) {
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final nowBh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(nowBh.year, nowBh.month, nowBh.day);
    final messageDay = DateTime(bh.year, bh.month, bh.day);

    final hour = bh.hour > 12 ? bh.hour - 12 : (bh.hour == 0 ? 12 : bh.hour);
    final minute = bh.minute.toString().padLeft(2, '0');
    final ampm = bh.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $ampm';

    if (messageDay == today) return time;
    if (messageDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (today.difference(messageDay).inDays < 7) return _dayName(bh.weekday);
    return '${_monthName(bh.month)} ${bh.day}';
  }

  static String _dayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'scheduled'  => ('Scheduled', Colors.amber.shade600, Icons.schedule),
      'sending'    => ('Sending', VividColors.brightBlue, Icons.send),
      'sent'       => ('Sent', Colors.green, Icons.check_circle_outline),
      'failed'     => ('Failed', Colors.red, Icons.error_outline),
      'cancelled'  => ('Cancelled', Colors.grey, Icons.cancel_outlined),
      'draft'      => ('Draft', Colors.grey, Icons.edit_outlined),
      _            => ('Sent', Colors.green, Icons.check_circle_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'sending')
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientDetails extends StatefulWidget {
  @override
  State<_RecipientDetails> createState() => _RecipientDetailsState();
}

class _RecipientDetailsState extends State<_RecipientDetails> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing(String currentName) {
    setState(() {
      _isEditing = true;
      _nameController.text = currentName;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveNewName(BroadcastsProvider provider, String broadcastId) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await provider.renameBroadcast(broadcastId, newName);
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        VividToast.show(context,
          message: 'Failed to rename: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<BroadcastsProvider>();
    final broadcast = provider.selectedBroadcast;

    if (broadcast == null) {
      return _buildEmptyState(vc);
    }

    final campaignName = broadcast.campaignName ?? 'Campaign Details';

    return Container(
      color: vc.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: vc.border,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: vc.popupBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: vc.popupBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: VividColors.cyan),
                            ),
                            filled: true,
                            fillColor: vc.surfaceAlt,
                          ),
                          onSubmitted: (_) => _saveNewName(provider, broadcast.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan))
                            : const Icon(Icons.check, color: Colors.green, size: 20),
                        onPressed: _isSaving ? null : () => _saveNewName(provider, broadcast.id),
                        tooltip: 'Save',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: vc.textMuted, size: 20),
                        onPressed: _cancelEditing,
                        tooltip: 'Cancel',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          campaignName,
                          style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: vc.textMuted, size: 18),
                        onPressed: () => _startEditing(campaignName),
                        tooltip: 'Rename campaign',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatFullDate(broadcast.sentAt),
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (broadcast.messageContent != null || broadcast.photo != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: vc.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vc.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message',
                            style: TextStyle(
                              color: vc.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final vc = context.vividColors;
                              final hasImage = broadcast.photo != null;
                              final hasText = broadcast.messageContent != null;
                              final isNarrow = constraints.maxWidth < 600;

                              final imageErrorWidget = Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: vc.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.broken_image_outlined, color: vc.textMuted, size: 32),
                              );

                              final textWidget = hasText
                                  ? Text(
                                      broadcast.messageContent!,
                                      style: TextStyle(
                                        color: vc.textPrimary,
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    )
                                  : const SizedBox.shrink();

                              if (!hasImage) return textWidget;

                              Widget buildTappableImage({
                                required double width,
                                required double height,
                                bool fullWidth = false,
                              }) {
                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: const EdgeInsets.all(24),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: InteractiveViewer(
                                                child: Image.network(
                                                  broadcast.photo!,
                                                  fit: BoxFit.contain,
                                                  loadingBuilder: (context, child, progress) {
                                                    if (progress == null) return child;
                                                    return const Center(
                                                      child: CircularProgressIndicator(color: VividColors.cyan),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 0,
                                              right: 0,
                                              child: IconButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.black54,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: vc.border,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          broadcast.photo!,
                                          width: fullWidth ? double.infinity : width,
                                          height: height,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => imageErrorWidget,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    buildTappableImage(width: 0, height: 160, fullWidth: true),
                                    if (hasText) const SizedBox(height: 12),
                                    if (hasText) textWidget,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildTappableImage(width: 220, height: 280),
                                  const SizedBox(width: 20),
                                  Expanded(child: textWidget),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Recipients',
                              style: TextStyle(
                                color: vc.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (provider.isLoadingRecipients)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: vc.textMuted,
                                ),
                              )
                            else
                              Text(
                                '(${provider.selectedBroadcast?.totalRecipients ?? provider.recipients.length})',
                                style: TextStyle(
                                  color: vc.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                        if (!provider.isLoadingRecipients &&
                            provider.selectedBroadcast!.totalRecipients > 0) ...[
                          const SizedBox(height: 10),
                          _DeliveryStats(
                            sentCount: provider.recipientSentCount,
                            failedCount: (provider.selectedBroadcast?.totalRecipients ?? 0) -
                                provider.recipientSentCount,
                            totalCount: provider.selectedBroadcast?.totalRecipients ?? 0,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.isLoadingRecipients)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (provider.recipients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No recipients yet',
                          style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.recipients.length,
                          itemBuilder: (context, index) {
                            final recipient = provider.recipients[index];
                            return _RecipientTile(recipient: recipient);
                          },
                        ),
                        if (provider.hasMoreRecipients)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: provider.isLoadingMoreRecipients
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : OutlinedButton(
                                    onPressed: () => provider.loadMoreRecipients(),
                                    child: Text(
                                      'Load more (${provider.recipients.length} of ${provider.selectedBroadcast?.totalRecipients ?? '?'})',
                                    ),
                                  ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(VividColorScheme vc) {
    return Container(
      color: vc.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 64,
              color: vc.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a broadcast',
              style: TextStyle(
                color: vc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View recipient details and delivery status',
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

  String _formatFullDate(DateTime dt) {
    final bh = dt.toUtc().add(const Duration(hours: 3));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final hour = bh.hour > 12 ? bh.hour - 12 : (bh.hour == 0 ? 12 : bh.hour);
    final minute = bh.minute.toString().padLeft(2, '0');
    final ampm = bh.hour >= 12 ? 'PM' : 'AM';
    return '${months[bh.month - 1]} ${bh.day}, ${bh.year} at $hour:$minute $ampm';
  }
}

class _DeliveryStats extends StatelessWidget {
  final int sentCount;
  final int failedCount;
  final int totalCount;

  const _DeliveryStats({
    required this.sentCount,
    required this.failedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final sent = sentCount;
    final failed = failedCount < 0 ? 0 : failedCount;
    final rate = totalCount > 0 ? (sent / totalCount * 100) : 0.0;

    return Row(
      children: [
        _buildStat(vc, 'Sent', sent.toString(), Colors.green),
        const SizedBox(width: 16),
        _buildStat(vc, 'Failed', failed.toString(), Colors.red),
        const SizedBox(width: 16),
        _buildStat(vc, 'Rate', '${rate.toStringAsFixed(1)}%', VividColors.cyan),
      ],
    );
  }

  Widget _buildStat(VividColorScheme vc, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            color: vc.textMuted,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final BroadcastRecipient recipient;

  const _RecipientTile({required this.recipient});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final bool isSent = recipient.status == 'accepted' || recipient.status == 'sent' || recipient.status == 'delivered';
    final Color statusColor = isSent ? Colors.green : Colors.red;
    final String statusLabel = isSent ? 'Delivered' : 'Failed';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: VividColors.brightBlue.withValues(alpha: 0.2),
            child: Builder(builder: (context) {
              final initials = _getInitials(recipient.displayName);
              return Text(
                initials,
                textDirection: isArabicText(initials) ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  color: VividColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.displayName,
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (recipient.customerPhone != null &&
                    recipient.customerName != null)
                  Text(
                    recipient.customerPhone!,
                    style: TextStyle(
                      color: vc.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSent ? Icons.check_circle : Icons.error_outline,
                  size: 12,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) => getInitials(name);
}

/// Public dialog for composing or scheduling a broadcast.
/// Used both from [BroadcastsPanel] and from the Vivid AI chat.
class ComposeBroadcastDialog extends StatefulWidget {
  final Broadcast? editBroadcast;
  final String? initialInstruction;
  final bool initiallyScheduled;

  const ComposeBroadcastDialog({
    super.key,
    this.editBroadcast,
    this.initialInstruction,
    this.initiallyScheduled = false,
  });

  @override
  State<ComposeBroadcastDialog> createState() => _ComposeBroadcastDialogState();
}

class _ComposeBroadcastDialogState extends State<ComposeBroadcastDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isScheduled = false;
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  WhatsAppTemplate? _selectedTemplate;

  bool get _isEditing => widget.editBroadcast != null;

  @override
  void initState() {
    super.initState();

    final edit = widget.editBroadcast;
    final existingInstruction = edit?.webhookPayload?['instruction'] as String?
        ?? widget.initialInstruction
        ?? '';
    _controller = TextEditingController(text: existingInstruction);

    // Default scheduled time: tomorrow at 9:00 AM BHT
    final nowBht = DateTime.now().toUtc().add(const Duration(hours: 3));
    final tomorrow = DateTime(nowBht.year, nowBht.month, nowBht.day + 1);

    if (edit?.scheduledAt != null) {
      final bht = edit!.scheduledAt!.toUtc().add(const Duration(hours: 3));
      _isScheduled = true;
      _scheduledDate = DateTime(bht.year, bht.month, bht.day);
      _scheduledTime = TimeOfDay(hour: bht.hour, minute: bht.minute);
    } else {
      _isScheduled = widget.initiallyScheduled;
      _scheduledDate = tomorrow;
      _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
    }

    Future.microtask(() => _focusNode.requestFocus());

    // Ensure templates are loaded so the picker is populated even if the
    // user has never visited the Templates screen in this session.
    Future.microtask(() {
      if (!mounted) return;
      final tProvider = context.read<TemplatesProvider>();
      if (tProvider.templates.isEmpty && !tProvider.isLoading) {
        tProvider.fetchTemplates();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final nowBht = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(nowBht.year, nowBht.month, nowBht.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate.isBefore(today) ? today : _scheduledDate,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'SELECT TIME (Bahrain GMT+3)',
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _confirm() async {
    final typed = _controller.text.trim();
    // If no instruction typed but a template is selected, use the template
    // label as the instruction so n8n knows what to do.
    // If neither is provided, show an error instead of silently doing nothing.
    final text = typed.isNotEmpty
        ? typed
        : (_selectedTemplate != null ? _selectedTemplate!.label : '');
    if (text.isEmpty) {
      VividToast.show(context,
        message: 'Please type an instruction or select a template',
        type: ToastType.error,
      );
      return;
    }

    final provider = context.read<BroadcastsProvider>();
    bool success;

    if (_isScheduled) {
      // Combine date + time (treated as BHT — provider converts to UTC)
      final scheduledBht = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      // Validate: scheduled time must be in the future (compare as BHT, 2-min buffer).
      // Construct a naive (timezone-unaware) DateTime for "now in Bahrain" so Dart
      // doesn't adjust for device local timezone when comparing with scheduledBht.
      final nowUtc = DateTime.now().toUtc();
      final nowBht = DateTime(
        nowUtc.year, nowUtc.month, nowUtc.day,
        nowUtc.hour, nowUtc.minute, nowUtc.second,
      ).add(const Duration(hours: 3));
      if (scheduledBht.isBefore(nowBht.subtract(const Duration(minutes: 2)))) {
        VividToast.show(context,
          message: 'Cannot schedule in the past — please select a future time',
          type: ToastType.error,
        );
        return;
      }

      success = await provider.scheduleBroadcast(
        text,
        scheduledBht,
        editBroadcastId: widget.editBroadcast?.id,
        templateName: _selectedTemplate?.name,
        targetSheet: _selectedTemplate?.targetSheet,
      );
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
        final formattedTime = _scheduledTime.format(context);
        final formattedDate = _formatPickedDate(scheduledBht);
        VividToast.show(context,
          message: 'Broadcast scheduled for $formattedDate at $formattedTime',
          type: ToastType.success,
        );
      }
    } else {
      success = await provider.sendBroadcast(text, templateName: _selectedTemplate?.name, targetSheet: _selectedTemplate?.targetSheet);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
        VividToast.show(context,
          message: 'Broadcast sent! Processing recipients...',
          type: ToastType.success,
        );
      }
    }
  }

  String _formatPickedDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final nowBht = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(nowBht.year, nowBht.month, nowBht.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);
    if (target == today) return 'Today';
    if (target == tomorrow) return 'Tomorrow';
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<BroadcastsProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width < 550
            ? MediaQuery.of(context).size.width * 0.9
            : 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: vc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: vc.popupBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: VividColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Scheduled Broadcast' : 'New Broadcast',
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Describe who should receive the message',
                        style: TextStyle(color: vc.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: vc.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: vc.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VividColors.cyan.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: VividColors.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Example: "send to Full Body Laser list"',
                      style: TextStyle(
                        color: vc.textMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Instruction input
            Container(
              decoration: BoxDecoration(
                color: vc.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: vc.popupBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !provider.isSending,
                maxLines: 4,
                style: TextStyle(color: vc.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. "send to all Calcium customers" or "send to Full Body Laser list"',
                  hintStyle: TextStyle(color: vc.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Template picker — tappable list matching outreach style
            Consumer<TemplatesProvider>(
              builder: (context, tProvider, _) {
                final templates = tProvider.templates
                    .where((t) => t.status.toUpperCase() == 'APPROVED')
                    .toList();
                if (templates.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Template',
                            style: TextStyle(
                                color: vc.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        Text('(optional)',
                            style: TextStyle(
                                color: vc.textMuted.withValues(alpha: 0.6),
                                fontSize: 11)),
                        if (_selectedTemplate != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _selectedTemplate = null),
                            child: const Text('Clear',
                                style: TextStyle(
                                    color: VividColors.cyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: vc.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: vc.border),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: templates.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: vc.border),
                        itemBuilder: (context, i) {
                          final t = templates[i];
                          final isSelected = _selectedTemplate?.id == t.id;
                          final isFirst = i == 0;
                          final isLast = i == templates.length - 1;
                          final radius = BorderRadius.vertical(
                            top: isFirst ? const Radius.circular(10) : Radius.zero,
                            bottom: isLast ? const Radius.circular(10) : Radius.zero,
                          );
                          return InkWell(
                            borderRadius: radius,
                            onTap: () => setState(
                                () => _selectedTemplate = isSelected ? null : t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? VividColors.cyan.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: radius,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? VividColors.cyan
                                            : vc.textPrimary,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: VividColors.cyan.withValues(
                                          alpha: isSelected ? 0.25 : 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t.language.toUpperCase(),
                                      style: const TextStyle(
                                          color: VividColors.cyan,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle,
                                        size: 16, color: VividColors.cyan),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_selectedTemplate != null &&
                        _selectedTemplate!.body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: vc.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: VividColors.cyan.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _selectedTemplate!.body,
                          style: TextStyle(
                              color: vc.textSecondary,
                              fontSize: 12,
                              height: 1.5),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // When to send toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vc.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ToggleOption(
                      label: 'Send Now',
                      icon: Icons.send,
                      selected: !_isScheduled,
                      onTap: () => setState(() => _isScheduled = false),
                    ),
                  ),
                  Expanded(
                    child: _ToggleOption(
                      label: 'Schedule for Later',
                      icon: Icons.schedule,
                      selected: _isScheduled,
                      onTap: () => setState(() => _isScheduled = true),
                    ),
                  ),
                ],
              ),
            ),

            // Schedule pickers
            if (_isScheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateTimePickerButton(
                      label: _formatPickedDate(_scheduledDate),
                      icon: Icons.calendar_today,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateTimePickerButton(
                      label: _scheduledTime.format(context),
                      icon: Icons.access_time,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: vc.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Times are in Bahrain time (GMT+3)',
                    style: TextStyle(color: vc.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],

            // Error
            if (provider.sendError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.sendError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: provider.isSending ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: provider.isSending ? null : _confirm,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: provider.isSending ? null : VividColors.primaryGradient,
                      color: provider.isSending ? vc.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: provider.isSending
                          ? null
                          : [
                              BoxShadow(
                                color: VividColors.brightBlue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.isSending) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VividColors.cyan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScheduled ? 'Scheduling...' : 'Sending...',
                            style: TextStyle(
                              color: vc.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            _isScheduled ? Icons.schedule : Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScheduled
                                ? (_isEditing ? 'Update Schedule' : 'Schedule Broadcast')
                                : 'Send Broadcast',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? VividColors.brightBlue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: selected
              ? Border.all(color: VividColors.cyan.withValues(alpha: 0.4))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? VividColors.cyan : vc.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? VividColors.cyan : vc.textMuted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimePickerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimePickerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: vc.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vc.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: VividColors.cyan),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: vc.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}