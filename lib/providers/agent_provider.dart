import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Provider for managing agent/authentication state
/// Uses hardcoded credentials from BusinessConfig
class AgentProvider extends ChangeNotifier {
  Agent? _agent;
  bool _isLoading = false;
  String? _error;

  // Getters
  Agent? get agent => _agent;
  bool get isAuthenticated => _agent != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Login with hardcoded credentials
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Check hardcoded credentials
    if (email != BusinessConfig.managerEmail) {
      _error = 'Invalid email. Use ${BusinessConfig.managerEmail}';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (password != BusinessConfig.managerPassword) {
      _error = 'Invalid password. Use ${BusinessConfig.managerPassword}';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Create agent
    _agent = Agent(
      name: BusinessConfig.managerName,
      email: BusinessConfig.managerEmail,
      isOnline: true,
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Logout
  void logout() {
    _agent = null;
    _error = null;
    notifyListeners();
  }

  /// Update online status
  void updateOnlineStatus(bool isOnline) {
    if (_agent != null) {
      _agent = _agent!.copyWith(isOnline: isOnline);
      notifyListeners();
    }
  }

  /// Clear any errors
  void clearError() {
    _error = null;
    notifyListeners();
  }
}