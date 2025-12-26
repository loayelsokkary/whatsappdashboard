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
    String? webhookUrl,
    List<String> enabledFeatures = const [],
    String? businessPhone,
  }) async {
    _error = null;

    final client = await SupabaseService.instance.createClient(
      name: name,
      slug: slug,
      webhookUrl: webhookUrl,
      enabledFeatures: enabledFeatures,
      businessPhone: businessPhone,
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
    String? webhookUrl,
    List<String>? enabledFeatures,
    String? businessPhone,
  }) async {
    _error = null;

    final success = await SupabaseService.instance.updateClient(
      clientId: clientId,
      name: name,
      slug: slug,
      webhookUrl: webhookUrl,
      enabledFeatures: enabledFeatures,
      businessPhone: businessPhone,
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
  }) async {
    _error = null;

    final user = await SupabaseService.instance.createUser(
      email: email,
      password: password,
      name: name,
      role: 'client',
      clientId: clientId,
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
  }) async {
    _error = null;

    final success = await SupabaseService.instance.updateUser(
      userId: userId,
      email: email,
      password: password,
      name: name,
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

  /// Delete a user
  Future<bool> deleteUser(String userId) async {
    _error = null;

    final success = await SupabaseService.instance.deleteUser(userId);

    if (success) {
      _selectedClientUsers.removeWhere((u) => u.id == userId);
      _allUsers.removeWhere((u) => u['id'] == userId);
      notifyListeners();
      return true;
    }

    _error = 'Failed to delete user';
    notifyListeners();
    return false;
  }

  /// Get available features
  List<String> get availableFeatures => [
    'conversations',
    'broadcasts', 
    'analytics',
  ];
}