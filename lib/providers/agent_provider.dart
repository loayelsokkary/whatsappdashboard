import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for managing agent/authentication state
/// Uses unified users table for authentication
class AgentProvider extends ChangeNotifier {
  Agent? _agent;
  bool _isLoading = false;
  bool _isRestoringSession = true; // Start true — check session before showing login
  String? _error;
  bool _isAdmin = false;

  // Getters
  Agent? get agent => _agent;
  bool get isAuthenticated => _agent != null;
  bool get isLoading => _isLoading;
  bool get isRestoringSession => _isRestoringSession;
  String? get error => _error;
  bool get isAdmin => _isAdmin;

  /// Try to restore session from sessionStorage
  Future<void> restoreSession() async {
    try {
      final storage = web.window.sessionStorage;
      final userId = storage.getItem('vivid_user_id');

      if (userId == null || userId.isEmpty) {
        _isRestoringSession = false;
        notifyListeners();
        return;
      }

      // Fetch the user from the database by ID
      final userResponse = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        // User no longer exists — clear stale session
        storage.removeItem('vivid_user_id');
        _isRestoringSession = false;
        notifyListeners();
        return;
      }

      final user = AppUser.fromJson(userResponse);

      // Check if user is blocked
      if (user.isBlocked) {
        storage.removeItem('vivid_user_id');
        _isRestoringSession = false;
        notifyListeners();
        return;
      }

      _agent = Agent(name: user.name, email: user.email);

      if (user.isVividAdmin) {
        ClientConfig.setAdmin(user);
        _isAdmin = true;
      } else if (user.clientId != null) {
        final client = await SupabaseService.instance.fetchClientById(user.clientId!);
        if (client != null) {
          ClientConfig.setClientUser(client, user);
          _isAdmin = false;
        } else {
          // Client data missing — clear session
          _agent = null;
          storage.removeItem('vivid_user_id');
          _isRestoringSession = false;
          notifyListeners();
          return;
        }
      } else {
        _agent = null;
        storage.removeItem('vivid_user_id');
        _isRestoringSession = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      // Silent fail — just show login screen
      print('Session restore failed: $e');
    }

    _isRestoringSession = false;
    notifyListeners();
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await SupabaseService.instance.login(email, password);
      
      if (user == null) {
        _error = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _agent = Agent(
        name: user.name,
        email: user.email,
      );

      // CRITICAL: Set up ClientConfig based on user type
      if (user.isVividAdmin) {
        // Vivid super admin - no client
        ClientConfig.setAdmin(user);
        _isAdmin = true;
      } else if (user.clientId != null) {
        // Client user - fetch their client data
        final client = await SupabaseService.instance.fetchClientById(user.clientId!);
        
        if (client != null) {
          ClientConfig.setClientUser(client, user);
          _isAdmin = false; // Not a Vivid admin, even if they're a client admin
        } else {
          _error = 'Could not load client data';
          _agent = null;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        // Edge case: non-admin user with no client (shouldn't happen)
        _error = 'User has no assigned client';
        _agent = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Save user ID to sessionStorage for session persistence
      web.window.sessionStorage.setItem('vivid_user_id', user.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('ACCOUNT_BLOCKED')) {
        _error = 'Your account has been blocked. Contact your administrator.';
      } else {
        _error = 'Login failed: $e';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  void logout() {
    SupabaseService.instance.logout();
    _agent = null;
    _error = null;
    _isAdmin = false;

    // Clear session storage
    web.window.sessionStorage.removeItem('vivid_user_id');

    // CRITICAL: Clear ClientConfig on logout
    ClientConfig.clear();
    
    notifyListeners();
  }

  /// Clear any errors
  void clearError() {
    _error = null;
    notifyListeners();
  }
}