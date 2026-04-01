import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class TemplatesProvider extends ChangeNotifier {
  List<WhatsAppTemplate> _templates = [];
  bool _isLoading = false;
  String? _error;
  bool _isSubmitting = false;
  bool _isSyncing = false;
  Map<String, Map<String, dynamic>> _templateDbStatuses = {};

  // MEDIUM #4 — Global mutex: prevents concurrent syncs across instances/tabs
  static bool _globalSyncLock = false;

  // LOW #9 — Tracks last successful Meta API fetch to guard against stale cleanup
  DateTime? _lastSuccessfulFetchTime;

  List<WhatsAppTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSubmitting => _isSubmitting;
  bool get isSyncing => _isSyncing;
  Map<String, Map<String, dynamic>> get templateDbStatuses => _templateDbStatuses;

  static String get _baseUrl =>
      'https://graph.facebook.com/${SupabaseService.metaApiVersion}';

  /// Returns the WABA ID for the current client directly from ClientConfig.
  /// Never falls back to the global SupabaseService.metaWabaId — a wrong WABA
  /// means templates from another account get written into this client's table.
  String get _clientWabaId {
    final clientWaba = ClientConfig.currentClient?.wabaId;
    if (clientWaba == null || clientWaba.isEmpty) {
      debugPrint('[templates] ERROR: No WABA ID for client "${ClientConfig.currentClient?.name}" — operation will be aborted');
      return '';
    }
    return clientWaba;
  }

  /// Returns the access token for the current client.
  /// Falls back to the global token only for the token (one Vivid app token
  /// works across all WABAs) — but WABA ID must always be per-client.
  String get _clientAccessToken {
    final clientToken = ClientConfig.currentClient?.metaAccessToken;
    return (clientToken != null && clientToken.isNotEmpty)
        ? clientToken
        : SupabaseService.metaAccessToken;
  }

  /// Normalize a client slug into a safe prefix for Meta template names.
  /// Only lowercase letters and digits; everything else becomes underscore.
  static String normalizeSlug(String slug) =>
      slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_clientAccessToken',
        'Content-Type': 'application/json',
      };

  // ============================================
  // FETCH TEMPLATES (from per-client Supabase table)
  // ============================================

  /// All templates from Meta API (unfiltered). Used for sync operations only.
  List<WhatsAppTemplate> get allMetaTemplates => _allMetaTemplates;
  List<WhatsAppTemplate> _allMetaTemplates = [];

  /// Fetches templates from the per-client Supabase table.
  /// This is the DISPLAY path — only shows templates synced to this client.
  Future<void> fetchTemplates() async {
    final table = ClientConfig.templatesTable;
    if (table == null || table.isEmpty) {
      _templates = [];
      _error = 'Templates table not configured';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('TEMPLATES: loading from Supabase table: $table');
      final clientId = ClientConfig.currentClient?.id ?? '';
      final rows = await SupabaseService.adminClient
          .from(table)
          .select()
          .eq('client_id', clientId);

      _templates = (rows as List).map((r) {
        final buttonsRaw = r['buttons'] as List<dynamic>? ?? [];
        final buttons = buttonsRaw.map((b) {
          final m = b as Map<String, dynamic>;
          return TemplateButton(type: m['type'] as String? ?? '', text: m['text'] as String? ?? '');
        }).toList();

        return WhatsAppTemplate(
          id: r['meta_template_id'] as String? ?? '',
          name: r['template_name'] as String? ?? '',
          displayName: r['display_name'] as String?,
          status: r['status'] as String? ?? '',
          language: r['language_code'] as String? ?? '',
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

      // Also populate DB statuses map for validation dots
      _templateDbStatuses = {
        for (final r in rows)
          (r['meta_template_id'] as String? ?? ''): r,
      };

      print('TEMPLATES: loaded ${_templates.length} templates from $table');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('TEMPLATES: error fetching from $table: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches ALL templates from Meta API for the current client's WABA.
  /// Used only by sync operations — NOT for display.
  Future<void> fetchMetaTemplates() async {
    final wabaId = _clientWabaId;
    if (wabaId.isEmpty) {
      _error = 'No WABA ID configured for this client — cannot fetch templates';
      notifyListeners();
      return;
    }
    try {
      final all = <WhatsAppTemplate>[];
      debugPrint('📋 Fetching templates for WABA: $wabaId');
      String? nextUrl =
          '$_baseUrl/$wabaId/message_templates?limit=100&fields=id,name,status,language,category,components';

      while (nextUrl != null) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: _headers,
        );

        if (response.statusCode != 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final err = body['error'] as Map<String, dynamic>?;
          throw Exception(err?['message'] ?? 'HTTP ${response.statusCode}');
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        for (final item in data) {
          all.add(WhatsAppTemplate.fromJson(item as Map<String, dynamic>));
        }

        final paging = body['paging'] as Map<String, dynamic>?;
        final next = paging?['next'] as String?;
        nextUrl = (next != null && next.isNotEmpty) ? next : null;
      }

      debugPrint('📋 Templates received: ${all.length} from WABA $wabaId');
      _allMetaTemplates = all;
      if (all.isNotEmpty) _lastSuccessfulFetchTime = DateTime.now();
      print('TEMPLATES: fetched ${all.length} templates from Meta API');
    } catch (e) {
      print('TEMPLATES: Meta API error: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================
  // CREATE TEMPLATE
  // ============================================

  /// Creates a new template via the Meta API.
  /// Returns `(error: null, templateId: '<id>')` on success,
  /// or `(error: '<message>', templateId: null)` on failure.
  Future<({String? error, String? templateId})> createTemplate({
    required String name,
    required String language,
    required String category,
    required List<Map<String, dynamic>> components,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final payload = {
        'name': name,
        'language': language,
        'category': category.toUpperCase(),
        'components': components,
      };
      final body = jsonEncode(payload);

      final wabaId = _clientWabaId;
      if (wabaId.isEmpty) {
        _isSubmitting = false;
        notifyListeners();
        return (error: 'No WABA ID configured for this client', templateId: null);
      }
      debugPrint('[createTemplate] POST $_baseUrl/$wabaId/message_templates');
      debugPrint('[createTemplate] Payload: ${const JsonEncoder.withIndent('  ').convert(payload)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/$wabaId/message_templates'),
        headers: _headers,
        body: body,
      );

      debugPrint('[createTemplate] Response: ${response.statusCode} — ${response.body}');

      _isSubmitting = false;
      notifyListeners();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final templateId = decoded['id'] as String?;
        debugPrint('[createTemplate] SUCCESS — templateId: $templateId');
        return (error: null, templateId: templateId);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      final msg = (err?['message'] as String?) ?? 'Failed to create template (${response.statusCode})';
      return (error: msg, templateId: null);
    } catch (e, st) {
      debugPrint('[createTemplate] EXCEPTION: $e\n$st');
      _isSubmitting = false;
      notifyListeners();
      return (error: e.toString(), templateId: null);
    }
  }

  // ============================================
  // DELETE TEMPLATE
  // ============================================

  /// Deletes a template by name via the WABA endpoint.
  /// Returns null on success, error string on failure.
  Future<String?> deleteTemplate(String name, String id) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final wabaId = _clientWabaId;
      if (wabaId.isEmpty) {
        _isSubmitting = false;
        notifyListeners();
        return 'No WABA ID configured for this client';
      }
      final uri = Uri.parse(
        '$_baseUrl/$wabaId/message_templates?name=$name',
      );
      debugPrint('[TemplatesProvider] DELETE $uri');

      final response = await http.delete(uri, headers: _headers);
      debugPrint('[TemplatesProvider] Status: ${response.statusCode} Body: ${response.body}');

      _isSubmitting = false;

      if (response.statusCode == 200) {
        // Remove from per-client Supabase table
        final table = ClientConfig.templatesTable;
        if (table != null && table.isNotEmpty) {
          try {
            await SupabaseService.adminClient
                .from(table)
                .delete()
                .eq('template_name', name);
          } catch (e) {
            debugPrint('[deleteTemplate] Supabase cleanup error: $e');
          }
        }
        _templates.removeWhere((t) => t.name == name);
        notifyListeners();
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      notifyListeners();
      return err?['message'] ?? 'Failed to delete (${response.statusCode})';
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return e.toString();
    }
  }

  // ============================================
  // AUTO-LABEL HELPERS
  // ============================================

  static const _defaultLabels = [
    'customer_name',
    'service',
    'price',
    'date',
  ];

  /// Returns auto-generated label names for [count] body variables.
  /// Falls back to `param_N` for variables beyond the defaults list.
  static List<String> _autoLabels(int count) => List.generate(
        count,
        (i) => i < _defaultLabels.length ? _defaultLabels[i] : 'param_${i + 1}',
      );

  /// Context-aware label detection. Looks at the ~50 chars before each
  /// {{n}} placeholder to guess the most likely label.
  static List<String> _smartLabels(String bodyText, int varCount) {
    final labels = <String>[];
    for (int i = 1; i <= varCount; i++) {
      final placeholder = '{{$i}}';
      final idx = bodyText.indexOf(placeholder);
      if (idx == -1) {
        labels.add('variable_$i');
        continue;
      }
      final contextStart = (idx - 50).clamp(0, bodyText.length);
      final ctx = bodyText.substring(contextStart, idx).toLowerCase();

      if (i == 1 &&
          (ctx.contains('hi ') ||
              ctx.contains('hello') ||
              ctx.contains('dear') ||
              ctx.contains('مرحبا') ||
              ctx.contains('هلا') ||
              ctx.contains('أهلاً') ||
              ctx.isEmpty)) {
        labels.add('customer_name');
      } else if (ctx.contains('bhd') ||
          ctx.contains('price') ||
          ctx.contains('offer') ||
          ctx.contains('discount') ||
          ctx.contains('دينار') ||
          ctx.contains('cost') ||
          ctx.contains('amount')) {
        labels.add('price');
      } else if (ctx.contains('service') ||
          ctx.contains('treatment') ||
          ctx.contains('procedure') ||
          ctx.contains('خدمة')) {
        labels.add('service');
      } else if (ctx.contains('branch') ||
          ctx.contains('location') ||
          ctx.contains('فرع') ||
          ctx.contains('address')) {
        labels.add('branch');
      } else if (ctx.contains('dr ') ||
          ctx.contains('doctor') ||
          ctx.contains('provider') ||
          ctx.contains('دكتور') ||
          ctx.contains('specialist')) {
        labels.add('provider');
      } else if (ctx.contains('date') ||
          ctx.contains('time') ||
          ctx.contains('when') ||
          ctx.contains('تاريخ') ||
          ctx.contains('appointment') ||
          ctx.contains('scheduled')) {
        labels.add('date');
      } else if (i <= _defaultLabels.length) {
        labels.add(_defaultLabels[i - 1]);
      } else {
        labels.add('variable_$i');
      }
    }
    return labels;
  }

  /// Returns auto-generated source strings matching the given label list.
  /// `customer_name` → `customer_data`; everything else → `ai_extracted`.
  static List<String> _autoSources(List<String> labels) => labels
      .map((l) => l == 'customer_name' ? 'customer_data' : 'ai_extracted')
      .toList();

  // ============================================
  // FETCH TEMPLATE DB STATUSES
  // ============================================

  /// No-op — fetchTemplates() now populates _templateDbStatuses directly.
  /// Kept for backward compatibility with callers.
  Future<void> fetchTemplateDbStatuses(String clientId) async {
    // DB statuses are now loaded as part of fetchTemplates().
  }

  // ============================================
  // SYNC TO SUPABASE
  // ============================================

  /// Fetches all templates from Meta API, then upserts them into the
  /// per-client Supabase table. Returns null on success, error string on failure.
  Future<String?> syncTemplatesToSupabase() async {
    // MEDIUM #4 — Global mutex
    if (_globalSyncLock) {
      debugPrint('[sync] Another sync is already running globally — skipping');
      return 'Sync already in progress';
    }
    _globalSyncLock = true;

    final clientId = ClientConfig.currentClient?.id ?? '';
    if (clientId.isEmpty) {
      _globalSyncLock = false;
      return 'No client selected';
    }

    final tableName = ClientConfig.templatesTable;
    if (tableName == null || tableName.isEmpty) {
      _globalSyncLock = false;
      return 'Templates table not configured';
    }

    _isSyncing = true;
    notifyListeners();

    try {
      // Step 1: Fetch fresh templates from Meta API
      await fetchMetaTemplates();
      // LOW #9 — Stale cache guard: if Meta returned empty but we've had
      // a successful fetch before, abort rather than triggering a stale cleanup.
      if (_allMetaTemplates.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        if (_lastSuccessfulFetchTime != null) {
          debugPrint('[sync] Meta fetch returned empty but prior fetch succeeded — aborting to protect existing data');
          return 'Meta API returned no templates. Sync aborted to protect existing data.';
        }
        return 'No templates found in Meta API';
      }

      final now = DateTime.now().toIso8601String();

      // MEDIUM #6 — Safety: verify client hasn't changed mid-async gap
      if (clientId != ClientConfig.currentClient?.id) {
        debugPrint('[sync] SAFETY ABORT: clientId mismatch — refusing to write (expected $clientId, got ${ClientConfig.currentClient?.id})');
        _isSyncing = false;
        notifyListeners();
        return 'Safety abort: client context changed during sync';
      }

      // ROOT CAUSE 5 — Validation gate: warn if Meta returned templates that look like
      // they belong to a different client, which would indicate a WABA mismatch.
      // This should not happen after Root Cause 1 fix (we now read WABA from ClientConfig
      // directly), but log a loud warning if it ever does.
      if (ClientConfig.currentClient?.isSharedWaba != true) {
        final slug = ClientConfig.currentClient?.slug ?? '';
        final expectedPrefix = slug.isNotEmpty ? '${normalizeSlug(slug)}_' : '';
        int suspiciousCount = 0;
        for (final t in _allMetaTemplates) {
          final name = t.name.toLowerCase();
          if (expectedPrefix.isNotEmpty && !name.startsWith(expectedPrefix) && name != 'hello_world') {
            suspiciousCount++;
            debugPrint('[sync] ⚠️ WABA MISMATCH WARNING: Template "${t.name}" does not start with expected prefix "$expectedPrefix" — possible wrong WABA!');
          }
        }
        if (suspiciousCount > 0) {
          debugPrint('[sync] ⚠️ $suspiciousCount suspicious template(s) detected for ${ClientConfig.currentClient?.name} — verify WABA ID is correct in client settings');
        }
      }

      // Step 2: Apply prefix filter for shared-WABA clients to prevent cross-client contamination.
      final slug = ClientConfig.currentClient?.slug ?? '';
      final clientPrefix = slug.isNotEmpty ? '${normalizeSlug(slug)}_' : '';

      List<WhatsAppTemplate> clientTemplates = _allMetaTemplates;
      if (ClientConfig.isSharedWaba && slug.isNotEmpty) {
        clientTemplates = _allMetaTemplates.where((t) {
          final name = t.name.toLowerCase();
          return name.startsWith(clientPrefix) ||
              name == 'hello_world' ||
              name == 'vivddemo';
        }).toList();
        debugPrint('[sync] Shared WABA filter applied for "$slug": ${clientTemplates.length} of ${_allMetaTemplates.length} templates match');
      }

      if (clientTemplates.isEmpty && ClientConfig.isSharedWaba) {
        _isSyncing = false;
        _error = 'No templates found with prefix "$clientPrefix" on shared WABA. Create templates from the New Template screen first.';
        notifyListeners();
        return _error;
      }

      final displayNames = <String, String>{};
      for (final t in clientTemplates) {
        displayNames[t.name] = (clientPrefix.isNotEmpty && t.name.startsWith(clientPrefix))
            ? t.name.substring(clientPrefix.length)
            : t.name;
      }

      debugPrint('[sync] ${clientTemplates.length} templates to sync for "$slug"');

      // GATEWAY — second line of defense: skip any template that doesn't match
      // the client prefix, in case clientTemplates filtering above is ever bypassed.
      final isSharedWaba = ClientConfig.isSharedWaba;

      // Build rows sequentially, doing a per-template DB read to reliably
      // preserve human-set labels/sources/images instead of overwriting them.
      final rows = (await Future.wait(clientTemplates.map((t) async {
        if (isSharedWaba && clientPrefix.isNotEmpty) {
          final name = t.name.toLowerCase();
          if (!name.startsWith(clientPrefix) && name != 'hello_world' && name != 'vivddemo') {
            debugPrint('[sync] GATEWAY BLOCKED: "${t.name}" does not match prefix "$clientPrefix" — skipping');
            return null;
          }
        }
        // Individual read — guaranteed to return the correct row for this client+template.
        final existing = await SupabaseService.adminClient
            .from(tableName)
            .select('body_variable_labels, body_variable_sources, offer_image_url')
            .eq('template_name', t.name)
            .eq('client_id', clientId)
            .maybeSingle();

        // Preserve existing labels if non-null and non-empty, else auto-generate
        final existingLabels = existing?['body_variable_labels'];
        final hasExistingLabels = existingLabels is List && existingLabels.isNotEmpty &&
            existingLabels.any((l) => (l as String?)?.trim().isNotEmpty == true);
        final varCount = RegExp(r'\{\{\d+\}\}').allMatches(t.body).length;
        final labels = hasExistingLabels
            ? List<String>.from(existingLabels)
            : _smartLabels(t.body, varCount);

        final existingSources = existing?['body_variable_sources'];
        final hasExistingSources = existingSources is List && existingSources.isNotEmpty;
        final sources = hasExistingSources
            ? List<String>.from(existingSources)
            : _autoSources(labels);

        // Normalize header_type to lowercase for n8n compatibility
        final headerType = t.headerType.toLowerCase() == 'none'
            ? 'none'
            : t.headerType.toLowerCase();

        final existingImageUrl = existing?['offer_image_url'] as String?;
        // LOW #8 — Use exact project URL to avoid false positives on 'scontent' substring
        final isSupabaseStorageUrl = existingImageUrl != null &&
            existingImageUrl.contains('zxvjzaowvzvfgrzdimbm.supabase.co/storage/v1/object/public');
        final isExpiringCdnUrl = existingImageUrl != null && (
            existingImageUrl.contains('scontent.') ||
            existingImageUrl.contains('fbcdn.net') ||
            existingImageUrl.contains('cdninstagram.com'));
        final offerImageUrl = (isSupabaseStorageUrl && !isExpiringCdnUrl)
            ? existingImageUrl
            : null;

        return <String, dynamic>{
          'meta_template_id': t.id,
          'client_id': clientId,
          'template_name': t.name,
          'display_name': displayNames[t.name] ?? t.name,
          'language_code': t.language,
          'category': t.category,
          'status': t.status,
          'header_type': headerType,
          'header_text': t.headerText,
          // Store Meta's scontent URL for display (temporary — may expire)
          // offer_image_url holds permanent Supabase Storage URL when available
          'header_media_url': t.headerMediaUrl,
          'header_has_variable': false,
          'body_text': t.body,
          'body_variable_count': varCount,
          'body_variable_labels': labels,
          'body_variable_descriptions': labels,
          'body_variable_sources': sources,
          'buttons': t.buttons.map((b) => {'type': b.type, 'text': b.text}).toList(),
          'button_count': t.buttons.length,
          'is_active': t.status == 'APPROVED',
          'updated_at': now,
          'offer_image_url': offerImageUrl,
        };
      }))).whereType<Map<String, dynamic>>().toList();

      // Use adminClient to bypass RLS on per-client templates table writes.
      // Split into insert/update to avoid needing a unique constraint on meta_template_id.
      final existingResponse = await SupabaseService.adminClient
          .from(tableName)
          .select('meta_template_id')
          .eq('client_id', clientId);
      final existingIds = (existingResponse as List)
          .map((r) => r['meta_template_id'] as String)
          .toSet();
      final toInsert =
          rows.where((r) => !existingIds.contains(r['meta_template_id'])).toList();
      final toUpdate =
          rows.where((r) => existingIds.contains(r['meta_template_id'])).toList();
      if (toInsert.isNotEmpty) {
        await SupabaseService.adminClient.from(tableName).upsert(
          toInsert,
          onConflict: 'client_id,template_name,language_code',
        );
      }
      for (final row in toUpdate) {
        await SupabaseService.adminClient
            .from(tableName)
            .update(row)
            .eq('client_id', clientId)
            .eq('meta_template_id', row['meta_template_id'] as String);
      }

      // Clean up stale rows — templates deleted from Meta but still in DB
      final validIds = rows.map((r) => r['meta_template_id'] as String).toSet();
      final dbRows = await SupabaseService.adminClient
          .from(tableName)
          .select('meta_template_id')
          .eq('client_id', clientId);
      final staleIds = (dbRows as List)
          .map((r) => r['meta_template_id'] as String)
          .where((id) => !validIds.contains(id))
          .toList();
      if (staleIds.isNotEmpty) {
        await SupabaseService.adminClient
            .from(tableName)
            .delete()
            .eq('client_id', clientId)
            .inFilter('meta_template_id', staleIds);
        debugPrint('[sync] Removed ${staleIds.length} stale template(s) from $tableName');
      }

      _isSyncing = false;
      // Refresh display from DB so newly synced templates appear
      await fetchTemplates();
      return null;
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      return e.toString();
    } finally {
      // MEDIUM #4 — Always release the global mutex
      _globalSyncLock = false;
    }
  }

  // ============================================
  // SYNC SINGLE TEMPLATE (with full AI metadata)
  // ============================================

  /// Upserts one template into `whatsapp_templates` with all AI fields populated.
  /// [targetServices] is either the string `'all'` or a `List<String>`.
  /// Returns null on success, error string on failure.
  Future<String?> syncSingleTemplate(
    WhatsAppTemplate t, {
    required dynamic targetServices,
    required List<String> variableLabels,
    required List<String> variableSources,
    String? offerImageUrl,
    String? displayName,
  }) async {
    final clientId = ClientConfig.currentClient?.id ?? '';
    if (clientId.isEmpty) return 'No client selected';

    final tableName = ClientConfig.templatesTable;
    if (tableName == null || tableName.isEmpty) return 'Templates table not configured';

    try {
      final varCount = RegExp(r'\{\{\d+\}\}').allMatches(t.body).length;
      final now = DateTime.now().toIso8601String();

      // Fall back to auto-generated labels/sources if caller provided empty arrays
      final hasLabels = variableLabels.any((l) => l.trim().isNotEmpty);
      final effectiveLabels = hasLabels ? variableLabels : _autoLabels(varCount);
      final hasSources = variableSources.any((s) => s.trim().isNotEmpty);
      final effectiveSources = hasSources ? variableSources : _autoSources(effectiveLabels);

      final row = <String, dynamic>{
        'meta_template_id': t.id,
        'client_id': clientId,
        'template_name': t.name,
        'display_name': displayName ?? t.name,
        'language_code': t.language,
        'category': t.category,
        'status': t.status,
        'header_type': t.headerType.toLowerCase(),
        'header_text': t.headerText,
        // Store Meta's scontent URL for display (temporary — may expire)
        // offer_image_url holds permanent Supabase Storage URL when available
        'header_media_url': t.headerMediaUrl,
        'header_has_variable': false,
        'body_text': t.body,
        'body_variable_count': varCount,
        'body_variable_labels': effectiveLabels,
        'body_variable_descriptions': effectiveLabels,
        'body_variable_sources': effectiveSources,
        'buttons': t.buttons.map((b) => {'type': b.type, 'text': b.text}).toList(),
        'button_count': t.buttons.length,
        'is_active': t.status == 'APPROVED',
        'target_services': targetServices,
        'updated_at': now,
      };
      // Resolve offer_image_url: prefer existing Storage URL, otherwise
      // download from Meta scontent and re-upload to Storage.
      // Always include offer_image_url — null explicitly clears stale scontent URLs
      row['offer_image_url'] = await _resolveOfferImageUrl(t,
          callerProvidedUrl: offerImageUrl);

      debugPrint('[syncSingleTemplate] Upserting ${t.name} (display: ${displayName ?? t.name}, offer_image_url: ${row['offer_image_url'] ?? 'omitted'})');
      // Use adminClient to bypass RLS on per-client templates table writes.
      // Check existence first to avoid needing a unique constraint on meta_template_id.
      // Scope by client_id to prevent 406 when the same meta_template_id appears in multiple clients' tables.
      final existingRow = await SupabaseService.adminClient
          .from(tableName)
          .select('id')
          .eq('meta_template_id', t.id)
          .eq('client_id', clientId)
          .maybeSingle();
      if (existingRow != null) {
        await SupabaseService.adminClient
            .from(tableName)
            .update(row)
            .eq('meta_template_id', t.id)
            .eq('client_id', clientId);
      } else {
        await SupabaseService.adminClient.from(tableName).insert(row);
      }

      debugPrint('[syncSingleTemplate] Done');
      return null;
    } catch (e, st) {
      debugPrint('[syncSingleTemplate] EXCEPTION: $e\n$st');
      return e.toString();
    }
  }

  // ============================================
  // RESOLVE OFFER IMAGE URL
  // ============================================

  /// Returns the correct `offer_image_url` value for a template:
  /// 1. Caller-provided Storage URL takes priority (fresh upload — DB row may not exist yet)
  /// 2. Existing DB Storage URL (preserve across syncs)
  /// 3. Otherwise null (caller must write null to clear stale scontent)
  Future<String?> _resolveOfferImageUrl(
    WhatsAppTemplate t, {
    String? callerProvidedUrl,
  }) async {
    // Step 1: caller provided a fresh Storage URL — trust it unconditionally
    if (callerProvidedUrl != null &&
        callerProvidedUrl.contains('supabase.co/storage')) {
      debugPrint('[resolveOfferImageUrl] ${t.name}: using caller-provided Storage URL');
      return callerProvidedUrl;
    }

    // Step 2: check existing DB value — filter by template_name + client_id + language
    // Must include client_id to avoid 406 when same template name exists across clients.
    final tableName = ClientConfig.templatesTable;
    if (tableName == null || tableName.isEmpty) return null;
    final clientId = ClientConfig.currentClient?.id ?? '';
    try {
      final existing = await SupabaseService.adminClient
          .from(tableName)
          .select('offer_image_url')
          .eq('template_name', t.name)
          .eq('client_id', clientId)
          .eq('language_code', t.language)
          .maybeSingle();
      final existingUrl = existing?['offer_image_url'] as String?;
      if (existingUrl != null && existingUrl.contains('supabase.co/storage')) {
        debugPrint('[resolveOfferImageUrl] ${t.name}: keeping existing Storage URL');
        return existingUrl;
      }
    } catch (e) {
      debugPrint('[resolveOfferImageUrl] ${t.name}: DB read failed: $e');
    }

    // No Storage URL available
    return null;
  }

  // ============================================
  // UPLOAD OFFER IMAGE TO SUPABASE STORAGE
  // ============================================

  /// Uploads image bytes to Supabase Storage and returns the permanent public URL.
  /// Throws a descriptive [Exception] on failure — never returns null.
  Future<String> uploadOfferImageToStorage(
    Uint8List imageBytes,
    String templateName,
    String mimeType,
  ) async {
    if (imageBytes.isEmpty) {
      throw Exception('Image bytes are empty');
    }

    // Sanitize to a Storage-safe filename: lowercase, spaces→underscores,
    // strip anything except alphanumeric / underscore / hyphen / dot.
    final safeName = templateName
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
    if (safeName.isEmpty) {
      throw Exception('Template name is invalid for storage upload');
    }

    final path = '$safeName.jpeg';
    debugPrint('[uploadOfferImage] Uploading ${imageBytes.length} bytes → Template-images/$path');

    try {
      // Use adminClient (service role) to bypass RLS — internal dashboard only.
      await SupabaseService.adminClient.storage
          .from('Template-images')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } on StorageException catch (e) {
      debugPrint('[uploadOfferImage] StorageException: ${e.message} (status: ${e.statusCode})');
      throw Exception('Storage upload failed: ${e.message}');
    } catch (e, st) {
      debugPrint('[uploadOfferImage] EXCEPTION: $e\n$st');
      throw Exception('Storage upload failed: $e');
    }

    // Public URL uses the regular client — no auth needed to read public objects.
    final url = SupabaseService.client.storage
        .from('Template-images')
        .getPublicUrl(path);

    debugPrint('[uploadOfferImage] Public URL: $url');
    return url;
  }

  // ============================================
  // UPLOAD IMAGE (resumable upload)
  // ============================================

  /// Uploads image bytes to Meta and returns a media handle string,
  /// or null if the upload fails. [error] is set on failure.
  Future<String?> uploadImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    // Guard: metaAppId must be set
    if (SupabaseService.metaAppId.isEmpty) {
      debugPrint('[uploadImage] ERROR: metaAppId is empty — set SupabaseService.metaAppId to your Meta App ID');
      _isSubmitting = false;
      _error = 'Meta App ID is not configured';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      // Step 1: Start upload session
      final initUrl = 'https://graph.facebook.com/${SupabaseService.metaApiVersion}/${SupabaseService.metaAppId}/uploads'
          '?file_type=$mimeType&file_length=${imageBytes.length}';
      debugPrint('[uploadImage] Step 1 — POST $initUrl');

      final initResponse = await http.post(
        Uri.parse(initUrl),
        headers: {'Authorization': 'Bearer $_clientAccessToken'},
      );

      debugPrint('[uploadImage] Step 1 response: ${initResponse.statusCode} — ${initResponse.body}');

      if (initResponse.statusCode != 200) {
        _isSubmitting = false;
        notifyListeners();
        return null;
      }

      final initBody = jsonDecode(initResponse.body) as Map<String, dynamic>;
      final uploadId = initBody['id'] as String?;
      if (uploadId == null) {
        debugPrint('[uploadImage] ERROR: no upload session id in response: ${initResponse.body}');
        _isSubmitting = false;
        notifyListeners();
        return null;
      }

      final sessionUrl =
          'https://graph.facebook.com/${SupabaseService.metaApiVersion}/$uploadId';
      debugPrint('[uploadImage] Step 2 — uploading ${imageBytes.length} bytes to session $uploadId');

      String? handle;

      if (kIsWeb) {
        // On web, direct upload is blocked by CORS — proxy through Supabase Edge Function
        debugPrint('[uploadImage] Web detected — routing Step 2 through Edge Function');
        final fileBase64 = base64Encode(imageBytes);
        final fnResponse = await SupabaseService.client.functions.invoke(
          'proxy-meta-upload',
          body: {
            'sessionUrl': sessionUrl,
            'fileBase64': fileBase64,
            'mimeType': mimeType,
            'accessToken': _clientAccessToken,
          },
        );
        debugPrint('[uploadImage] Edge Function response: ${fnResponse.data}');
        handle = (fnResponse.data as Map<String, dynamic>?)?['handle'] as String?;
        if (handle == null) {
          final err = (fnResponse.data as Map<String, dynamic>?)?['error'];
          debugPrint('[uploadImage] ERROR from Edge Function: $err');
        }
      } else {
        // Native platforms — direct upload works fine
        final uploadResponse = await http.post(
          Uri.parse(sessionUrl),
          headers: {
            'Authorization': 'OAuth ${SupabaseService.metaAccessToken}',
            'file_offset': '0',
            'Content-Type': mimeType,
          },
          body: imageBytes,
        );
        debugPrint('[uploadImage] Step 2 response: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        if (uploadResponse.statusCode == 200) {
          final uploadBody = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
          handle = uploadBody['h'] as String?;
        }
      }

      _isSubmitting = false;
      notifyListeners();

      if (handle == null) {
        debugPrint('[uploadImage] ERROR: no handle returned');
      } else {
        debugPrint('[uploadImage] SUCCESS — handle: $handle');
      }
      return handle;
    } catch (e, st) {
      debugPrint('[uploadImage] EXCEPTION: $e\n$st');
      _isSubmitting = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}

