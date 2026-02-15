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

  // Getters
  List<Client> get clients => _clients;
  List<Map<String, dynamic>> get allUsers => _allUsers;
  Client? get selectedClient => _selectedClient;
  List<AppUser> get selectedClientUsers => _selectedClientUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    String? bookingsTable,
    String? conversationsPhone,
    String? conversationsWebhookUrl,
    String? broadcastsPhone,
    String? broadcastsWebhookUrl,
    String? remindersPhone,
    String? remindersWebhookUrl,
    String? managerChatWebhookUrl,
  }) async {
    _error = null;

    final client = await SupabaseService.instance.createClient(
      name: name,
      slug: slug,
      enabledFeatures: enabledFeatures,
      hasAiConversations: hasAiConversations,
      bookingsTable: bookingsTable,
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
    String? bookingsTable,
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
      bookingsTable: bookingsTable,
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

    final success = await SupabaseService.instance.deleteClient(clientId);

    if (success) {
      _clients.removeWhere((c) => c.id == clientId);
      if (_selectedClient?.id == clientId) {
        _selectedClient = null;
        _selectedClientUsers = [];
      }
      notifyListeners();
      return true;
    }

    _error = 'Failed to delete client';
    notifyListeners();
    return false;
  }

  /// Select a client to view/edit users
  Future<void> selectClient(Client client) async {
    _selectedClient = client;
    notifyListeners();
    await fetchClientUsers(client.id);
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

  /// Get available features
  List<String> get availableFeatures => [
    'conversations',
    'broadcasts', 
    'analytics',
    'manager_chat',
    'booking_reminders',
  ];

  /// Get available roles for client users
  List<String> get availableRoles => [
    'admin',
    'manager',
    'agent',
    'viewer',
  ];
}