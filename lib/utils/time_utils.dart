import 'package:intl/intl.dart';

/// Time formatting utilities for the dashboard
class TimeUtils {
  /// Format time as "3:45 PM"
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  /// Format as relative time: "Just now", "5m ago", "2h ago", "3d ago"
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  /// Format as "Dec 12, 3:45 PM"
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }

  /// Format for date headers: "Today", "Yesterday", "Monday", "December 12, 2024"
  static String formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(dateDay).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(date); // "Monday"
    } else {
      return DateFormat('MMMM d, y').format(date); // "December 12, 2024"
    }
  }

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Format for export/logs: "2024-12-12 15:45:30"
  static String formatForLog(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// Parse ISO 8601 string safely
  static DateTime? parseIso(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }
}
