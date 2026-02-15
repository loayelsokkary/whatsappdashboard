/// Utility for formatting dates in chat views (Bahrain time, UTC+3)
class DateFormatter {
  /// Convert UTC to Bahrain time (UTC+3)
  static DateTime _toBahrain(DateTime dt) => dt.toUtc().add(const Duration(hours: 3));

  /// Returns a relative date label: "Today", "Yesterday", day name, or formatted date
  static String formatChatDate(DateTime date) {
    final nowBh = _toBahrain(DateTime.now().toUtc());
    final dateBh = _toBahrain(date);
    final today = DateTime(nowBh.year, nowBh.month, nowBh.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateBh.year, dateBh.month, dateBh.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (today.difference(messageDate).inDays < 7) {
      return _getDayName(dateBh.weekday);
    } else if (dateBh.year == nowBh.year) {
      return '${_getMonthName(dateBh.month)} ${dateBh.day}';
    } else {
      return '${dateBh.day}/${dateBh.month}/${dateBh.year}';
    }
  }

  /// Returns true if two dates fall on different calendar days (in Bahrain time)
  static bool isDifferentDay(DateTime a, DateTime b) {
    final aBh = _toBahrain(a);
    final bBh = _toBahrain(b);
    return aBh.year != bBh.year || aBh.month != bBh.month || aBh.day != bBh.day;
  }

  static String _getDayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return days[weekday - 1];
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
