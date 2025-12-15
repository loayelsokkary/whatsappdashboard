import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Supabase Service with real-time updates and webhook support
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  final _exchangesController = StreamController<List<RawExchange>>.broadcast();
  Stream<List<RawExchange>> get exchangesStream => _exchangesController.stream;

  RealtimeChannel? _channel;
  List<RawExchange> _cachedExchanges = [];

  // ============================================
  // CONFIG - UPDATE THESE!
  // ============================================
  
  static const String _supabaseUrl = 'https://zxvjzaowvzvfgrzdimbm.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4dmp6YW93dnp2ZmdyemRpbWJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1NjM2MjUsImV4cCI6MjA4MTEzOTYyNX0.NkVPCRTLcQOdkzIhfsnvPBWJ1vcfeMQOysAuq6Erryg';
  static const String _n8nWebhookUrl = 'https://malyooon.app.n8n.cloud/webhook/0a47ebfd-56ae-425a-8e95-0b453b67bad3';

  // ============================================
  // SINGLETON
  // ============================================

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized');
    }
    return _client!;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    _client = Supabase.instance.client;
    print('Supabase initialized');
  }

  // ============================================
  // FETCH
  // ============================================

  Future<List<RawExchange>> fetchAllExchanges() async {
    try {
      final response = await client
          .from('messages')
          .select()
          .eq('ai_phone', BusinessConfig.businessPhone)
          .order('created_at', ascending: true);

      _cachedExchanges = (response as List)
          .map((json) => RawExchange.fromJson(json))
          .toList();

      print('Fetched ${_cachedExchanges.length} exchanges');
      return _cachedExchanges;
    } catch (e) {
      print('Fetch error: $e');
      rethrow;
    }
  }

  // ============================================
  // REAL-TIME SUBSCRIPTION
  // ============================================

  void subscribeToExchanges() {
    final businessPhone = BusinessConfig.businessPhone;

    _channel?.unsubscribe();

    _channel = client
        .channel('messages_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('New message: ${payload.newRecord}');
            
            final exchange = RawExchange.fromJson(payload.newRecord);
            if (exchange.aiPhone == businessPhone) {
              _cachedExchanges.add(exchange);
              _cachedExchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              _exchangesController.add(List.from(_cachedExchanges));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('Updated message: ${payload.newRecord}');
            
            final exchange = RawExchange.fromJson(payload.newRecord);
            if (exchange.aiPhone == businessPhone) {
              final index = _cachedExchanges.indexWhere((e) => e.id == exchange.id);
              if (index != -1) {
                _cachedExchanges[index] = exchange;
              } else {
                _cachedExchanges.add(exchange);
              }
              _cachedExchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              _exchangesController.add(List.from(_cachedExchanges));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            _cachedExchanges.removeWhere((e) => e.id == deletedId);
            _exchangesController.add(List.from(_cachedExchanges));
          },
        )
        .subscribe();

    print('Subscribed to real-time messages');
  }

  // ============================================
  // SEND MESSAGE VIA WEBHOOK (saves to manager_response)
  // ============================================

  Future<bool> sendMessageViaWebhook({
    required String customerPhone,
    required String message,
    String? customerName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_n8nWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ai_phone': BusinessConfig.businessPhone,
          'customer_phone': customerPhone,
          'customer_name': customerName ?? 'Customer',
          'manager_response': message, // Save to manager_response column
        }),
      );

      if (response.statusCode == 200) {
        print('Message sent via webhook');
        return true;
      } else {
        print('Webhook error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Webhook error: $e');
      return false;
    }
  }

  // ============================================
  // DISPOSE
  // ============================================

  void dispose() {
    _channel?.unsubscribe();
    _exchangesController.close();
  }
}