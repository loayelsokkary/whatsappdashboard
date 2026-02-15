import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Provider for client admins to manage their team users
class UserManagementProvider extends ChangeNotifier {
  List<AppUser> _users = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all users for the current client
  Future<void> fetchUsers() async {
    final clientId = ClientConfig.currentClient?.id;
    if (clientId == null) {
      _error = 'No client selected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      _users = (response as List)
          .map((json) => AppUser.fromJson(json))
          .toList();

      print('Fetched ${_users.length} users for client');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching users: $e');
      _error = 'Failed to load users';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new user for the current client
  Future<bool> createUser({
    required String name,
    required String email,
    required UserRole role,
    required String password,
    List<String>? customPermissions,
    List<String>? revokedPermissions,
  }) async {
    final clientId = ClientConfig.currentClient?.id;
    if (clientId == null) {
      _error = 'No client selected';
      notifyListeners();
      return false;
    }

    _error = null;

    try {
      final userData = <String, dynamic>{
        'name': name,
        'email': email,
        'role': role.value,
        'client_id': clientId,
        'password': password,
      };

      // Add custom permissions if provided
      if (customPermissions != null && customPermissions.isNotEmpty) {
        userData['custom_permissions'] = customPermissions;
      }
      if (revokedPermissions != null && revokedPermissions.isNotEmpty) {
        userData['revoked_permissions'] = revokedPermissions;
      }

      final response = await SupabaseService.client
          .from('users')
          .insert(userData)
          .select()
          .single();

      final newUser = AppUser.fromJson(response);
      _users.insert(0, newUser);
      notifyListeners();

      // Log the activity
      await SupabaseService.instance.log(
        actionType: ActionType.userCreated,
        description: 'Created user: $name ($email)',
        metadata: {
          'new_user_id': newUser.id,
          'new_user_email': email,
          'new_user_role': role.value,
          'has_custom_permissions': customPermissions != null && customPermissions.isNotEmpty,
        },
      );
      
      print('Created user: ${newUser.email}');
      return true;
    } catch (e) {
      print('Error creating user: $e');
      if (e.toString().contains('duplicate')) {
        _error = 'Email already exists';
      } else {
        _error = 'Failed to create user';
      }
      notifyListeners();
      return false;
    }
  }

  /// Update an existing user
  Future<bool> updateUser({
    required String userId,
    String? name,
    String? email,
    UserRole? role,
    String? password,
    List<String>? customPermissions,
    List<String>? revokedPermissions,
  }) async {
    _error = null;

    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (role != null) updates['role'] = role.value;
      if (password != null && password.isNotEmpty) {
        updates['password'] = password;
      }

      // Handle custom permissions
      // Empty list = clear, null = don't change
      if (customPermissions != null) {
        updates['custom_permissions'] = customPermissions.isEmpty ? null : customPermissions;
      }
      if (revokedPermissions != null) {
        updates['revoked_permissions'] = revokedPermissions.isEmpty ? null : revokedPermissions;
      }

      if (updates.isEmpty) return true;

      await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', userId);

      // Refetch to get updated user with all fields
      await fetchUsers();

      // Log the activity
      await SupabaseService.instance.log(
        actionType: ActionType.userUpdated,
        description: 'Updated user${name != null ? ": $name" : ""}',
        metadata: {
          'user_id': userId,
          'updates': updates.keys.where((k) => k != 'password').toList(),
        },
      );

      print('Updated user: $userId');
      return true;
    } catch (e) {
      print('Error updating user: $e');
      if (e.toString().contains('duplicate')) {
        _error = 'Email already exists';
      } else {
        _error = 'Failed to update user';
      }
      notifyListeners();
      return false;
    }
  }

  /// Toggle user status between 'active' and 'blocked'
  Future<bool> toggleUserStatus(String userId) async {
    _error = null;

    try {
      final user = _users.firstWhere(
        (u) => u.id == userId,
        orElse: () => throw Exception('User not found'),
      );

      final newStatus = user.isBlocked ? 'active' : 'blocked';
      final success = await SupabaseService.instance.toggleUserStatus(userId, newStatus);

      if (success) {
        await fetchUsers();
        return true;
      }

      _error = 'Failed to ${user.isBlocked ? "unblock" : "block"} user';
      notifyListeners();
      return false;
    } catch (e) {
      print('Error toggling user status: $e');
      _error = 'Failed to update user status';
      notifyListeners();
      return false;
    }
  }

  /// Get users by role
  List<AppUser> getUsersByRole(UserRole role) {
    return _users.where((u) => u.role == role).toList();
  }

  /// Check if email exists
  bool emailExists(String email, {String? excludeUserId}) {
    return _users.any((u) => 
        u.email.toLowerCase() == email.toLowerCase() && 
        u.id != excludeUserId
    );
  }

  /// Clear data
  void clear() {
    _users = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}