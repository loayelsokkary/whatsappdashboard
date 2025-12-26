import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for managing agent/authentication state
/// Uses unified users table for authentication
class AgentProvider extends ChangeNotifier {
  Agent? _agent;
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;

  // Getters
  Agent? get agent => _agent;
  bool get isAuthenticated => _agent != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _isAdmin;

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
      _isAdmin = user.isAdmin;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login failed: $e';
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
    notifyListeners();
  }

  /// Clear any errors
  void clearError() {
    _error = null;
    notifyListeners();
  }
}