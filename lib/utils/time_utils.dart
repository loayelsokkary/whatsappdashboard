/// Time utilities for formatting with Bahrain timezone (UTC+3)
class TimeUtils {
  /// Convert UTC to Bahrain time (UTC+3)
  static DateTime toBahrainTime(DateTime utcTime) {
    // Supabase timestamps are already UTC, just add 3 hours
    return utcTime.add(const Duration(hours: 3));
  }

  /// Format time relative to now (e.g., "Just now", "5m", "2h", "Yesterday")
  static String formatRelativeTime(DateTime utcTime) {
    final bahrainTime = toBahrainTime(utcTime);
    final now = DateTime.now().add(const Duration(hours: 3));
    final difference = now.difference(bahrainTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${bahrainTime.day} ${months[bahrainTime.month - 1]}';
    }
  }

  /// Format full date and time in Bahrain timezone
  static String formatDateTime(DateTime utcTime) {
    final bt = toBahrainTime(utcTime);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = bt.hour.toString().padLeft(2, '0');
    final minute = bt.minute.toString().padLeft(2, '0');
    return '${bt.day} ${months[bt.month - 1]} ${bt.year}, $hour:$minute';
  }

  /// Format time only in Bahrain timezone
  static String formatTime(DateTime utcTime) {
    final bt = toBahrainTime(utcTime);
    final hour = bt.hour.toString().padLeft(2, '0');
    final minute = bt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}