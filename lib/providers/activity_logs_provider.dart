import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for managing activity logs with pagination and filtering.
class ActivityLogsProvider extends ChangeNotifier {
  List<ActivityLog> _logs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  Set<String> _blockedUserIds = {};

  // Pagination (server-side)
  static const _pageSize = 1000;
  int _offset = 0;
  bool _hasMore = true;

  // Display limit (client-side lazy rendering)
  int _displayLimit = 50;
  static const _displayIncrement = 50;

  // The clientId used for fetching (null = all clients)
  String? _fetchClientId;

  // Filters
  String? _selectedClientId; // admin-only: filter by client
  String? _selectedUserId;
  ActionType? _selectedActionType;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  bool _filterAiOnly = false;

  // Getters
  List<ActivityLog> get logs => _filteredLogs;
  /// The displayed slice (up to _displayLimit) of filtered logs.
  List<ActivityLog> get displayedLogs {
    final filtered = _filteredLogs;
    if (_displayLimit >= filtered.length) return filtered;
    return filtered.sublist(0, _displayLimit);
  }
  /// Total count of all filtered logs (for header display).
  int get filteredCount => _filteredLogs.length;
  /// Total count of all fetched logs (unfiltered).
  int get totalFetchedCount => _logs.length;
  /// Whether there are more filtered logs to display locally.
  bool get hasMoreToDisplay => _displayLimit < _filteredLogs.length;
  List<ActivityLog> get allLogs => _logs;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String? get selectedClientId => _selectedClientId;
  String? get selectedUserId => _selectedUserId;
  ActionType? get selectedActionType => _selectedActionType;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get searchQuery => _searchQuery;
  bool get filterAiOnly => _filterAiOnly;
  Set<String> get blockedUserIds => _blockedUserIds;

  /// Get filtered logs based on current filter settings.
  /// Server-side filters (client, dates, action types) are applied at fetch time.
  /// Client-side filters (search, user, AI-only) are applied here.
  List<ActivityLog> get _filteredLogs {
    var filtered = _logs;

    // Filter by user
    if (_selectedUserId != null && _selectedUserId!.isNotEmpty) {
      filtered = filtered.where((log) => log.userId == _selectedUserId).toList();
    }

    // Filter by action type (client-side fallback when not server-filtered)
    if (_selectedActionType != null) {
      filtered = filtered.where((log) => log.actionType == _selectedActionType).toList();
    }

    // Filter by date range (client-side fallback)
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

  /// Build the server-side filter parameters.
  Map<String, dynamic> get _serverFilters => {
    'clientId': _selectedClientId ?? _fetchClientId,
    'actionTypes': _selectedActionType != null ? [_selectedActionType!.value] : null,
    'startDate': _startDate,
    'endDate': _endDate != null
        ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)
        : null,
  };

  /// Fetch activity logs (first page). Resets pagination.
  ///
  /// [clientId] — scope to a specific client. Null fetches all (for Vivid admins).
  Future<void> fetchLogs({String? clientId}) async {
    _fetchClientId = clientId;
    _offset = 0;
    _hasMore = true;
    _displayLimit = 50;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final filters = _serverFilters;
      _logs = await SupabaseService.instance.fetchActivityLogs(
        clientId: filters['clientId'] as String?,
        actionTypes: (filters['actionTypes'] as List<String>?),
        startDate: filters['startDate'] as DateTime?,
        endDate: filters['endDate'] as DateTime?,
        offset: 0,
        limit: _pageSize,
      );
      _hasMore = _logs.length >= _pageSize;
      _offset = _logs.length;
      await _fetchBlockedUserIds(clientId: filters['clientId'] as String?);
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch activity logs: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch all logs (for Vivid admins). Alias for fetchLogs(clientId: null).
  Future<void> fetchAllLogs() => fetchLogs();

  /// Show more items from the already-fetched filtered list.
  void showMore() {
    _displayLimit += _displayIncrement;
    notifyListeners();
  }

  /// Load the next page of results from the server. Appends to existing logs.
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final filters = _serverFilters;
      final newLogs = await SupabaseService.instance.fetchActivityLogs(
        clientId: filters['clientId'] as String?,
        actionTypes: (filters['actionTypes'] as List<String>?),
        startDate: filters['startDate'] as DateTime?,
        endDate: filters['endDate'] as DateTime?,
        offset: _offset,
        limit: _pageSize,
      );

      _logs.addAll(newLogs);
      _hasMore = newLogs.length >= _pageSize;
      _offset += newLogs.length;
    } catch (e) {
      debugPrint('Failed to load more logs: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Filter setters ──────────────────────────────────

  /// Set client filter (admin-only). Re-fetches from server.
  void setClientFilter(String? clientId) {
    _selectedClientId = clientId;
    fetchLogs(clientId: _fetchClientId);
  }

  /// Set user filter (client-side)
  void setUserFilter(String? userId) {
    _selectedUserId = userId;
    _displayLimit = 50;
    notifyListeners();
  }

  /// Set action type filter. Re-fetches from server for efficiency.
  void setActionTypeFilter(ActionType? actionType) {
    _selectedActionType = actionType;
    fetchLogs(clientId: _fetchClientId);
  }

  /// Set date range filter. Re-fetches from server.
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    fetchLogs(clientId: _fetchClientId);
  }

  /// Set search query (client-side)
  void setSearchQuery(String query) {
    _searchQuery = query;
    _displayLimit = 50;
    notifyListeners();
  }

  /// Set AI-only filter (client-side)
  void setAiFilter(bool value) {
    _filterAiOnly = value;
    _displayLimit = 50;
    notifyListeners();
  }

  /// Clear all filters and re-fetch
  void clearFilters() {
    _selectedClientId = null;
    _selectedUserId = null;
    _selectedActionType = null;
    _startDate = null;
    _endDate = null;
    _searchQuery = '';
    _filterAiOnly = false;
    fetchLogs(clientId: _fetchClientId);
  }

  // ── Computed getters ────────────────────────────────

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
