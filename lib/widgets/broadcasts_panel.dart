import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/broadcasts_provider.dart';
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
        // Broadcasts list
        SizedBox(
          width: 360,
          child: _BroadcastsList(),
        ),
        
        // Divider
        Container(
          width: 1,
          color: VividColors.tealBlue.withOpacity(0.2),
        ),
        
        // Recipient details
        Expanded(
          child: _RecipientDetails(),
        ),
      ],
    );
  }
}

// ============================================
// BROADCASTS LIST
// ============================================

class _BroadcastsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcastsProvider>();

    return Container(
      color: VividColors.darkNavy,
      child: Column(
        children: [
          // Header
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
              ],
            ),
          ),

          // List
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

// ============================================
// BROADCAST CARD
// ============================================

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
            // Campaign name
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
            
            // Message preview
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
            
            // Stats row
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
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

// ============================================
// RECIPIENT DETAILS
// ============================================

class _RecipientDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcastsProvider>();
    final broadcast = provider.selectedBroadcast;

    if (broadcast == null) {
      return _buildEmptyState();
    }

    final stats = provider.recipientStats;

    return Container(
      color: VividColors.navy,
      child: Column(
        children: [
          // Header with stats
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
                const SizedBox(height: 16),
                
                // Stats cards
                Row(
                  children: [
                    _StatCard(
                      label: 'Sent',
                      value: stats['sent'] ?? 0,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Delivered',
                      value: stats['delivered'] ?? 0,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Read',
                      value: stats['read'] ?? 0,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Failed',
                      value: stats['failed'] ?? 0,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message content
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

          // Recipients list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
          ),

          const SizedBox(height: 12),

          // Recipients list
          Expanded(
            child: ListView.builder(
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
}

// ============================================
// STAT CARD
// ============================================

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// RECIPIENT TILE
// ============================================

class _RecipientTile extends StatelessWidget {
  final BroadcastRecipient recipient;

  const _RecipientTile({required this.recipient});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VividColors.deepBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Avatar
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
          
          // Name & Phone
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
          
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: recipient.statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              recipient.status.toUpperCase(),
              style: TextStyle(
                color: recipient.statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
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