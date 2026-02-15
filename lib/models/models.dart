/// Simplified Data Models for Vivid WhatsApp Dashboard
/// Single messages table - each row is one exchange

// ============================================
// ENUMS
// ============================================

/// Message sender type
enum SenderType {
  customer('customer'),
  ai('ai'),
  manager('manager');

  final String value;
  const SenderType(this.value);
}

/// Conversation status (derived from data)
enum ConversationStatus {
  needsReply('needs_reply', 'Needs Reply'),
  replied('replied', 'Replied');

  final String value;
  final String displayName;
  const ConversationStatus(this.value, this.displayName);
}

/// Booking reminder status
enum ReminderStatus {
  pending('pending', 'Pending'),
  reminderSent('reminder_sent', 'Reminder Sent'),
  confirmed('confirmed', 'Confirmed'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String displayName;
  const ReminderStatus(this.value, this.displayName);

  static ReminderStatus fromString(String value) {
    return ReminderStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ReminderStatus.pending,
    );
  }
}

/// Types of actions that can be logged
enum ActionType {
  login('login'),
  logout('logout'),
  messageSent('message_sent'),
  broadcastSent('broadcast_sent'),
  aiToggled('ai_toggled'),
  userCreated('user_created'),
  userUpdated('user_updated'),
  userDeleted('user_deleted'),
  userBlocked('user_blocked'),
  clientCreated('client_created'),
  clientUpdated('client_updated'),
  bookingReminder('booking_reminder');

  final String value;
  const ActionType(this.value);

  static ActionType fromString(String value) {
    return ActionType.values.firstWhere(
      (a) => a.value == value,
      orElse: () => ActionType.login,
    );
  }

  String get displayName {
    switch (this) {
      case ActionType.login:
        return 'Login';
      case ActionType.logout:
        return 'Logout';
      case ActionType.messageSent:
        return 'Message Sent';
      case ActionType.broadcastSent:
        return 'Broadcast Sent';
      case ActionType.aiToggled:
        return 'AI Toggle';
      case ActionType.userCreated:
        return 'User Created';
      case ActionType.userUpdated:
        return 'User Updated';
      case ActionType.userDeleted:
        return 'User Deleted';
      case ActionType.userBlocked:
        return 'User Blocked';
      case ActionType.clientCreated:
        return 'Client Created';
      case ActionType.clientUpdated:
        return 'Client Updated';
      case ActionType.bookingReminder:
        return 'Booking Reminder';
    }
  }
}

// ============================================
// RAW EXCHANGE (from Supabase)
// ============================================

/// Raw exchange exactly as stored in Supabase
/// One row = customer message + AI response + optional manager response
class RawExchange {
  final String id;
  final String aiPhone;
  final String customerPhone;
  final String? customerName;
  final String customerMessage;
  final String? voiceResponse;
  final String aiResponse;
  final String? managerResponse;
  final String? label;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaFilename;
  final DateTime createdAt;

  const RawExchange({
    required this.id,
    required this.aiPhone,
    required this.customerPhone,
    this.customerName,
    required this.customerMessage,
    this.voiceResponse,
    required this.aiResponse,
    this.managerResponse,
    this.label,
    this.mediaUrl,
    this.mediaType,
    this.mediaFilename,
    required this.createdAt,
  });

  factory RawExchange.fromJson(Map<String, dynamic> json) {
    final rawAiPhone = json['ai_phone'];
    final rawCustomerPhone = json['customer_phone'];
    
    return RawExchange(
      id: json['id'] as String,
      aiPhone: rawAiPhone?.toString() ?? '',
      customerPhone: rawCustomerPhone?.toString() ?? '',
      customerName: json['customer_name'] as String?,
      customerMessage: json['customer_message'] as String? ?? '',
      voiceResponse: json['Voice_Response'] as String?,
      aiResponse: json['ai_response'] as String? ?? '',
      managerResponse: json['manager_response'] as String?,
      label: json['label'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      mediaFilename: json['media_filename'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  bool get isVoiceMessage => voiceResponse != null && voiceResponse!.trim().isNotEmpty;
  String get customerInput => isVoiceMessage ? voiceResponse! : customerMessage;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isDocument => mediaType == 'document' || mediaType == 'pdf';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ai_phone': aiPhone,
      'customer_phone': customerPhone,
      'customer_name': customerName,
      'customer_message': customerMessage,
      'Voice_Response': voiceResponse,
      'ai_response': aiResponse,
      'manager_response': managerResponse,
      'label': label,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_filename': mediaFilename,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ============================================
// DISPLAY MESSAGE (for UI)
// ============================================

/// Message for display in chat UI
class Message {
  final String id;
  final String content;
  final SenderType senderType;
  final bool isOutbound;
  final String? senderName;
  final DateTime createdAt;
  final bool isVoiceMessage;
  final String? label;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaFilename;

  const Message({
    required this.id,
    required this.content,
    required this.senderType,
    required this.isOutbound,
    this.senderName,
    required this.createdAt,
    this.isVoiceMessage = false,
    this.label,
    this.mediaUrl,
    this.mediaType,
    this.mediaFilename,
  });

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isDocument => mediaType == 'document' || mediaType == 'pdf';
}

// ============================================
// CONVERSATION (for UI)
// ============================================

/// Conversation derived from grouped exchanges
class Conversation {
  final String customerPhone;
  final String? customerName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final ConversationStatus status;
  final int unreadCount;
  final DateTime startedAt;
  final String? label;

  const Conversation({
    required this.customerPhone,
    this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.status,
    this.unreadCount = 0,
    required this.startedAt,
    this.label,
  });

  String get displayName => customerName ?? customerPhone;
  String get id => customerPhone;

  Conversation copyWith({
    String? customerPhone,
    String? customerName,
    String? lastMessage,
    DateTime? lastMessageAt,
    ConversationStatus? status,
    int? unreadCount,
    DateTime? startedAt,
    String? label,
    bool clearLabel = false,
  }) {
    return Conversation(
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      status: status ?? this.status,
      unreadCount: unreadCount ?? this.unreadCount,
      startedAt: startedAt ?? this.startedAt,
      label: clearLabel ? null : (label ?? this.label),
    );
  }
}

// ============================================
// ACTIVITY LOG
// ============================================

/// Activity log entry for audit trail
class ActivityLog {
  final String id;
  final String? clientId;
  final String? userId;
  final String userName;
  final String? userEmail;
  final ActionType actionType;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ActivityLog({
    required this.id,
    this.clientId,
    this.userId,
    required this.userName,
    this.userEmail,
    required this.actionType,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      clientId: json['client_id'] as String?,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String? ?? 'Unknown',
      userEmail: json['user_email'] as String?,
      actionType: ActionType.fromString(json['action_type'] as String? ?? 'login'),
      description: json['description'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'action_type': actionType.value,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get a detail from metadata
  String? getMetadata(String key) {
    return metadata[key]?.toString();
  }
}

// ============================================
// USER ROLES & PERMISSIONS
// ============================================

/// User roles - determines access level
enum UserRole {
  admin('admin'),       // Full access (Vivid if no client_id, Client admin if has client_id)
  manager('manager'),   // All features except user management
  agent('agent'),       // Customer chats only
  viewer('viewer');     // Read-only access

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => UserRole.viewer,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.agent:
        return 'Agent';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Full access including user management';
      case UserRole.manager:
        return 'All features except user management';
      case UserRole.agent:
        return 'Customer conversations only';
      case UserRole.viewer:
        return 'Read-only access to all features';
    }
  }
}

/// Permission types for granular access control
enum Permission {
  // Dashboard features
  viewDashboard,
  viewAnalytics,
  
  // Conversations
  viewConversations,
  sendMessages,
  
  // Broadcasts
  viewBroadcasts,
  sendBroadcasts,
  
  // Manager Chat (AI)
  viewManagerChat,
  useManagerChat,
  
  // User Management
  viewUsers,
  manageUsers,
  
  // Booking Reminders
  viewBookingReminders,
  
  // Activity Logs
  viewActivityLogs;

  /// Convert permission to snake_case string for database storage
  String get value {
    switch (this) {
      case Permission.viewDashboard: return 'view_dashboard';
      case Permission.viewAnalytics: return 'view_analytics';
      case Permission.viewConversations: return 'view_conversations';
      case Permission.sendMessages: return 'send_messages';
      case Permission.viewBroadcasts: return 'view_broadcasts';
      case Permission.sendBroadcasts: return 'send_broadcasts';
      case Permission.viewManagerChat: return 'view_manager_chat';
      case Permission.useManagerChat: return 'use_manager_chat';
      case Permission.viewUsers: return 'view_users';
      case Permission.manageUsers: return 'manage_users';
      case Permission.viewBookingReminders: return 'view_booking_reminders';
      case Permission.viewActivityLogs: return 'view_activity_logs';
    }
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case Permission.viewDashboard: return 'View Dashboard';
      case Permission.viewAnalytics: return 'View Analytics';
      case Permission.viewConversations: return 'View Conversations';
      case Permission.sendMessages: return 'Send Messages';
      case Permission.viewBroadcasts: return 'View Broadcasts';
      case Permission.sendBroadcasts: return 'Send Broadcasts';
      case Permission.viewManagerChat: return 'View AI Assistant';
      case Permission.useManagerChat: return 'Use AI Assistant';
      case Permission.viewUsers: return 'View Users';
      case Permission.manageUsers: return 'Manage Users';
      case Permission.viewBookingReminders: return 'View Booking Reminders';
      case Permission.viewActivityLogs: return 'View Activity Logs';
    }
  }

  /// Category for grouping in UI
  String get category {
    switch (this) {
      case Permission.viewDashboard:
      case Permission.viewAnalytics:
        return 'Dashboard';
      case Permission.viewConversations:
      case Permission.sendMessages:
        return 'Conversations';
      case Permission.viewBroadcasts:
      case Permission.sendBroadcasts:
        return 'Broadcasts';
      case Permission.viewManagerChat:
      case Permission.useManagerChat:
        return 'AI Assistant';
      case Permission.viewUsers:
      case Permission.manageUsers:
        return 'User Management';
      case Permission.viewBookingReminders:
        return 'Booking Reminders';
      case Permission.viewActivityLogs:
        return 'Activity Logs';
    }
  }

  /// Parse from snake_case string
  static Permission? fromString(String value) {
    for (final perm in Permission.values) {
      if (perm.value == value) return perm;
    }
    return null;
  }

  /// Parse list of permission strings
  static Set<Permission> fromStringList(List<dynamic>? list) {
    if (list == null) return {};
    return list
        .map((s) => Permission.fromString(s.toString()))
        .whereType<Permission>()
        .toSet();
  }

  /// Convert set of permissions to string list
  static List<String> toStringList(Set<Permission> permissions) {
    return permissions.map((p) => p.value).toList();
  }
}

/// Permission matrix - what each role can do
class Permissions {
  static const Map<UserRole, Set<Permission>> rolePermissions = {
    UserRole.admin: {
      Permission.viewDashboard,
      Permission.viewAnalytics,
      Permission.viewConversations,
      Permission.sendMessages,
      Permission.viewBroadcasts,
      Permission.sendBroadcasts,
      Permission.viewManagerChat,
      Permission.useManagerChat,
      Permission.viewUsers,
      Permission.manageUsers,
      Permission.viewBookingReminders,
      Permission.viewActivityLogs,
    },
    UserRole.manager: {
      Permission.viewDashboard,
      Permission.viewAnalytics,
      Permission.viewConversations,
      Permission.sendMessages,
      Permission.viewBroadcasts,
      Permission.sendBroadcasts,
      Permission.viewManagerChat,
      Permission.useManagerChat,
      Permission.viewBookingReminders,
    },
    UserRole.agent: {
      Permission.viewDashboard,
      Permission.viewConversations,
      Permission.sendMessages,
      Permission.viewBookingReminders,
    },
    UserRole.viewer: {
      Permission.viewDashboard,
      Permission.viewAnalytics,
      Permission.viewConversations,
      Permission.viewBroadcasts,
      Permission.viewManagerChat,
      Permission.viewBookingReminders,
    },
  };

  static bool hasPermission(UserRole role, Permission permission) {
    return rolePermissions[role]?.contains(permission) ?? false;
  }

  static Set<Permission> getPermissions(UserRole role) {
    return rolePermissions[role] ?? {};
  }
}

// ============================================
// APP USER
// ============================================

/// Unified user model (admins and client users)
class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? clientId;
  final DateTime createdAt;
  
  /// Custom permissions granted beyond role defaults (nullable = use role defaults)
  final Set<Permission>? customPermissions;
  
  /// Permissions explicitly revoked from this user
  final Set<Permission>? revokedPermissions;

  /// Plaintext password (only populated for client admin user management)
  final String? password;

  /// User status ('active' or 'blocked')
  final String status;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.clientId,
    required this.createdAt,
    this.customPermissions,
    this.revokedPermissions,
    this.password,
    this.status = 'active',
  });

  /// True if Vivid super admin (admin role with no client)
  bool get isVividAdmin => role == UserRole.admin && clientId == null;
  
  /// True if client admin (admin role with client)
  bool get isClientAdmin => role == UserRole.admin && clientId != null;
  
  /// True if any admin
  bool get isAdmin => role == UserRole.admin;

  /// True if user has custom permission overrides
  bool get hasCustomPermissions => 
      (customPermissions != null && customPermissions!.isNotEmpty) ||
      (revokedPermissions != null && revokedPermissions!.isNotEmpty);

  /// Check if user has specific permission
  /// Priority: 1) Revoked (deny) 2) Custom (grant) 3) Role default
  bool hasPermission(Permission permission) {
    // Vivid admins have all permissions, no overrides
    if (isVividAdmin) return true;
    
    // Check if permission is explicitly revoked
    if (revokedPermissions?.contains(permission) ?? false) {
      return false;
    }
    
    // Check if permission is explicitly granted
    if (customPermissions?.contains(permission) ?? false) {
      return true;
    }
    
    // Fall back to role-based permissions
    return Permissions.hasPermission(role, permission);
  }

  /// Get effective permissions (role + custom - revoked)
  Set<Permission> get effectivePermissions {
    if (isVividAdmin) return Permission.values.toSet();
    
    // Start with role defaults
    Set<Permission> perms = Set.from(Permissions.getPermissions(role));
    
    // Add custom grants
    if (customPermissions != null) {
      perms.addAll(customPermissions!);
    }
    
    // Remove revoked
    if (revokedPermissions != null) {
      perms.removeAll(revokedPermissions!);
    }
    
    return perms;
  }

  /// Check if user can manage users
  bool get canManageUsers => hasPermission(Permission.manageUsers);

  /// Check if user can send messages
  bool get canSendMessages => hasPermission(Permission.sendMessages);

  /// Check if user can send broadcasts
  bool get canSendBroadcasts => hasPermission(Permission.sendBroadcasts);

  /// Check if user is read-only (viewer role with no custom permissions)
  bool get isReadOnly => role == UserRole.viewer && !hasCustomPermissions;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'viewer'),
      clientId: json['client_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      customPermissions: json['custom_permissions'] != null
          ? Permission.fromStringList(json['custom_permissions'] as List)
          : null,
      revokedPermissions: json['revoked_permissions'] != null
          ? Permission.fromStringList(json['revoked_permissions'] as List)
          : null,
      password: json['password'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  /// Whether this user is blocked
  bool get isBlocked => status == 'blocked';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.value,
      'client_id': clientId,
      'created_at': createdAt.toIso8601String(),
      if (customPermissions != null && customPermissions!.isNotEmpty)
        'custom_permissions': Permission.toStringList(customPermissions!),
      if (revokedPermissions != null && revokedPermissions!.isNotEmpty)
        'revoked_permissions': Permission.toStringList(revokedPermissions!),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? clientId,
    DateTime? createdAt,
    Set<Permission>? customPermissions,
    Set<Permission>? revokedPermissions,
    bool clearCustomPermissions = false,
    bool clearRevokedPermissions = false,
    String? password,
    String? status,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      customPermissions: clearCustomPermissions ? null : (customPermissions ?? this.customPermissions),
      revokedPermissions: clearRevokedPermissions ? null : (revokedPermissions ?? this.revokedPermissions),
      password: password ?? this.password,
      status: status ?? this.status,
    );
  }

  /// Get the user's initials
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ============================================
// CLIENT CONFIG
// ============================================

/// Client configuration - loaded dynamically after login
class ClientConfig {
  static Client? _currentClient;
  static AppUser? _currentUser;

  static Client? get currentClient => _currentClient;
  static AppUser? get currentUser => _currentUser;

  static bool get isVividAdmin => _currentUser?.isVividAdmin ?? false;
  static bool get isClientAdmin => _currentUser?.isClientAdmin ?? false;
  static bool get isAdmin => _currentUser?.isAdmin ?? false;

  static Client get client {
    if (_currentClient == null) {
      throw Exception('Client not loaded. User must log in first.');
    }
    return _currentClient!;
  }

  static AppUser get user {
    if (_currentUser == null) {
      throw Exception('User not loaded. User must log in first.');
    }
    return _currentUser!;
  }

  static String get businessPhone => _currentClient?.businessPhone ?? '';
  static String get businessName => _currentClient?.name ?? 'Vivid Dashboard';
  static String get webhookUrl => _currentClient?.webhookUrl ?? '';
  static List<String> get enabledFeatures => _currentClient?.enabledFeatures ?? [];
  
  // ============================================
  // DYNAMIC TABLE NAMES
  // ============================================
  
  /// Messages table name (e.g., 'threeBs_messages')
  static String? get messagesTable => _currentClient?.messagesTable;
  
  /// Broadcasts table name (e.g., 'karisma_broadcasts')
  static String? get broadcastsTable => _currentClient?.broadcastsTable;
  
  /// Bookings table name (e.g., 'karisma_bookings')
  static String? get bookingsTable => _currentClient?.bookingsTable;
  
  /// Get messages table name, throws if not configured
  static String get messagesTableName {
    final table = _currentClient?.messagesTable;
    if (table == null || table.isEmpty) {
      throw Exception('Messages table not configured for this client');
    }
    return table;
  }

  /// Get broadcasts table name, throws if not configured
  static String get broadcastsTableName {
    final table = _currentClient?.broadcastsTable;
    if (table == null || table.isEmpty) {
      throw Exception('Broadcasts table not configured for this client');
    }
    return table;
  }

  /// Get bookings table name, throws if not configured
  static String get bookingsTableName {
    final table = _currentClient?.bookingsTable;
    if (table == null || table.isEmpty) {
      throw Exception('Bookings table not configured for this client');
    }
    return table;
  }

  /// Check if conversations feature is fully configured
  static bool get isConversationsConfigured => 
    (conversationsPhone?.isNotEmpty ?? false) && 
    (messagesTable?.isNotEmpty ?? false);

  /// Check if broadcasts feature is fully configured
  static bool get isBroadcastsConfigured => 
    ((broadcastsPhone?.isNotEmpty ?? false) || (broadcastsWebhookUrl?.isNotEmpty ?? false)) && 
    (broadcastsTable?.isNotEmpty ?? false);

  /// Check if bookings feature is fully configured
  static bool get isBookingsConfigured => 
    bookingsTable?.isNotEmpty ?? false;
  
  // ============================================
  // PER-FEATURE PHONE GETTERS
  // ============================================
  
  static String? get conversationsPhone => _currentClient?.conversationsPhone ?? _currentClient?.businessPhone;
  static String? get broadcastsPhone => _currentClient?.broadcastsPhone ?? _currentClient?.businessPhone;
  static String? get remindersPhone => _currentClient?.remindersPhone ?? _currentClient?.businessPhone;
  
  // ============================================
  // PER-FEATURE WEBHOOK GETTERS
  // ============================================
  
  static String? get conversationsWebhookUrl => _currentClient?.conversationsWebhookUrl ?? _currentClient?.webhookUrl;
  static String? get broadcastsWebhookUrl => _currentClient?.broadcastsWebhookUrl ?? _currentClient?.webhookUrl;
  static String? get remindersWebhookUrl => _currentClient?.remindersWebhookUrl;
  static String? get managerChatWebhookUrl => _currentClient?.managerChatWebhookUrl ?? _currentClient?.webhookUrl;

  /// Whether the current client uses AI-powered conversations
  static bool get hasAiConversations => _currentClient?.hasAiConversations ?? false;

  /// Check if feature is enabled AND user has permission
  static bool hasFeature(String feature) {
    if (isVividAdmin) return true;
    
    // Check if feature is enabled for client
    if (!enabledFeatures.contains(feature)) return false;
    
    // Check if user role allows this feature
    final user = _currentUser;
    if (user == null) return false;
    
    switch (feature) {
      case 'conversations':
        return user.hasPermission(Permission.viewConversations);
      case 'broadcasts':
        return user.hasPermission(Permission.viewBroadcasts);
      case 'analytics':
        return user.hasPermission(Permission.viewAnalytics);
      case 'manager_chat':
        return user.hasPermission(Permission.viewManagerChat);
      case 'user_management':
        return user.hasPermission(Permission.viewUsers);
      case 'booking_reminders':
        return user.hasPermission(Permission.viewBookingReminders);
      default:
        return true;
    }
  }

  /// Check if user can perform action (not just view)
  static bool canPerformAction(String action) {
    final user = _currentUser;
    if (user == null) return false;
    if (isVividAdmin) return true;
    
    switch (action) {
      case 'send_message':
        return user.canSendMessages;
      case 'send_broadcast':
        return user.canSendBroadcasts;
      case 'manage_users':
        return user.canManageUsers;
      default:
        return !user.isReadOnly;
    }
  }

  static void setClientUser(Client client, AppUser user) {
    _currentClient = client;
    _currentUser = user;
  }

  static void setAdmin(AppUser user) {
    _currentUser = user;
    _currentClient = null;
  }

  static void clear() {
    _currentClient = null;
    _currentUser = null;
  }

  static String get currentUserName => _currentUser?.name ?? 'User';
  static String get currentUserEmail => _currentUser?.email ?? '';
  static UserRole get currentUserRole => _currentUser?.role ?? UserRole.viewer;
}

// ============================================
// CLIENT
// ============================================

/// Client model from Supabase
class Client {
  final String id;
  final String name;
  final String slug;
  final String? webhookUrl; // Legacy - kept for backward compatibility
  final List<String> enabledFeatures;
  final String? businessPhone; // Legacy - kept for backward compatibility
  
  // Dynamic table names (per-client tables)
  final String? messagesTable;
  final String? broadcastsTable;
  final String? bookingsTable;
  
  // Per-feature configuration
  final String? conversationsPhone;
  final String? conversationsWebhookUrl;
  final String? broadcastsPhone;
  final String? broadcastsWebhookUrl;
  final String? remindersPhone;
  final String? remindersWebhookUrl;
  final String? managerChatWebhookUrl;

  final int? broadcastLimit;

  /// Whether this client uses AI-powered conversations
  final bool hasAiConversations;

  final DateTime createdAt;

  const Client({
    required this.id,
    required this.name,
    required this.slug,
    this.webhookUrl,
    required this.enabledFeatures,
    this.businessPhone,
    this.messagesTable,
    this.broadcastsTable,
    this.bookingsTable,
    this.conversationsPhone,
    this.conversationsWebhookUrl,
    this.broadcastsPhone,
    this.broadcastsWebhookUrl,
    this.remindersPhone,
    this.remindersWebhookUrl,
    this.managerChatWebhookUrl,
    this.broadcastLimit,
    this.hasAiConversations = true,
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    final rawPhone = json['business_phone'];
    final businessPhone = rawPhone != null ? rawPhone.toString() : null;
    final rawConversationsPhone = json['conversations_phone'];
    final conversationsPhone = rawConversationsPhone != null ? rawConversationsPhone.toString() : null;
    final rawBroadcastsPhone = json['broadcasts_phone'];
    final broadcastsPhone = rawBroadcastsPhone != null ? rawBroadcastsPhone.toString() : null;
    final rawRemindersPhone = json['reminders_phone'];
    final remindersPhone = rawRemindersPhone != null ? rawRemindersPhone.toString() : null;
    
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      webhookUrl: json['webhook_url'] as String?,
      enabledFeatures: (json['enabled_features'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      businessPhone: businessPhone,
      messagesTable: json['messages_table'] as String?,
      broadcastsTable: json['broadcasts_table'] as String?,
      bookingsTable: json['bookings_table'] as String?,
      conversationsPhone: conversationsPhone,
      conversationsWebhookUrl: json['conversations_webhook_url'] as String?,
      broadcastsPhone: broadcastsPhone,
      broadcastsWebhookUrl: json['broadcasts_webhook_url'] as String?,
      remindersPhone: remindersPhone,
      remindersWebhookUrl: json['reminders_webhook_url'] as String?,
      managerChatWebhookUrl: json['manager_chat_webhook_url'] as String?,
      broadcastLimit: json['broadcast_limit'] as int?,
      hasAiConversations: json['has_ai_conversations'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'webhook_url': webhookUrl,
      'enabled_features': enabledFeatures,
      'business_phone': businessPhone,
      'messages_table': messagesTable,
      'broadcasts_table': broadcastsTable,
      'bookings_table': bookingsTable,
      'conversations_phone': conversationsPhone,
      'conversations_webhook_url': conversationsWebhookUrl,
      'broadcasts_phone': broadcastsPhone,
      'broadcasts_webhook_url': broadcastsWebhookUrl,
      'reminders_phone': remindersPhone,
      'reminders_webhook_url': remindersWebhookUrl,
      'manager_chat_webhook_url': managerChatWebhookUrl,
      'broadcast_limit': broadcastLimit,
      'has_ai_conversations': hasAiConversations,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool hasFeature(String feature) {
    return enabledFeatures.contains(feature);
  }
  
  /// Get phone for a specific feature (falls back to legacy businessPhone)
  String? getPhoneForFeature(String feature) {
    switch (feature) {
      case 'conversations':
        return conversationsPhone ?? businessPhone;
      case 'broadcasts':
        return broadcastsPhone ?? businessPhone;
      case 'booking_reminders':
        return remindersPhone ?? businessPhone;
      default:
        return businessPhone;
    }
  }
  
  /// Get webhook URL for a specific feature (falls back to legacy webhookUrl)
  String? getWebhookForFeature(String feature) {
    switch (feature) {
      case 'conversations':
        return conversationsWebhookUrl ?? webhookUrl;
      case 'broadcasts':
        return broadcastsWebhookUrl ?? webhookUrl;
      case 'booking_reminders':
        return remindersWebhookUrl;
      case 'manager_chat':
        return managerChatWebhookUrl ?? webhookUrl;
      default:
        return webhookUrl;
    }
  }
}

// ============================================
// AGENT (for UI display)
// ============================================

/// Simple agent model for UI
class Agent {
  final String name;
  final String email;

  const Agent({
    required this.name,
    required this.email,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ============================================
// BOOKING (for Booking Reminders feature)
// ============================================

/// Booking model from client's bookings table
class Booking {
  final String id;
  final String bookingId;
  final String? odooUserId;
  final String customerName;
  final String customerPhone;
  final String service;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String status;
  final bool reminder3Day;
  final bool reminder1Day;
  final String? source;
  final DateTime? manualReminderSentAt;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.bookingId,
    this.odooUserId,
    required this.customerName,
    required this.customerPhone,
    required this.service,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.reminder3Day,
    required this.reminder1Day,
    this.source,
    this.manualReminderSentAt,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      odooUserId: json['user_id']?.toString(),
      customerName: json['name'] as String? ?? 'Unknown',
      customerPhone: json['phone']?.toString() ?? '',
      service: json['service'] as String? ?? 'Service',
      appointmentDate: json['appointment_date'] != null
          ? DateTime.parse(json['appointment_date'] as String)
          : DateTime.now(),
      appointmentTime: json['appointment_time'] as String? ?? '00:00',
      status: json['status'] as String? ?? 'pending',
      reminder3Day: json['reminder_3day'] as bool? ?? false,
      reminder1Day: json['reminder_1day'] as bool? ?? false,
      source: json['source'] as String?,
      manualReminderSentAt: json['manual_reminder_sent_at'] != null
          ? DateTime.parse(json['manual_reminder_sent_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'user_id': odooUserId,
      'name': customerName,
      'phone': customerPhone,
      'service': service,
      'appointment_date': appointmentDate.toIso8601String().split('T')[0],
      'appointment_time': appointmentTime,
      'status': status,
      'reminder_3day': reminder3Day,
      'reminder_1day': reminder1Day,
      'source': source,
      'manual_reminder_sent_at': manualReminderSentAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get the computed reminder status based on flags and status
  ReminderStatus get reminderStatus {
    if (status.toLowerCase() == 'cancelled') return ReminderStatus.cancelled;
    if (status.toLowerCase() == 'confirmed') return ReminderStatus.confirmed;
    if (reminder1Day || reminder3Day || manualReminderSentAt != null) return ReminderStatus.reminderSent;
    return ReminderStatus.pending;
  }

  /// Get full appointment DateTime
  DateTime get appointmentDateTime {
    final timeParts = appointmentTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    return DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      hour,
      minute,
    );
  }

  /// Check if appointment is upcoming (in the future)
  bool get isUpcoming => appointmentDateTime.isAfter(DateTime.now());

  /// Check if appointment is today
  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }

  /// Days until appointment (negative if past)
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
    );
    return apptDay.difference(today).inDays;
  }

  Booking copyWith({
    String? id,
    String? bookingId,
    String? odooUserId,
    String? customerName,
    String? customerPhone,
    String? service,
    DateTime? appointmentDate,
    String? appointmentTime,
    String? status,
    bool? reminder3Day,
    bool? reminder1Day,
    String? source,
    DateTime? manualReminderSentAt,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      odooUserId: odooUserId ?? this.odooUserId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      service: service ?? this.service,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      status: status ?? this.status,
      reminder3Day: reminder3Day ?? this.reminder3Day,
      reminder1Day: reminder1Day ?? this.reminder1Day,
      source: source ?? this.source,
      manualReminderSentAt: manualReminderSentAt ?? this.manualReminderSentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ============================================
// BOOKING REMINDER STATS
// ============================================

/// Statistics for booking reminders dashboard
class BookingReminderStats {
  final int totalBookings;
  final int upcomingBookings;
  final int remindersSent;
  final int confirmed;
  final int cancelled;
  final int pendingReminders;

  const BookingReminderStats({
    required this.totalBookings,
    required this.upcomingBookings,
    required this.remindersSent,
    required this.confirmed,
    required this.cancelled,
    required this.pendingReminders,
  });

  factory BookingReminderStats.empty() {
    return const BookingReminderStats(
      totalBookings: 0,
      upcomingBookings: 0,
      remindersSent: 0,
      confirmed: 0,
      cancelled: 0,
      pendingReminders: 0,
    );
  }

  factory BookingReminderStats.fromBookings(List<Booking> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int upcoming = 0;
    int sent = 0;
    int confirmed = 0;
    int cancelled = 0;
    int pending = 0;

    for (final booking in bookings) {
      final apptDate = DateTime(
        booking.appointmentDate.year,
        booking.appointmentDate.month,
        booking.appointmentDate.day,
      );
      
      if (apptDate.isAfter(today) || apptDate.isAtSameMomentAs(today)) {
        upcoming++;
      }

      switch (booking.reminderStatus) {
        case ReminderStatus.reminderSent:
          sent++;
          break;
        case ReminderStatus.confirmed:
          confirmed++;
          break;
        case ReminderStatus.cancelled:
          cancelled++;
          break;
        case ReminderStatus.pending:
          if (booking.isUpcoming) pending++;
          break;
      }
    }

    return BookingReminderStats(
      totalBookings: bookings.length,
      upcomingBookings: upcoming,
      remindersSent: sent,
      confirmed: confirmed,
      cancelled: cancelled,
      pendingReminders: pending,
    );
  }
}