import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vivid company-wide analytics (for admin dashboard)
class VividCompanyAnalytics {
  final int totalClients;
  final int totalMessages;
  final int totalBroadcasts;
  final int totalRecipientsReached;
  final double overallAutomationRate;
  final int totalAiMessages;
  final int totalManagerMessages;
  final int totalUniqueCustomers;
  final DateTime? lastActivityAcrossAll;
  final List<ClientActivity> mostActiveClients;
  final Map<String, int> messagesByDay; // Last 7 days

  const VividCompanyAnalytics({
    required this.totalClients,
    required this.totalMessages,
    required this.totalBroadcasts,
    required this.totalRecipientsReached,
    required this.overallAutomationRate,
    required this.totalAiMessages,
    required this.totalManagerMessages,
    required this.totalUniqueCustomers,
    this.lastActivityAcrossAll,
    required this.mostActiveClients,
    required this.messagesByDay,
  });
}

/// Activity summary for a single client
class ClientActivity {
  final String clientId;
  final String clientName;
  final int messageCount;
  final int broadcastCount;
  final DateTime? lastActivity;

  const ClientActivity({
    required this.clientId,
    required this.clientName,
    required this.messageCount,
    required this.broadcastCount,
    this.lastActivity,
  });
}

/// Analytics data for conversation-based clients (like 3B's)
class ConversationClientAnalytics {
  final int totalAiMessages;
  final int totalManagerMessages;
  final double automationRate; // AI / (AI + Manager) × 100
  final Duration avgResponseTime;
  final int successfulBookings;
  final DateTime? lastActivity;
  // Universal metrics
  final int daysSinceOnboarding;
  final int uniqueCustomers;
  final int totalConversations;

  const ConversationClientAnalytics({
    required this.totalAiMessages,
    required this.totalManagerMessages,
    required this.automationRate,
    required this.avgResponseTime,
    required this.successfulBookings,
    this.lastActivity,
    required this.daysSinceOnboarding,
    required this.uniqueCustomers,
    required this.totalConversations,
  });
}

/// Analytics data for broadcast-based clients (like Karisma)
class BroadcastClientAnalytics {
  final int totalBroadcastsSent;
  final int totalRecipientsReached;
  final double deliveryRate;
  final double readRate;
  final double failedRate;
  final DateTime? lastActivity;
  // Universal metrics
  final int daysSinceOnboarding;
  final double avgCampaignSize;

  const BroadcastClientAnalytics({
    required this.totalBroadcastsSent,
    required this.totalRecipientsReached,
    required this.deliveryRate,
    required this.readRate,
    required this.failedRate,
    this.lastActivity,
    required this.daysSinceOnboarding,
    required this.avgCampaignSize,
  });
}

/// Provider for admin-level analytics per client
class AdminAnalyticsProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoadingCompany = false;
  String? _error;
  
  // Cache analytics per client
  final Map<String, ConversationClientAnalytics> _conversationAnalytics = {};
  final Map<String, BroadcastClientAnalytics> _broadcastAnalytics = {};
  
  // Company-wide analytics
  VividCompanyAnalytics? _companyAnalytics;

  // Real-time subscriptions
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _broadcastsChannel;
  RealtimeChannel? _companyMessagesChannel;
  Client? _currentClient;

  bool get isLoading => _isLoading;
  bool get isLoadingCompany => _isLoadingCompany;
  String? get error => _error;
  VividCompanyAnalytics? get companyAnalytics => _companyAnalytics;

  ConversationClientAnalytics? getConversationAnalytics(String clientId) {
    return _conversationAnalytics[clientId];
  }

  BroadcastClientAnalytics? getBroadcastAnalytics(String clientId) {
    return _broadcastAnalytics[clientId];
  }

  /// Fetch analytics for a conversation-based client
  Future<void> fetchConversationAnalytics(Client client) async {
    if (client.businessPhone == null || client.businessPhone!.isEmpty) {
      _error = 'No business phone configured for this client';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _currentClient = client;
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      
      // Fetch all messages for this client's phone number
      final response = await supabase
          .from('messages')
          .select()
          .eq('ai_phone', client.businessPhone!)
          .order('created_at', ascending: false);

      final messages = response as List;
      _processConversationMessages(client, messages);

      // Set up real-time subscription
      _subscribeToMessages(client);

      _error = null;
    } catch (e) {
      _error = 'Failed to fetch analytics: $e';
      print('Error fetching conversation analytics: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void _processConversationMessages(Client client, List messages) {
    int aiMessages = 0;
    int managerMessages = 0;
    int successfulBookings = 0;
    DateTime? lastActivity;
    Set<String> uniquePhones = {};
    List<Duration> responseTimes = [];
    
    // For smart conversation counting - track gaps
    Map<String, List<DateTime>> customerMessageTimes = {};

    for (final msg in messages) {
      // Track unique customers
      final customerPhone = msg['customer_phone'] as String?;
      if (customerPhone != null) {
        uniquePhones.add(customerPhone);
        
        // Track message times per customer for conversation counting
        final createdAt = DateTime.tryParse(msg['created_at'] ?? '');
        if (createdAt != null) {
          customerMessageTimes.putIfAbsent(customerPhone, () => []);
          customerMessageTimes[customerPhone]!.add(createdAt);
        }
      }

      // Count AI messages (non-empty ai_response)
      final aiResponse = msg['ai_response'] as String? ?? '';
      if (aiResponse.trim().isNotEmpty) {
        aiMessages++;
      }

      // Count Manager messages (non-empty manager_response)
      final managerResponse = msg['manager_response'] as String?;
      if (managerResponse != null && managerResponse.trim().isNotEmpty) {
        managerMessages++;
      }

      // Check for successful bookings (look for booking confirmation patterns)
      if (_isBookingConfirmation(aiResponse) || 
          _isBookingConfirmation(managerResponse ?? '')) {
        successfulBookings++;
      }

      // Track last activity
      if (lastActivity == null && msg['created_at'] != null) {
        lastActivity = DateTime.tryParse(msg['created_at']);
      }

      // Calculate response time from actual timestamps
      final customerSentAt = msg['customer_sent_at'] as String?;
      final aiRespondedAt = msg['ai_responded_at'] as String?;
      
      if (customerSentAt != null && aiRespondedAt != null) {
        final sentTime = DateTime.tryParse(customerSentAt);
        final respondedTime = DateTime.tryParse(aiRespondedAt);
        
        if (sentTime != null && respondedTime != null) {
          final responseTime = respondedTime.difference(sentTime);
          // Only count reasonable response times (< 5 minutes)
          if (responseTime.inSeconds > 0 && responseTime.inMinutes < 5) {
            responseTimes.add(responseTime);
          }
        }
      }
    }

    // Calculate automation rate
    final totalResponses = aiMessages + managerMessages;
    final automationRate = totalResponses > 0 
        ? (aiMessages / totalResponses) * 100 
        : 0.0;

    // Calculate average response time
    Duration avgResponseTime;
    if (responseTimes.isNotEmpty) {
      final totalSeconds = responseTimes.fold<int>(
        0, (sum, duration) => sum + duration.inSeconds
      );
      avgResponseTime = Duration(seconds: totalSeconds ~/ responseTimes.length);
    } else {
      avgResponseTime = Duration.zero; // No data yet
    }

    // Days since onboarding
    final daysSinceOnboarding = DateTime.now().difference(client.createdAt).inDays;

    // Smart conversation counting - count gaps > 2 hours as separate conversations
    int totalConversations = 0;
    for (final times in customerMessageTimes.values) {
      if (times.isEmpty) continue;
      
      times.sort(); // Sort chronologically
      totalConversations++; // At least one conversation per customer
      
      for (int i = 1; i < times.length; i++) {
        final gap = times[i].difference(times[i - 1]);
        if (gap.inHours >= 2) {
          totalConversations++; // Gap > 2 hours = new conversation
        }
      }
    }

    _conversationAnalytics[client.id] = ConversationClientAnalytics(
      totalAiMessages: aiMessages,
      totalManagerMessages: managerMessages,
      automationRate: automationRate,
      avgResponseTime: avgResponseTime,
      successfulBookings: successfulBookings,
      lastActivity: lastActivity,
      daysSinceOnboarding: daysSinceOnboarding,
      uniqueCustomers: uniquePhones.length,
      totalConversations: totalConversations,
    );
  }

  void _subscribeToMessages(Client client) {
    // Cancel existing subscription
    _messagesChannel?.unsubscribe();

    final supabase = SupabaseService.client;

    _messagesChannel = supabase
        .channel('admin_messages_${client.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ai_phone',
            value: client.businessPhone!,
          ),
          callback: (payload) {
            print('📊 Real-time analytics update for ${client.name}');
            // Refetch analytics on any change
            _refetchConversationAnalytics(client);
          },
        )
        .subscribe();

    print('📊 Subscribed to real-time analytics for ${client.name}');
  }

  Future<void> _refetchConversationAnalytics(Client client) async {
    try {
      final supabase = SupabaseService.client;
      
      final response = await supabase
          .from('messages')
          .select()
          .eq('ai_phone', client.businessPhone!)
          .order('created_at', ascending: false);

      final messages = response as List;
      _processConversationMessages(client, messages);
      notifyListeners();
    } catch (e) {
      print('Error refetching analytics: $e');
    }
  }

  /// Fetch analytics for a broadcast-based client
  Future<void> fetchBroadcastAnalytics(Client client) async {
    _isLoading = true;
    _error = null;
    _currentClient = client;
    notifyListeners();

    try {
      final supabase = SupabaseService.client;

      // Fetch all broadcasts for this client
      final broadcastsResponse = await supabase
          .from('broadcasts')
          .select()
          .eq('client_id', client.id)
          .order('sent_at', ascending: false);

      final broadcasts = broadcastsResponse as List;
      await _processBroadcasts(client, broadcasts);

      // Set up real-time subscription
      _subscribeToBroadcasts(client);

      _error = null;
    } catch (e) {
      _error = 'Failed to fetch analytics: $e';
      print('Error fetching broadcast analytics: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _processBroadcasts(Client client, List broadcasts) async {
    final supabase = SupabaseService.client;
    
    // Fetch all recipients for this client's broadcasts
    final broadcastIds = broadcasts.map((b) => b['id'] as String).toList();
    
    int totalRecipients = 0;
    int deliveredCount = 0;
    int readCount = 0;
    int failedCount = 0;
    DateTime? lastActivity;

    if (broadcastIds.isNotEmpty) {
      final recipientsResponse = await supabase
          .from('broadcast_recipients')
          .select()
          .inFilter('broadcast_id', broadcastIds);

      final recipients = recipientsResponse as List;
      totalRecipients = recipients.length;

      for (final recipient in recipients) {
        final status = recipient['status'] as String? ?? 'sent';
        switch (status.toLowerCase()) {
          case 'delivered':
            deliveredCount++;
            break;
          case 'read':
            readCount++;
            deliveredCount++; // Read implies delivered
            break;
          case 'failed':
            failedCount++;
            break;
        }
      }
    }

    // Get last activity
    if (broadcasts.isNotEmpty && broadcasts.first['sent_at'] != null) {
      lastActivity = DateTime.tryParse(broadcasts.first['sent_at']);
    }

    // Calculate rates
    final deliveryRate = totalRecipients > 0 
        ? (deliveredCount / totalRecipients) * 100 
        : 0.0;
    final readRate = totalRecipients > 0 
        ? (readCount / totalRecipients) * 100 
        : 0.0;
    final failedRate = totalRecipients > 0 
        ? (failedCount / totalRecipients) * 100 
        : 0.0;

    // Universal metrics
    final daysSinceOnboarding = DateTime.now().difference(client.createdAt).inDays;
    final avgCampaignSize = broadcasts.isNotEmpty 
        ? totalRecipients / broadcasts.length 
        : 0.0;

    _broadcastAnalytics[client.id] = BroadcastClientAnalytics(
      totalBroadcastsSent: broadcasts.length,
      totalRecipientsReached: totalRecipients,
      deliveryRate: deliveryRate,
      readRate: readRate,
      failedRate: failedRate,
      lastActivity: lastActivity,
      daysSinceOnboarding: daysSinceOnboarding,
      avgCampaignSize: avgCampaignSize,
    );
  }

  void _subscribeToBroadcasts(Client client) {
    // Cancel existing subscription
    _broadcastsChannel?.unsubscribe();

    final supabase = SupabaseService.client;

    _broadcastsChannel = supabase
        .channel('admin_broadcasts_${client.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'broadcasts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'client_id',
            value: client.id,
          ),
          callback: (payload) {
            print('📊 Real-time broadcast analytics update for ${client.name}');
            _refetchBroadcastAnalytics(client);
          },
        )
        .subscribe();

    // Also subscribe to recipient status changes
    supabase
        .channel('admin_recipients_${client.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'broadcast_recipients',
          callback: (payload) {
            print('📊 Real-time recipient update for ${client.name}');
            _refetchBroadcastAnalytics(client);
          },
        )
        .subscribe();

    print('📊 Subscribed to real-time broadcast analytics for ${client.name}');
  }

  Future<void> _refetchBroadcastAnalytics(Client client) async {
    try {
      final supabase = SupabaseService.client;

      final broadcastsResponse = await supabase
          .from('broadcasts')
          .select()
          .eq('client_id', client.id)
          .order('sent_at', ascending: false);

      final broadcasts = broadcastsResponse as List;
      await _processBroadcasts(client, broadcasts);
      notifyListeners();
    } catch (e) {
      print('Error refetching broadcast analytics: $e');
    }
  }

  /// Check if a message contains booking confirmation patterns
  bool _isBookingConfirmation(String message) {
    if (message.isEmpty) return false;
    
    final lowerMessage = message.toLowerCase();
    
    // English booking confirmation patterns
    final bookingPatterns = [
      'booking confirmed',
      'appointment confirmed',
      'booked for',
      'scheduled for',
      'your appointment is set',
      'reservation confirmed',
      'see you on',
      'looking forward to seeing you',
      'booking has been made',
      'successfully booked',
    ];

    // Arabic booking confirmation patterns
    final arabicPatterns = [
      'تم الحجز',
      'تم تأكيد',
      'موعدك',
      'حجزك',
    ];

    for (final pattern in bookingPatterns) {
      if (lowerMessage.contains(pattern)) return true;
    }

    for (final pattern in arabicPatterns) {
      if (message.contains(pattern)) return true;
    }

    return false;
  }

  /// Fetch company-wide analytics (all clients combined)
  Future<void> fetchCompanyAnalytics(List<Client> clients) async {
    _isLoadingCompany = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = SupabaseService.client;

      // Fetch all messages
      final messagesResponse = await supabase
          .from('messages')
          .select()
          .order('created_at', ascending: false);
      final allMessages = messagesResponse as List;

      // Fetch all broadcasts
      final broadcastsResponse = await supabase
          .from('broadcasts')
          .select()
          .order('sent_at', ascending: false);
      final allBroadcasts = broadcastsResponse as List;

      // Fetch all broadcast recipients
      final recipientsResponse = await supabase
          .from('broadcast_recipients')
          .select();
      final allRecipients = recipientsResponse as List;

      // Calculate metrics
      int totalAiMessages = 0;
      int totalManagerMessages = 0;
      Set<String> uniqueCustomers = {};
      DateTime? lastActivity;
      Map<String, int> messagesByDay = {};
      Map<String, ClientActivity> clientActivityMap = {};

      // Initialize client activity map
      for (final client in clients) {
        clientActivityMap[client.businessPhone ?? client.id] = ClientActivity(
          clientId: client.id,
          clientName: client.name,
          messageCount: 0,
          broadcastCount: 0,
        );
      }

      // Process messages
      for (final msg in allMessages) {
        final aiResponse = msg['ai_response'] as String? ?? '';
        final managerResponse = msg['manager_response'] as String?;
        final customerPhone = msg['customer_phone'] as String?;
        final aiPhone = msg['ai_phone'] as String?;
        final createdAt = msg['created_at'] as String?;

        if (aiResponse.trim().isNotEmpty) totalAiMessages++;
        if (managerResponse != null && managerResponse.trim().isNotEmpty) {
          totalManagerMessages++;
        }
        if (customerPhone != null) uniqueCustomers.add(customerPhone);

        // Track last activity
        if (lastActivity == null && createdAt != null) {
          lastActivity = DateTime.tryParse(createdAt);
        }

        // Count messages by day (last 7 days)
        if (createdAt != null) {
          final date = DateTime.tryParse(createdAt);
          if (date != null) {
            final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final now = DateTime.now();
            if (now.difference(date).inDays < 7) {
              messagesByDay[dayKey] = (messagesByDay[dayKey] ?? 0) + 1;
            }
          }
        }

        // Update client activity
        if (aiPhone != null && clientActivityMap.containsKey(aiPhone)) {
          final existing = clientActivityMap[aiPhone]!;
          clientActivityMap[aiPhone] = ClientActivity(
            clientId: existing.clientId,
            clientName: existing.clientName,
            messageCount: existing.messageCount + 1,
            broadcastCount: existing.broadcastCount,
            lastActivity: existing.lastActivity ?? (createdAt != null ? DateTime.tryParse(createdAt) : null),
          );
        }
      }

      // Process broadcasts for client activity
      for (final broadcast in allBroadcasts) {
        final clientId = broadcast['client_id'] as String?;
        if (clientId != null) {
          // Find the client by ID
          for (final entry in clientActivityMap.entries) {
            if (clients.any((c) => c.id == clientId && (c.businessPhone == entry.key || c.id == entry.key))) {
              final existing = entry.value;
              if (existing.clientId == clientId) {
                clientActivityMap[entry.key] = ClientActivity(
                  clientId: existing.clientId,
                  clientName: existing.clientName,
                  messageCount: existing.messageCount,
                  broadcastCount: existing.broadcastCount + 1,
                  lastActivity: existing.lastActivity,
                );
              }
            }
          }
        }
      }

      // Calculate automation rate
      final totalResponses = totalAiMessages + totalManagerMessages;
      final automationRate = totalResponses > 0
          ? (totalAiMessages / totalResponses) * 100
          : 0.0;

      // Get most active clients (sorted by message count)
      final sortedClients = clientActivityMap.values.toList()
        ..sort((a, b) => (b.messageCount + b.broadcastCount * 10)
            .compareTo(a.messageCount + a.broadcastCount * 10));
      final mostActive = sortedClients.take(5).toList();

      _companyAnalytics = VividCompanyAnalytics(
        totalClients: clients.length,
        totalMessages: allMessages.length,
        totalBroadcasts: allBroadcasts.length,
        totalRecipientsReached: allRecipients.length,
        overallAutomationRate: automationRate,
        totalAiMessages: totalAiMessages,
        totalManagerMessages: totalManagerMessages,
        totalUniqueCustomers: uniqueCustomers.length,
        lastActivityAcrossAll: lastActivity,
        mostActiveClients: mostActive,
        messagesByDay: messagesByDay,
      );

      // Subscribe to real-time updates
      _subscribeToCompanyUpdates(clients);

      _error = null;
    } catch (e) {
      _error = 'Failed to fetch company analytics: $e';
      print('Error fetching company analytics: $e');
    }

    _isLoadingCompany = false;
    notifyListeners();
  }

  void _subscribeToCompanyUpdates(List<Client> clients) {
    _companyMessagesChannel?.unsubscribe();

    final supabase = SupabaseService.client;

    _companyMessagesChannel = supabase
        .channel('company_messages_all')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('📊 Company-wide analytics update');
            fetchCompanyAnalytics(clients);
          },
        )
        .subscribe();

    print('📊 Subscribed to company-wide real-time analytics');
  }

  /// Clear cached analytics and unsubscribe
  void clearCache() {
    _messagesChannel?.unsubscribe();
    _broadcastsChannel?.unsubscribe();
    _companyMessagesChannel?.unsubscribe();
    _conversationAnalytics.clear();
    _broadcastAnalytics.clear();
    _companyAnalytics = null;
    _currentClient = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _broadcastsChannel?.unsubscribe();
    _companyMessagesChannel?.unsubscribe();
    super.dispose();
  }
}