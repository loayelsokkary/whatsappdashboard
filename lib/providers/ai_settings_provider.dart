import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// AI Settings for a customer
class AiChatSetting {
  final String id;
  final String aiPhone;
  final String customerPhone;
  final bool aiEnabled;
  final String? lastChangedBy;
  final DateTime? updatedAt;

  AiChatSetting({
    required this.id,
    required this.aiPhone,
    required this.customerPhone,
    required this.aiEnabled,
    this.lastChangedBy,
    this.updatedAt,
  });

  factory AiChatSetting.fromJson(Map<String, dynamic> json) {
    return AiChatSetting(
      id: json['id'] as String,
      aiPhone: json['ai_phone'] as String,
      customerPhone: json['customer_phone'] as String,
      aiEnabled: json['ai_enabled'] as bool? ?? true,
      lastChangedBy: json['last_changed_by'] as String?,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
}

/// Provider for AI chat settings
class AiSettingsProvider extends ChangeNotifier {
  final Map<String, AiChatSetting> _settings = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  SupabaseClient get _client => Supabase.instance.client;

  /// Get AI enabled status for a customer
  bool isAiEnabled(String customerPhone) {
    final setting = _settings[customerPhone];
    // Default to true if no setting exists
    return setting?.aiEnabled ?? true;
  }

  /// Get setting for a customer
  AiChatSetting? getSetting(String customerPhone) {
    return _settings[customerPhone];
  }

  /// Fetch all AI settings for this business
  Future<void> fetchAllSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _client
          .from('ai_chat_settings')
          .select()
          .eq('ai_phone', BusinessConfig.businessPhone);

      _settings.clear();
      for (final json in response as List) {
        final setting = AiChatSetting.fromJson(json);
        _settings[setting.customerPhone] = setting;
      }

      print('Loaded ${_settings.length} AI settings');
    } catch (e) {
      _error = 'Failed to load settings: $e';
      print('AI settings error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch setting for a specific customer
  Future<AiChatSetting?> fetchSetting(String customerPhone) async {
    try {
      final response = await _client
          .from('ai_chat_settings')
          .select()
          .eq('ai_phone', BusinessConfig.businessPhone)
          .eq('customer_phone', customerPhone)
          .maybeSingle();

      if (response != null) {
        final setting = AiChatSetting.fromJson(response);
        _settings[customerPhone] = setting;
        notifyListeners();
        return setting;
      }
      return null;
    } catch (e) {
      print('Error fetching setting: $e');
      return null;
    }
  }

  /// Toggle AI for a customer
  Future<bool> toggleAi(String customerPhone, bool enabled) async {
    try {
      final existingSetting = _settings[customerPhone];

      if (existingSetting != null) {
        // Update existing
        await _client
            .from('ai_chat_settings')
            .update({
              'ai_enabled': enabled,
              'last_changed_by': 'manager',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingSetting.id);
      } else {
        // Create new
        await _client.from('ai_chat_settings').insert({
          'ai_phone': BusinessConfig.businessPhone,
          'customer_phone': customerPhone,
          'ai_enabled': enabled,
          'last_changed_by': 'manager',
        });
      }

      // Update local cache
      await fetchSetting(customerPhone);

      print('AI ${enabled ? 'enabled' : 'disabled'} for $customerPhone');
      return true;
    } catch (e) {
      _error = 'Failed to update setting: $e';
      print('Toggle AI error: $e');
      notifyListeners();
      return false;
    }
  }
}