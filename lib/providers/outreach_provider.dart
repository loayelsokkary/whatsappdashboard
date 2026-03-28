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
  Timer? _messagesPollTimer;
  Map<String, OutreachMessage> _lastMessageByContact = {};

  // Broadcasts
  List<OutreachBroadcast> _broadcasts = [];
  OutreachBroadcast? _selectedBroadcast;
  List<OutreachBroadcastRecipient> _broadcastRecipients = [];
  bool _isLoadingBroadcasts = false;
  bool _isLoadingRecipients = false;
  int _recipientTotalCount = 0;
  static const _recipientPageSize = 50;

  // Templates
  List<WhatsAppTemplate> _templates = [];
  bool _isLoadingTemplates = false;

  // Template creation
  bool _isSubmittingTemplate = false;

  // General
  String? _error;

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
    // Sort by last message time (most recent first)
    list = List.of(list)..sort((a, b) {
      final aMsg = _lastMessageByContact[a.id];
      final bMsg = _lastMessageByContact[b.id];
      final aTime = aMsg?.createdAt ?? a.lastContactedAt ?? a.createdAt;
      final bTime = bMsg?.createdAt ?? b.lastContactedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  List<OutreachContact> get allContacts => _contacts;
  OutreachContact? get selectedContact => _selectedContact;
  ContactStatus? get contactFilter => _contactFilter;
  String get contactSearch => _contactSearch;
  bool get isLoadingContacts => _isLoadingContacts;

  List<OutreachMessage> get messages => _messages;
  bool get isLoadingMessages => _isLoadingMessages;
  OutreachMessage? lastMessageFor(String contactId) => _lastMessageByContact[contactId];

  List<OutreachBroadcast> get broadcasts => _broadcasts;
  OutreachBroadcast? get selectedBroadcast => _selectedBroadcast;
  List<OutreachBroadcastRecipient> get broadcastRecipients => _broadcastRecipients;
  bool get isLoadingBroadcasts => _isLoadingBroadcasts;
  bool get isLoadingRecipients => _isLoadingRecipients;
  int get recipientTotalCount => _recipientTotalCount;
  bool get hasMoreRecipients => _broadcastRecipients.length < _recipientTotalCount;

  List<WhatsAppTemplate> get templates => _templates;
  bool get isLoadingTemplates => _isLoadingTemplates;

  String? get error => _error;
  bool get isSubmittingTemplate => _isSubmittingTemplate;
  bool get hasSendWebhook => SupabaseService.outreachSendWebhook.isNotEmpty;
  bool get hasBroadcastWebhook => SupabaseService.outreachBroadcastWebhook.isNotEmpty;
  bool get hasMetaCredentials =>
      SupabaseService.outreachWabaId.isNotEmpty &&
      SupabaseService.outreachMetaAccessToken.isNotEmpty;
  String get outreachPhone => SupabaseService.outreachPhone;

  SupabaseClient get _db => SupabaseService.adminClient;

  // Needs reply: contacts whose last message is inbound
  Set<String> get needsReplyContactIds {
    final result = <String>{};
    for (final contact in _contacts) {
      final lastMsg = _lastMessageByContact[contact.id];
      if (lastMsg != null && !lastMsg.isOutbound) {
        result.add(contact.id);
      }
    }
    return result;
  }

  int get needsReplyCount => needsReplyContactIds.length;

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

  /// Reload outreach config from system_settings (phone, webhooks).
  Future<void> reloadOutreachConfig() async {
    await SupabaseService.instance.loadOutreachConfig();
    debugPrint('OUTREACH: send webhook ${hasSendWebhook ? "configured" : "not configured"}');
    debugPrint('OUTREACH: broadcast webhook ${hasBroadcastWebhook ? "configured" : "not configured"}');
    notifyListeners();
  }

  // ============================================
  // CONTACTS CRUD
  // ============================================

  Future<void> fetchContacts() async {
    _isLoadingContacts = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('OUTREACH: fetching contacts from vivid_outreach_contacts');
      final rows = await _db
          .from('vivid_outreach_contacts')
          .select()
          .order('created_at', ascending: false);

      _contacts = (rows as List)
          .map((r) => OutreachContact.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('OUTREACH: loaded ${_contacts.length} contacts');

      // Fetch last message per contact for list preview
      _fetchLastMessages();
    } catch (e) {
      debugPrint('OUTREACH: contacts error: $e');
      _error = e.toString();
    }

    _isLoadingContacts = false;
    notifyListeners();
  }

  Future<String?> createContact(OutreachContact contact) async {
    try {
      await _db.from('vivid_outreach_contacts').insert(contact.toInsertJson());
      debugPrint('OUTREACH: created contact ${contact.companyName}');
      await fetchContacts();
      return null;
    } catch (e) {
      debugPrint('OUTREACH: create contact error: $e');
      return e.toString();
    }
  }

  Future<String?> updateContact(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _db.from('vivid_outreach_contacts').update(updates).eq('id', id);
      debugPrint('OUTREACH: updated contact $id');
      await fetchContacts();
      return null;
    } catch (e) {
      debugPrint('OUTREACH: update contact error: $e');
      return e.toString();
    }
  }

  Future<String?> deleteContact(String id) async {
    try {
      await _db.from('vivid_outreach_contacts').delete().eq('id', id);
      debugPrint('OUTREACH: deleted contact $id');
      _contacts.removeWhere((c) => c.id == id);
      if (_selectedContact?.id == id) _selectedContact = null;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('OUTREACH: delete contact error: $e');
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
      debugPrint('OUTREACH: bulk imported ${insertRows.length} contacts');
      await fetchContacts();
      return (imported: insertRows.length, error: null);
    } catch (e) {
      debugPrint('OUTREACH: bulk import error: $e');
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

  Future<void> selectContact(OutreachContact contact) async {
    _selectedContact = contact;
    _messages = [];
    notifyListeners();
    await fetchMessages(contact.id, phone: contact.phone);
    subscribeToMessages(contact.phone);
    _startMessagesPoll(contact.id);
  }

  void clearContactSelection() {
    _selectedContact = null;
    _messages = [];
    _stopMessagesPoll();
    unsubscribeMessages();
    notifyListeners();
  }

  // ============================================
  // MESSAGES
  // ============================================

  Future<void> _fetchLastMessages() async {
    try {
      final phones = _contacts
          .map((c) => c.phone)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      if (phones.isEmpty) return;

      // Get recent messages ordered by created_at desc, then pick latest per phone
      final rows = await _db
          .from('vivid_outreach_messages')
          .select()
          .inFilter('customer_phone', phones)
          .order('created_at', ascending: false);

      final Map<String, OutreachMessage> latest = {};
      for (final r in rows) {
        final msg = OutreachMessage.fromJson(r);
        final phone = msg.customerPhone;
        if (phone.isNotEmpty && !latest.containsKey(phone)) {
          latest[phone] = msg;
        }
      }

      // Map by contact id
      _lastMessageByContact = {};
      for (final contact in _contacts) {
        final msg = latest[contact.phone];
        if (msg != null) {
          _lastMessageByContact[contact.id] = msg;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('OUTREACH: fetch last messages error: $e');
    }
  }

  Future<void> fetchMessages(String contactId, {String? phone}) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      final contactPhone = phone ?? _selectedContact?.phone;
      debugPrint('OUTREACH: fetching messages for contact $contactId (phone: $contactPhone)');

      // Query by customer_phone (reliable on both inbound & outbound) with contact_id fallback
      List<dynamic> rows;
      if (contactPhone != null && contactPhone.isNotEmpty) {
        rows = await _db
            .from('vivid_outreach_messages')
            .select()
            .eq('customer_phone', contactPhone)
            .order('created_at', ascending: true);
      } else {
        rows = await _db
            .from('vivid_outreach_messages')
            .select()
            .eq('contact_id', contactId)
            .order('created_at', ascending: true);
      }

      _messages = rows
          .map((r) => OutreachMessage.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('OUTREACH: loaded ${_messages.length} messages');
    } catch (e) {
      debugPrint('OUTREACH: messages error: $e');
    }

    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<String?> uploadMedia(Uint8List bytes, String filename) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitized = filename
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'outreach/${timestamp}_$sanitized';

      final ext = filename.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

      await SupabaseService.client.storage
          .from('media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      final url = SupabaseService.client.storage
          .from('media')
          .getPublicUrl(path);

      debugPrint('OUTREACH: uploaded media: $url');
      return url;
    } catch (e) {
      debugPrint('OUTREACH: upload media error: $e');
      return null;
    }
  }

  Future<String?> sendMessage(
    String contactId,
    String text, {
    String? mediaUrl,
    String? mediaType,
    String? mediaFilename,
  }) async {
    if (_selectedContact == null) return 'No contact selected';

    final contact = _selectedContact!;
    final now = DateTime.now().toUtc();

    try {
      final row = {
        'contact_id': contactId,
        'ai_phone': SupabaseService.outreachPhone,
        'customer_phone': contact.phone,
        'customer_name': contact.displayName,
        'customer_message': '',
        'ai_response': '',
        'manager_response': text,
        'sent_by': 'manager',
        'label': 'outreach',
        'created_at': now.toIso8601String(),
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaType != null) 'media_type': mediaType,
        if (mediaFilename != null) 'media_filename': mediaFilename,
      };

      final inserted = await _db.from('vivid_outreach_messages').insert(row).select().single();
      final newMsg = OutreachMessage.fromJson(inserted);
      // Dedup: realtime may have already added this message before the HTTP response arrived
      if (!_messages.any((m) => m.id == newMsg.id)) {
        _messages.add(newMsg);
      }
      _lastMessageByContact[contactId] = newMsg;
      notifyListeners();
      debugPrint('OUTREACH: message stored to DB');

      // Update last_contacted_at
      await _db
          .from('vivid_outreach_contacts')
          .update({'last_contacted_at': now.toIso8601String()})
          .eq('id', contactId);

      // Send via n8n webhook if configured
      if (hasSendWebhook) {
        try {
          await http.post(
            Uri.parse(SupabaseService.outreachSendWebhook),
            headers: {
              'Content-Type': 'application/json',
              if (SupabaseService.webhookSecret.isNotEmpty)
                'X-Vivid-Secret': SupabaseService.webhookSecret,
            },
            body: jsonEncode({
              'ai_phone': SupabaseService.outreachPhone,
              'customer_phone': contact.phone,
              'customer_name': contact.displayName,
              'manager_response': text,
              'sent_by': 'manager',
              'media_url': mediaUrl ?? '',
              'media_type': mediaType ?? '',
              'media_filename': mediaFilename ?? '',
            }),
          );
          debugPrint('OUTREACH: message sent via webhook');
        } catch (e) {
          debugPrint('OUTREACH: webhook send error (message still saved): $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('OUTREACH: send message error: $e');
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
                  // Update last message for sidebar preview
                  final cId = msg.contactId ?? _selectedContact?.id;
                  if (cId != null) _lastMessageByContact[cId] = msg;
                  notifyListeners();
                }
              }
            },
          )
          .subscribe();
      debugPrint('OUTREACH: subscribed to messages for $contactPhone');
    } catch (e) {
      debugPrint('OUTREACH: realtime subscribe error: $e');
    }
  }

  void unsubscribeMessages() {
    if (_messagesChannel != null) {
      SupabaseService.client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  void _startMessagesPoll(String contactId) {
    _stopMessagesPoll();
    _messagesPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_selectedContact?.id == contactId) {
        _pollMessages(contactId);
      } else {
        _stopMessagesPoll();
      }
    });
  }

  void _stopMessagesPoll() {
    _messagesPollTimer?.cancel();
    _messagesPollTimer = null;
  }

  /// Lightweight fetch that merges new messages without replacing the list.
  Future<void> _pollMessages(String contactId) async {
    try {
      final contactPhone = _selectedContact?.phone;
      List<dynamic> rows;
      if (contactPhone != null && contactPhone.isNotEmpty) {
        rows = await _db
            .from('vivid_outreach_messages')
            .select()
            .eq('customer_phone', contactPhone)
            .order('created_at', ascending: true);
      } else {
        rows = await _db
            .from('vivid_outreach_messages')
            .select()
            .eq('contact_id', contactId)
            .order('created_at', ascending: true);
      }

      final fetched = rows
          .map((r) => OutreachMessage.fromJson(r as Map<String, dynamic>))
          .toList();

      final existingIds = _messages.map((m) => m.id).toSet();
      var added = false;
      for (final msg in fetched) {
        if (!existingIds.contains(msg.id)) {
          _messages.add(msg);
          added = true;
        }
      }
      if (added && _selectedContact != null && _messages.isNotEmpty) {
        _lastMessageByContact[_selectedContact!.id] = _messages.last;
        notifyListeners();
      } else if (added) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('OUTREACH: poll messages error: $e');
    }
  }

  // ============================================
  // BROADCASTS
  // ============================================

  Future<void> fetchBroadcasts() async {
    _isLoadingBroadcasts = true;
    notifyListeners();

    try {
      debugPrint('OUTREACH: fetching broadcasts');
      final rows = await _db
          .from('vivid_outreach_broadcasts')
          .select()
          .order('created_at', ascending: false);

      _broadcasts = (rows as List)
          .map((r) => OutreachBroadcast.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('OUTREACH: loaded ${_broadcasts.length} broadcasts');
    } catch (e) {
      debugPrint('OUTREACH: broadcasts error: $e');
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

  Future<String?> renameBroadcast(String id, String newName) async {
    try {
      await _db
          .from('vivid_outreach_broadcasts')
          .update({'name': newName})
          .eq('id', id);
      final idx = _broadcasts.indexWhere((b) => b.id == id);
      if (idx >= 0) {
        final old = _broadcasts[idx];
        _broadcasts[idx] = OutreachBroadcast(
          id: old.id,
          name: newName,
          templateName: old.templateName,
          messageBody: old.messageBody,
          status: old.status,
          scheduledAt: old.scheduledAt,
          sentAt: old.sentAt,
          totalRecipients: old.totalRecipients,
          deliveredCount: old.deliveredCount,
          failedCount: old.failedCount,
          createdAt: old.createdAt,
        );
        if (_selectedBroadcast?.id == id) {
          _selectedBroadcast = _broadcasts[idx];
        }
        notifyListeners();
      }
      return null;
    } catch (e) {
      debugPrint('OUTREACH: rename broadcast error: $e');
      return e.toString();
    }
  }

  Future<void> fetchBroadcastRecipients(String broadcastId) async {
    _isLoadingRecipients = true;
    _broadcastRecipients = [];
    _recipientTotalCount = 0;
    notifyListeners();

    try {
      // Get total count
      final countRows = await _db
          .from('vivid_outreach_broadcast_recipients')
          .select('id')
          .eq('broadcast_id', broadcastId);
      _recipientTotalCount = (countRows as List).length;

      // Fetch first page
      final rows = await _db
          .from('vivid_outreach_broadcast_recipients')
          .select()
          .eq('broadcast_id', broadcastId)
          .order('name')
          .limit(_recipientPageSize);

      _broadcastRecipients = (rows as List)
          .map((r) =>
              OutreachBroadcastRecipient.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('OUTREACH: loaded ${_broadcastRecipients.length}/$_recipientTotalCount recipients for broadcast $broadcastId');
    } catch (e) {
      debugPrint('OUTREACH: recipients error: $e');
    }

    _isLoadingRecipients = false;
    notifyListeners();
  }

  Future<void> loadMoreRecipients(String broadcastId) async {
    if (!hasMoreRecipients) return;

    try {
      final rows = await _db
          .from('vivid_outreach_broadcast_recipients')
          .select()
          .eq('broadcast_id', broadcastId)
          .order('name')
          .range(_broadcastRecipients.length, _broadcastRecipients.length + _recipientPageSize - 1);

      final more = (rows as List)
          .map((r) =>
              OutreachBroadcastRecipient.fromJson(r as Map<String, dynamic>))
          .toList();

      _broadcastRecipients.addAll(more);
      notifyListeners();
    } catch (e) {
      debugPrint('OUTREACH: load more recipients error: $e');
    }
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

      debugPrint('OUTREACH: created broadcast "$name" with ${selectedContacts.length} recipients');

      // Send via n8n broadcast webhook if configured
      if (hasBroadcastWebhook && templateName != null && templateName.isNotEmpty) {
        try {
          await http.post(
            Uri.parse(SupabaseService.outreachBroadcastWebhook),
            headers: {
              'Content-Type': 'application/json',
              if (SupabaseService.webhookSecret.isNotEmpty)
                'X-Vivid-Secret': SupabaseService.webhookSecret,
            },
            body: jsonEncode({
              'template_name': templateName,
              'campaign_name': name,
              'broadcast_id': broadcastId,
              'filters': {
                'specific_ids': selectedContacts.map((c) => c.id).toList(),
              },
              'variable_overrides': {},
              'created_by': 'Vivid Admin',
            }),
          );
          debugPrint('OUTREACH: broadcast sent via webhook');
        } catch (e) {
          debugPrint('OUTREACH: broadcast webhook error: $e');
        }
      }

      await fetchBroadcasts();
      return null;
    } catch (e) {
      debugPrint('OUTREACH: create broadcast error: $e');
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
      debugPrint('OUTREACH: fetching templates from vivid_outreach_whatsapp_templates');
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
          headerMediaUrl: (r['offer_image_url'] as String?)?.isNotEmpty == true
              ? r['offer_image_url'] as String
              : r['header_media_url'] as String?,
          body: r['body_text'] as String? ?? '',
          buttons: buttons,
        );
      }).toList();

      debugPrint('OUTREACH: loaded ${_templates.length} templates');
    } catch (e) {
      debugPrint('OUTREACH: templates error: $e');
    }

    _isLoadingTemplates = false;
    notifyListeners();
  }

  /// Sync templates from Meta Graph API into local DB.
  Future<String?> syncTemplatesFromMeta() async {
    if (!hasMetaCredentials) {
      return 'Outreach Meta credentials not configured.';
    }

    _isLoadingTemplates = true;
    notifyListeners();

    try {
      final url = '$_metaBaseUrl/${SupabaseService.outreachWabaId}/message_templates?limit=100';
      debugPrint('OUTREACH: syncing templates from Meta: $url');

      final response = await http.get(Uri.parse(url), headers: _metaHeaders);
      if (response.statusCode != 200) {
        _isLoadingTemplates = false;
        notifyListeners();
        return 'Meta API error: ${response.statusCode}';
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];

      for (final tpl in data) {
        final t = tpl as Map<String, dynamic>;
        final components = t['components'] as List<dynamic>? ?? [];

        String headerType = 'none';
        String? headerText;
        String? headerMediaUrl;
        String bodyText = '';
        List<Map<String, dynamic>> buttons = [];

        for (final comp in components) {
          final c = comp as Map<String, dynamic>;
          final type = (c['type'] as String? ?? '').toUpperCase();
          if (type == 'HEADER') {
            headerType = (c['format'] as String? ?? 'TEXT').toLowerCase();
            headerText = c['text'] as String?;
            if (headerType == 'image' || headerType == 'video') {
              final example = c['example'] as Map<String, dynamic>?;
              final handles = example?['header_handle'] as List<dynamic>?;
              if (handles != null && handles.isNotEmpty) {
                headerMediaUrl = handles.first as String?;
              }
            }
          } else if (type == 'BODY') {
            bodyText = c['text'] as String? ?? '';
          } else if (type == 'BUTTONS') {
            final btns = c['buttons'] as List<dynamic>? ?? [];
            buttons = btns.map((b) => b as Map<String, dynamic>).toList();
          }
        }

        await syncTemplateToDb(
          metaTemplateId: t['id']?.toString() ?? '',
          templateName: t['name'] as String? ?? '',
          status: (t['status'] as String? ?? '').toLowerCase(),
          language: t['language'] as String? ?? '',
          category: (t['category'] as String? ?? '').toLowerCase(),
          headerType: headerType,
          headerText: headerText,
          headerMediaUrl: headerMediaUrl,
          bodyText: bodyText,
          buttons: buttons.map((b) => {
            'type': b['type'] ?? '',
            'text': b['text'] ?? '',
          }).toList(),
        );
      }

      debugPrint('OUTREACH: synced ${data.length} templates from Meta');
      await fetchTemplates();
      return null;
    } catch (e) {
      debugPrint('OUTREACH: sync templates error: $e');
      _isLoadingTemplates = false;
      notifyListeners();
      return e.toString();
    }
  }

  /// Delete a template from Meta and local DB.
  Future<String?> deleteTemplate(String templateName, String metaTemplateId) async {
    if (!hasMetaCredentials) {
      return 'Outreach Meta credentials not configured.';
    }

    try {
      // Delete from Meta
      final url = '$_metaBaseUrl/${SupabaseService.outreachWabaId}/message_templates?name=$templateName';
      final response = await http.delete(Uri.parse(url), headers: _metaHeaders);

      if (response.statusCode != 200 && response.statusCode != 204) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final err = decoded['error'] as Map<String, dynamic>?;
        final errorMsg = err?['message'] as String? ?? '';
        final errorUserTitle = err?['error_user_title'] as String? ?? '';

        // If Meta says template doesn't exist, still delete from Supabase
        final isNotFound = errorMsg.toLowerCase().contains('invalid parameter') ||
            errorUserTitle.toLowerCase().contains('does not exist') ||
            errorMsg.toLowerCase().contains('does not exist') ||
            response.statusCode == 404;

        if (!isNotFound) {
          debugPrint('OUTREACH: Meta delete failed: $errorMsg ($errorUserTitle)');
          return errorMsg.isNotEmpty ? errorMsg : 'Delete failed (${response.statusCode})';
        }

        // Template not found on Meta — proceed to delete from Supabase anyway
        debugPrint('OUTREACH: Template not found on Meta, deleting from Supabase only');
      }

      // Delete from local DB
      await _db
          .from('vivid_outreach_whatsapp_templates')
          .delete()
          .eq('meta_template_id', metaTemplateId);

      _templates.removeWhere((t) => t.id == metaTemplateId);
      notifyListeners();

      debugPrint('OUTREACH: deleted template "$templateName"');
      return null;
    } catch (e) {
      debugPrint('OUTREACH: delete template error: $e');
      return e.toString();
    }
  }

  // ============================================
  // TEMPLATE CREATION (Meta API)
  // ============================================

  static String get _metaBaseUrl =>
      'https://graph.facebook.com/${SupabaseService.metaApiVersion}';

  Map<String, String> get _metaHeaders => {
        'Authorization': 'Bearer ${SupabaseService.outreachMetaAccessToken}',
        'Content-Type': 'application/json',
      };

  /// Create a template on Meta's WABA for the outreach account.
  Future<({String? error, String? templateId})> createTemplate({
    required String name,
    required String language,
    required String category,
    required List<Map<String, dynamic>> components,
  }) async {
    if (!hasMetaCredentials) {
      return (error: 'Outreach Meta credentials not configured. Set WABA ID and Access Token in Settings.', templateId: null);
    }

    _isSubmittingTemplate = true;
    notifyListeners();

    try {
      final payload = {
        'name': name,
        'language': language,
        'category': category.toUpperCase(),
        'components': components,
      };

      debugPrint('OUTREACH: creating template "$name" on Meta WABA ${SupabaseService.outreachWabaId}');

      final response = await http.post(
        Uri.parse('$_metaBaseUrl/${SupabaseService.outreachWabaId}/message_templates'),
        headers: _metaHeaders,
        body: jsonEncode(payload),
      );

      debugPrint('OUTREACH: createTemplate response: ${response.statusCode}');

      _isSubmittingTemplate = false;
      notifyListeners();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final templateId = decoded['id'] as String?;
        return (error: null, templateId: templateId);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      final msg = (err?['message'] as String?) ?? 'Failed to create template (${response.statusCode})';
      return (error: msg, templateId: null);
    } catch (e) {
      debugPrint('OUTREACH: createTemplate error: $e');
      _isSubmittingTemplate = false;
      notifyListeners();
      return (error: e.toString(), templateId: null);
    }
  }

  /// Upload an image to Meta's resumable upload API for template headers.
  Future<String?> uploadImageToMeta(Uint8List imageBytes, String mimeType) async {
    if (!hasMetaCredentials) return null;

    try {
      // Step 1: Start upload session
      final initUrl = '$_metaBaseUrl/${SupabaseService.metaAppId}/uploads'
          '?file_type=$mimeType&file_length=${imageBytes.length}';
      debugPrint('OUTREACH: image upload step 1 — start session');

      final initResponse = await http.post(
        Uri.parse(initUrl),
        headers: {'Authorization': 'Bearer ${SupabaseService.outreachMetaAccessToken}'},
      );

      if (initResponse.statusCode != 200) {
        debugPrint('OUTREACH: upload session failed: ${initResponse.statusCode}');
        return null;
      }

      final initBody = jsonDecode(initResponse.body) as Map<String, dynamic>;
      final uploadId = initBody['id'] as String?;
      if (uploadId == null) return null;

      // Step 2: Upload bytes via Edge Function (CORS workaround for web)
      final sessionUrl = '$_metaBaseUrl/$uploadId';
      debugPrint('OUTREACH: image upload step 2 — uploading ${imageBytes.length} bytes');

      if (kIsWeb) {
        final fileBase64 = base64Encode(imageBytes);
        final fnResponse = await SupabaseService.client.functions.invoke(
          'proxy-meta-upload',
          body: {
            'sessionUrl': sessionUrl,
            'fileBase64': fileBase64,
            'mimeType': mimeType,
            'accessToken': SupabaseService.outreachMetaAccessToken,
          },
        );
        final fnBody = fnResponse.data is Map
            ? fnResponse.data as Map<String, dynamic>
            : jsonDecode(fnResponse.data.toString()) as Map<String, dynamic>;
        return fnBody['h'] as String?;
      } else {
        final uploadResponse = await http.post(
          Uri.parse(sessionUrl),
          headers: {
            'Authorization': 'OAuth ${SupabaseService.outreachMetaAccessToken}',
            'file_offset': '0',
            'Content-Type': mimeType,
          },
          body: imageBytes,
        );
        if (uploadResponse.statusCode != 200) return null;
        final uploadBody = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
        return uploadBody['h'] as String?;
      }
    } catch (e) {
      debugPrint('OUTREACH: image upload error: $e');
      return null;
    }
  }

  /// After creating on Meta, upsert the template into the outreach Supabase table.
  Future<String?> syncTemplateToDb({
    required String metaTemplateId,
    required String templateName,
    required String status,
    required String language,
    required String category,
    required String headerType,
    String? headerText,
    String? headerMediaUrl,
    required String bodyText,
    List<Map<String, dynamic>>? buttons,
    String? offerImageUrl,
  }) async {
    try {
      final row = {
        'meta_template_id': metaTemplateId,
        'template_name': templateName,
        'status': status,
        'language_code': language,
        'category': category,
        'header_type': headerType.toLowerCase(),
        'header_text': headerText,
        'header_media_url': headerMediaUrl,
        'body_text': bodyText,
        'buttons': buttons ?? [],
        'offer_image_url': offerImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _db
          .from('vivid_outreach_whatsapp_templates')
          .upsert(row, onConflict: 'meta_template_id');

      debugPrint('OUTREACH: synced template "$templateName" to DB');
      return null;
    } catch (e) {
      debugPrint('OUTREACH: sync template to DB error: $e');
      return e.toString();
    }
  }

  /// Upload an offer image to Supabase Storage for permanent URL.
  Future<String?> uploadOfferImageToStorage(
    Uint8List imageBytes,
    String templateName,
    String mimeType,
  ) async {
    try {
      final safeName = templateName
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
      if (safeName.isEmpty) return null;

      final path = '$safeName.jpeg';
      await SupabaseService.adminClient.storage
          .from('Template-images')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final url = SupabaseService.adminClient.storage
          .from('Template-images')
          .getPublicUrl(path);

      debugPrint('OUTREACH: uploaded offer image → $url');
      return url;
    } catch (e) {
      debugPrint('OUTREACH: offer image upload error: $e');
      return null;
    }
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
