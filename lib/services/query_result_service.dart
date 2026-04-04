import 'package:supabase_flutter/supabase_flutter.dart';

class QueryResultData {
  final String id;
  final String title;
  final int totalCustomers;
  final int totalVisits;
  final List<String> columns;
  final List<List<dynamic>> rows;
  final DateTime createdAt;

  const QueryResultData({
    required this.id,
    required this.title,
    required this.totalCustomers,
    required this.totalVisits,
    required this.columns,
    required this.rows,
    required this.createdAt,
  });

  factory QueryResultData.fromJson(Map<String, dynamic> json) {
    return QueryResultData(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      totalCustomers: json['total_customers'] as int? ?? 0,
      totalVisits: json['total_visits'] as int? ?? 0,
      columns: List<String>.from((json['columns'] as List?) ?? []),
      rows: ((json['rows'] as List?) ?? [])
          .map((row) => List<dynamic>.from(row as List))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class QueryResultService {
  static final _supabase = Supabase.instance.client;

  static const _table = 'hob_query_results';
  static const _windowSeconds = 60;

  /// Fetch the most recent query result created within the last [_windowSeconds].
  static Future<QueryResultData?> fetchRecentResult() async {
    try {
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: _windowSeconds))
          .toIso8601String();

      final response = await _supabase
          .from(_table)
          .select()
          .gte('created_at', cutoff)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return QueryResultData.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Fetch a specific query result by ID.
  static Future<QueryResultData?> fetchById(String id) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return QueryResultData.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
