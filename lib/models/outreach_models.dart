import 'package:flutter/material.dart';
import '../theme/vivid_theme.dart';

// ============================================
// CONTACT STATUS
// ============================================

enum ContactStatus {
  lead,
  contacted,
  interested,
  meetingScheduled,
  proposalSent,
  client,
  lost;

  String get label => switch (this) {
        lead => 'Lead',
        contacted => 'Contacted',
        interested => 'Interested',
        meetingScheduled => 'Meeting',
        proposalSent => 'Proposal',
        client => 'Client',
        lost => 'Lost',
      };

  String get dbValue => switch (this) {
        lead => 'lead',
        contacted => 'contacted',
        interested => 'interested',
        meetingScheduled => 'meeting_scheduled',
        proposalSent => 'proposal_sent',
        client => 'client',
        lost => 'lost',
      };

  Color get color => switch (this) {
        lead => Colors.grey,
        contacted => VividColors.brightBlue,
        interested => VividColors.cyan,
        meetingScheduled => VividColors.statusWarning,
        proposalSent => Colors.purple,
        client => VividColors.statusSuccess,
        lost => VividColors.statusUrgent,
      };

  static ContactStatus fromDb(String? value) => switch (value) {
        'contacted' => contacted,
        'interested' => interested,
        'meeting_scheduled' => meetingScheduled,
        'proposal_sent' => proposalSent,
        'client' => client,
        'lost' => lost,
        _ => lead,
      };
}

// ============================================
// OUTREACH CONTACT
// ============================================

class OutreachContact {
  final String id;
  final String companyName;
  final String? contactName;
  final String phone;
  final String? email;
  final String? industry;
  final ContactStatus status;
  final String? notes;
  final List<String> tags;
  final DateTime? lastContactedAt;
  final DateTime createdAt;

  const OutreachContact({
    required this.id,
    required this.companyName,
    this.contactName,
    required this.phone,
    this.email,
    this.industry,
    this.status = ContactStatus.lead,
    this.notes,
    this.tags = const [],
    this.lastContactedAt,
    required this.createdAt,
  });

  factory OutreachContact.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }

    return OutreachContact(
      id: json['id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      contactName: json['contact_name'] as String?,
      phone: json['phone']?.toString() ?? '',
      email: json['email'] as String?,
      industry: json['industry'] as String?,
      status: ContactStatus.fromDb(json['status'] as String?),
      notes: json['notes'] as String?,
      tags: tags,
      lastContactedAt: json['last_contacted_at'] != null
          ? DateTime.tryParse(json['last_contacted_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'company_name': companyName,
        'contact_name': contactName,
        'phone': phone,
        'email': email,
        'industry': industry,
        'status': status.dbValue,
        'notes': notes,
        'tags': tags,
      };

  String get displayName => contactName ?? companyName;
}

// ============================================
// OUTREACH MESSAGE
// ============================================

class OutreachMessage {
  final String id;
  final String? contactId;
  final String? aiPhone;
  final String customerPhone;
  final String? customerName;
  final String customerMessage;
  final String? aiResponse;
  final String? managerResponse;
  final String? sentBy;
  final String? direction;
  final String? content;
  final String? label;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaFilename;
  final DateTime createdAt;

  const OutreachMessage({
    required this.id,
    this.contactId,
    this.aiPhone,
    required this.customerPhone,
    this.customerName,
    required this.customerMessage,
    this.aiResponse,
    this.managerResponse,
    this.sentBy,
    this.direction,
    this.content,
    this.label,
    this.mediaUrl,
    this.mediaType,
    this.mediaFilename,
    required this.createdAt,
  });

  factory OutreachMessage.fromJson(Map<String, dynamic> json) {
    return OutreachMessage(
      id: json['id'] as String? ?? '',
      contactId: json['contact_id'] as String?,
      aiPhone: json['ai_phone']?.toString(),
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerName: json['customer_name'] as String?,
      customerMessage: json['customer_message'] as String? ?? '',
      aiResponse: json['ai_response'] as String?,
      managerResponse: json['manager_response'] as String?,
      sentBy: json['sent_by'] as String?,
      direction: json['direction'] as String?,
      content: json['content'] as String?,
      label: json['label'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      mediaFilename: json['media_filename'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  /// The text to display in the bubble — checks all possible text fields:
  /// manager_response, ai_response, content (used by broadcasts/templates),
  /// then customer_message as fallback.
  String get displayText {
    if (managerResponse != null && managerResponse!.isNotEmpty) {
      return managerResponse!;
    }
    if (aiResponse != null && aiResponse!.isNotEmpty) return aiResponse!;
    if (content != null && content!.isNotEmpty) return content!;
    return customerMessage;
  }

  bool get isOutbound =>
      sentBy == 'manager' ||
      sentBy == 'ai' ||
      direction == 'outbound';
}

// ============================================
// OUTREACH BROADCAST
// ============================================

class OutreachBroadcast {
  final String id;
  final String? name;
  final String? templateName;
  final String? messageBody;
  final String? status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final int totalRecipients;
  final int deliveredCount;
  final int failedCount;
  final DateTime createdAt;

  const OutreachBroadcast({
    required this.id,
    this.name,
    this.templateName,
    this.messageBody,
    this.status,
    this.scheduledAt,
    this.sentAt,
    this.totalRecipients = 0,
    this.deliveredCount = 0,
    this.failedCount = 0,
    required this.createdAt,
  });

  factory OutreachBroadcast.fromJson(Map<String, dynamic> json) {
    return OutreachBroadcast(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      templateName: json['template_name'] as String?,
      messageBody: json['message_body'] as String?,
      status: json['status'] as String?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString())
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'].toString())
          : null,
      totalRecipients: json['total_recipients'] as int? ?? 0,
      deliveredCount: json['delivered_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  String get displayName => name ?? templateName ?? 'Untitled';
}

// ============================================
// OUTREACH BROADCAST RECIPIENT
// ============================================

class OutreachBroadcastRecipient {
  final String id;
  final String? broadcastId;
  final String? contactId;
  final String? phone;
  final String? name;
  final String? status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const OutreachBroadcastRecipient({
    required this.id,
    this.broadcastId,
    this.contactId,
    this.phone,
    this.name,
    this.status,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
  });

  factory OutreachBroadcastRecipient.fromJson(Map<String, dynamic> json) {
    return OutreachBroadcastRecipient(
      id: json['id'] as String? ?? '',
      broadcastId: json['broadcast_id'] as String?,
      contactId: json['contact_id'] as String?,
      phone: json['phone']?.toString(),
      name: json['name'] as String?,
      status: json['status'] as String?,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'].toString())
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'].toString())
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
    );
  }

  String get displayName => name ?? phone ?? 'Unknown';

  bool get isDelivered =>
      status == 'delivered' || status == 'read' || status == 'sent';
}
