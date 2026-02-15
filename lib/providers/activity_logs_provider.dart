import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for managing activity logs
class ActivityLogsProvider extends ChangeNotifier {
  List<ActivityLog> _logs = [];
  bool _isLoading = false;
  String? _error;
  Set<String> _blockedUserIds = {};

  // Filters
  String? _selectedUserId;
  ActionType? _selectedActionType;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  bool _filterAiOnly = false;

  // Getters
  List<ActivityLog> get logs => _filteredLogs;
  List<ActivityLog> get allLogs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedUserId => _selectedUserId;
  ActionType? get selectedActionType => _selectedActionType;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get searchQuery => _searchQuery;
  bool get filterAiOnly => _filterAiOnly;
  Set<String> get blockedUserIds => _blockedUserIds;

  /// Get filtered logs based on current filter settings
  List<ActivityLog> get _filteredLogs {
    var filtered = _logs;

    // Filter by user
    if (_selectedUserId != null && _selectedUserId!.isNotEmpty) {
      filtered = filtered.where((log) => log.userId == _selectedUserId).toList();
    }

    // Filter by action type
    if (_selectedActionType != null) {
      filtered = filtered.where((log) => log.actionType == _selectedActionType).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((log) => log.createdAt.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((log) => log.createdAt.isBefore(endOfDay)).toList();
    }

    // Filter by AI activity (only when client has AI)
    if (_filterAiOnly && ClientConfig.hasAiConversations) {
      filtered = filtered.where((log) => log.actionType == ActionType.aiToggled).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((log) =>
        log.userName.toLowerCase().contains(query) ||
        log.description.toLowerCase().contains(query) ||
        (log.userEmail?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return filtered;
  }

  /// Fetch blocked user IDs for display in filters
  Future<void> _fetchBlockedUserIds({String? clientId}) async {
    try {
      final query = SupabaseService.client
          .from('users')
          .select('id')
          .eq('status', 'blocked');

      final response = clientId != null
          ? await query.eq('client_id', clientId)
          : await query;

      _blockedUserIds = (response as List)
          .map((row) => row['id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('Failed to fetch blocked user IDs: $e');
    }
  }

  /// Fetch activity logs for a client
  Future<void> fetchLogs({String? clientId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logs = await SupabaseService.instance.fetchActivityLogs(clientId: clientId);
      await _fetchBlockedUserIds(clientId: clientId);
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch activity logs: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch all logs (for Vivid admins)
  Future<void> fetchAllLogs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logs = await SupabaseService.instance.fetchActivityLogs();
      await _fetchBlockedUserIds();
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch activity logs: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set user filter
  void setUserFilter(String? userId) {
    _selectedUserId = userId;
    notifyListeners();
  }

  /// Set action type filter
  void setActionTypeFilter(ActionType? actionType) {
    _selectedActionType = actionType;
    notifyListeners();
  }

  /// Set date range filter
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set AI-only filter
  void setAiFilter(bool value) {
    _filterAiOnly = value;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedUserId = null;
    _selectedActionType = null;
    _startDate = null;
    _endDate = null;
    _searchQuery = '';
    _filterAiOnly = false;
    notifyListeners();
  }

  /// Get unique users from logs (for filter dropdown)
  List<Map<String, String>> get uniqueUsers {
    final Map<String, Map<String, String>> usersMap = {};
    for (final log in _logs) {
      if (log.userId != null && !usersMap.containsKey(log.userId)) {
        usersMap[log.userId!] = {
          'id': log.userId!,
          'name': log.userName,
          'email': log.userEmail ?? '',
        };
      }
    }
    return usersMap.values.toList();
  }

  /// Get log counts by action type
  Map<ActionType, int> get logCountsByType {
    final counts = <ActionType, int>{};
    for (final log in _logs) {
      counts[log.actionType] = (counts[log.actionType] ?? 0) + 1;
    }
    return counts;
  }

  /// Get log counts by user
  Map<String, int> get logCountsByUser {
    final counts = <String, int>{};
    for (final log in _logs) {
      final key = log.userName;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Get logs for today
  List<ActivityLog> get todayLogs {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _logs.where((log) => log.createdAt.isAfter(startOfDay)).toList();
  }

  /// Get logs for this week
  List<ActivityLog> get thisWeekLogs {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return _logs.where((log) => log.createdAt.isAfter(startOfDay)).toList();
  }
}