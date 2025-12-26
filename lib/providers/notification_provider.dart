import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Notification for manager
class ManagerNotification {
  final String id;
  final String customerPhone;
  final String? customerName;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  ManagerNotification({
    required this.id,
    required this.customerPhone,
    this.customerName,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  String get displayName => customerName ?? customerPhone;
}

/// Provider for notifications when AI is disabled and customer needs help
class NotificationProvider extends ChangeNotifier {
  final List<ManagerNotification> _notifications = [];
  int _unreadCount = 0;
  bool _soundEnabled = true;
  bool _browserNotificationsEnabled = false;

  RealtimeChannel? _channel;

  List<ManagerNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get soundEnabled => _soundEnabled;
  bool get browserNotificationsEnabled => _browserNotificationsEnabled;

  SupabaseClient get _client => Supabase.instance.client;

  /// Initialize and request permissions
  Future<void> initialize() async {
    // Request browser notification permission
    if (kIsWeb) {
      try {
        final permission = await html.Notification.requestPermission();
        _browserNotificationsEnabled = permission == 'granted';
        print('Browser notifications: $_browserNotificationsEnabled');
      } catch (e) {
        print('Notification permission error: $e');
      }
    }

    // Subscribe to real-time messages
    _subscribeToMessages();
  }

  /// Subscribe to new messages where AI is disabled
  void _subscribeToMessages() {
    _channel?.unsubscribe();

    _channel = _client
        .channel('notifications_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final newMessage = payload.newRecord;
            final aiPhone = newMessage['ai_phone'] as String?;
            final customerPhone = newMessage['customer_phone'] as String?;

            // Only process messages for our business
            if (aiPhone != ClientConfig.businessPhone) return;
            if (customerPhone == null) return;

            // Check if AI is disabled for this customer
            final isAiDisabled = await _checkAiDisabled(customerPhone);

            if (isAiDisabled) {
              // Create notification
              final notification = ManagerNotification(
                id: newMessage['id'] as String,
                customerPhone: customerPhone,
                customerName: newMessage['customer_name'] as String?,
                message: newMessage['customer_message'] as String? ?? '',
                createdAt: DateTime.now(),
              );

              _addNotification(notification);
            }
          },
        )
        .subscribe();

    print('Subscribed to notification channel');
  }

  /// Check if AI is disabled for customer
  Future<bool> _checkAiDisabled(String customerPhone) async {
    try {
      final response = await _client
          .from('ai_chat_settings')
          .select('ai_enabled')
          .eq('ai_phone', ClientConfig.businessPhone)
          .eq('customer_phone', customerPhone)
          .maybeSingle();

      if (response == null) {
        // No setting = AI enabled by default
        return false;
      }

      return !(response['ai_enabled'] as bool? ?? true);
    } catch (e) {
      print('Check AI disabled error: $e');
      return false;
    }
  }

  /// Add notification and trigger alerts
  void _addNotification(ManagerNotification notification) {
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();

    // Play sound
    if (_soundEnabled) {
      _playNotificationSound();
    }

    // Show browser notification
    if (_browserNotificationsEnabled && kIsWeb) {
      _showBrowserNotification(notification);
    }
  }

  /// Play notification sound
  void _playNotificationSound() {
    if (kIsWeb) {
      try {
        // Use simple audio element for web
        final audio = html.AudioElement();
        audio.src = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdH2JkI2Coverage';
        audio.volume = 0.3;
        audio.play();
      } catch (e) {
        print('Sound error: $e');
      }
    }
  }

  /// Show browser notification
  void _showBrowserNotification(ManagerNotification notification) {
    if (kIsWeb) {
      try {
        html.Notification(
          'Customer Needs Help',
          body: '${notification.displayName}: ${notification.message}',
          icon: '/icons/Icon-192.png',
        );
      } catch (e) {
        print('Browser notification error: $e');
      }
    }
  }

  /// Mark notification as read
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = ManagerNotification(
        id: _notifications[index].id,
        customerPhone: _notifications[index].customerPhone,
        customerName: _notifications[index].customerName,
        message: _notifications[index].message,
        createdAt: _notifications[index].createdAt,
        isRead: true,
      );
      _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length);
      notifyListeners();
    }
  }

  /// Mark all as read
  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = ManagerNotification(
          id: _notifications[i].id,
          customerPhone: _notifications[i].customerPhone,
          customerName: _notifications[i].customerName,
          message: _notifications[i].message,
          createdAt: _notifications[i].createdAt,
          isRead: true,
        );
      }
    }
    _unreadCount = 0;
    notifyListeners();
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  /// Toggle sound
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  /// Dispose
  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}