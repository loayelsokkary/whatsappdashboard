import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Supabase Service with Webhook Support for Human Handover
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  // Stream controllers
  final _exchangesController = StreamController<List<RawExchange>>.broadcast();
  Stream<List<RawExchange>> get exchangesStream => _exchangesController.stream;

  // Realtime channel
  RealtimeChannel? _channel;

  // Local cache of exchanges
  List<RawExchange> _cachedExchanges = [];

  // ============================================
  // CONFIGURATION - UPDATE THESE
  // ============================================
  
  static const String _supabaseUrl = 'https://zxvjzaowvzvfgrzdimbm.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4dmp6YW93dnp2ZmdyemRpbWJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1NjM2MjUsImV4cCI6MjA4MTEzOTYyNX0.NkVPCRTLcQOdkzIhfsnvPBWJ1vcfeMQOysAuq6Erryg';
  
  // N8N Webhook URL for sending WhatsApp messages
  static const String _n8nWebhookUrl = 'https://malyooon.app.n8n.cloud/webhook/0a47ebfd-56ae-425a-8e95-0b453b67bad3';

  // ============================================
  // INITIALIZATION
  // ============================================

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    print('Supabase initialized');
  }

  // ============================================
  // FETCH EXCHANGES
  // ============================================

  /// Fetch all exchanges for this business
  Future<List<RawExchange>> fetchAllExchanges() async {
    try {
      final businessPhone = BusinessConfig.businessPhone;

      final response = await client
          .from('messages')
          .select()
          .eq('ai_phone', businessPhone)
          .order('created_at', ascending: true);

      _cachedExchanges = (response as List)
          .map((json) => RawExchange.fromJson(json))
          .toList();

      print('Fetched ${_cachedExchanges.length} exchanges');
      return _cachedExchanges;
    } catch (e) {
      print('Error fetching exchanges: $e');
      rethrow;
    }
  }

  // ============================================
  // REAL-TIME SUBSCRIPTION (FIXED)
  // ============================================

  /// Subscribe to real-time exchange updates
  void subscribeToExchanges() {
    final businessPhone = BusinessConfig.businessPhone;

    // Unsubscribe from any existing channel
    _channel?.unsubscribe();

    // Subscribe to INSERT events on messages table
    _channel = client
        .channel('messages_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('New message received: ${payload.newRecord}');
            
            final newExchange = RawExchange.fromJson(payload.newRecord);
            
            // Only add if it's for our business
            if (newExchange.aiPhone == businessPhone) {
              // Add to cache
              _cachedExchanges.add(newExchange);
              
              // Sort by created_at
              _cachedExchanges.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              
              // Emit updated list
              _exchangesController.add(List.from(_cachedExchanges));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('Message updated: ${payload.newRecord}');
            
            final updatedExchange = RawExchange.fromJson(payload.newRecord);
            
            if (updatedExchange.aiPhone == businessPhone) {
              // Find and update in cache
              final index = _cachedExchanges.indexWhere((e) => e.id == updatedExchange.id);
              if (index != -1) {
                _cachedExchanges[index] = updatedExchange;
              } else {
                _cachedExchanges.add(updatedExchange);
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
            print('Message deleted: ${payload.oldRecord}');
            
            final deletedId = payload.oldRecord['id'];
            _cachedExchanges.removeWhere((e) => e.id == deletedId);
            _exchangesController.add(List.from(_cachedExchanges));
          },
        )
        .subscribe();

    print('Subscribed to real-time messages');
  }

  // ============================================
  // SEND MESSAGE VIA N8N WEBHOOK
  // ============================================

  /// Send a message from the dashboard via n8n webhook
  Future<bool> sendMessageViaWebhook({
    required String customerPhone,
    required String message,
    String? customerName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_n8nWebhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ai_phone': BusinessConfig.businessPhone,
          'customer_phone': customerPhone,
          'customer_name': customerName ?? 'Customer',
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        print('Message sent via webhook');
        return true;
      } else {
        print('Webhook error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending via webhook: $e');
      return false;
    }
  }

  // ============================================
  // BACKUP: SAVE DIRECTLY TO SUPABASE
  // ============================================

  /// Save exchange directly to Supabase (backup method)
  Future<RawExchange?> saveExchangeDirectly({
    required String customerPhone,
    required String customerMessage,
    required String aiResponse,
    String? customerName,
  }) async {
    try {
      final response = await client.from('messages').insert({
        'ai_phone': BusinessConfig.businessPhone,
        'customer_phone': customerPhone,
        'customer_name': customerName,
        'customer_message': customerMessage,
        'ai_response': aiResponse,
      }).select().single();

      print('Exchange saved directly to Supabase');
      return RawExchange.fromJson(response);
    } catch (e) {
      print('Error saving exchange: $e');
      rethrow;
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