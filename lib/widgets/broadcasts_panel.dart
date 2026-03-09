import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/broadcasts_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import '../utils/initials_helper.dart';

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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showComposeBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ComposeBroadcastDialog(),
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

  const _BroadcastCard({
    required this.broadcast,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
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
            bottom: BorderSide(
              color: vc.borderSubtle,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              broadcast.campaignName ?? 'Unnamed Campaign',
              style: TextStyle(
                color: vc.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (broadcast.messageContent != null)
              Text(
                broadcast.messageContent!,
                style: TextStyle(
                  color: vc.textMuted,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 14,
                  color: vc.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${broadcast.totalRecipients} recipients',
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(broadcast.sentAt),
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 12,
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
    final bh = dt.toUtc().add(const Duration(hours: 3));
    final nowBh = DateTime.now().toUtc().add(const Duration(hours: 3));
    final today = DateTime(nowBh.year, nowBh.month, nowBh.day);
    final messageDay = DateTime(bh.year, bh.month, bh.day);

    final hour = bh.hour > 12 ? bh.hour - 12 : (bh.hour == 0 ? 12 : bh.hour);
    final minute = bh.minute.toString().padLeft(2, '0');
    final ampm = bh.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $ampm';

    if (messageDay == today) {
      return time;
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (today.difference(messageDay).inDays < 7) {
      return _dayName(bh.weekday);
    } else {
      return '${_monthName(bh.month)} ${bh.day}';
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename: $e'), backgroundColor: Colors.red),
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
                            Text(
                              '(${provider.recipients.length})',
                              style: TextStyle(
                                color: vc.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (provider.recipients.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _DeliveryStats(recipients: provider.recipients),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.recipients.isEmpty)
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
  final List<BroadcastRecipient> recipients;

  const _DeliveryStats({required this.recipients});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final sent = recipients.where((r) => r.status == 'accepted' || r.status == 'sent' || r.status == 'delivered').length;
    final failed = recipients.length - sent;
    final rate = recipients.isNotEmpty
        ? (sent / recipients.length * 100)
        : 0.0;

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
            backgroundColor: VividColors.brightBlue.withOpacity(0.2),
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
              color: statusColor.withOpacity(0.15),
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

class _ComposeBroadcastDialog extends StatefulWidget {
  const _ComposeBroadcastDialog();

  @override
  State<_ComposeBroadcastDialog> createState() => _ComposeBroadcastDialogState();
}

class _ComposeBroadcastDialogState extends State<_ComposeBroadcastDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<BroadcastsProvider>();
    final success = await provider.sendBroadcast(text);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Broadcast sent! Processing recipients...'),
            ],
          ),
          backgroundColor: VividColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    // On failure, dialog stays open and provider.sendError is shown inline
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
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        'New Broadcast',
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Describe who should receive the message',
                        style: TextStyle(
                          color: vc.textMuted,
                          fontSize: 12,
                        ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: vc.surfaceAlt.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VividColors.cyan.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: VividColors.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Example: "Send {Name} an offer in english/arabic"',
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
                  hintText: 'Type your broadcast instruction...',
                  hintStyle: TextStyle(color: vc.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            if (provider.sendError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
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
                        provider.sendError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: provider.isSending ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: vc.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: provider.isSending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: provider.isSending ? null : VividColors.primaryGradient,
                      color: provider.isSending ? vc.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: provider.isSending ? null : [
                        BoxShadow(
                          color: VividColors.brightBlue.withOpacity(0.3),
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
                            'Sending...',
                            style: TextStyle(
                              color: vc.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          const Icon(Icons.send, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Send Broadcast',
                            style: TextStyle(
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