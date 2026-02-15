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

          // Check if user is blocked
          if (user.isBlocked) {
            print('Login rejected: user is blocked');
            throw Exception('ACCOUNT_BLOCKED');
          }

          if (user.isAdmin) {
            ClientConfig.setAdmin(user);
            print('Admin login successful');

            // Log the login
            await logActivity(
              clientId: user.clientId,
              userId: user.id,
              userName: user.name,
              userEmail: user.email,
              actionType: ActionType.login.value,
              description: '${user.name} logged in',
            );
            
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

          // Log the login
          await logActivity(
            clientId: user.clientId,
            userId: user.id,
            userName: user.name,
            userEmail: user.email,
            actionType: ActionType.login.value,
            description: '${user.name} logged in',
          );

          print('Client login successful');
          return user;
        }
      } catch (rpcError) {
        // Re-throw blocked account errors so they aren't swallowed
        if (rpcError.toString().contains('ACCOUNT_BLOCKED')) {
          rethrow;
        }
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

      // Check if user is blocked
      if (user.isBlocked) {
        print('Login rejected: user is blocked');
        throw Exception('ACCOUNT_BLOCKED');
      }

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

      // Log the login
      await logActivity(
        clientId: user.clientId,
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        actionType: ActionType.login.value,
        description: '${user.name} logged in',
      );

      return user;
    } catch (e, stack) {
      print('Login error: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// Logout - clear client config
  Future<void> logout() async {
    // Log before clearing config
    final user = ClientConfig.currentUser;
    if (user != null) {
      await logActivity(
        clientId: user.clientId,
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        actionType: ActionType.logout.value,
        description: '${user.name} logged out',
      );
    }
    
    ClientConfig.clear();
    _cachedExchanges.clear();
    _channel?.unsubscribe();
    print('Logged out');
  }

  // ============================================
  // ACTIVITY LOGGING
  // ============================================

  /// Log an activity
  Future<bool> logActivity({
    required String? clientId,
    required String userId,
    required String userName,
    String? userEmail,
    required String actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await client.from('activity_logs').insert({
        'client_id': clientId,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'action_type': actionType,
        'description': description,
        'metadata': metadata ?? {},
      });
      return true;
    } catch (e) {
      print('Error logging activity: $e');
      return false;
    }
  }

  /// Quick log helper - uses ClientConfig for context
  Future<void> log({
    required ActionType actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final user = ClientConfig.currentUser;
    if (user == null) return;
    
    await logActivity(
      clientId: user.clientId,
      userId: user.id,
      userName: user.name,
      userEmail: user.email,
      actionType: actionType.value,
      description: description,
      metadata: metadata,
    );
  }

  /// Fetch activity logs
  /// If clientId is null, fetches all logs (for Vivid admins)
  /// If clientId is provided, fetches only that client's logs
  Future<List<ActivityLog>> fetchActivityLogs({String? clientId, int limit = 500}) async {
    try {
      dynamic response;
      
      if (clientId != null) {
        response = await client
            .from('activity_logs')
            .select()
            .eq('client_id', clientId)
            .order('created_at', ascending: false)
            .limit(limit);
      } else {
        response = await client
            .from('activity_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
      }
      
      return (response as List)
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching activity logs: $e');
      return [];
    }
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

  Future<Client?> fetchClientById(String clientId) async {
    try {
      final response = await _client
          ?.from('clients')
          .select()
          .eq('id', clientId)
          .single();
      
      return Client.fromJson(response!);
    } catch (e) {
      print('Error fetching client by ID: $e');
      return null;
    }
  }

  /// Create a new client
  Future<Client?> createClient({
    required String name,
    required String slug,
    List<String> enabledFeatures = const [],
    String? bookingsTable,
    String? conversationsPhone,
    String? conversationsWebhookUrl,
    String? broadcastsPhone,
    String? broadcastsWebhookUrl,
    String? remindersPhone,
    String? remindersWebhookUrl,
    String? managerChatWebhookUrl,
    bool hasAiConversations = true,
  }) async {
    try {
      final response = await client.from('clients').insert({
        'name': name,
        'slug': slug,
        'enabled_features': enabledFeatures,
        'bookings_table': bookingsTable,
        'conversations_phone': conversationsPhone,
        'conversations_webhook_url': conversationsWebhookUrl,
        'broadcasts_phone': broadcastsPhone,
        'broadcasts_webhook_url': broadcastsWebhookUrl,
        'reminders_phone': remindersPhone,
        'reminders_webhook_url': remindersWebhookUrl,
        'manager_chat_webhook_url': managerChatWebhookUrl,
        'has_ai_conversations': hasAiConversations,
      }).select().single();

      final newClient = Client.fromJson(response);
      
      // Log the action
      await log(
        actionType: ActionType.clientCreated,
        description: 'Created client: $name',
        metadata: {
          'client_id': newClient.id,
          'client_name': name,
          'slug': slug,
        },
      );

      return newClient;
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
    List<String>? enabledFeatures,
    String? bookingsTable,
    String? conversationsPhone,
    String? conversationsWebhookUrl,
    String? broadcastsPhone,
    String? broadcastsWebhookUrl,
    String? remindersPhone,
    String? remindersWebhookUrl,
    String? managerChatWebhookUrl,
    bool? hasAiConversations,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (slug != null) updates['slug'] = slug;
      if (enabledFeatures != null) updates['enabled_features'] = enabledFeatures;
      if (bookingsTable != null) updates['bookings_table'] = bookingsTable;
      if (conversationsPhone != null) updates['conversations_phone'] = conversationsPhone;
      if (conversationsWebhookUrl != null) updates['conversations_webhook_url'] = conversationsWebhookUrl;
      if (broadcastsPhone != null) updates['broadcasts_phone'] = broadcastsPhone;
      if (broadcastsWebhookUrl != null) updates['broadcasts_webhook_url'] = broadcastsWebhookUrl;
      if (remindersPhone != null) updates['reminders_phone'] = remindersPhone;
      if (remindersWebhookUrl != null) updates['reminders_webhook_url'] = remindersWebhookUrl;
      if (managerChatWebhookUrl != null) updates['manager_chat_webhook_url'] = managerChatWebhookUrl;
      if (hasAiConversations != null) updates['has_ai_conversations'] = hasAiConversations;

      await client.from('clients').update(updates).eq('id', clientId);
      
      // Log the action
      await log(
        actionType: ActionType.clientUpdated,
        description: 'Updated client${name != null ? ": $name" : ""}',
        metadata: {
          'client_id': clientId,
          'updates': updates.keys.toList(),
        },
      );
      
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

  /// Fetch all users for a client (all roles)
  Future<List<AppUser>> fetchClientUsers(String clientId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('client_id', clientId)
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
    List<String>? customPermissions,
    List<String>? revokedPermissions,
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

      // Add custom permissions if provided
      if (customPermissions != null && customPermissions.isNotEmpty) {
        userData['custom_permissions'] = customPermissions;
      }
      if (revokedPermissions != null && revokedPermissions.isNotEmpty) {
        userData['revoked_permissions'] = revokedPermissions;
      }
      
      final response = await client.from('users').insert(userData).select().single();

      final newUser = AppUser.fromJson(response);
      
      // Log the action
      await log(
        actionType: ActionType.userCreated,
        description: 'Created user: $name ($email)',
        metadata: {
          'new_user_id': newUser.id,
          'new_user_email': email,
          'new_user_name': name,
          'new_user_role': role,
          'has_custom_permissions': customPermissions != null && customPermissions.isNotEmpty,
        },
      );

      return newUser;
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
    String? role,
    List<String>? customPermissions,
    List<String>? revokedPermissions,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (email != null) updates['email'] = email;
      if (name != null) updates['name'] = name;
      if (role != null) updates['role'] = role;

      // Handle custom permissions
      // Empty list = clear, null = don't change
      if (customPermissions != null) {
        updates['custom_permissions'] = customPermissions.isEmpty ? null : customPermissions;
      }
      if (revokedPermissions != null) {
        updates['revoked_permissions'] = revokedPermissions.isEmpty ? null : revokedPermissions;
      }
      
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
      
      // Log the action
      await log(
        actionType: ActionType.userUpdated,
        description: 'Updated user${name != null ? ": $name" : ""}',
        metadata: {
          'user_id': userId,
          'updates': updates.keys.where((k) => k != 'password' && k != 'password_hash').toList(),
        },
      );
      
      return true;
    } catch (e) {
      print('Update user error: $e');
      return false;
    }
  }

  /// Delete a user
  /// Toggle user status between 'active' and 'blocked'
  Future<bool> toggleUserStatus(String userId, String newStatus) async {
    try {
      final userInfo = await client.from('users').select('name, email').eq('id', userId).maybeSingle();

      await client.from('users').update({'status': newStatus}).eq('id', userId);

      if (userInfo != null) {
        final isBlocked = newStatus == 'blocked';
        await log(
          actionType: ActionType.userBlocked,
          description: '${isBlocked ? "Blocked" : "Unblocked"} user: ${userInfo['name']} (${userInfo['email']})',
          metadata: {
            'user_id': userId,
            'user_name': userInfo['name'],
            'user_email': userInfo['email'],
            'new_status': newStatus,
          },
        );
      }

      print('User status updated to $newStatus: $userId');
      return true;
    } catch (e) {
      print('Toggle user status error: $e');
      return false;
    }
  }

  // ============================================
  // PASSWORD RESET
  // ============================================

  /// Check if email exists in users table
  Future<String?> getUserIdByEmail(String email) async {
    try {
      final response = await client
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return response?['id'] as String?;
    } catch (e) {
      print('getUserIdByEmail error: $e');
      return null;
    }
  }

  /// Save a password reset code to the database
  Future<bool> saveResetCode(String email, String code) async {
    try {
      await client.from('password_reset_codes').insert({
        'email': email,
        'code': code,
        'used': false,
      });
      return true;
    } catch (e) {
      print('saveResetCode error: $e');
      return false;
    }
  }

  /// Send reset code via n8n webhook
  Future<bool> sendResetCodeEmail(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://n8n.vividsystems.cloud/webhook/password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('sendResetCodeEmail error: $e');
      return false;
    }
  }

  /// Verify a reset code: must match email, code, not used, and within 10 minutes
  Future<bool> verifyResetCode(String email, String code) async {
    try {
      final tenMinutesAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 10)).toIso8601String();
      final response = await client
          .from('password_reset_codes')
          .select()
          .eq('email', email)
          .eq('code', code)
          .eq('used', false)
          .gte('created_at', tenMinutesAgo)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('verifyResetCode error: $e');
      return false;
    }
  }

  /// Reset password by email and mark the code as used
  Future<bool> resetPasswordByEmail(String email, String newPassword, String code) async {
    try {
      // Hash the password if possible
      final updates = <String, dynamic>{};
      try {
        final hashResult = await client.rpc('hash_password', params: {
          'password': newPassword,
        });
        updates['password_hash'] = hashResult;
        updates['password'] = newPassword;
      } catch (e) {
        updates['password'] = newPassword;
      }

      await client.from('users').update(updates).eq('email', email);

      // Mark code as used
      await client
          .from('password_reset_codes')
          .update({'used': true})
          .eq('email', email)
          .eq('code', code);

      return true;
    } catch (e) {
      print('resetPasswordByEmail error: $e');
      return false;
    }
  }

  // ============================================
  // FETCH EXCHANGES (DYNAMIC TABLE)
  // ============================================

  Future<List<RawExchange>> fetchAllExchanges() async {
    try {
      // Use dynamic table name from ClientConfig
      final tableName = ClientConfig.messagesTableName;
      final businessPhone = ClientConfig.conversationsPhone;
      
      if (businessPhone == null || businessPhone.isEmpty) {
        print('No conversations phone configured');
        return [];
      }
      
      final response = await client
          .from(tableName)  // Dynamic table name!
          .select()
          .eq('ai_phone', businessPhone)
          .order('created_at', ascending: true);

      _cachedExchanges = (response as List)
          .map((json) => RawExchange.fromJson(json))
          .toList();

      print('Fetched ${_cachedExchanges.length} exchanges from $tableName');
      return _cachedExchanges;
    } catch (e) {
      print('Fetch error: $e');
      rethrow;
    }
  }

  // ============================================
  // REAL-TIME SUBSCRIPTION (DYNAMIC TABLE)
  // ============================================

  void subscribeToExchanges() {
    final businessPhone = ClientConfig.conversationsPhone;
    
    // Check if conversations is configured
    if (!ClientConfig.isConversationsConfigured) {
      print('Conversations not configured - skipping subscription');
      return;
    }
    
    final tableName = ClientConfig.messagesTableName;

    _channel?.unsubscribe();

    _channel = client
        .channel('messages_realtime_$tableName')  // Unique channel per table
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: tableName,  // Dynamic table name!
          callback: (payload) {
            print('New message in $tableName: ${payload.newRecord}');
            
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
          table: tableName,  // Dynamic table name!
          callback: (payload) {
            print('Updated message in $tableName: ${payload.newRecord}');
            
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
          table: tableName,  // Dynamic table name!
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            _cachedExchanges.removeWhere((e) => e.id == deletedId);
            _exchangesController.add(List.from(_cachedExchanges));
          },
        )
        .subscribe();

    print('Subscribed to real-time messages on $tableName');
  }

  // ============================================
  // SEND MESSAGE VIA WEBHOOK (saves to manager_response)
  // ============================================

  Future<bool> sendMessageViaWebhook({
    required String customerPhone,
    required String message,
    String? customerName,
    String? mediaUrl,
    String? mediaType,
    String? mediaFilename,
  }) async {
    try {
      final webhookUrl = ClientConfig.conversationsWebhookUrl;
      if (webhookUrl == null || webhookUrl.isEmpty) {
        print('No conversations webhook URL configured');
        return false;
      }

      final payload = {
        'ai_phone': ClientConfig.conversationsPhone,
        'customer_phone': customerPhone,
        'customer_name': customerName ?? 'Customer',
        'manager_response': message,
        'messages_table': ClientConfig.messagesTable,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'media_type': mediaType,
        if (mediaFilename != null) 'media_filename': mediaFilename,
      };

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('Message sent via webhook');
        
        // Log the action
        await log(
          actionType: ActionType.messageSent,
          description: 'Sent message to ${customerName ?? customerPhone}',
          metadata: {
            'customer_phone': customerPhone,
            'customer_name': customerName,
            'message_preview': message.length > 50 ? '${message.substring(0, 50)}...' : message,
          },
        );
        
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
  // ANALYTICS (DYNAMIC TABLE)
  // ============================================

  Future<AnalyticsData> fetchAnalytics() async {
    try {
      // Check if conversations is configured
      if (!ClientConfig.isConversationsConfigured) {
        print('Conversations not configured for analytics');
        return AnalyticsData(
          totalMessages: 0,
          aiResponses: 0,
          managerResponses: 0,
          uniqueCustomers: 0,
          todayMessages: 0,
          thisWeekMessages: 0,
          thisMonthMessages: 0,
          last7Days: [],
          topCustomers: [],
        );
      }
      
      final tableName = ClientConfig.messagesTableName;
      final businessPhone = ClientConfig.conversationsPhone!;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Fetch all messages from dynamic table
      final allMessages = await client
          .from(tableName)  // Dynamic table name!
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
          .eq('ai_phone', ClientConfig.conversationsPhone ?? '')
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
      final aiPhone = ClientConfig.conversationsPhone;
      if (aiPhone == null) return false;
      
      // Check if setting exists
      final existing = await client
          .from('ai_chat_settings')
          .select('id')
          .eq('ai_phone', aiPhone)
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
            .eq('ai_phone', aiPhone)
            .eq('customer_phone', customerPhone);
      } else {
        // Insert new
        await client.from('ai_chat_settings').insert({
          'ai_phone': aiPhone,
          'customer_phone': customerPhone,
          'ai_enabled': enabled,
          'last_changed_by': 'manager',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Log the action
      await log(
        actionType: ActionType.aiToggled,
        description: 'AI ${enabled ? "enabled" : "disabled"} for $customerPhone',
        metadata: {
          'customer_phone': customerPhone,
          'ai_enabled': enabled,
        },
      );

      print('AI ${enabled ? "enabled" : "disabled"} for $customerPhone');
      return true;
    } catch (e) {
      print('Set AI enabled error: $e');
      return false;
    }
  }

  // ============================================
  // BOOKING REMINDERS
  // ============================================

  /// Fetch all bookings from client's bookings table
  Future<List<Booking>> fetchBookings(String tableName) async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true);

      return (response as List)
          .map((json) => Booking.fromJson(json))
          .toList();
    } catch (e) {
      print('Fetch bookings error: $e');
      return [];
    }
  }

  /// Fetch only upcoming bookings (today and future)
  Future<List<Booking>> fetchUpcomingBookings(String tableName) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final response = await client
          .from(tableName)
          .select()
          .gte('appointment_date', todayStr)
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true);

      return (response as List)
          .map((json) => Booking.fromJson(json))
          .toList();
    } catch (e) {
      print('Fetch upcoming bookings error: $e');
      return [];
    }
  }

  /// Subscribe to real-time booking updates
  Stream<List<Booking>> subscribeToBookings(String tableName) {
    final controller = StreamController<List<Booking>>.broadcast();
    
    // Create channel for this table
    final channel = client
        .channel('bookings_realtime_$tableName')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tableName,
          callback: (payload) {
            print('Booking change detected: ${payload.eventType}');
            // Refetch all bookings on any change
            fetchBookings(tableName).then((bookings) {
              if (!controller.isClosed) {
                controller.add(bookings);
              }
            });
          },
        )
        .subscribe();

    // Initial fetch
    fetchBookings(tableName).then((bookings) {
      if (!controller.isClosed) {
        controller.add(bookings);
      }
    });

    // Clean up on stream close
    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  /// Update booking reminder status
  Future<bool> updateBookingReminderStatus({
    required String tableName,
    required String bookingId,
    bool? reminder3Day,
    bool? reminder1Day,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (reminder3Day != null) updates['reminder_3day'] = reminder3Day;
      if (reminder1Day != null) updates['reminder_1day'] = reminder1Day;
      if (status != null) updates['status'] = status;

      if (updates.isEmpty) return true;

      await client
          .from(tableName)
          .update(updates)
          .eq('id', bookingId);

      print('Updated booking $bookingId: $updates');
      return true;
    } catch (e) {
      print('Update booking error: $e');
      return false;
    }
  }

  /// Get booking statistics
  Future<BookingReminderStats> getBookingStats(String tableName) async {
    try {
      final bookings = await fetchBookings(tableName);
      return BookingReminderStats.fromBookings(bookings);
    } catch (e) {
      print('Get booking stats error: $e');
      return BookingReminderStats.empty();
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