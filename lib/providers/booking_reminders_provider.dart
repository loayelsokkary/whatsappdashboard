import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Filter options for reminder status
enum ReminderStatusFilter {
  all,
  pending,
  reminderSent,
  confirmed,
  cancelled,
}

/// Filter options for date range
enum DateRangeFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  upcoming,
  past,
}

/// Provider for managing booking reminders state
class BookingRemindersProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  // State
  List<Booking> _bookings = [];
  Booking? _selectedBooking;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  ReminderStatusFilter _statusFilter = ReminderStatusFilter.all;
  DateRangeFilter _dateFilter = DateRangeFilter.upcoming;
  String? _tableName;

  // Manual reminder state
  Set<String> _sendingReminders = {}; // Track which bookings are currently sending
  String? _sendError;

  // Subscription
  StreamSubscription<List<Booking>>? _subscription;

  // Getters
  List<Booking> get bookings => _bookings;
  Booking? get selectedBooking => _selectedBooking;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  ReminderStatusFilter get statusFilter => _statusFilter;
  DateRangeFilter get dateFilter => _dateFilter;
  String? get sendError => _sendError;

  /// Check if a specific booking is currently sending
  bool isSendingReminder(String bookingId) => _sendingReminders.contains(bookingId);

  /// Get computed stats from current bookings
  BookingReminderStats get stats => BookingReminderStats.fromBookings(_bookings);

  /// Get filtered bookings based on current filters
  List<Booking> get filteredBookings {
    List<Booking> result = List.from(_bookings);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((b) {
        return b.customerName.toLowerCase().contains(query) ||
            b.customerPhone.contains(query) ||
            b.service.toLowerCase().contains(query) ||
            b.bookingId.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != ReminderStatusFilter.all) {
      result = result.where((b) {
        switch (_statusFilter) {
          case ReminderStatusFilter.pending:
            return b.reminderStatus == ReminderStatus.pending;
          case ReminderStatusFilter.reminderSent:
            return b.reminderStatus == ReminderStatus.reminderSent;
          case ReminderStatusFilter.confirmed:
            return b.reminderStatus == ReminderStatus.confirmed;
          case ReminderStatusFilter.cancelled:
            return b.reminderStatus == ReminderStatus.cancelled;
          default:
            return true;
        }
      }).toList();
    }

    // Apply date filter
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    if (_dateFilter != DateRangeFilter.all) {
      result = result.where((b) {
        final apptDate = DateTime(
          b.appointmentDate.year,
          b.appointmentDate.month,
          b.appointmentDate.day,
        );

        switch (_dateFilter) {
          case DateRangeFilter.today:
            return apptDate.isAtSameMomentAs(today);
          case DateRangeFilter.thisWeek:
            return apptDate.isAfter(today.subtract(const Duration(days: 1))) &&
                apptDate.isBefore(weekEnd);
          case DateRangeFilter.thisMonth:
            return apptDate.isAfter(today.subtract(const Duration(days: 1))) &&
                apptDate.isBefore(monthEnd.add(const Duration(days: 1)));
          case DateRangeFilter.upcoming:
            return apptDate.isAfter(today.subtract(const Duration(days: 1)));
          case DateRangeFilter.past:
            return apptDate.isBefore(today);
          default:
            return true;
        }
      }).toList();
    }

    // Sort by appointment date (closest first for upcoming, most recent first for past)
    if (_dateFilter == DateRangeFilter.past) {
      result.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    } else {
      result.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
    }

    return result;
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _statusFilter != ReminderStatusFilter.all ||
        _dateFilter != DateRangeFilter.upcoming;
  }

  /// Initialize the provider with a table name
  Future<void> initialize(String tableName) async {
    _tableName = tableName;
    await loadBookings();
    _subscribeToChanges();
  }

  /// Load all bookings from the database
  Future<void> loadBookings() async {
    if (_tableName == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookings = await _supabaseService.fetchBookings(_tableName!);
      _error = null;
    } catch (e) {
      _error = 'Failed to load bookings: $e';
      print(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Subscribe to real-time booking changes
  void _subscribeToChanges() {
    if (_tableName == null) return;

    _subscription?.cancel();
    _subscription = _supabaseService.subscribeToBookings(_tableName!).listen(
      (bookings) {
        _bookings = bookings;
        
        // Update selected booking if it changed
        if (_selectedBooking != null) {
          final updated = _bookings.where((b) => b.id == _selectedBooking!.id).firstOrNull;
          if (updated != null) {
            _selectedBooking = updated;
          }
        }
        
        notifyListeners();
      },
      onError: (e) {
        print('Booking subscription error: $e');
      },
    );
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set status filter
  void setStatusFilter(ReminderStatusFilter filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  /// Set date filter
  void setDateFilter(DateRangeFilter filter) {
    _dateFilter = filter;
    notifyListeners();
  }

  /// Select a booking
  void selectBooking(Booking? booking) {
    _selectedBooking = booking;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _statusFilter = ReminderStatusFilter.all;
    _dateFilter = DateRangeFilter.upcoming;
    notifyListeners();
  }

  /// Update booking reminder status
  Future<bool> updateBookingStatus({
    required String bookingId,
    bool? reminder3Day,
    bool? reminder1Day,
    String? status,
  }) async {
    if (_tableName == null) return false;

    try {
      final success = await _supabaseService.updateBookingReminderStatus(
        tableName: _tableName!,
        bookingId: bookingId,
        reminder3Day: reminder3Day,
        reminder1Day: reminder1Day,
        status: status,
      );

      if (success) {
        // Optimistic update
        final index = _bookings.indexWhere((b) => b.id == bookingId);
        if (index != -1) {
          _bookings[index] = _bookings[index].copyWith(
            reminder3Day: reminder3Day ?? _bookings[index].reminder3Day,
            reminder1Day: reminder1Day ?? _bookings[index].reminder1Day,
            status: status ?? _bookings[index].status,
          );
          
          // Update selected if it's the same booking
          if (_selectedBooking?.id == bookingId) {
            _selectedBooking = _bookings[index];
          }
          
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      print('Update booking status error: $e');
      return false;
    }
  }

  /// Send manual reminder for a booking
  Future<bool> sendManualReminder(Booking booking) async {
    if (_tableName == null) return false;

    // Get reminder webhook URL from client config
    final reminderWebhookUrl = ClientConfig.remindersWebhookUrl;
    if (reminderWebhookUrl == null || reminderWebhookUrl.isEmpty) {
      _sendError = 'Reminder webhook URL not configured';
      notifyListeners();
      return false;
    }

    // Mark as sending
    _sendingReminders.add(booking.id);
    _sendError = null;
    notifyListeners();

    try {
      final payload = {
        'type': 'manual_reminder',
        'booking_id': booking.id,
        'booking_ref': booking.bookingId,
        'customer_phone': booking.customerPhone,
        'customer_name': booking.customerName,
        'service': booking.service,
        'appointment_date': booking.appointmentDate.toIso8601String().split('T')[0],
        'appointment_time': booking.appointmentTime,
        'reminder_phone': ClientConfig.remindersPhone ?? '',
        'client_id': ClientConfig.currentClient?.id ?? '',
        'client_name': ClientConfig.currentClient?.name ?? '',
        'table_name': _tableName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('Sending manual reminder: $payload');

      final response = await http.post(
        Uri.parse(reminderWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Manual reminder sent successfully');

        // Update local state optimistically
        final index = _bookings.indexWhere((b) => b.id == booking.id);
        if (index != -1) {
          _bookings[index] = _bookings[index].copyWith(
            manualReminderSentAt: DateTime.now(),
          );

          if (_selectedBooking?.id == booking.id) {
            _selectedBooking = _bookings[index];
          }
        }

        _sendingReminders.remove(booking.id);
        notifyListeners();
        return true;
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Send manual reminder error: $e');
      _sendError = 'Failed to send reminder: $e';
      _sendingReminders.remove(booking.id);
      notifyListeners();
      return false;
    }
  }

  /// Clear send error
  void clearSendError() {
    _sendError = null;
    notifyListeners();
  }

  /// Refresh bookings
  Future<void> refresh() async {
    await loadBookings();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}