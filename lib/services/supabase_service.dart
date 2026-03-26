import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // WARNING: Service role key bypasses ALL RLS — internal dashboard use only.
  // Get from: Supabase → Project Settings → API → service_role secret key.
  // TODO: Replace the placeholder below with your actual service role key.
  static const String _supabaseServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4dmp6YW93dnp2ZmdyemRpbWJtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTU2MzYyNSwiZXhwIjoyMDgxMTM5NjI1fQ.Fn-X_nwqm9pUtnn6vhKm_p11sXL7R4gtn1Q7H6e24Y4';

  // Lazy admin client — created once on first use, used only for Storage uploads.
  static SupabaseClient? _adminClient;
  static SupabaseClient get adminClient {
    _adminClient ??= SupabaseClient(_supabaseUrl, _supabaseServiceRoleKey);
    return _adminClient!;
  }

  // Webhook URL is now loaded from ClientConfig

  // ============================================
  // META API CONFIG
  // ============================================

  static String metaApiVersion = 'v21.0';
  static String metaAccessToken = '';
  static String metaWabaId = '';
  static String metaAppId = '1969042950344680';

  // Outreach config (loaded from system_settings, NOT from ClientConfig)
  static final Map<String, String> _outreachConfig = {};
  static String get outreachPhone => _outreachConfig['outreach_phone'] ?? '';
  static String get outreachSendWebhook => _outreachConfig['outreach_send_webhook'] ?? '';
  static String get outreachBroadcastWebhook => _outreachConfig['outreach_broadcast_webhook'] ?? '';
  static String get outreachWabaId => _outreachConfig['outreach_waba_id'] ?? '';
  static String get outreachMetaAccessToken => _outreachConfig['outreach_meta_access_token'] ?? '';
  static String get webhookSecret => _outreachConfig['webhook_secret'] ?? '';

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
    ClientConfig.registerPreviewCredentialCallbacks(
      onEnter: applyClientMetaConfig,
      onExit: resetToDefaultMetaConfig,
    );
    debugPrint('Supabase initialized');
  }

  // ============================================
  // AUTHENTICATION
  // ============================================

  /// Login with email and password (unified for admins and clients)
  /// Returns AppUser if successful, null otherwise
  Future<AppUser?> login(String email, String password) async {
    try {
      debugPrint('Attempting login for: $email');
      
      // Try secure login function first (hashed passwords)
      try {
        final loginResponse = await client
            .rpc('login_user', params: {
              'p_email': email,
              'p_password': password,
            });

        if (loginResponse != null && (loginResponse as List).isNotEmpty) {
          final userData = loginResponse[0];
          debugPrint('User found via secure login: ${userData['name']} (${userData['role']})');
          
          // Fetch full user data
          final userResponse = await client
              .from('users')
              .select()
              .eq('id', userData['id'])
              .single();

          final user = AppUser.fromJson(userResponse);

          // Check if user is blocked
          if (user.isBlocked) {
            debugPrint('Login rejected: user is blocked');
            throw Exception('ACCOUNT_BLOCKED');
          }

          if (user.isAdmin) {
            ClientConfig.setAdmin(user);
            debugPrint('Admin login successful');

            // If admin has a client_id (e.g. client-level admin like HOB Manager),
            // load the client config so WABA ID and table routing work correctly.
            if (user.clientId != null) {
              try {
                final adminClientResponse = await client
                    .from('clients')
                    .select()
                    .eq('id', user.clientId!)
                    .maybeSingle();
                if (adminClientResponse != null) {
                  final clientData = Client.fromJson(adminClientResponse);
                  ClientConfig.setClientUser(clientData, user);
                  applyClientMetaConfig(clientData);
                }
              } catch (e) {
                debugPrint('Could not load client config for admin: $e');
              }
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
            applyClientMetaConfig(clientData);
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

          debugPrint('Client login successful');
          return user;
        }
      } catch (rpcError) {
        // Re-throw blocked account errors so they aren't swallowed
        if (rpcError.toString().contains('ACCOUNT_BLOCKED')) {
          rethrow;
        }
        debugPrint('Secure login not available, trying fallback: $rpcError');
      }
      
      // Fallback: plain text password (for transition period)
      final userResponse = await client
          .from('users')
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      if (userResponse == null) {
        debugPrint('No user found with email: $email');
        return null;
      }

      debugPrint('User found via fallback: ${userResponse['name']} (${userResponse['role']})');

      final user = AppUser.fromJson(userResponse);

      // Check if user is blocked
      if (user.isBlocked) {
        debugPrint('Login rejected: user is blocked');
        throw Exception('ACCOUNT_BLOCKED');
      }

      if (user.isAdmin) {
        // Admin user - no client needed
        ClientConfig.setAdmin(user);
        debugPrint('Admin logged in: ${user.name}');

        // If admin has a client_id (e.g. client-level admin like HOB Manager),
        // load the client config so WABA ID and table routing work correctly.
        if (user.clientId != null) {
          try {
            final adminClientResponse = await client
                .from('clients')
                .select()
                .eq('id', user.clientId!)
                .maybeSingle();
            if (adminClientResponse != null) {
              final clientData = Client.fromJson(adminClientResponse);
              ClientConfig.setClientUser(clientData, user);
              applyClientMetaConfig(clientData);
            }
          } catch (e) {
            debugPrint('Could not load client config for admin: $e');
          }
        }
      } else {
        // Client user - fetch their client config
        if (user.clientId == null) {
          debugPrint('ERROR: Client user has no client_id');
          return null;
        }

        debugPrint('Fetching client with id: ${user.clientId}');
        
        final clientResponse = await client
            .from('clients')
            .select()
            .eq('id', user.clientId!)
            .maybeSingle();

        if (clientResponse == null) {
          debugPrint('ERROR: No client found with id: ${user.clientId}');
          return null;
        }

        final clientData = Client.fromJson(clientResponse);
        ClientConfig.setClientUser(clientData, user);
        applyClientMetaConfig(clientData);

        debugPrint('Logged in as ${user.name} for ${clientData.name}');
        debugPrint('Enabled features: ${clientData.enabledFeatures}');
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
      debugPrint('Login error: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  // ============================================
  // PER-CLIENT META CONFIG
  // ============================================

  // Safe empty defaults — no client's credentials are baked in.
  // Each client must have waba_id and meta_access_token set in the DB.
  static const String _defaultMetaAccessToken = '';
  static const String _defaultMetaWabaId = '';

  /// Resets metaWabaId / metaAccessToken back to empty defaults.
  /// Called when exiting client preview mode.
  static void resetToDefaultMetaConfig() {
    metaWabaId = _defaultMetaWabaId;
    metaAccessToken = _defaultMetaAccessToken;
  }

  /// Overrides metaWabaId / metaAccessToken from the client's DB row.
  /// Logs a warning when credentials are missing — fails loudly instead
  /// of silently using another client's token.
  static void applyClientMetaConfig(Client client) {
    if (client.wabaId != null && client.wabaId!.isNotEmpty) {
      metaWabaId = client.wabaId!;
    } else {
      metaWabaId = _defaultMetaWabaId;
      debugPrint('[Meta] WARNING: No waba_id for client ${client.name} — set it in Supabase clients table.');
    }
    if (client.metaAccessToken != null && client.metaAccessToken!.isNotEmpty) {
      metaAccessToken = client.metaAccessToken!;
    } else {
      metaAccessToken = _defaultMetaAccessToken;
      debugPrint('[Meta] WARNING: No meta_access_token for client ${client.name} — template sync will fail. Set token in Supabase clients table.');
    }
    debugPrint('📋 Client loaded: ${client.name}');
    debugPrint('📋 Messages table: ${ClientConfig.messagesTable}');
    debugPrint('📋 Templates table: ${ClientConfig.templatesTable}');
    debugPrint('📋 AI Settings table: ${ClientConfig.aiSettingsTableName}');
    debugPrint('📋 Predictions table: ${ClientConfig.customerPredictionsTableName}');
    debugPrint('📋 WABA ID: $metaWabaId');
    debugPrint('📋 Conversations phone: ${ClientConfig.conversationsPhone}');
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

    // Reset Meta credentials to defaults so the next login gets fresh values
    metaWabaId = _defaultMetaWabaId;
    metaAccessToken = _defaultMetaAccessToken;

    ClientConfig.clear();
    _cachedExchanges.clear();
    _channel?.unsubscribe();
    debugPrint('Logged out');
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
      debugPrint('Error logging activity: $e');
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
  /// Fetch activity logs with optional server-side filters and pagination.
  ///
  /// [clientId] — filter by client; null = all clients.
  /// [actionTypes] — filter by action type strings (e.g. ['login','logout']).
  /// [startDate] / [endDate] — date range filter.
  /// [offset] — pagination offset (0-based).
  /// [limit] — page size.
  Future<List<ActivityLog>> fetchActivityLogs({
    String? clientId,
    List<String>? actionTypes,
    DateTime? startDate,
    DateTime? endDate,
    int offset = 0,
    int limit = 100,
  }) async {
    try {
      var query = client.from('activity_logs').select();

      if (clientId != null) {
        query = query.eq('client_id', clientId);
      }
      if (actionTypes != null && actionTypes.isNotEmpty) {
        query = query.inFilter('action_type', actionTypes);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching activity logs: $e');
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
      debugPrint('Fetch clients error: $e');
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
      debugPrint('Error fetching client by ID: $e');
      return null;
    }
  }

  /// Create a new client
  Future<Client?> createClient({
    required String name,
    required String slug,
    List<String> enabledFeatures = const [],
    String? messagesTable,
    String? broadcastsTable,
    String? templatesTable,
    String? managerChatsTable,
    String? broadcastRecipientsTable,
    String? aiSettingsTable,
    String? conversationsPhone,
    String? conversationsWebhookUrl,
    String? broadcastsPhone,
    String? broadcastsWebhookUrl,
    String? remindersPhone,
    String? remindersWebhookUrl,
    String? managerChatWebhookUrl,
    String? customerPredictionsTable,
    bool hasAiConversations = true,
    String? wabaId,
    String? metaAccessToken,
    int? broadcastLimit,
    String? productType,
    String? predictionsRefreshWebhookUrl,
  }) async {
    try {
      final response = await client.from('clients').insert({
        'name': name,
        'slug': slug,
        'enabled_features': enabledFeatures,
        'messages_table': messagesTable,
        'broadcasts_table': broadcastsTable,
        'templates_table': templatesTable,
        'manager_chats_table': managerChatsTable,
        'broadcast_recipients_table': broadcastRecipientsTable,
        'ai_settings_table': aiSettingsTable,
        'customer_predictions_table': customerPredictionsTable,
        'conversations_phone': conversationsPhone,
        'conversations_webhook_url': conversationsWebhookUrl,
        'broadcasts_phone': broadcastsPhone,
        'broadcasts_webhook_url': broadcastsWebhookUrl,
        'reminders_phone': remindersPhone,
        'reminders_webhook_url': remindersWebhookUrl,
        'manager_chat_webhook_url': managerChatWebhookUrl,
        'has_ai_conversations': hasAiConversations,
        if (wabaId != null && wabaId.isNotEmpty) 'waba_id': wabaId,
        if (metaAccessToken != null && metaAccessToken.isNotEmpty) 'meta_access_token': metaAccessToken,
        if (broadcastLimit != null) 'broadcast_limit': broadcastLimit,
        if (productType != null) 'product_type': productType,
        if (predictionsRefreshWebhookUrl != null && predictionsRefreshWebhookUrl.isNotEmpty) 'predictions_refresh_webhook_url': predictionsRefreshWebhookUrl,
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
      debugPrint('Create client error: $e');
      return null;
    }
  }

  /// Update a client
  Future<bool> updateClient({
    required String clientId,
    String? name,
    String? slug,
    List<String>? enabledFeatures,
    String? messagesTable,
    String? broadcastsTable,
    String? templatesTable,
    String? managerChatsTable,
    String? broadcastRecipientsTable,
    String? aiSettingsTable,
    String? conversationsPhone,
    String? conversationsWebhookUrl,
    String? broadcastsPhone,
    String? broadcastsWebhookUrl,
    String? remindersPhone,
    String? remindersWebhookUrl,
    String? managerChatWebhookUrl,
    String? customerPredictionsTable,
    bool? hasAiConversations,
    String? wabaId,
    String? metaAccessToken,
    int? broadcastLimit,
    String? productType,
    String? predictionsRefreshWebhookUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (slug != null) updates['slug'] = slug;
      if (enabledFeatures != null) updates['enabled_features'] = enabledFeatures;
      if (messagesTable != null) updates['messages_table'] = messagesTable;
      if (broadcastsTable != null) updates['broadcasts_table'] = broadcastsTable;
      if (templatesTable != null) updates['templates_table'] = templatesTable;
      if (managerChatsTable != null) updates['manager_chats_table'] = managerChatsTable;
      if (broadcastRecipientsTable != null) updates['broadcast_recipients_table'] = broadcastRecipientsTable;
      if (aiSettingsTable != null) updates['ai_settings_table'] = aiSettingsTable;
      if (customerPredictionsTable != null) updates['customer_predictions_table'] = customerPredictionsTable;
      if (conversationsPhone != null) updates['conversations_phone'] = conversationsPhone;
      if (conversationsWebhookUrl != null) updates['conversations_webhook_url'] = conversationsWebhookUrl;
      if (broadcastsPhone != null) updates['broadcasts_phone'] = broadcastsPhone;
      if (broadcastsWebhookUrl != null) updates['broadcasts_webhook_url'] = broadcastsWebhookUrl;
      if (remindersPhone != null) updates['reminders_phone'] = remindersPhone;
      if (remindersWebhookUrl != null) updates['reminders_webhook_url'] = remindersWebhookUrl;
      if (managerChatWebhookUrl != null) updates['manager_chat_webhook_url'] = managerChatWebhookUrl;
      if (hasAiConversations != null) updates['has_ai_conversations'] = hasAiConversations;
      if (wabaId != null) updates['waba_id'] = wabaId;
      if (metaAccessToken != null) updates['meta_access_token'] = metaAccessToken;
      if (broadcastLimit != null) updates['broadcast_limit'] = broadcastLimit;
      if (productType != null) updates['product_type'] = productType;
      if (predictionsRefreshWebhookUrl != null) updates['predictions_refresh_webhook_url'] = predictionsRefreshWebhookUrl;

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
      debugPrint('Update client error: $e');
      return false;
    }
  }

  /// Fetch a customer prediction by phone number from the client's predictions table.
  Future<CustomerPrediction?> fetchCustomerPrediction(String customerPhone) async {
    final table = ClientConfig.customerPredictionsTable;
    if (table == null || table.isEmpty) return null;
    try {
      final response = await client
          .from(table)
          .select()
          .eq('phone', customerPhone)
          .maybeSingle();
      if (response == null) return null;
      return CustomerPrediction.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching prediction: $e');
      return null;
    }
  }

  /// Fetch aggregate prediction stats for the Vivid AI panel.
  /// Returns null if predictions table is not configured or on any error.
  static Future<PredictionStats?> fetchPredictionStats() async {
    final table = ClientConfig.customerPredictionsTable;
    if (table == null || table.isEmpty) return null;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final in7Days =
          DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T')[0];
      final in30Days =
          DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0];

      final overdueRes = await adminClient.from(table).select().lt('predicted_next_visit', today);
      final weekRes = await adminClient
          .from(table)
          .select()
          .gte('predicted_next_visit', today)
          .lte('predicted_next_visit', in7Days);
      final monthRes = await adminClient
          .from(table)
          .select()
          .gt('predicted_next_visit', in7Days)
          .lte('predicted_next_visit', in30Days);
      final allRows = await adminClient.from(table).select('primary_service');

      final Map<String, int> services = {};
      for (final row in allRows as List) {
        final svc = (row['primary_service'] as String?) ?? 'Other';
        services[svc] = (services[svc] ?? 0) + 1;
      }
      final sorted = Map.fromEntries(
        services.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      );
      final top5 = Map.fromEntries(sorted.entries.take(5));

      return PredictionStats(
        overdueCount: (overdueRes as List).length,
        thisWeekCount: (weekRes as List).length,
        thisMonthCount: (monthRes as List).length,
        serviceBreakdown: top5,
      );
    } catch (e) {
      debugPrint('[PredictionStats] fetch failed: $e');
      return null;
    }
  }

  /// Delete a client
  Future<bool> deleteClient(String clientId) async {
    try {
      // Delete client's users first as a safety measure
      await client.from('users').delete().eq('client_id', clientId);
      await client.from('clients').delete().eq('id', clientId);
      return true;
    } catch (e) {
      debugPrint('Delete client error: $e');
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
      debugPrint('Fetch client users error: $e');
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
      debugPrint('Fetch all users error: $e');
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
        debugPrint('Hash function not available, storing plain (temporary): $e');
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
      debugPrint('Create user error: $e');
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
          debugPrint('Hash function not available, storing plain (temporary): $e');
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
      debugPrint('Update user error: $e');
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

      debugPrint('User status updated to $newStatus: $userId');
      return true;
    } catch (e) {
      debugPrint('Toggle user status error: $e');
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
      debugPrint('getUserIdByEmail error: $e');
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
      debugPrint('saveResetCode error: $e');
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
      debugPrint('sendResetCodeEmail error: $e');
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
      debugPrint('verifyResetCode error: $e');
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
      debugPrint('resetPasswordByEmail error: $e');
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
      if (tableName == null || tableName.isEmpty) return [];
      final businessPhone = ClientConfig.conversationsPhone;

      if (businessPhone == null || businessPhone.isEmpty) {
        debugPrint('No conversations phone configured');
        return [];
      }

      // Paginate to fetch ALL rows (Supabase default limit is 1000)
      const pageSize = 1000;
      List<Map<String, dynamic>> allRows = [];
      int from = 0;

      while (true) {
        final response = await client
            .from(tableName)
            .select()
            .eq('ai_phone', businessPhone)
            .order('created_at', ascending: true)
            .range(from, from + pageSize - 1);

        final rows = List<Map<String, dynamic>>.from(response as List);
        allRows.addAll(rows);

        if (rows.length < pageSize) break; // Last page
        from += pageSize;
      }

      _cachedExchanges = allRows
          .map((json) => RawExchange.fromJson(json))
          .toList();

      debugPrint('Fetched ${_cachedExchanges.length} exchanges from $tableName');
      return _cachedExchanges;
    } catch (e) {
      debugPrint('Fetch error: $e');
      rethrow;
    }
  }

  // ============================================
  // MESSAGE SEARCH (SUPABASE ilike)
  // ============================================

  /// Search messages table for query matches in customer_message, manager_response,
  /// customer_name, or customer_phone. Returns raw rows sorted by created_at desc.
  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    try {
      final tableName = ClientConfig.messagesTableName;
      if (tableName == null || tableName.isEmpty) return [];
      final businessPhone = ClientConfig.conversationsPhone;
      if (businessPhone == null || businessPhone.isEmpty) return [];

      final pattern = '%$query%';
      final response = await client
          .from(tableName)
          .select()
          .eq('ai_phone', businessPhone)
          .or('customer_message.ilike.$pattern,manager_response.ilike.$pattern,customer_name.ilike.$pattern,customer_phone.ilike.$pattern')
          .order('created_at', ascending: false)
          .limit(500);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  // ============================================
  // REAL-TIME SUBSCRIPTION (DYNAMIC TABLE)
  // ============================================

  void subscribeToExchanges() {
    // Never subscribe to real-time updates in preview mode — read-only snapshot only
    if (ClientConfig.isPreviewMode) {
      debugPrint('Preview mode — skipping real-time subscription');
      return;
    }

    final businessPhone = ClientConfig.conversationsPhone;

    // Check if conversations is configured
    if (!ClientConfig.isConversationsConfigured) {
      debugPrint('Conversations not configured - skipping subscription');
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
            debugPrint('New message in $tableName');
            
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
            debugPrint('Updated message in $tableName');
            
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

    debugPrint('Subscribed to real-time messages on $tableName');
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
        debugPrint('No conversations webhook URL configured');
        return false;
      }

      final payload = {
        'ai_phone': ClientConfig.conversationsPhone,
        'customer_phone': customerPhone,
        'customer_name': customerName ?? 'Customer',
        'manager_response': message,
        'sent_by': ClientConfig.currentUserName,
        'messages_table': ClientConfig.messagesTable,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'media_type': mediaType,
        if (mediaFilename != null) 'media_filename': mediaFilename,
      };

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {
          'Content-Type': 'application/json',
          if (webhookSecret.isNotEmpty) 'X-Vivid-Secret': webhookSecret,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('Message sent via webhook');
        
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
        debugPrint('Webhook error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Webhook error: $e');
      return false;
    }
  }

  // ============================================
  // UPDATE CONVERSATION LABEL
  // ============================================

  /// Updates the label on the most recent exchange for a customer phone.
  Future<bool> updateConversationLabel({
    required String customerPhone,
    required String label,
  }) async {
    try {
      final tableName = ClientConfig.messagesTable;
      if (tableName == null) return false;

      if (label.isEmpty) {
        // CLEAR: remove label from ALL rows for this customer
        try {
          await client
              .from(tableName)
              .update({'label': '', 'label_set_at': null})
              .eq('customer_phone', customerPhone)
              .neq('label', '');
        } catch (_) {
          await client
              .from(tableName)
              .update({'label': ''})
              .eq('customer_phone', customerPhone)
              .neq('label', '');
        }
      } else {
        // SET: update the most recent row for this customer
        final rows = await client
            .from(tableName)
            .select('id')
            .eq('customer_phone', customerPhone)
            .order('created_at', ascending: false)
            .limit(1);

        if (rows.isEmpty) return false;

        final rowId = rows[0]['id'].toString();
        final labelSetAt = DateTime.now().toUtc().toIso8601String();

        try {
          await client
              .from(tableName)
              .update({'label': label, 'label_set_at': labelSetAt})
              .eq('id', rowId);
        } catch (_) {
          await client
              .from(tableName)
              .update({'label': label})
              .eq('id', rowId);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating label: $e');
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
        debugPrint('Conversations not configured for analytics');
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
      if (tableName == null || tableName.isEmpty) return AnalyticsData(totalMessages: 0, aiResponses: 0, managerResponses: 0, uniqueCustomers: 0, todayMessages: 0, thisWeekMessages: 0, thisMonthMessages: 0, last7Days: [], topCustomers: []);
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
      debugPrint('Analytics error: $e');
      rethrow;
    }
  }

  // ============================================
  // AI CHAT SETTINGS (Toggle)
  // ============================================

  /// Get AI enabled status for a customer
  Future<bool> getAiEnabled(String customerPhone) async {
    final table = ClientConfig.aiSettingsTable;
    if (table == null || table.isEmpty) return true; // Default: AI enabled
    try {
      final response = await client
          .from(table)
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
      debugPrint('Get AI enabled error: $e');
      return true; // Default to enabled
    }
  }

  /// Set AI enabled status for a customer
  Future<bool> setAiEnabled(String customerPhone, bool enabled) async {
    try {
      final aiPhone = ClientConfig.conversationsPhone;
      if (aiPhone == null) return false;

      final table = ClientConfig.aiSettingsTable;
      if (table == null || table.isEmpty) return false;

      // Check if setting exists
      final existing = await client
          .from(table)
          .select('id')
          .eq('ai_phone', aiPhone)
          .eq('customer_phone', customerPhone)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await client
            .from(table)
            .update({
              'ai_enabled': enabled,
              'last_changed_by': 'manager',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('ai_phone', aiPhone)
            .eq('customer_phone', customerPhone);
      } else {
        // Insert new
        await client.from(table).insert({
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

      debugPrint('AI ${enabled ? "enabled" : "disabled"} for $customerPhone');
      return true;
    } catch (e) {
      debugPrint('Set AI enabled error: $e');
      return false;
    }
  }

  // ============================================
  // CUSTOMER PROFILE STATS
  // ============================================

  Future<CustomerProfileStats> fetchCustomerProfileStats(String customerPhone) async {
    try {
      final table = ClientConfig.messagesTable;
      if (table == null || table.isEmpty) {
        return const CustomerProfileStats(
          totalExchanges: 0, customerMessageCount: 0,
          agentMessageCount: 0, broadcastCount: 0, broadcastResponseRate: 0,
        );
      }
      final rows = await client
          .from(table)
          .select()
          .eq('customer_phone', customerPhone)
          .order('created_at', ascending: false);
      int customerMsgs = 0, agentMsgs = 0;
      DateTime? lastContactedAt;
      for (final row in rows) {
        final sender = row['sender_type'] as String? ?? '';
        if (sender == 'customer') customerMsgs++; else agentMsgs++;
      }
      if (rows.isNotEmpty) {
        final ts = rows.first['created_at'] as String?;
        if (ts != null) lastContactedAt = DateTime.tryParse(ts);
      }
      return CustomerProfileStats(
        totalExchanges: rows.length,
        customerMessageCount: customerMsgs,
        agentMessageCount: agentMsgs,
        broadcastCount: 0,
        broadcastResponseRate: 0,
        lastContactedAt: lastContactedAt,
      );
    } catch (e) {
      debugPrint('fetchCustomerProfileStats error: $e');
      return const CustomerProfileStats(
        totalExchanges: 0, customerMessageCount: 0,
        agentMessageCount: 0, broadcastCount: 0, broadcastResponseRate: 0,
      );
    }
  }

  // ============================================
  // SYSTEM SETTINGS
  // ============================================

  /// Fetch all system settings as a key-value map.
  /// The table 'system_settings' has columns: key, value.
  Future<Map<String, String>> fetchSystemSettings() async {
    try {
      final response = await client.from('system_settings').select('key, value');
      final rows = response as List;
      final map = <String, String>{};
      for (final row in rows) {
        final k = row['key'] as String?;
        final v = row['value'] as String?;
        if (k != null) map[k] = v ?? '';
      }
      return map;
    } catch (e) {
      debugPrint('fetchSystemSettings error: $e');
      return {};
    }
  }

  /// Insert or update a single system setting.
  Future<bool> updateSystemSetting(String key, String value, {String? updatedBy}) async {
    try {
      await client.from('system_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (updatedBy != null) 'updated_by': updatedBy,
      }, onConflict: 'key');
      return true;
    } catch (e) {
      debugPrint('updateSystemSetting error: $e');
      return false;
    }
  }

  /// Load system settings and apply Meta API values to static fields.
  Future<void> loadAndApplySystemSettings() async {
    final settings = await fetchSystemSettings();
    if (settings.containsKey('meta_api_version') && settings['meta_api_version']!.isNotEmpty) {
      metaApiVersion = settings['meta_api_version']!;
    }
    if (settings.containsKey('meta_access_token') && settings['meta_access_token']!.isNotEmpty) {
      metaAccessToken = settings['meta_access_token']!;
    }
    if (settings.containsKey('meta_waba_id') && settings['meta_waba_id']!.isNotEmpty) {
      metaWabaId = settings['meta_waba_id']!;
    }
    if (settings.containsKey('meta_app_id') && settings['meta_app_id']!.isNotEmpty) {
      metaAppId = settings['meta_app_id']!;
    }

    // Also load outreach config from system_settings
    await loadOutreachConfig();
  }

  /// Load outreach-specific config from system_settings.
  /// Outreach does NOT use ClientConfig — Vivid is the platform operator, not a client.
  Future<void> loadOutreachConfig() async {
    try {
      final response = await adminClient
          .from('system_settings')
          .select('key, value')
          .inFilter('key', ['outreach_phone', 'outreach_send_webhook', 'outreach_broadcast_webhook', 'outreach_waba_id', 'outreach_meta_access_token', 'webhook_secret']);
      _outreachConfig.clear();
      for (final row in (response as List)) {
        final k = row['key'] as String?;
        final v = row['value'] as String?;
        if (k != null && v != null) _outreachConfig[k] = v;
      }
      debugPrint('OUTREACH CONFIG: loaded ${_outreachConfig.length} keys');
    } catch (e) {
      debugPrint('OUTREACH CONFIG: load error: $e');
    }
  }

  /// Check if a Supabase table exists by running a limited SELECT.
  /// Returns true if the table responds, false on error.
  Future<bool> doesTableExist(String tableName) async {
    try {
      await client.from(tableName).select('*').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get approximate row count for a table.
  Future<int> getTableRowCount(String tableName) async {
    try {
      final response = await client.from(tableName).select('*');
      return (response as List).length;
    } catch (e) {
      return -1; // -1 signals error
    }
  }

  /// Batch-check multiple tables: returns map of tableName → row count.
  /// A null value means the table does not exist (or access denied).
  Future<Map<String, int?>> checkTablesStatus(List<String> tableNames) async {
    final results = <String, int?>{};
    for (final table in tableNames) {
      try {
        final response = await client.from(table).select('id');
        results[table] = (response as List).length;
      } catch (e) {
        results[table] = null;
      }
    }
    return results;
  }

  // ============================================
  // FINANCIALS
  // ============================================

  Future<List<Map<String, dynamic>>> fetchFinancials({
    String? type,
    String? status,
    String? clientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = adminClient.from('vivid_financials').select('*, clients(name)');
    if (type != null) query = query.eq('type', type);
    if (status != null) query = query.eq('payment_status', status);
    if (clientId != null) query = query.eq('client_id', clientId);
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }
    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createFinancial(Map<String, dynamic> data) async {
    await adminClient.from('vivid_financials').insert(data);
  }

  Future<void> updateFinancial(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await adminClient.from('vivid_financials').update(updates).eq('id', id);
  }

  Future<void> deleteFinancial(String id) async {
    await adminClient.from('vivid_financials').delete().eq('id', id);
  }

  // ============================================
  // LABEL TRIGGERS
  // ============================================

  Future<List<Map<String, dynamic>>> fetchLabelTriggers(String clientId) async {
    final response = await adminClient
        .from('label_trigger_words')
        .select()
        .eq('client_id', clientId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createLabelTrigger({
    required String clientId,
    required String label,
    required List<String> triggerWords,
    String? color,
    bool autoApply = true,
  }) async {
    await adminClient.from('label_trigger_words').insert({
      'client_id': clientId,
      'label': label,
      'trigger_words': triggerWords,
      'color': color ?? '#38BEC9',
      'auto_apply': autoApply,
    });
  }

  Future<void> updateLabelTrigger(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await adminClient.from('label_trigger_words').update(updates).eq('id', id);
  }

  Future<void> deleteLabelTrigger(String id) async {
    await adminClient.from('label_trigger_words').delete().eq('id', id);
  }

  // ============================================
  // DISPOSE
  // ============================================

  void dispose() {
    _channel?.unsubscribe();
    _exchangesController.close();
  }
}