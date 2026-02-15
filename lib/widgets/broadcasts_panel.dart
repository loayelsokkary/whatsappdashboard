import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/broadcasts_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

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
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: _BroadcastsList(),
        ),
        Container(
          width: 1,
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
        Expanded(
          child: _RecipientDetails(),
        ),
      ],
    );
  }
}

class _BroadcastsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcastsProvider>();

    return Container(
      color: VividColors.darkNavy,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: VividColors.tealBlue.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: VividColors.cyan, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Broadcasts',
                  style: TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: VividColors.brightBlue.withOpacity(0.2),
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
                      color: provider.isAtLimit ? VividColors.deepBlue : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: provider.isAtLimit ? null : [
                        BoxShadow(
                          color: VividColors.brightBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: provider.isAtLimit ? VividColors.textMuted : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (provider.hasLimit) _buildMonthlyCounter(provider),
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: VividColors.cyan),
                  )
                : provider.broadcasts.isEmpty
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

  Widget _buildMonthlyCounter(BroadcastsProvider provider) {
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
            ? VividColors.statusUrgent.withOpacity(0.05)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.2),
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
              backgroundColor: VividColors.deepBlue,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (isAtLimit) ...[
            const SizedBox(height: 6),
            Text(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 64,
            color: VividColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No broadcasts yet',
            style: TextStyle(
              color: VividColors.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Campaigns will appear here',
            style: TextStyle(
              color: VividColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? VividColors.brightBlue.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? VividColors.cyan : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: VividColors.tealBlue.withOpacity(0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              broadcast.campaignName ?? 'Unnamed Campaign',
              style: TextStyle(
                color: VividColors.textPrimary,
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
                style: const TextStyle(
                  color: VividColors.textMuted,
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
                  color: VividColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${broadcast.totalRecipients} recipients',
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(broadcast.sentAt),
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

class _RecipientDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcastsProvider>();
    final broadcast = provider.selectedBroadcast;

    if (broadcast == null) {
      return _buildEmptyState();
    }

    return Container(
      color: VividColors.navy,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: VividColors.tealBlue.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  broadcast.campaignName ?? 'Campaign Details',
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFullDate(broadcast.sentAt),
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (broadcast.messageContent != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VividColors.deepBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VividColors.tealBlue.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message',
                    style: TextStyle(
                      color: VividColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    broadcast.messageContent!,
                    style: const TextStyle(
                      color: VividColors.textPrimary,
                      fontSize: 14,
                    ),
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
                    const Text(
                      'Recipients',
                      style: TextStyle(
                        color: VividColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${provider.recipients.length})',
                      style: const TextStyle(
                        color: VividColors.textMuted,
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
          Expanded(
            child: provider.recipients.isEmpty
                ? Center(
                    child: Text(
                      'No recipients yet',
                      style: TextStyle(
                        color: VividColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: provider.recipients.length,
                    itemBuilder: (context, index) {
                      final recipient = provider.recipients[index];
                      return _RecipientTile(recipient: recipient);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: VividColors.navy,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 64,
              color: VividColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a broadcast',
              style: TextStyle(
                color: VividColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View recipient details and delivery status',
              style: TextStyle(
                color: VividColors.textMuted,
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
    final sent = recipients.where((r) => r.status == 'accepted' || r.status == 'sent').length;
    final failed = recipients.length - sent;
    final rate = recipients.isNotEmpty
        ? (sent / recipients.length * 100)
        : 0.0;

    return Row(
      children: [
        _buildStat('Sent', sent.toString(), Colors.green),
        const SizedBox(width: 16),
        _buildStat('Failed', failed.toString(), Colors.red),
        const SizedBox(width: 16),
        _buildStat('Rate', '${rate.toStringAsFixed(1)}%', VividColors.cyan),
      ],
    );
  }

  Widget _buildStat(String label, String value, Color color) {
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
          style: const TextStyle(
            color: VividColors.textMuted,
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
    final bool isSent = recipient.status == 'accepted' || recipient.status == 'sent';
    final Color statusColor = isSent ? Colors.green : Colors.red;
    final String statusLabel = isSent ? 'Sent' : 'Failed';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: VividColors.brightBlue.withOpacity(0.2),
            child: Text(
              _getInitials(recipient.displayName),
              style: const TextStyle(
                color: VividColors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.displayName,
                  style: const TextStyle(
                    color: VividColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (recipient.customerPhone != null &&
                    recipient.customerName != null)
                  Text(
                    recipient.customerPhone!,
                    style: const TextStyle(
                      color: VividColors.textMuted,
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

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
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
    final provider = context.watch<BroadcastsProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: VividColors.navy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Broadcast',
                        style: TextStyle(
                          color: VividColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Describe who should receive the message',
                        style: TextStyle(
                          color: VividColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: VividColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VividColors.deepBlue.withOpacity(0.5),
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
                        color: VividColors.textMuted,
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
                color: VividColors.darkNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VividColors.tealBlue.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !provider.isSending,
                maxLines: 4,
                style: const TextStyle(color: VividColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Type your broadcast instruction...',
                  hintStyle: TextStyle(color: VividColors.textMuted),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: VividColors.textMuted),
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
                      color: provider.isSending ? VividColors.deepBlue : null,
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
                          const Text(
                            'Sending...',
                            style: TextStyle(
                              color: VividColors.textMuted,
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