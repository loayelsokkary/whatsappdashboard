import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for admin panel - manages clients and users
class AdminProvider extends ChangeNotifier {
  List<Client> _clients = [];
  List<Map<String, dynamic>> _allUsers = [];
  Client? _selectedClient;
  List<AppUser> _selectedClientUsers = [];
  bool _isLoading = false;
  String? _error;

  // Last login per client (cached)
  Map<String, DateTime?> _lastLogins = {};

  // Label triggers for selected client
  List<Map<String, dynamic>> _labelTriggers = [];
  bool _isLoadingTriggers = false;

  // Getters
  List<Client> get clients => _clients;
  List<Map<String, dynamic>> get allUsers => _allUsers;
  Client? get selectedClient => _selectedClient;
  List<AppUser> get selectedClientUsers => _selectedClientUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, DateTime?> get lastLogins => _lastLogins;
  List<Map<String, dynamic>> get labelTriggers => _labelTriggers;
  bool get isLoadingTriggers => _isLoadingTriggers;

  // ============================================
  // CLIENTS
  // ============================================

  /// Fetch all clients
  Future<void> fetchClients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _clients = await SupabaseService.instance.fetchAllClients();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load clients: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new client
  Future<bool> createClient({
    required String name,
    required String slug,
    List<String> enabledFeatures = const [],
    bool hasAiConversations = true,
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
  }) async {
    _error = null;

    final client = await SupabaseService.instance.createClient(
      name: name,
      slug: slug,
      enabledFeatures: enabledFeatures,
      hasAiConversations: hasAiConversations,
      messagesTable: messagesTable,
      broadcastsTable: broadcastsTable,
      templatesTable: templatesTable,
      managerChatsTable: managerChatsTable,
      broadcastRecipientsTable: broadcastRecipientsTable,
      aiSettingsTable: aiSettingsTable,
      customerPredictionsTable: customerPredictionsTable,
      conversationsPhone: conversationsPhone,
      conversationsWebhookUrl: conversationsWebhookUrl,
      broadcastsPhone: broadcastsPhone,
      broadcastsWebhookUrl: broadcastsWebhookUrl,
      remindersPhone: remindersPhone,
      remindersWebhookUrl: remindersWebhookUrl,
      managerChatWebhookUrl: managerChatWebhookUrl,
    );

    if (client != null) {
      _clients.insert(0, client);
      notifyListeners();
      return true;
    }

    _error = 'Failed to create client';
    notifyListeners();
    return false;
  }

  /// Update a client
  Future<bool> updateClient({
    required String clientId,
    String? name,
    String? slug,
    List<String>? enabledFeatures,
    bool? hasAiConversations,
    String? messagesTable,
    String? broadcastsTable,
    String? templatesTable,
    String? managerChatsTable,
    String? broadcastRecipientsTable,
    String? aiSettingsTable,
    String? customerPredictionsTable,
    String? conversationsPhone,
    String? conversationsWebhookUrl,
    String? broadcastsPhone,
    String? broadcastsWebhookUrl,
    String? remindersPhone,
    String? remindersWebhookUrl,
    String? managerChatWebhookUrl,
  }) async {
    _error = null;

    final success = await SupabaseService.instance.updateClient(
      clientId: clientId,
      name: name,
      slug: slug,
      enabledFeatures: enabledFeatures,
      hasAiConversations: hasAiConversations,
      messagesTable: messagesTable,
      broadcastsTable: broadcastsTable,
      templatesTable: templatesTable,
      managerChatsTable: managerChatsTable,
      broadcastRecipientsTable: broadcastRecipientsTable,
      aiSettingsTable: aiSettingsTable,
      customerPredictionsTable: customerPredictionsTable,
      conversationsPhone: conversationsPhone,
      conversationsWebhookUrl: conversationsWebhookUrl,
      broadcastsPhone: broadcastsPhone,
      broadcastsWebhookUrl: broadcastsWebhookUrl,
      remindersPhone: remindersPhone,
      remindersWebhookUrl: remindersWebhookUrl,
      managerChatWebhookUrl: managerChatWebhookUrl,
    );

    if (success) {
      await fetchClients(); // Refresh list
      return true;
    }

    _error = 'Failed to update client';
    notifyListeners();
    return false;
  }

  /// Delete a client
  Future<bool> deleteClient(String clientId) async {
    _error = null;

    try {
      final success = await SupabaseService.instance.deleteClient(clientId);

      if (success) {
        _clients.removeWhere((c) => c.id == clientId);
        if (_selectedClient?.id == clientId) {
          _selectedClient = null;
          _selectedClientUsers = [];
        }
        await fetchAllUsers(); // Refresh users list
        notifyListeners();
        return true;
      }

      _error = 'Failed to delete client';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to delete client: $e';
      notifyListeners();
      return false;
    }
  }

  /// Select a client to view/edit users
  Future<void> selectClient(Client client) async {
    _selectedClient = client;
    notifyListeners();
    await fetchClientUsers(client.id);
    if (client.enabledFeatures.contains('labels')) {
      fetchLabelTriggers(client.id);
    }
  }

  /// Clear client selection
  void clearSelection() {
    _selectedClient = null;
    _selectedClientUsers = [];
    notifyListeners();
  }

  // ============================================
  // USERS
  // ============================================

  /// Fetch users for selected client
  Future<void> fetchClientUsers(String clientId) async {
    try {
      _selectedClientUsers = await SupabaseService.instance.fetchClientUsers(clientId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load users: $e';
      notifyListeners();
    }
  }

  /// Fetch all users
  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allUsers = await SupabaseService.instance.fetchAllUsers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load users: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new user for a client
  Future<bool> createUser({
    required String clientId,
    required String email,
    required String password,
    required String name,
    required String role,
    List<String>? customPermissions,
    List<String>? revokedPermissions,
  }) async {
    _error = null;

    final user = await SupabaseService.instance.createUser(
      email: email,
      password: password,
      name: name,
      role: role,
      clientId: clientId,
      customPermissions: customPermissions,
      revokedPermissions: revokedPermissions,
    );

    if (user != null) {
      if (_selectedClient?.id == clientId) {
        _selectedClientUsers.insert(0, user);
      }
      await fetchAllUsers(); // Refresh all users list
      notifyListeners();
      return true;
    }

    _error = 'Failed to create user. Email may already exist.';
    notifyListeners();
    return false;
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
    _error = null;

    final success = await SupabaseService.instance.updateUser(
      userId: userId,
      email: email,
      password: password,
      name: name,
      role: role,
      customPermissions: customPermissions,
      revokedPermissions: revokedPermissions,
    );

    if (success) {
      if (_selectedClient != null) {
        await fetchClientUsers(_selectedClient!.id);
      }
      await fetchAllUsers();
      return true;
    }

    _error = 'Failed to update user';
    notifyListeners();
    return false;
  }

  /// Reset a user's password (admin only)
  Future<bool> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    _error = null;

    final success = await SupabaseService.instance.updateUser(
      userId: userId,
      password: newPassword,
    );

    if (success) {
      return true;
    }

    _error = 'Failed to reset password';
    notifyListeners();
    return false;
  }

  /// Toggle user status between 'active' and 'blocked'
  Future<bool> toggleUserStatus(String userId, String newStatus) async {
    _error = null;

    final success = await SupabaseService.instance.toggleUserStatus(userId, newStatus);

    if (success) {
      // Refresh user lists
      if (_selectedClient != null) {
        await fetchClientUsers(_selectedClient!.id);
      }
      await fetchAllUsers();
      return true;
    }

    _error = 'Failed to ${newStatus == 'blocked' ? 'block' : 'unblock'} user';
    notifyListeners();
    return false;
  }

  /// Bulk toggle status for multiple users. Returns count of successful updates.
  Future<int> bulkToggleStatus(List<String> userIds, String newStatus) async {
    int successCount = 0;
    for (final id in userIds) {
      try {
        await SupabaseService.client
            .from('users')
            .update({'status': newStatus})
            .eq('id', id);
        successCount++;
      } catch (e) {
        debugPrint('Failed to update status for $id: $e');
      }
    }
    await fetchAllUsers();
    if (_selectedClient != null) await fetchClientUsers(_selectedClient!.id);
    return successCount;
  }

  /// Bulk change role for multiple users. Returns count of successful updates.
  Future<int> bulkChangeRole(List<String> userIds, String newRole) async {
    int successCount = 0;
    for (final id in userIds) {
      try {
        await SupabaseService.client
            .from('users')
            .update({'role': newRole})
            .eq('id', id);
        successCount++;
      } catch (e) {
        debugPrint('Failed to update role for $id: $e');
      }
    }
    await fetchAllUsers();
    if (_selectedClient != null) await fetchClientUsers(_selectedClient!.id);
    return successCount;
  }

  /// Bulk delete users. Returns count of successful deletions.
  Future<int> bulkDeleteUsers(List<String> userIds) async {
    int successCount = 0;
    for (final id in userIds) {
      try {
        await SupabaseService.client
            .from('users')
            .delete()
            .eq('id', id);
        successCount++;
      } catch (e) {
        debugPrint('Failed to delete user $id: $e');
      }
    }
    await fetchAllUsers();
    if (_selectedClient != null) await fetchClientUsers(_selectedClient!.id);
    return successCount;
  }

  /// Import users from parsed CSV rows. Each row must have: name, email, password, role, client_id.
  /// Returns (successCount, errors) tuple.
  Future<({int success, List<String> errors})> importUsersFromCsv(
    List<Map<String, String>> rows,
  ) async {
    int successCount = 0;
    final errors = <String>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = row['name']?.trim() ?? '';
      final email = row['email']?.trim() ?? '';
      final password = row['password']?.trim() ?? '';
      final role = row['role']?.trim().toLowerCase() ?? 'agent';
      final clientId = row['client_id']?.trim() ?? '';

      if (email.isEmpty || name.isEmpty || clientId.isEmpty) {
        errors.add('Row ${i + 1}: Missing required field (name, email, or client_id)');
        continue;
      }
      if (password.isEmpty || password.length < 8) {
        errors.add('Row ${i + 1}: Password must be at least 8 characters');
        continue;
      }

      final user = await SupabaseService.instance.createUser(
        email: email,
        password: password,
        name: name,
        role: role,
        clientId: clientId,
      );

      if (user != null) {
        successCount++;
      } else {
        errors.add('Row ${i + 1}: Failed to create "$email" (may already exist)');
      }
    }

    await fetchAllUsers();
    return (success: successCount, errors: errors);
  }

  // ============================================
  // CLIENT HEALTH (login activity)
  // ============================================

  /// Fetch last login timestamp per client from activity_logs.
  /// Single lightweight query, cached in provider.
  Future<void> fetchLastLoginPerClient() async {
    try {
      final response = await SupabaseService.client
          .from('activity_logs')
          .select('client_id, created_at')
          .eq('action_type', 'login')
          .order('created_at', ascending: false);

      final logins = <String, DateTime?>{};
      for (final log in response) {
        final clientId = log['client_id'] as String?;
        if (clientId != null && !logins.containsKey(clientId)) {
          logins[clientId] = DateTime.parse(log['created_at'] as String);
        }
      }
      _lastLogins = logins;
      notifyListeners();
    } catch (e) {
      // Silently fail — health dots just won't show
    }
  }

  /// Get health status for a client based on last login.
  /// 0 = active (login <24h), 1 = recent (login <7d), 2 = inactive (7d+ or never).
  int getHealthStatus(String clientId) {
    final lastLogin = _lastLogins[clientId];
    if (lastLogin == null) return 2;
    final hours = DateTime.now().difference(lastLogin).inHours;
    if (hours < 24) return 0;
    if (hours < 168) return 1;
    return 2;
  }

  /// Get a human-readable label for last login time.
  String getLastLoginLabel(String clientId) {
    final lastLogin = _lastLogins[clientId];
    if (lastLogin == null) return 'Never logged in';
    final diff = DateTime.now().difference(lastLogin);
    if (diff.inMinutes < 60) return 'Last login: ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last login: ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Last login: ${diff.inDays}d ago';
    return 'Last login: ${diff.inDays}d ago';
  }

  /// Get available features
  List<String> get availableFeatures => [
    'conversations',
    'broadcasts',
    'analytics',
    'manager_chat',
    'whatsapp_templates',
    'media',
    'labels',
  ];

  /// Get available roles for client users
  List<String> get availableRoles => [
    'admin',
    'manager',
    'agent',
    'viewer',
  ];

  // ============================================
  // LABEL TRIGGERS
  // ============================================

  Future<void> fetchLabelTriggers(String clientId) async {
    _isLoadingTriggers = true;
    notifyListeners();

    try {
      _labelTriggers = await SupabaseService.instance.fetchLabelTriggers(clientId);
      print('ADMIN: loaded ${_labelTriggers.length} label triggers for $clientId');
    } catch (e) {
      print('ADMIN: label triggers error: $e');
    }

    _isLoadingTriggers = false;
    notifyListeners();
  }

  Future<String?> createLabelTrigger({
    required String clientId,
    required String label,
    required List<String> triggerWords,
    String? color,
    bool autoApply = true,
  }) async {
    try {
      await SupabaseService.instance.createLabelTrigger(
        clientId: clientId,
        label: label,
        triggerWords: triggerWords,
        color: color,
        autoApply: autoApply,
      );
      await fetchLabelTriggers(clientId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateLabelTrigger(String id, Map<String, dynamic> updates, String clientId) async {
    try {
      await SupabaseService.instance.updateLabelTrigger(id, updates);
      await fetchLabelTriggers(clientId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteLabelTrigger(String id, String clientId) async {
    try {
      await SupabaseService.instance.deleteLabelTrigger(id);
      _labelTriggers.removeWhere((t) => t['id'] == id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}