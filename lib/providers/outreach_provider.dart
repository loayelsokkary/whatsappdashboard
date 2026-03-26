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
  bool get isSubmittingTemplate => _isSubmittingTemplate;
  bool get hasSendWebhook => SupabaseService.outreachSendWebhook.isNotEmpty;
  bool get hasBroadcastWebhook => SupabaseService.outreachBroadcastWebhook.isNotEmpty;
  bool get hasMetaCredentials =>
      SupabaseService.outreachWabaId.isNotEmpty &&
      SupabaseService.outreachMetaAccessToken.isNotEmpty;
  String get outreachPhone => SupabaseService.outreachPhone;

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
      debugPrint('OUTREACH: fetching messages for contact $contactId');
      final rows = await _db
          .from('vivid_outreach_messages')
          .select()
          .eq('contact_id', contactId)
          .order('created_at', ascending: true);

      _messages = (rows as List)
          .map((r) => OutreachMessage.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('OUTREACH: loaded ${_messages.length} messages');
    } catch (e) {
      debugPrint('OUTREACH: messages error: $e');
    }

    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<String?> sendMessage(String contactId, String text) async {
    if (_selectedContact == null) return 'No contact selected';

    final contact = _selectedContact!;
    final now = DateTime.now();

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
      };

      await _db.from('vivid_outreach_messages').insert(row);
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
              'media_url': '',
              'media_type': '',
              'media_filename': '',
            }),
          );
          debugPrint('OUTREACH: message sent via webhook');
        } catch (e) {
          debugPrint('OUTREACH: webhook send error (message still saved): $e');
        }
      }

      // Refresh messages
      await fetchMessages(contactId);
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

      debugPrint('OUTREACH: loaded ${_broadcastRecipients.length} recipients for broadcast $broadcastId');
    } catch (e) {
      debugPrint('OUTREACH: recipients error: $e');
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
          headerMediaUrl: r['offer_image_url'] as String?,
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
