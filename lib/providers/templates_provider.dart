import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/supabase_service.dart';

class TemplatesProvider extends ChangeNotifier {
  List<WhatsAppTemplate> _templates = [];
  bool _isLoading = false;
  String? _error;
  bool _isSubmitting = false;

  List<WhatsAppTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSubmitting => _isSubmitting;

  static String get _baseUrl =>
      'https://graph.facebook.com/${SupabaseService.metaApiVersion}';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SupabaseService.metaAccessToken}',
        'Content-Type': 'application/json',
      };

  // ============================================
  // FETCH TEMPLATES
  // ============================================

  Future<void> fetchTemplates() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final all = <WhatsAppTemplate>[];
      String? nextUrl =
          '$_baseUrl/${SupabaseService.metaWabaId}/message_templates?limit=100&fields=id,name,status,language,category,components';

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
        // Use 'next' if available, else stop pagination
        nextUrl = (next != null && next.isNotEmpty) ? next : null;
      }

      _templates = all;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // CREATE TEMPLATE
  // ============================================

  /// Creates a new template via the Meta API.
  /// Returns null on success, or an error message string on failure.
  Future<String?> createTemplate({
    required String name,
    required String language,
    required String category,
    required List<Map<String, dynamic>> components,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final body = jsonEncode({
        'name': name,
        'language': language,
        'category': category.toUpperCase(),
        'components': components,
      });

      final response = await http.post(
        Uri.parse(
            '$_baseUrl/${SupabaseService.metaWabaId}/message_templates'),
        headers: _headers,
        body: body,
      );

      _isSubmitting = false;
      notifyListeners();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // success
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      return err?['message'] ?? 'Failed to create template (${response.statusCode})';
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      return e.toString();
    }
  }

  // ============================================
  // DELETE TEMPLATE
  // ============================================

  /// Deletes a template by name. Returns null on success, error string on failure.
  Future<String?> deleteTemplate(String name) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '$_baseUrl/${SupabaseService.metaWabaId}/message_templates?name=$name',
      );
      final response = await http.delete(uri, headers: _headers);

      _isSubmitting = false;

      if (response.statusCode == 200) {
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
  // UPLOAD IMAGE (resumable upload)
  // ============================================

  /// Uploads image bytes to Meta and returns a media handle string,
  /// or null if the upload fails. [error] is set on failure.
  Future<String?> uploadImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      // Step 1: Start upload session
      final initResponse = await http.post(
        Uri.parse(
          'https://graph.facebook.com/${SupabaseService.metaApiVersion}/${SupabaseService.metaAppId}/uploads'
          '?file_type=$mimeType&file_length=${imageBytes.length}',
        ),
        headers: {'Authorization': 'Bearer ${SupabaseService.metaAccessToken}'},
      );

      if (initResponse.statusCode != 200) {
        _isSubmitting = false;
        notifyListeners();
        return null;
      }

      final initBody =
          jsonDecode(initResponse.body) as Map<String, dynamic>;
      final uploadId = initBody['id'] as String?;
      if (uploadId == null) {
        _isSubmitting = false;
        notifyListeners();
        return null;
      }

      // Step 2: Upload the bytes
      final uploadResponse = await http.post(
        Uri.parse(
            'https://graph.facebook.com/${SupabaseService.metaApiVersion}/$uploadId'),
        headers: {
          'Authorization': 'OAuth ${SupabaseService.metaAccessToken}',
          'file_offset': '0',
          'Content-Type': mimeType,
        },
        body: imageBytes,
      );

      _isSubmitting = false;
      notifyListeners();

      if (uploadResponse.statusCode != 200) return null;

      final uploadBody =
          jsonDecode(uploadResponse.body) as Map<String, dynamic>;
      return uploadBody['h'] as String?;
    } catch (e) {
      _isSubmitting = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}

