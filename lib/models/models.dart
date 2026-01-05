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
  final String? voiceResponse; // NEW: Transcribed voice message
  final String aiResponse;
  final String? managerResponse; // NEW: Manager's response
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
    required this.createdAt,
  });

  factory RawExchange.fromJson(Map<String, dynamic> json) {
    // Handle phone numbers being either int or string
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Check if this exchange was from a voice message
  bool get isVoiceMessage => voiceResponse != null && voiceResponse!.trim().isNotEmpty;

  /// Get the customer's input (text or voice transcription)
  String get customerInput => isVoiceMessage ? voiceResponse! : customerMessage;

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
  final bool isVoiceMessage; // NEW: Was this transcribed from voice?

  const Message({
    required this.id,
    required this.content,
    required this.senderType,
    required this.isOutbound,
    this.senderName,
    required this.createdAt,
    this.isVoiceMessage = false,
  });
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

  const Conversation({
    required this.customerPhone,
    this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.status,
    this.unreadCount = 0,
    required this.startedAt,
  });

  /// Display name for UI
  String get displayName => customerName ?? customerPhone;

  /// Unique identifier (phone number)
  String get id => customerPhone;

  Conversation copyWith({
    String? customerPhone,
    String? customerName,
    String? lastMessage,
    DateTime? lastMessageAt,
    ConversationStatus? status,
    int? unreadCount,
    DateTime? startedAt,
  }) {
    return Conversation(
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      status: status ?? this.status,
      unreadCount: unreadCount ?? this.unreadCount,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

// ============================================
// CLIENT CONFIG (Loaded from Supabase after login)
// ============================================

/// User roles
enum UserRole {
  admin('admin'),
  client('client');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => UserRole.client,
    );
  }
}

/// Unified user model (admins and client users)
class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? clientId;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.clientId,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'client'),
      clientId: json['client_id'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.value,
      'client_id': clientId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Client configuration - loaded dynamically after login
class ClientConfig {
  static Client? _currentClient;
  static AppUser? _currentUser;

  // Nullable getters for safe access
  static Client? get currentClient => _currentClient;
  static AppUser? get currentUser => _currentUser;

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

  static bool hasFeature(String feature) {
    if (isAdmin) return true; // Admins see everything
    return enabledFeatures.contains(feature);
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
}

/// Client model from Supabase
class Client {
  final String id;
  final String name;
  final String slug;
  final String? webhookUrl;
  final List<String> enabledFeatures;
  final String? businessPhone;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.name,
    required this.slug,
    this.webhookUrl,
    required this.enabledFeatures,
    this.businessPhone,
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    // Handle business_phone being either int or string
    final rawPhone = json['business_phone'];
    final businessPhone = rawPhone != null ? rawPhone.toString() : null;
    
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      webhookUrl: json['webhook_url'] as String?,
      enabledFeatures: (json['enabled_features'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      businessPhone: businessPhone,
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
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if client has a specific feature enabled
  bool hasFeature(String feature) {
    return enabledFeatures.contains(feature);
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