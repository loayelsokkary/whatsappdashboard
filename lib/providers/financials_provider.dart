import 'package:flutter/foundation.dart';
import '../models/financial_models.dart';
import '../services/supabase_service.dart';

class FinancialsProvider extends ChangeNotifier {
  // ============================================
  // STATE
  // ============================================

  List<FinancialTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  TransactionType? _typeFilter;
  PaymentStatus? _statusFilter;
  String? _clientFilter;
  DateRangePreset _datePreset = DateRangePreset.allTime;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _search = '';

  // ============================================
  // GETTERS
  // ============================================

  List<FinancialTransaction> get transactions {
    var list = _transactions;

    if (_typeFilter != null) {
      list = list.where((t) => t.type == _typeFilter).toList();
    }
    if (_statusFilter != null) {
      list = list.where((t) => t.paymentStatus == _statusFilter).toList();
    }
    if (_clientFilter != null && _clientFilter!.isNotEmpty) {
      list = list.where((t) => t.clientId == _clientFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) =>
          (t.description?.toLowerCase().contains(q) ?? false) ||
          (t.invoiceNumber?.toLowerCase().contains(q) ?? false) ||
          (t.category?.toLowerCase().contains(q) ?? false) ||
          (t.clientName?.toLowerCase().contains(q) ?? false)).toList();
    }

    return list;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  TransactionType? get typeFilter => _typeFilter;
  PaymentStatus? get statusFilter => _statusFilter;
  String? get clientFilter => _clientFilter;
  DateRangePreset get datePreset => _datePreset;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  String get search => _search;

  // Summary getters — computed from filtered date range (not UI filters)
  double get totalRevenue => _transactions
      .where((t) => t.type == TransactionType.income && t.paymentStatus == PaymentStatus.paid)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get outstanding => _transactions
      .where((t) =>
          t.type == TransactionType.income &&
          (t.paymentStatus == PaymentStatus.pending || t.paymentStatus == PaymentStatus.overdue))
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense && t.paymentStatus == PaymentStatus.paid)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get netProfit => totalRevenue - totalExpenses;

  // ============================================
  // FETCH
  // ============================================

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final dateRange = _getDateRange();
      print('FINANCIALS: fetching transactions (${_datePreset.label})');

      final rows = await SupabaseService.instance.fetchFinancials(
        startDate: dateRange.$1,
        endDate: dateRange.$2,
      );

      _transactions = rows
          .map((r) => FinancialTransaction.fromJson(r))
          .toList();

      print('FINANCIALS: loaded ${_transactions.length} transactions');
    } catch (e) {
      print('FINANCIALS: error: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================
  // CRUD
  // ============================================

  Future<String?> create(FinancialTransaction transaction) async {
    try {
      await SupabaseService.instance.createFinancial(transaction.toInsertJson());
      print('FINANCIALS: created ${transaction.type.label} — ${transaction.amount} ${transaction.currency}');
      await fetchAll();
      return null;
    } catch (e) {
      print('FINANCIALS: create error: $e');
      return e.toString();
    }
  }

  Future<String?> update(String id, Map<String, dynamic> updates) async {
    try {
      await SupabaseService.instance.updateFinancial(id, updates);
      print('FINANCIALS: updated $id');
      await fetchAll();
      return null;
    } catch (e) {
      print('FINANCIALS: update error: $e');
      return e.toString();
    }
  }

  Future<String?> delete(String id) async {
    try {
      await SupabaseService.instance.deleteFinancial(id);
      print('FINANCIALS: deleted $id');
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      print('FINANCIALS: delete error: $e');
      return e.toString();
    }
  }

  Future<String?> markAsPaid(String id) async {
    return update(id, {
      'payment_status': 'paid',
      'paid_date': DateTime.now().toIso8601String(),
    });
  }

  // ============================================
  // FILTERS
  // ============================================

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setStatusFilter(PaymentStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setClientFilter(String? clientId) {
    _clientFilter = clientId;
    notifyListeners();
  }

  void setDatePreset(DateRangePreset preset) {
    _datePreset = preset;
    if (preset != DateRangePreset.custom) {
      _customStart = null;
      _customEnd = null;
      fetchAll();
    }
    notifyListeners();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    _datePreset = DateRangePreset.custom;
    _customStart = start;
    _customEnd = end;
    fetchAll();
    notifyListeners();
  }

  void setSearch(String query) {
    _search = query;
    notifyListeners();
  }

  // ============================================
  // HELPERS
  // ============================================

  (DateTime?, DateTime?) _getDateRange() {
    final now = DateTime.now();
    switch (_datePreset) {
      case DateRangePreset.thisMonth:
        return (DateTime(now.year, now.month, 1), null);
      case DateRangePreset.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        return (start, end);
      case DateRangePreset.thisQuarter:
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(now.year, qStart, 1), null);
      case DateRangePreset.thisYear:
        return (DateTime(now.year, 1, 1), null);
      case DateRangePreset.allTime:
        return (null, null);
      case DateRangePreset.custom:
        return (_customStart, _customEnd);
    }
  }
}
