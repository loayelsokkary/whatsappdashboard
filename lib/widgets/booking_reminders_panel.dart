import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/booking_reminders_provider.dart';
import '../theme/vivid_theme.dart';

class BookingRemindersPanel extends StatefulWidget {
  final String tableName;
  const BookingRemindersPanel({super.key, required this.tableName});

  @override
  State<BookingRemindersPanel> createState() => _BookingRemindersPanelState();
}

class _BookingRemindersPanelState extends State<BookingRemindersPanel> {
  Booking? _selectedBooking;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingRemindersProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            // Left: Bookings list
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: VividColors.navy,
                  border: Border(right: BorderSide(color: VividColors.tealBlue.withOpacity(0.2))),
                ),
                child: Column(
                  children: [
                    _buildHeader(provider),
                    _buildStatsRow(provider.stats),
                    _buildFilters(provider),
                    _buildSearchBar(provider),
                    Expanded(child: _buildBookingsList(provider)),
                  ],
                ),
              ),
            ),
            // Right: Details
            Expanded(
              flex: 3,
              child: _selectedBooking == null 
                  ? _buildEmptyDetail() 
                  : _buildBookingDetails(_selectedBooking!, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BookingRemindersProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: VividColors.brightBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_month, color: VividColors.cyan, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Reminders', style: TextStyle(color: VividColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Track appointment reminders', style: TextStyle(color: VividColors.textMuted, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => provider.refresh(),
            icon: const Icon(Icons.refresh, color: VividColors.textMuted),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BookingReminderStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatBadge(label: 'Total', value: stats.totalBookings, color: VividColors.textMuted),
          _StatBadge(label: 'Upcoming', value: stats.upcomingBookings, color: VividColors.brightBlue),
          _StatBadge(label: 'Sent', value: stats.remindersSent, color: Colors.orange),
          _StatBadge(label: 'Confirmed', value: stats.confirmed, color: VividColors.statusSuccess),
          _StatBadge(label: 'Cancelled', value: stats.cancelled, color: VividColors.statusUrgent),
        ],
      ),
    );
  }

  Widget _buildFilters(BookingRemindersProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', isSelected: provider.statusFilter == ReminderStatusFilter.all, onTap: () => provider.setStatusFilter(ReminderStatusFilter.all)),
                _FilterChip(label: 'Pending', isSelected: provider.statusFilter == ReminderStatusFilter.pending, onTap: () => provider.setStatusFilter(ReminderStatusFilter.pending), color: VividColors.textMuted),
                _FilterChip(label: 'Sent', isSelected: provider.statusFilter == ReminderStatusFilter.reminderSent, onTap: () => provider.setStatusFilter(ReminderStatusFilter.reminderSent), color: Colors.orange),
                _FilterChip(label: 'Confirmed', isSelected: provider.statusFilter == ReminderStatusFilter.confirmed, onTap: () => provider.setStatusFilter(ReminderStatusFilter.confirmed), color: VividColors.statusSuccess),
                _FilterChip(label: 'Cancelled', isSelected: provider.statusFilter == ReminderStatusFilter.cancelled, onTap: () => provider.setStatusFilter(ReminderStatusFilter.cancelled), color: VividColors.statusUrgent),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Date filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All Time', isSelected: provider.dateFilter == DateRangeFilter.all, onTap: () => provider.setDateFilter(DateRangeFilter.all)),
                _FilterChip(label: 'Today', isSelected: provider.dateFilter == DateRangeFilter.today, onTap: () => provider.setDateFilter(DateRangeFilter.today)),
                _FilterChip(label: 'This Week', isSelected: provider.dateFilter == DateRangeFilter.thisWeek, onTap: () => provider.setDateFilter(DateRangeFilter.thisWeek)),
                _FilterChip(label: 'This Month', isSelected: provider.dateFilter == DateRangeFilter.thisMonth, onTap: () => provider.setDateFilter(DateRangeFilter.thisMonth)),
                _FilterChip(label: 'Upcoming', isSelected: provider.dateFilter == DateRangeFilter.upcoming, onTap: () => provider.setDateFilter(DateRangeFilter.upcoming)),
                _FilterChip(label: 'Past', isSelected: provider.dateFilter == DateRangeFilter.past, onTap: () => provider.setDateFilter(DateRangeFilter.past)),
              ],
            ),
          ),
          if (provider.hasActiveFilters) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => provider.clearFilters(),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear filters'),
              style: TextButton.styleFrom(foregroundColor: VividColors.textMuted, padding: EdgeInsets.zero),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(BookingRemindersProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: provider.setSearchQuery,
        style: const TextStyle(color: VividColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name, phone, service...',
          hintStyle: TextStyle(color: VividColors.textMuted.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: VividColors.textMuted),
          suffixIcon: provider.searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); provider.setSearchQuery(''); }, color: VividColors.textMuted)
              : null,
          filled: true,
          fillColor: VividColors.deepBlue,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBookingsList(BookingRemindersProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: VividColors.cyan));
    }

    final bookings = provider.filteredBookings;

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 48, color: VividColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(provider.hasActiveFilters ? 'No bookings match filters' : 'No bookings found', style: const TextStyle(color: VividColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final isSelected = _selectedBooking?.id == booking.id;
        return _BookingTile(
          booking: booking,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedBooking = booking),
          onSendReminder: () => _showSendReminderDialog(context, booking, provider),
          isSending: provider.isSendingReminder(booking.id),
        );
      },
    );
  }

  Widget _buildEmptyDetail() {
    return Container(
      color: VividColors.darkNavy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 64, color: VividColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('Select a booking', style: TextStyle(color: VividColors.textPrimary, fontSize: 18)),
            const Text('View details and reminder status', style: TextStyle(color: VividColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetails(Booking booking, BookingRemindersProvider provider) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final statusColor = _getStatusColor(booking.reminderStatus);
    final isSending = provider.isSendingReminder(booking.id);

    return Container(
      color: VividColors.darkNavy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: VividColors.brightBlue.withOpacity(0.2),
                  child: Text(booking.customerName.isNotEmpty ? booking.customerName[0].toUpperCase() : '?', style: const TextStyle(color: VividColors.cyan, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.customerName, style: const TextStyle(color: VividColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => Clipboard.setData(ClipboardData(text: booking.customerPhone)),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: VividColors.textMuted),
                            const SizedBox(width: 4),
                            Text(booking.customerPhone, style: const TextStyle(color: VividColors.textMuted)),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 12, color: VividColors.textMuted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(booking.reminderStatus.displayName, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Send Reminder Button
            _SendReminderButton(
              booking: booking,
              isSending: isSending,
              onPressed: () => _showSendReminderDialog(context, booking, provider),
            ),

            const SizedBox(height: 24),

            // Appointment Details Card
            _DetailCard(
              title: 'Appointment Details',
              icon: Icons.event,
              children: [
                _DetailRow(label: 'Service', value: booking.service),
                _DetailRow(label: 'Date', value: dateFormat.format(booking.appointmentDate)),
                _DetailRow(label: 'Time', value: booking.appointmentTime),
                _DetailRow(label: 'Booking ID', value: booking.bookingId),
                if (booking.source != null) _DetailRow(label: 'Source', value: booking.source!),
              ],
            ),

            const SizedBox(height: 16),

            // Reminder Status Card
            _DetailCard(
              title: 'Reminder Status',
              icon: Icons.notifications_active,
              children: [
                _ReminderStatusRow(label: '3-Day Reminder', sent: booking.reminder3Day),
                _ReminderStatusRow(label: '1-Day Reminder', sent: booking.reminder1Day),
                if (booking.manualReminderSentAt != null)
                  _ReminderStatusRow(
                    label: 'Manual Reminder',
                    sent: true,
                    sentAt: booking.manualReminderSentAt,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Timeline Card
            _DetailCard(
              title: 'Timeline',
              icon: Icons.timeline,
              children: [
                _TimelineItem(label: 'Booking Created', date: booking.createdAt, isCompleted: true),
                _TimelineItem(label: '3-Day Reminder', date: booking.appointmentDate.subtract(const Duration(days: 3)), isCompleted: booking.reminder3Day),
                _TimelineItem(label: '1-Day Reminder', date: booking.appointmentDate.subtract(const Duration(days: 1)), isCompleted: booking.reminder1Day),
                if (booking.manualReminderSentAt != null)
                  _TimelineItem(label: 'Manual Reminder Sent', date: booking.manualReminderSentAt!, isCompleted: true),
                _TimelineItem(label: 'Appointment', date: booking.appointmentDateTime, isCompleted: !booking.isUpcoming),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSendReminderDialog(BuildContext context, Booking booking, BookingRemindersProvider provider) {
    final dateFormat = DateFormat('MMMM d');
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VividColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VividColors.brightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.send, color: VividColors.cyan, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Send Reminder', style: TextStyle(color: VividColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a reminder to ${booking.customerName} for their ${booking.service} appointment?',
              style: const TextStyle(color: VividColors.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VividColors.deepBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: VividColors.textMuted),
                      const SizedBox(width: 6),
                      Text(booking.customerName, style: const TextStyle(color: VividColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: VividColors.textMuted),
                      const SizedBox(width: 6),
                      Text(booking.customerPhone, style: const TextStyle(color: VividColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14, color: VividColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${dateFormat.format(booking.appointmentDate)} at ${booking.appointmentTime}',
                        style: const TextStyle(color: VividColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VividColors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VividColors.cyan.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: VividColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will send an immediate WhatsApp reminder using the dedicated reminder number.',
                      style: TextStyle(color: VividColors.cyan.withOpacity(0.9), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: VividColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              final success = await provider.sendManualReminder(booking);
              
              if (context.mounted) {
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
                            ? 'Reminder sent to ${booking.customerName}!' 
                            : provider.sendError ?? 'Failed to send reminder'),
                      ],
                    ),
                    backgroundColor: success ? VividColors.statusSuccess : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VividColors.brightBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReminderStatus status) {
    switch (status) {
      case ReminderStatus.pending:
        return VividColors.textMuted;
      case ReminderStatus.reminderSent:
        return Colors.orange;
      case ReminderStatus.confirmed:
        return VividColors.statusSuccess;
      case ReminderStatus.cancelled:
        return VividColors.statusUrgent;
    }
  }
}

// ============================================
// SEND REMINDER BUTTON
// ============================================

class _SendReminderButton extends StatelessWidget {
  final Booking booking;
  final bool isSending;
  final VoidCallback onPressed;

  const _SendReminderButton({
    required this.booking,
    required this.isSending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasBeenSent = booking.manualReminderSentAt != null;
    final timeAgo = hasBeenSent ? _formatTimeAgo(booking.manualReminderSentAt!) : null;

    if (hasBeenSent) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VividColors.statusSuccess.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VividColors.statusSuccess.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VividColors.statusSuccess.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: VividColors.statusSuccess, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manual Reminder Sent',
                    style: TextStyle(
                      color: VividColors.statusSuccess,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    timeAgo!,
                    style: TextStyle(
                      color: VividColors.statusSuccess.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Resend'),
              style: TextButton.styleFrom(
                foregroundColor: VividColors.statusSuccess,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: isSending ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSending ? null : VividColors.primaryGradient,
          color: isSending ? VividColors.deepBlue : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSending ? null : [
            BoxShadow(
              color: VividColors.brightBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSending) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VividColors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sending Reminder...',
                style: TextStyle(
                  color: VividColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ] else ...[
              const Icon(Icons.send, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              const Text(
                'Send Reminder Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    final bh = dateTime.toUtc().add(const Duration(hours: 3));
    return DateFormat('MMM d, h:mm a').format(bh);
  }
}

// ============================================
// HELPER WIDGETS
// ============================================

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? VividColors.cyan;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withOpacity(0.2) : VividColors.deepBlue,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? chipColor : Colors.transparent),
          ),
          child: Text(label, style: TextStyle(color: isSelected ? chipColor : VividColors.textMuted, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSendReminder;
  final bool isSending;

  const _BookingTile({
    required this.booking,
    required this.isSelected,
    required this.onTap,
    required this.onSendReminder,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking.reminderStatus);
    final dateFormat = DateFormat('MMM d');
    final hasManualReminder = booking.manualReminderSentAt != null;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? VividColors.brightBlue.withOpacity(0.1) : VividColors.deepBlue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? VividColors.cyan : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            // Status bar
            Container(width: 4, height: 90, decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(booking.customerName, style: const TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: Text(booking.reminderStatus.displayName, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(booking.service, style: const TextStyle(color: VividColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 12, color: VividColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${dateFormat.format(booking.appointmentDate)} at ${booking.appointmentTime}', style: const TextStyle(color: VividColors.textMuted, fontSize: 11)),
                        const Spacer(),
                        // Reminder indicators
                        _ReminderDot(label: '3d', sent: booking.reminder3Day),
                        const SizedBox(width: 4),
                        _ReminderDot(label: '1d', sent: booking.reminder1Day),
                        const SizedBox(width: 8),
                        // Send button
                        if (hasManualReminder)
                          Tooltip(
                            message: 'Sent ${_formatTimeAgo(booking.manualReminderSentAt!)}',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: VividColors.statusSuccess.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.check, size: 14, color: VividColors.statusSuccess),
                            ),
                          )
                        else
                          InkWell(
                            onTap: isSending ? null : onSendReminder,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: VividColors.brightBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.send, size: 12, color: VividColors.cyan),
                                        SizedBox(width: 4),
                                        Text('Send', style: TextStyle(color: VividColors.cyan, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
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
      ),
    );
  }

  Color _getStatusColor(ReminderStatus status) {
    switch (status) {
      case ReminderStatus.pending: return VividColors.textMuted;
      case ReminderStatus.reminderSent: return Colors.orange;
      case ReminderStatus.confirmed: return VividColors.statusSuccess;
      case ReminderStatus.cancelled: return VividColors.statusUrgent;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ReminderDot extends StatelessWidget {
  final String label;
  final bool sent;
  const _ReminderDot({required this.label, required this.sent});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    if (sent) {
      color = VividColors.statusSuccess;
      icon = Icons.check;
    } else {
      color = VividColors.textMuted.withOpacity(0.3);
      icon = Icons.circle_outlined;
    }

    return Tooltip(
      message: '$label: ${sent ? "Sent" : "Not sent"}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(icon, size: 10, color: color),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _DetailCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: VividColors.navy, borderRadius: BorderRadius.circular(12), border: Border.all(color: VividColors.tealBlue.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: VividColors.cyan, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: VividColors.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1, color: VividColors.tealBlue),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: VividColors.textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: VividColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ReminderStatusRow extends StatelessWidget {
  final String label;
  final bool sent;
  final DateTime? sentAt;
  
  const _ReminderStatusRow({required this.label, required this.sent, this.sentAt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: VividColors.textMuted, fontSize: 13))),
          if (sent) ...[
            const Icon(Icons.check_circle, color: VividColors.statusSuccess, size: 16),
            const SizedBox(width: 6),
            Text(
              sentAt != null ? 'Sent ${_formatTimeAgo(sentAt!)}' : 'Sent',
              style: const TextStyle(color: VividColors.statusSuccess, fontSize: 13),
            ),
          ] else ...[
            Icon(Icons.circle_outlined, color: VividColors.textMuted.withOpacity(0.5), size: 16),
            const SizedBox(width: 6),
            Text('Not sent', style: TextStyle(color: VividColors.textMuted.withOpacity(0.5), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _TimelineItem extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isCompleted;
  const _TimelineItem({required this.label, required this.date, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('MMM d, h:mm a');
    final bh = date.toUtc().add(const Duration(hours: 3));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? VividColors.statusSuccess.withOpacity(0.2) : VividColors.deepBlue,
              border: Border.all(color: isCompleted ? VividColors.statusSuccess : VividColors.textMuted.withOpacity(0.3)),
            ),
            child: isCompleted ? const Icon(Icons.check, size: 14, color: VividColors.statusSuccess) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isCompleted ? VividColors.textPrimary : VividColors.textMuted, fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal)),
                Text(format.format(bh), style: TextStyle(color: VividColors.textMuted.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}