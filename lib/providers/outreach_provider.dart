import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/outreach_models.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class OutreachProvider extends ChangeNotifier {
  // ============================================
  // STATE
  // ============================================

  // Contacts
  List<OutreachContact> _contacts = [];
  OutreachContact? _selectedContact;
  ContactStatus? _contactFilter;
  String _contactSearch = '';
  bool _isLoadingContacts = false;

  // Messages
  List<OutreachMessage> _messages = [];
  bool _isLoadingMessages = false;
  RealtimeChannel? _messagesChannel;

  // Broadcasts
  List<OutreachBroadcast> _broadcasts = [];
  OutreachBroadcast? _selectedBroadcast;
  List<OutreachBroadcastRecipient> _broadcastRecipients = [];
  bool _isLoadingBroadcasts = false;
  bool _isLoadingRecipients = false;

  // Templates
  List<WhatsAppTemplate> _templates = [];
  bool _isLoadingTemplates = false;

  // General
  String? _error;
  String? _webhookUrl;

  // ============================================
  // GETTERS
  // ============================================

  List<OutreachContact> get contacts {
    var list = _contacts;
    if (_contactFilter != null) {
      list = list.where((c) => c.status == _contactFilter).toList();
    }
    if (_contactSearch.isNotEmpty) {
      final q = _contactSearch.toLowerCase();
      list = list.where((c) =>
          c.companyName.toLowerCase().contains(q) ||
          (c.contactName?.toLowerCase().contains(q) ?? false) ||
          c.phone.contains(q)).toList();
    }
    return list;
  }

  List<OutreachContact> get allContacts => _contacts;
  OutreachContact? get selectedContact => _selectedContact;
  ContactStatus? get contactFilter => _contactFilter;
  String get contactSearch => _contactSearch;
  bool get isLoadingContacts => _isLoadingContacts;

  List<OutreachMessage> get messages => _messages;
  bool get isLoadingMessages => _isLoadingMessages;

  List<OutreachBroadcast> get broadcasts => _broadcasts;
  OutreachBroadcast? get selectedBroadcast => _selectedBroadcast;
  List<OutreachBroadcastRecipient> get broadcastRecipients => _broadcastRecipients;
  bool get isLoadingBroadcasts => _isLoadingBroadcasts;
  bool get isLoadingRecipients => _isLoadingRecipients;

  List<WhatsAppTemplate> get templates => _templates;
  bool get isLoadingTemplates => _isLoadingTemplates;

  String? get error => _error;
  String? get webhookUrl => _webhookUrl;
  bool get hasWebhook => _webhookUrl != null && _webhookUrl!.isNotEmpty;

  SupabaseClient get _db => SupabaseService.adminClient;

  // Contact counts per status
  Map<ContactStatus, int> get contactCounts {
    final counts = <ContactStatus, int>{};
    for (final s in ContactStatus.values) {
      counts[s] = _contacts.where((c) => c.status == s).length;
    }
    return counts;
  }

  // ============================================
  // INIT
  // ============================================

  Future<void> loadWebhookUrl() async {
    try {
      final settings = await SupabaseService.instance.fetchSystemSettings();
      _webhookUrl = settings['vivid_outreach_webhook_url'];
      print('OUTREACH: webhook URL ${hasWebhook ? "configured" : "not configured"}');
    } catch (e) {
      print('OUTREACH: failed to load webhook URL: $e');
    }
  }

  // ============================================
  // CONTACTS CRUD
  // ============================================

  Future<void> fetchContacts() async {
    _isLoadingContacts = true;
    _error = null;
    notifyListeners();

    try {
      print('OUTREACH: fetching contacts from vivid_outreach_contacts');
      final rows = await _db
          .from('vivid_outreach_contacts')
          .select()
          .order('created_at', ascending: false);

      _contacts = (rows as List)
          .map((r) => OutreachContact.fromJson(r as Map<String, dynamic>))
          .toList();

      print('OUTREACH: loaded ${_contacts.length} contacts');
    } catch (e) {
      print('OUTREACH: contacts error: $e');
      _error = e.toString();
    }

    _isLoadingContacts = false;
    notifyListeners();
  }

  Future<String?> createContact(OutreachContact contact) async {
    try {
      await _db.from('vivid_outreach_contacts').insert(contact.toInsertJson());
      print('OUTREACH: created contact ${contact.companyName}');
      await fetchContacts();
      return null;
    } catch (e) {
      print('OUTREACH: create contact error: $e');
      return e.toString();
    }
  }

  Future<String?> updateContact(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _db.from('vivid_outreach_contacts').update(updates).eq('id', id);
      print('OUTREACH: updated contact $id');
      await fetchContacts();
      return null;
    } catch (e) {
      print('OUTREACH: update contact error: $e');
      return e.toString();
    }
  }

  Future<String?> deleteContact(String id) async {
    try {
      await _db.from('vivid_outreach_contacts').delete().eq('id', id);
      print('OUTREACH: deleted contact $id');
      _contacts.removeWhere((c) => c.id == id);
      if (_selectedContact?.id == id) _selectedContact = null;
      notifyListeners();
      return null;
    } catch (e) {
      print('OUTREACH: delete contact error: $e');
      return e.toString();
    }
  }

  Future<({int imported, String? error})> bulkImportContacts(
      List<Map<String, dynamic>> rows) async {
    try {
      final insertRows = rows.map((r) => {
            'company_name': r['company_name'] ?? '',
            'contact_name': r['contact_name'],
            'phone': r['phone']?.toString() ?? '',
            'email': r['email'],
            'industry': r['industry'],
            'status': 'lead',
          }).toList();

      await _db.from('vivid_outreach_contacts').insert(insertRows);
      print('OUTREACH: bulk imported ${insertRows.length} contacts');
      await fetchContacts();
      return (imported: insertRows.length, error: null);
    } catch (e) {
      print('OUTREACH: bulk import error: $e');
      return (imported: 0, error: e.toString());
    }
  }

  void setContactFilter(ContactStatus? status) {
    _contactFilter = status;
    notifyListeners();
  }

  void setContactSearch(String query) {
    _contactSearch = query;
    notifyListeners();
  }

  void selectContact(OutreachContact contact) {
    _selectedContact = contact;
    notifyListeners();
    fetchMessages(contact.id);
    subscribeToMessages(contact.phone);
  }

  void clearContactSelection() {
    _selectedContact = null;
    _messages = [];
    unsubscribeMessages();
    notifyListeners();
  }

  // ============================================
  // MESSAGES
  // ============================================

  Future<void> fetchMessages(String contactId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      print('OUTREACH: fetching messages for contact $contactId');
      final rows = await _db
          .from('vivid_outreach_messages')
          .select()
          .eq('contact_id', contactId)
          .order('created_at', ascending: true);

      _messages = (rows as List)
          .map((r) => OutreachMessage.fromJson(r as Map<String, dynamic>))
          .toList();

      print('OUTREACH: loaded ${_messages.length} messages');
    } catch (e) {
      print('OUTREACH: messages error: $e');
    }

    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<String?> sendMessage(String contactId, String text) async {
    if (_selectedContact == null) return 'No contact selected';

    final contact = _selectedContact!;
    final now = DateTime.now();

    // Optimistic insert to DB
    try {
      final row = {
        'contact_id': contactId,
        'ai_phone': '', // Vivid's outreach phone — set when webhook configured
        'customer_phone': contact.phone,
        'customer_name': contact.displayName,
        'customer_message': '',
        'ai_response': '',
        'manager_response': text,
        'sent_by': 'manager',
        'label': 'outreach',
        'created_at': now.toIso8601String(),
      };

      await _db.from('vivid_outreach_messages').insert(row);
      print('OUTREACH: message stored to DB');

      // Update last_contacted_at
      await _db
          .from('vivid_outreach_contacts')
          .update({'last_contacted_at': now.toIso8601String()})
          .eq('id', contactId);

      // Send via webhook if configured
      if (hasWebhook) {
        try {
          await http.post(
            Uri.parse(_webhookUrl!),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': contact.phone,
              'name': contact.displayName,
              'message': text,
              'sent_by': 'manager',
            }),
          );
          print('OUTREACH: message sent via webhook');
        } catch (e) {
          print('OUTREACH: webhook send error (message still saved): $e');
        }
      }

      // Refresh messages
      await fetchMessages(contactId);
      return null;
    } catch (e) {
      print('OUTREACH: send message error: $e');
      return e.toString();
    }
  }

  void subscribeToMessages(String contactPhone) {
    unsubscribeMessages();
    try {
      _messagesChannel = SupabaseService.client
          .channel('outreach_messages_$contactPhone')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'vivid_outreach_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_phone',
              value: contactPhone,
            ),
            callback: (payload) {
              final row = payload.newRecord;
              if (row.isNotEmpty) {
                final msg = OutreachMessage.fromJson(row);
                if (!_messages.any((m) => m.id == msg.id)) {
                  _messages.add(msg);
                  notifyListeners();
                }
              }
            },
          )
          .subscribe();
      print('OUTREACH: subscribed to messages for $contactPhone');
    } catch (e) {
      print('OUTREACH: realtime subscribe error: $e');
    }
  }

  void unsubscribeMessages() {
    if (_messagesChannel != null) {
      SupabaseService.client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  // ============================================
  // BROADCASTS
  // ============================================

  Future<void> fetchBroadcasts() async {
    _isLoadingBroadcasts = true;
    notifyListeners();

    try {
      print('OUTREACH: fetching broadcasts');
      final rows = await _db
          .from('vivid_outreach_broadcasts')
          .select()
          .order('created_at', ascending: false);

      _broadcasts = (rows as List)
          .map((r) => OutreachBroadcast.fromJson(r as Map<String, dynamic>))
          .toList();

      print('OUTREACH: loaded ${_broadcasts.length} broadcasts');
    } catch (e) {
      print('OUTREACH: broadcasts error: $e');
    }

    _isLoadingBroadcasts = false;
    notifyListeners();
  }

  void selectBroadcast(OutreachBroadcast broadcast) {
    _selectedBroadcast = broadcast;
    notifyListeners();
    fetchBroadcastRecipients(broadcast.id);
  }

  void clearBroadcastSelection() {
    _selectedBroadcast = null;
    _broadcastRecipients = [];
    notifyListeners();
  }

  Future<void> fetchBroadcastRecipients(String broadcastId) async {
    _isLoadingRecipients = true;
    notifyListeners();

    try {
      final rows = await _db
          .from('vivid_outreach_broadcast_recipients')
          .select()
          .eq('broadcast_id', broadcastId)
          .order('name');

      _broadcastRecipients = (rows as List)
          .map((r) =>
              OutreachBroadcastRecipient.fromJson(r as Map<String, dynamic>))
          .toList();

      print('OUTREACH: loaded ${_broadcastRecipients.length} recipients for broadcast $broadcastId');
    } catch (e) {
      print('OUTREACH: recipients error: $e');
    }

    _isLoadingRecipients = false;
    notifyListeners();
  }

  Future<String?> createBroadcast({
    required String name,
    String? templateName,
    required String messageBody,
    required List<OutreachContact> selectedContacts,
  }) async {
    try {
      // Insert broadcast
      final broadcastRow = {
        'name': name,
        'template_name': templateName,
        'message_body': messageBody,
        'status': 'draft',
        'total_recipients': selectedContacts.length,
        'delivered_count': 0,
        'failed_count': 0,
      };

      final result = await _db
          .from('vivid_outreach_broadcasts')
          .insert(broadcastRow)
          .select('id')
          .single();

      final broadcastId = result['id'] as String;

      // Insert recipients
      final recipientRows = selectedContacts.map((c) => {
            'broadcast_id': broadcastId,
            'contact_id': c.id,
            'phone': c.phone,
            'name': c.displayName,
            'status': 'pending',
          }).toList();

      if (recipientRows.isNotEmpty) {
        await _db
            .from('vivid_outreach_broadcast_recipients')
            .insert(recipientRows);
      }

      print('OUTREACH: created broadcast "$name" with ${selectedContacts.length} recipients');
      await fetchBroadcasts();
      return null;
    } catch (e) {
      print('OUTREACH: create broadcast error: $e');
      return e.toString();
    }
  }

  // ============================================
  // TEMPLATES
  // ============================================

  Future<void> fetchTemplates() async {
    _isLoadingTemplates = true;
    notifyListeners();

    try {
      print('OUTREACH: fetching templates from vivid_outreach_whatsapp_templates');
      final rows = await _db
          .from('vivid_outreach_whatsapp_templates')
          .select();

      _templates = (rows as List).map((r) {
        final buttonsRaw = r['buttons'] as List<dynamic>? ?? [];
        final buttons = buttonsRaw.map((b) {
          final m = b as Map<String, dynamic>;
          return TemplateButton(
              type: m['type'] as String? ?? '',
              text: m['text'] as String? ?? '');
        }).toList();

        return WhatsAppTemplate(
          id: r['meta_template_id'] as String? ?? r['id']?.toString() ?? '',
          name: r['template_name'] as String? ?? r['name'] as String? ?? '',
          status: r['status'] as String? ?? '',
          language: r['language_code'] as String? ?? r['language'] as String? ?? '',
          category: r['category'] as String? ?? '',
          headerType: (r['header_type'] as String? ?? '').toUpperCase(),
          headerText: r['header_text'] as String?,
          headerMediaUrl: r['offer_image_url'] as String?,
          body: r['body_text'] as String? ?? '',
          buttons: buttons,
        );
      }).toList();

      print('OUTREACH: loaded ${_templates.length} templates');
    } catch (e) {
      print('OUTREACH: templates error: $e');
    }

    _isLoadingTemplates = false;
    notifyListeners();
  }

  // ============================================
  // CLEANUP
  // ============================================

  @override
  void dispose() {
    unsubscribeMessages();
    super.dispose();
  }
}
