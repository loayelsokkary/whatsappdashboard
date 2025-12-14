/// Simplified Data Models for Vivid WhatsApp Dashboard
/// Single messages table - each row is one exchange (customer + AI)

// ============================================
// ENUMS
// ============================================

/// Message sender type
enum SenderType {
  customer('customer'),
  ai('ai'),
  humanAgent('human_agent');

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
/// One row = customer message + AI response
class RawExchange {
  final String id;
  final String aiPhone;
  final String customerPhone;
  final String? customerName;
  final String customerMessage;
  final String aiResponse;
  final DateTime createdAt;

  const RawExchange({
    required this.id,
    required this.aiPhone,
    required this.customerPhone,
    this.customerName,
    required this.customerMessage,
    required this.aiResponse,
    required this.createdAt,
  });

  factory RawExchange.fromJson(Map<String, dynamic> json) {
    return RawExchange(
      id: json['id'] as String,
      aiPhone: json['ai_phone'] as String,
      customerPhone: json['customer_phone'] as String,
      customerName: json['customer_name'] as String?,
      customerMessage: json['customer_message'] as String,
      aiResponse: json['ai_response'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ai_phone': aiPhone,
      'customer_phone': customerPhone,
      'customer_name': customerName,
      'customer_message': customerMessage,
      'ai_response': aiResponse,
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

  const Message({
    required this.id,
    required this.content,
    required this.senderType,
    required this.isOutbound,
    this.senderName,
    required this.createdAt,
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
// BUSINESS CONFIG
// ============================================

/// Business configuration - hardcode per deployment
class BusinessConfig {
  static const String businessPhone = '97334653659'; // 3B's Gents Salon
  static const String businessName = "3B's Gents Salon";

  // Login credentials (for demo)
  static const String managerEmail = 'manager@3bs.com';
  static const String managerPassword = 'demo123';
  static const String managerName = '3B\'s Manager';
}

// ============================================
// AGENT (for authentication)
// ============================================

/// Simple agent model for UI
class Agent {
  final String name;
  final String email;
  final bool isOnline;

  const Agent({
    required this.name,
    required this.email,
    this.isOnline = true,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Agent copyWith({String? name, String? email, bool? isOnline}) {
    return Agent(
      name: name ?? this.name,
      email: email ?? this.email,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}