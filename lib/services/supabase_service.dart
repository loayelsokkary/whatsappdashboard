import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../providers/analytics_provider.dart';

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
  // Webhook URL is now loaded from ClientConfig

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
  // AUTHENTICATION
  // ============================================

  /// Login with email and password (unified for admins and clients)
  /// Returns AppUser if successful, null otherwise
  Future<AppUser?> login(String email, String password) async {
    try {
      print('Attempting login for: $email');
      
      // Try secure login function first (hashed passwords)
      try {
        final loginResponse = await client
            .rpc('login_user', params: {
              'p_email': email,
              'p_password': password,
            });

        if (loginResponse != null && (loginResponse as List).isNotEmpty) {
          final userData = loginResponse[0];
          print('User found via secure login: ${userData['name']} (${userData['role']})');
          
          // Fetch full user data
          final userResponse = await client
              .from('users')
              .select()
              .eq('id', userData['id'])
              .single();

          final user = AppUser.fromJson(userResponse);
          
          if (user.isAdmin) {
            ClientConfig.setAdmin(user);
            print('Admin login successful');
            return user;
          }

          // Load client config
          if (user.clientId != null) {
            final clientResponse = await client
                .from('clients')
                .select()
                .eq('id', user.clientId!)
                .single();

            final clientData = Client.fromJson(clientResponse);
            ClientConfig.setClientUser(clientData, user);
          }

          print('Client login successful');
          return user;
        }
      } catch (rpcError) {
        print('Secure login not available, trying fallback: $rpcError');
      }
      
      // Fallback: plain text password (for transition period)
      final userResponse = await client
          .from('users')
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      if (userResponse == null) {
        print('No user found with email: $email');
        return null;
      }

      print('User found via fallback: ${userResponse['name']} (${userResponse['role']})');
      
      final user = AppUser.fromJson(userResponse);

      if (user.isAdmin) {
        // Admin user - no client needed
        ClientConfig.setAdmin(user);
        print('Admin logged in: ${user.name}');
      } else {
        // Client user - fetch their client config
        if (user.clientId == null) {
          print('ERROR: Client user has no client_id');
          return null;
        }

        print('Fetching client with id: ${user.clientId}');
        
        final clientResponse = await client
            .from('clients')
            .select()
            .eq('id', user.clientId!)
            .maybeSingle();

        if (clientResponse == null) {
          print('ERROR: No client found with id: ${user.clientId}');
          return null;
        }

        final clientData = Client.fromJson(clientResponse);
        ClientConfig.setClientUser(clientData, user);

        print('Logged in as ${user.name} for ${clientData.name}');
        print('Enabled features: ${clientData.enabledFeatures}');
      }

      return user;
    } catch (e, stack) {
      print('Login error: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// Logout - clear client config
  void logout() {
    ClientConfig.clear();
    _cachedExchanges.clear();
    _channel?.unsubscribe();
    print('Logged out');
  }

  // ============================================
  // ADMIN: CLIENT MANAGEMENT
  // ============================================

  /// Fetch all clients
  Future<List<Client>> fetchAllClients() async {
    try {
      final response = await client
          .from('clients')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => Client.fromJson(json)).toList();
    } catch (e) {
      print('Fetch clients error: $e');
      return [];
    }
  }

  /// Create a new client
  Future<Client?> createClient({
    required String name,
    required String slug,
    String? webhookUrl,
    List<String> enabledFeatures = const [],
    String? businessPhone,
  }) async {
    try {
      final response = await client.from('clients').insert({
        'name': name,
        'slug': slug,
        'webhook_url': webhookUrl,
        'enabled_features': enabledFeatures,
        'business_phone': businessPhone,
      }).select().single();

      return Client.fromJson(response);
    } catch (e) {
      print('Create client error: $e');
      return null;
    }
  }

  /// Update a client
  Future<bool> updateClient({
    required String clientId,
    String? name,
    String? slug,
    String? webhookUrl,
    List<String>? enabledFeatures,
    String? businessPhone,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (slug != null) updates['slug'] = slug;
      if (webhookUrl != null) updates['webhook_url'] = webhookUrl;
      if (enabledFeatures != null) updates['enabled_features'] = enabledFeatures;
      if (businessPhone != null) updates['business_phone'] = businessPhone;

      await client.from('clients').update(updates).eq('id', clientId);
      return true;
    } catch (e) {
      print('Update client error: $e');
      return false;
    }
  }

  /// Delete a client
  Future<bool> deleteClient(String clientId) async {
    try {
      await client.from('clients').delete().eq('id', clientId);
      return true;
    } catch (e) {
      print('Delete client error: $e');
      return false;
    }
  }

  // ============================================
  // ADMIN: USER MANAGEMENT
  // ============================================

  /// Fetch all users for a client
  Future<List<AppUser>> fetchClientUsers(String clientId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('client_id', clientId)
          .eq('role', 'client')
          .order('created_at', ascending: false);

      return (response as List).map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('Fetch client users error: $e');
      return [];
    }
  }

  /// Fetch all users (both admins and clients)
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    try {
      final response = await client
          .from('users')
          .select('*, clients(name)')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Fetch all users error: $e');
      return [];
    }
  }

  /// Create a new user
  Future<AppUser?> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? clientId,
  }) async {
    try {
      // Try to hash the password using pgcrypto
      String? hashedPassword;
      try {
        final hashResult = await client.rpc('hash_password', params: {
          'password': password,
        });
        hashedPassword = hashResult as String?;
      } catch (e) {
        print('Hash function not available, storing plain (temporary): $e');
      }
      
      final userData = <String, dynamic>{
        'email': email,
        'name': name,
        'role': role,
        'client_id': clientId,
      };
      
      // Use hashed password if available, otherwise plain
      if (hashedPassword != null) {
        userData['password_hash'] = hashedPassword;
        userData['password'] = password; // Keep both during transition
      } else {
        userData['password'] = password;
      }
      
      final response = await client.from('users').insert(userData).select().single();

      return AppUser.fromJson(response);
    } catch (e) {
      print('Create user error: $e');
      return null;
    }
  }

  /// Update a user
  Future<bool> updateUser({
    required String userId,
    String? email,
    String? password,
    String? name,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (email != null) updates['email'] = email;
      if (name != null) updates['name'] = name;
      
      // Hash the password if provided
      if (password != null) {
        try {
          final hashResult = await client.rpc('hash_password', params: {
            'password': password,
          });
          updates['password_hash'] = hashResult;
          updates['password'] = password; // Keep both during transition
        } catch (e) {
          print('Hash function not available, storing plain (temporary): $e');
          updates['password'] = password;
        }
      }

      await client.from('users').update(updates).eq('id', userId);
      return true;
    } catch (e) {
      print('Update user error: $e');
      return false;
    }
  }

  /// Delete a user
  Future<bool> deleteUser(String userId) async {
    try {
      await client.from('users').delete().eq('id', userId);
      return true;
    } catch (e) {
      print('Delete user error: $e');
      return false;
    }
  }

  // ============================================
  // FETCH
  // ============================================

  Future<List<RawExchange>> fetchAllExchanges() async {
    try {
      final response = await client
          .from('messages')
          .select()
          .eq('ai_phone', ClientConfig.businessPhone)
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
    final businessPhone = ClientConfig.businessPhone;

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
      final webhookUrl = ClientConfig.webhookUrl;
      if (webhookUrl.isEmpty) {
        print('No webhook URL configured');
        return false;
      }

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ai_phone': ClientConfig.businessPhone,
          'customer_phone': customerPhone,
          'customer_name': customerName ?? 'Customer',
          'manager_response': message,
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
  // ANALYTICS
  // ============================================

  Future<AnalyticsData> fetchAnalytics() async {
    try {
      final businessPhone = ClientConfig.businessPhone;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Fetch all messages
      final allMessages = await client
          .from('messages')
          .select()
          .eq('ai_phone', businessPhone);

      final messages = allMessages as List;
      
      // Calculate stats
      int totalMessages = messages.length;
      int aiResponses = messages.where((m) => 
          m['ai_response'] != null && (m['ai_response'] as String).trim().isNotEmpty).length;
      int managerResponses = messages.where((m) => 
          m['manager_response'] != null && (m['manager_response'] as String).trim().isNotEmpty).length;
      
      // Unique customers
      final uniquePhones = messages.map((m) => m['customer_phone']).toSet();
      int uniqueCustomers = uniquePhones.length;

      // Time-based counts
      int todayMessages = 0;
      int thisWeekMessages = 0;
      int thisMonthMessages = 0;

      for (final msg in messages) {
        if (msg['created_at'] != null) {
          final createdAt = DateTime.parse(msg['created_at']);
          if (createdAt.isAfter(todayStart)) todayMessages++;
          if (createdAt.isAfter(weekStart)) thisWeekMessages++;
          if (createdAt.isAfter(monthStart)) thisMonthMessages++;
        }
      }

      // Last 7 days activity
      List<DailyActivity> last7Days = [];
      for (int i = 6; i >= 0; i--) {
        final date = todayStart.subtract(Duration(days: i));
        final nextDate = date.add(const Duration(days: 1));
        final count = messages.where((m) {
          if (m['created_at'] == null) return false;
          final createdAt = DateTime.parse(m['created_at']);
          return createdAt.isAfter(date) && createdAt.isBefore(nextDate);
        }).length;
        last7Days.add(DailyActivity(date: date, count: count));
      }

      // Top customers
      Map<String, Map<String, dynamic>> customerCounts = {};
      for (final msg in messages) {
        final phone = msg['customer_phone'] as String;
        final name = msg['customer_name'] as String?;
        if (!customerCounts.containsKey(phone)) {
          customerCounts[phone] = {'name': name, 'count': 0};
        }
        customerCounts[phone]!['count'] = (customerCounts[phone]!['count'] as int) + 1;
        if (name != null && name.isNotEmpty) {
          customerCounts[phone]!['name'] = name;
        }
      }

      final sortedCustomers = customerCounts.entries.toList()
        ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

      List<TopCustomer> topCustomers = sortedCustomers.take(5).map((e) => TopCustomer(
        phone: e.key,
        name: e.value['name'] as String?,
        messageCount: e.value['count'] as int,
      )).toList();

      return AnalyticsData(
        totalMessages: totalMessages,
        aiResponses: aiResponses,
        managerResponses: managerResponses,
        uniqueCustomers: uniqueCustomers,
        todayMessages: todayMessages,
        thisWeekMessages: thisWeekMessages,
        thisMonthMessages: thisMonthMessages,
        last7Days: last7Days,
        topCustomers: topCustomers,
      );
    } catch (e) {
      print('Analytics error: $e');
      rethrow;
    }
  }

  // ============================================
  // AI CHAT SETTINGS (Toggle)
  // ============================================

  /// Get AI enabled status for a customer
  Future<bool> getAiEnabled(String customerPhone) async {
    try {
      final response = await client
          .from('ai_chat_settings')
          .select('ai_enabled')
          .eq('ai_phone', ClientConfig.businessPhone)
          .eq('customer_phone', customerPhone)
          .maybeSingle();

      if (response == null) {
        // Default to enabled if no setting exists
        return true;
      }
      return response['ai_enabled'] as bool? ?? true;
    } catch (e) {
      print('Get AI enabled error: $e');
      return true; // Default to enabled
    }
  }

  /// Set AI enabled status for a customer
  Future<bool> setAiEnabled(String customerPhone, bool enabled) async {
    try {
      // Check if setting exists
      final existing = await client
          .from('ai_chat_settings')
          .select('id')
          .eq('ai_phone', ClientConfig.businessPhone)
          .eq('customer_phone', customerPhone)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await client
            .from('ai_chat_settings')
            .update({
              'ai_enabled': enabled,
              'last_changed_by': 'manager',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('ai_phone', ClientConfig.businessPhone)
            .eq('customer_phone', customerPhone);
      } else {
        // Insert new
        await client.from('ai_chat_settings').insert({
          'ai_phone': ClientConfig.businessPhone,
          'customer_phone': customerPhone,
          'ai_enabled': enabled,
          'last_changed_by': 'manager',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      print('AI ${enabled ? "enabled" : "disabled"} for $customerPhone');
      return true;
    } catch (e) {
      print('Set AI enabled error: $e');
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