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

  // Time-bucketed message counts
  final int todayMessages;
  final int thisWeekMessages;
  final int thisMonthMessages;

  // Broadcast delivery stats
  final int broadcastDeliveredCount;
  final int broadcastReadCount;
  final int broadcastFailedCount;
  final int broadcastTotalRecipients;

  // Busiest hours distribution (hour 0-23 -> count)
  final Map<int, int> messagesByHour;

  // Top customers across all clients
  final List<TopCustomerInfo> topCustomers;

  // AI performance
  final int handoffCount;
  final int aiEnabledCustomers;
  final int aiDisabledCustomers;

  // Full client breakdown
  final List<ClientActivity> allClientActivities;

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
    this.todayMessages = 0,
    this.thisWeekMessages = 0,
    this.thisMonthMessages = 0,
    this.broadcastDeliveredCount = 0,
    this.broadcastReadCount = 0,
    this.broadcastFailedCount = 0,
    this.broadcastTotalRecipients = 0,
    this.messagesByHour = const {},
    this.topCustomers = const [],
    this.handoffCount = 0,
    this.aiEnabledCustomers = 0,
    this.aiDisabledCustomers = 0,
    this.allClientActivities = const [],
  });
}

/// Activity summary for a single client
class ClientActivity {
  final String clientId;
  final String clientName;
  final int messageCount;
  final int broadcastCount;
  final DateTime? lastActivity;
  final int aiMessages;
  final int managerMessages;
  final int uniqueCustomers;
  final double automationRate;

  const ClientActivity({
    required this.clientId,
    required this.clientName,
    required this.messageCount,
    required this.broadcastCount,
    this.lastActivity,
    this.aiMessages = 0,
    this.managerMessages = 0,
    this.uniqueCustomers = 0,
    this.automationRate = 0.0,
  });
}

/// Top customer by message count across all clients
class TopCustomerInfo {
  final String phone;
  final String? name;
  final int messageCount;
  final String clientName;

  const TopCustomerInfo({
    required this.phone,
    this.name,
    required this.messageCount,
    required this.clientName,
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
  final List<RealtimeChannel> _companyChannels = [];
  Client? _currentClient;

  bool get isLoading => _isLoading;
  bool get isLoadingCompany => _isLoadingCompany;
  String? get error => _error;
  VividCompanyAnalytics? get companyAnalytics => _companyAnalytics;

  // ============================================
  // TABLE NAME HELPERS
  // ============================================

  /// Get messages table name for a client
  String _getMessagesTable(Client client) {
    if (client.messagesTable != null && client.messagesTable!.isNotEmpty) {
      return client.messagesTable!;
    }
    if (client.slug.isNotEmpty) {
      return '${client.slug}_messages';
    }
    return 'messages';
  }

  /// Get broadcasts table name for a client
  String _getBroadcastsTable(Client client) {
    if (client.broadcastsTable != null && client.broadcastsTable!.isNotEmpty) {
      return client.broadcastsTable!;
    }
    if (client.slug.isNotEmpty) {
      return '${client.slug}_broadcasts';
    }
    return 'broadcasts';
  }

  /// Get broadcast recipients table name for a client
  String _getRecipientsTable(Client client) {
    final broadcastsTable = _getBroadcastsTable(client);
    final prefix = broadcastsTable.replaceAll('_broadcasts', '');
    if (prefix.isNotEmpty && prefix != broadcastsTable) {
      return '${prefix}_broadcast_recipients';
    }
    return 'broadcast_recipients';
  }

  /// Get the phone number to use for conversation queries
  String? _getConversationsPhone(Client client) {
    return client.conversationsPhone ?? client.businessPhone;
  }

  ConversationClientAnalytics? getConversationAnalytics(String clientId) {
    return _conversationAnalytics[clientId];
  }

  BroadcastClientAnalytics? getBroadcastAnalytics(String clientId) {
    return _broadcastAnalytics[clientId];
  }

  /// Fetch analytics for a conversation-based client
  Future<void> fetchConversationAnalytics(Client client) async {
    final phone = _getConversationsPhone(client);
    if (phone == null || phone.isEmpty) {
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
      final table = _getMessagesTable(client);

      // Fetch all messages for this client's phone number from their slug-based table
      final response = await supabase
          .from(table)
          .select()
          .eq('ai_phone', phone)
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
    final table = _getMessagesTable(client);
    final phone = _getConversationsPhone(client);

    _messagesChannel = supabase
        .channel('admin_messages_${client.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: phone != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ai_phone',
            value: phone,
          ) : null,
          callback: (payload) {
            print('📊 Real-time analytics update for ${client.name}');
            _refetchConversationAnalytics(client);
          },
        )
        .subscribe();

    print('📊 Subscribed to real-time analytics for ${client.name} on table: $table');
  }

  Future<void> _refetchConversationAnalytics(Client client) async {
    try {
      final supabase = SupabaseService.client;
      final table = _getMessagesTable(client);
      final phone = _getConversationsPhone(client);

      final response = await supabase
          .from(table)
          .select()
          .eq('ai_phone', phone!)
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
      final table = _getBroadcastsTable(client);

      // Fetch all broadcasts from the client's slug-based table
      final broadcastsResponse = await supabase
          .from(table)
          .select()
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
    final recipientsTable = _getRecipientsTable(client);

    // Fetch all recipients for this client's broadcasts
    final broadcastIds = broadcasts.map((b) => b['id'] as String).toList();

    int totalRecipients = 0;
    int deliveredCount = 0;
    int readCount = 0;
    int failedCount = 0;
    DateTime? lastActivity;

    if (broadcastIds.isNotEmpty) {
      final recipientsResponse = await supabase
          .from(recipientsTable)
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
    final broadcastsTable = _getBroadcastsTable(client);
    final recipientsTable = _getRecipientsTable(client);

    _broadcastsChannel = supabase
        .channel('admin_broadcasts_${client.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: broadcastsTable,
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
          table: recipientsTable,
          callback: (payload) {
            print('📊 Real-time recipient update for ${client.name}');
            _refetchBroadcastAnalytics(client);
          },
        )
        .subscribe();

    print('📊 Subscribed to real-time broadcast analytics for ${client.name} on table: $broadcastsTable');
  }

  Future<void> _refetchBroadcastAnalytics(Client client) async {
    try {
      final supabase = SupabaseService.client;
      final table = _getBroadcastsTable(client);

      final broadcastsResponse = await supabase
          .from(table)
          .select()
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
  /// Iterates over each client's slug-based tables and aggregates results
  Future<void> fetchCompanyAnalytics(List<Client> clients) async {
    _isLoadingCompany = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = SupabaseService.client;

      int totalAiMessages = 0;
      int totalManagerMessages = 0;
      int totalMessageCount = 0;
      int totalBroadcastCount = 0;
      int totalRecipientsCount = 0;
      Set<String> uniqueCustomers = {};
      DateTime? lastActivity;
      Map<String, int> messagesByDay = {};
      Map<String, ClientActivity> clientActivityMap = {};

      // New tracking variables
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      int todayMessages = 0;
      int thisWeekMessages = 0;
      int thisMonthMessages = 0;
      Map<int, int> messagesByHour = {};
      Map<String, Map<String, dynamic>> globalCustomerCounts = {};
      int handoffCount = 0;
      int totalBroadcastDelivered = 0;
      int totalBroadcastRead = 0;
      int totalBroadcastFailed = 0;
      int totalBroadcastRecipients = 0;
      Map<String, int> clientAiMessages = {};
      Map<String, int> clientManagerMessages = {};
      Map<String, Set<String>> clientUniqueCustomers = {};

      // Query each client's tables individually
      for (final client in clients) {
        int clientMessageCount = 0;
        int clientBroadcastCount = 0;
        DateTime? clientLastActivity;

        // Fetch messages if client has conversations feature
        if (client.hasFeature('conversations')) {
          try {
            final messagesTable = _getMessagesTable(client);
            final phone = _getConversationsPhone(client);

            var query = supabase
                .from(messagesTable)
                .select()
                .order('created_at', ascending: false);

            if (phone != null && phone.isNotEmpty) {
              query = supabase
                  .from(messagesTable)
                  .select()
                  .eq('ai_phone', phone)
                  .order('created_at', ascending: false);
            }

            final messagesResponse = await query;
            final messages = messagesResponse as List;
            clientMessageCount = messages.length;
            totalMessageCount += messages.length;

            for (final msg in messages) {
              final aiResponse = msg['ai_response'] as String? ?? '';
              final managerResponse = msg['manager_response'] as String?;
              final customerPhone = msg['customer_phone'] as String?;
              final createdAt = msg['created_at'] as String?;

              final hasAi = aiResponse.trim().isNotEmpty;
              final hasManager = managerResponse != null && managerResponse.trim().isNotEmpty;

              if (hasAi) {
                totalAiMessages++;
                clientAiMessages[client.id] = (clientAiMessages[client.id] ?? 0) + 1;
              }
              if (hasManager) {
                totalManagerMessages++;
                clientManagerMessages[client.id] = (clientManagerMessages[client.id] ?? 0) + 1;
              }
              if (customerPhone != null) {
                uniqueCustomers.add(customerPhone);
                clientUniqueCustomers.putIfAbsent(client.id, () => {});
                clientUniqueCustomers[client.id]!.add(customerPhone);

                // Track top customers globally
                globalCustomerCounts.putIfAbsent(customerPhone, () => {
                  'name': msg['customer_name'] as String?,
                  'count': 0,
                  'clientName': client.name,
                });
                globalCustomerCounts[customerPhone]!['count'] =
                    (globalCustomerCounts[customerPhone]!['count'] as int) + 1;
                final custName = msg['customer_name'] as String?;
                if (custName != null && custName.isNotEmpty) {
                  globalCustomerCounts[customerPhone]!['name'] = custName;
                }
              }

              // Handoff: AI tried but manager also stepped in
              if (hasAi && hasManager) handoffCount++;

              // Track last activity and time-based metrics
              if (createdAt != null) {
                final date = DateTime.tryParse(createdAt);
                if (date != null) {
                  if (lastActivity == null || date.isAfter(lastActivity)) {
                    lastActivity = date;
                  }
                  if (clientLastActivity == null || date.isAfter(clientLastActivity)) {
                    clientLastActivity = date;
                  }

                  // Time-bucketed counts
                  if (date.isAfter(todayStart)) todayMessages++;
                  if (date.isAfter(weekStart)) thisWeekMessages++;
                  if (date.isAfter(monthStart)) thisMonthMessages++;

                  // Busiest hours
                  messagesByHour[date.hour] = (messagesByHour[date.hour] ?? 0) + 1;

                  // Count messages by day (last 7 days)
                  if (now.difference(date).inDays < 7) {
                    final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    messagesByDay[dayKey] = (messagesByDay[dayKey] ?? 0) + 1;
                  }
                }
              }
            }
          } catch (e) {
            print('Error fetching messages for ${client.name}: $e');
          }
        }

        // Fetch broadcasts if client has broadcasts feature
        if (client.hasFeature('broadcasts')) {
          try {
            final broadcastsTable = _getBroadcastsTable(client);
            final recipientsTable = _getRecipientsTable(client);

            final broadcastsResponse = await supabase
                .from(broadcastsTable)
                .select()
                .order('sent_at', ascending: false);

            final broadcasts = broadcastsResponse as List;
            clientBroadcastCount = broadcasts.length;
            totalBroadcastCount += broadcasts.length;

            // Track last broadcast activity
            if (broadcasts.isNotEmpty && broadcasts.first['sent_at'] != null) {
              final broadcastDate = DateTime.tryParse(broadcasts.first['sent_at']);
              if (broadcastDate != null) {
                if (lastActivity == null || broadcastDate.isAfter(lastActivity)) {
                  lastActivity = broadcastDate;
                }
                if (clientLastActivity == null || broadcastDate.isAfter(clientLastActivity)) {
                  clientLastActivity = broadcastDate;
                }
              }
            }

            // Fetch recipients and count delivery statuses
            final broadcastIds = broadcasts.map((b) => b['id'] as String).toList();
            if (broadcastIds.isNotEmpty) {
              final recipientsResponse = await supabase
                  .from(recipientsTable)
                  .select()
                  .inFilter('broadcast_id', broadcastIds);
              final recipients = recipientsResponse as List;
              totalRecipientsCount += recipients.length;
              totalBroadcastRecipients += recipients.length;

              for (final recipient in recipients) {
                final status = recipient['status'] as String? ?? 'sent';
                switch (status.toLowerCase()) {
                  case 'delivered':
                    totalBroadcastDelivered++;
                    break;
                  case 'read':
                    totalBroadcastRead++;
                    totalBroadcastDelivered++; // Read implies delivered
                    break;
                  case 'failed':
                    totalBroadcastFailed++;
                    break;
                }
              }
            }
          } catch (e) {
            print('Error fetching broadcasts for ${client.name}: $e');
          }
        }

        // Build client activity entry
        final cAi = clientAiMessages[client.id] ?? 0;
        final cMgr = clientManagerMessages[client.id] ?? 0;
        final cUniq = clientUniqueCustomers[client.id]?.length ?? 0;
        final cTotal = cAi + cMgr;
        final cAutoRate = cTotal > 0 ? (cAi / cTotal) * 100 : 0.0;

        clientActivityMap[client.id] = ClientActivity(
          clientId: client.id,
          clientName: client.name,
          messageCount: clientMessageCount,
          broadcastCount: clientBroadcastCount,
          lastActivity: clientLastActivity,
          aiMessages: cAi,
          managerMessages: cMgr,
          uniqueCustomers: cUniq,
          automationRate: cAutoRate,
        );
      }

      // Calculate automation rate
      final totalResponses = totalAiMessages + totalManagerMessages;
      final automationRate = totalResponses > 0
          ? (totalAiMessages / totalResponses) * 100
          : 0.0;

      // Get most active clients (sorted by activity)
      final sortedClients = clientActivityMap.values.toList()
        ..sort((a, b) => (b.messageCount + b.broadcastCount * 10)
            .compareTo(a.messageCount + a.broadcastCount * 10));
      final mostActive = sortedClients.take(5).toList();

      // Build top customers list
      final sortedCustomerEntries = globalCustomerCounts.entries.toList()
        ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
      final topCustomers = sortedCustomerEntries.take(10).map((e) => TopCustomerInfo(
        phone: e.key,
        name: e.value['name'] as String?,
        messageCount: e.value['count'] as int,
        clientName: e.value['clientName'] as String,
      )).toList();

      // Fetch AI chat settings
      int aiEnabledCount = 0;
      int aiDisabledCount = 0;
      try {
        final aiSettingsResponse = await supabase
            .from('ai_chat_settings')
            .select('ai_enabled');
        final settings = aiSettingsResponse as List;
        for (final setting in settings) {
          final enabled = setting['ai_enabled'] as bool? ?? true;
          if (enabled) {
            aiEnabledCount++;
          } else {
            aiDisabledCount++;
          }
        }
      } catch (e) {
        print('Error fetching AI chat settings: $e');
      }

      _companyAnalytics = VividCompanyAnalytics(
        totalClients: clients.length,
        totalMessages: totalMessageCount,
        totalBroadcasts: totalBroadcastCount,
        totalRecipientsReached: totalRecipientsCount,
        overallAutomationRate: automationRate,
        totalAiMessages: totalAiMessages,
        totalManagerMessages: totalManagerMessages,
        totalUniqueCustomers: uniqueCustomers.length,
        lastActivityAcrossAll: lastActivity,
        mostActiveClients: mostActive,
        messagesByDay: messagesByDay,
        todayMessages: todayMessages,
        thisWeekMessages: thisWeekMessages,
        thisMonthMessages: thisMonthMessages,
        broadcastDeliveredCount: totalBroadcastDelivered,
        broadcastReadCount: totalBroadcastRead,
        broadcastFailedCount: totalBroadcastFailed,
        broadcastTotalRecipients: totalBroadcastRecipients,
        messagesByHour: messagesByHour,
        topCustomers: topCustomers,
        handoffCount: handoffCount,
        aiEnabledCustomers: aiEnabledCount,
        aiDisabledCustomers: aiDisabledCount,
        allClientActivities: clientActivityMap.values.toList(),
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
    // Unsubscribe from all existing company channels
    for (final channel in _companyChannels) {
      channel.unsubscribe();
    }
    _companyChannels.clear();

    final supabase = SupabaseService.client;

    // Subscribe to each client's tables individually
    for (final client in clients) {
      if (client.hasFeature('conversations')) {
        final messagesTable = _getMessagesTable(client);
        final channel = supabase
            .channel('company_messages_${client.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: messagesTable,
              callback: (payload) {
                print('📊 Company-wide analytics update from ${client.name}');
                fetchCompanyAnalytics(clients);
              },
            )
            .subscribe();
        _companyChannels.add(channel);
      }

      if (client.hasFeature('broadcasts')) {
        final broadcastsTable = _getBroadcastsTable(client);
        final channel = supabase
            .channel('company_broadcasts_${client.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: broadcastsTable,
              callback: (payload) {
                print('📊 Company-wide broadcast update from ${client.name}');
                fetchCompanyAnalytics(clients);
              },
            )
            .subscribe();
        _companyChannels.add(channel);
      }
    }

    print('📊 Subscribed to company-wide real-time analytics (${_companyChannels.length} channels)');
  }

  /// Clear cached analytics and unsubscribe
  void clearCache() {
    _messagesChannel?.unsubscribe();
    _broadcastsChannel?.unsubscribe();
    for (final channel in _companyChannels) {
      channel.unsubscribe();
    }
    _companyChannels.clear();
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
    for (final channel in _companyChannels) {
      channel.unsubscribe();
    }
    _companyChannels.clear();
    super.dispose();
  }
}