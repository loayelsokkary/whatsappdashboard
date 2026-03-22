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

// ═══════════════════════════════════════════════════════════════════
// NEW PER-FEATURE ANALYTICS MODELS
// ═══════════════════════════════════════════════════════════════════

class ClientOverviewMetrics {
  final int daysActive;
  final int enabledFeatureCount;
  final int totalMessages;
  final int uniqueCustomers;
  final int totalBroadcasts;
  final int totalManagerQueries;

  const ClientOverviewMetrics({
    required this.daysActive,
    required this.enabledFeatureCount,
    required this.totalMessages,
    required this.uniqueCustomers,
    this.totalBroadcasts = 0,
    this.totalManagerQueries = 0,
  });
}

class ConversationMetrics {
  final int inboundMessages;
  final int outboundMessages;
  final int uniqueCustomers;
  final int newCustomersThisMonth;
  final int returningCustomers;
  // AI performance
  final double automationRate;
  final int aiMessages;
  final int humanMessages;
  final int handoffCount;
  // Response time
  final Duration avgFirstResponseTime;
  final bool hasTimestampColumns;
  final Map<String, Duration> perAgentResponseTime;
  // Activity patterns
  final Map<int, int> messagesByHour;
  final Map<int, int> messagesByDayOfWeek;
  final Map<String, int> dailyVolume;
  final Map<String, int> monthlyNewCustomers;
  // Message types
  final int textMessages;
  final int voiceMessages;
  final int mediaMessages;
  final bool hasMediaColumns;
  // Team performance
  final List<AgentPerformance> agentPerformance;
  final bool hasSentByData;
  // Customer insights
  final List<TopCustomerInfo> topCustomers;
  final double avgCustomerLifetimeDays;
  final int singleMessageCustomers;

  const ConversationMetrics({
    required this.inboundMessages,
    required this.outboundMessages,
    required this.uniqueCustomers,
    required this.newCustomersThisMonth,
    required this.returningCustomers,
    required this.automationRate,
    required this.aiMessages,
    required this.humanMessages,
    required this.handoffCount,
    required this.avgFirstResponseTime,
    this.hasTimestampColumns = false,
    this.perAgentResponseTime = const {},
    required this.messagesByHour,
    required this.messagesByDayOfWeek,
    required this.dailyVolume,
    required this.monthlyNewCustomers,
    this.textMessages = 0,
    this.voiceMessages = 0,
    this.mediaMessages = 0,
    this.hasMediaColumns = false,
    this.agentPerformance = const [],
    this.hasSentByData = false,
    this.topCustomers = const [],
    this.avgCustomerLifetimeDays = 0,
    this.singleMessageCustomers = 0,
  });
}

class BroadcastMetrics {
  final int totalCampaigns;
  final int totalRecipientsReached;
  final double deliveryRate;
  final double failRate;
  final double avgCampaignSize;
  final double totalOfferValue;
  final double avgOfferPerCampaign;
  final int broadcastDrivenConversations;
  final int acceptedCount;
  final int deliveredCount;
  final int sentCount;
  final int failedCount;
  final List<CampaignSummary> campaigns;
  final int repeatRecipients;
  final int uniqueReach;
  final int unreachableCount;

  const BroadcastMetrics({
    required this.totalCampaigns,
    required this.totalRecipientsReached,
    required this.deliveryRate,
    required this.failRate,
    required this.avgCampaignSize,
    this.totalOfferValue = 0,
    this.avgOfferPerCampaign = 0,
    this.broadcastDrivenConversations = 0,
    this.acceptedCount = 0,
    this.deliveredCount = 0,
    this.sentCount = 0,
    this.failedCount = 0,
    this.campaigns = const [],
    this.repeatRecipients = 0,
    this.uniqueReach = 0,
    this.unreachableCount = 0,
  });
}

class ManagerChatMetrics {
  final int totalQueries;
  final int uniqueUsers;
  final List<UserQuerySummary> perUserBreakdown;
  final Map<String, int> dailyUsage;
  final Map<int, int> usageByHour;

  const ManagerChatMetrics({
    required this.totalQueries,
    required this.uniqueUsers,
    this.perUserBreakdown = const [],
    this.dailyUsage = const {},
    this.usageByHour = const {},
  });
}

class LabelMetrics {
  final Map<String, int> labelDistribution;
  final Map<String, int> labelByUniqueCustomer;
  final Map<String, Map<String, int>> weeklyLabelTrend;

  const LabelMetrics({
    this.labelDistribution = const {},
    this.labelByUniqueCustomer = const {},
    this.weeklyLabelTrend = const {},
  });
}

class PredictiveMetrics {
  final Map<String, int> categoryDistribution;
  final double retentionRate;
  final int atRiskCount;
  final int lapsedCount;
  final int dueThisWeek;
  final int overdueCount;
  final Map<String, int> topServices;
  final double avgGapDays;
  final int totalCustomers;

  const PredictiveMetrics({
    this.categoryDistribution = const {},
    this.retentionRate = 0,
    this.atRiskCount = 0,
    this.lapsedCount = 0,
    this.dueThisWeek = 0,
    this.overdueCount = 0,
    this.topServices = const {},
    this.avgGapDays = 0,
    this.totalCustomers = 0,
  });
}

class AgentPerformance {
  final String name;
  final int messageCount;
  final Duration avgResponseTime;
  final int activeDays;

  const AgentPerformance({
    required this.name,
    required this.messageCount,
    required this.avgResponseTime,
    required this.activeDays,
  });
}

class CampaignSummary {
  final String name;
  final DateTime date;
  final int recipients;
  final double deliveryRate;
  final double responseRate;

  const CampaignSummary({
    required this.name,
    required this.date,
    required this.recipients,
    required this.deliveryRate,
    this.responseRate = 0,
  });
}

class UserQuerySummary {
  final String userName;
  final int queryCount;
  final DateTime lastQuery;

  const UserQuerySummary({
    required this.userName,
    required this.queryCount,
    required this.lastQuery,
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
  String? _getRecipientsTable(Client client) {
    return client.broadcastRecipientsTable;
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
    if (recipientsTable == null) return;

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
    if (recipientsTable != null) {
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
    }

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
      final supabase = SupabaseService.adminClient;

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

        // Fetch messages if client has conversations feature (paginated)
        if (client.hasFeature('conversations')) {
          try {
            final messagesTable = _getMessagesTable(client);
            final phone = _getConversationsPhone(client);
            final columns = 'ai_response,manager_response,customer_phone,customer_name,created_at';

            // Paginate in chunks of 1000
            const pageSize = 1000;
            int offset = 0;
            while (true) {
              var q = supabase.from(messagesTable).select(columns);
              if (phone != null && phone.isNotEmpty) {
                q = q.eq('ai_phone', phone);
              }
              final List<dynamic> messages = await q
                  .order('created_at', ascending: false)
                  .range(offset, offset + pageSize - 1);

              clientMessageCount += messages.length;
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

              if (messages.length < pageSize) break;
              offset += pageSize;
            }
          } catch (e) {
            print('Error fetching messages for ${client.name}: $e');
          }
        }

        // Fetch broadcasts if client has broadcasts feature (paginated)
        if (client.hasFeature('broadcasts')) {
          try {
            final broadcastsTable = _getBroadcastsTable(client);
            final recipientsTable = _getRecipientsTable(client);

            // Paginate broadcasts
            const pageSize = 1000;
            final allBroadcasts = <dynamic>[];
            int offset = 0;
            while (true) {
              final List<dynamic> broadcasts = await supabase
                  .from(broadcastsTable)
                  .select()
                  .order('sent_at', ascending: false)
                  .range(offset, offset + pageSize - 1);
              allBroadcasts.addAll(broadcasts);
              if (broadcasts.length < pageSize) break;
              offset += pageSize;
            }

            clientBroadcastCount = allBroadcasts.length;
            totalBroadcastCount += allBroadcasts.length;

            // Track last broadcast activity
            if (allBroadcasts.isNotEmpty && allBroadcasts.first['sent_at'] != null) {
              final broadcastDate = DateTime.tryParse(allBroadcasts.first['sent_at']);
              if (broadcastDate != null) {
                if (lastActivity == null || broadcastDate.isAfter(lastActivity)) {
                  lastActivity = broadcastDate;
                }
                if (clientLastActivity == null || broadcastDate.isAfter(clientLastActivity)) {
                  clientLastActivity = broadcastDate;
                }
              }
            }

            // Fetch recipients and count delivery statuses (paginated)
            final broadcastIds = allBroadcasts.map((b) => b['id'] as String).toList();
            if (broadcastIds.isNotEmpty && recipientsTable != null) {
              final allRecipients = <dynamic>[];
              int rOffset = 0;
              while (true) {
                final List<dynamic> recipients = await supabase
                    .from(recipientsTable)
                    .select('status')
                    .inFilter('broadcast_id', broadcastIds)
                    .range(rOffset, rOffset + pageSize - 1);
                allRecipients.addAll(recipients);
                if (recipients.length < pageSize) break;
                rOffset += pageSize;
              }
              totalRecipientsCount += allRecipients.length;
              totalBroadcastRecipients += allRecipients.length;

              for (final recipient in allRecipients) {
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

      // Fetch AI chat settings from each client's per-client table
      int aiEnabledCount = 0;
      int aiDisabledCount = 0;
      for (final client in clients) {
        final aiTable = client.aiSettingsTable;
        if (aiTable == null || aiTable.isEmpty) continue;
        try {
          final aiSettingsResponse = await supabase
              .from(aiTable)
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
          print('Error fetching AI settings from $aiTable: $e');
        }
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

  // ═══════════════════════════════════════════════════════════════
  // NEW PER-FEATURE ANALYTICS METHODS
  // ═══════════════════════════════════════════════════════════════

  // Caches keyed by "clientId_startIso_endIso"
  final Map<String, ClientOverviewMetrics> _overviewCache = {};
  final Map<String, ConversationMetrics> _convMetricsCache = {};
  final Map<String, BroadcastMetrics> _bcastMetricsCache = {};
  final Map<String, ManagerChatMetrics> _mchatMetricsCache = {};
  final Map<String, LabelMetrics> _labelMetricsCache = {};
  final Map<String, PredictiveMetrics> _predMetricsCache = {};
  bool _isLoadingFeature = false;

  bool get isLoadingFeature => _isLoadingFeature;

  ClientOverviewMetrics? getCachedOverview(String key) => _overviewCache[key];
  ConversationMetrics? getCachedConvMetrics(String key) => _convMetricsCache[key];
  BroadcastMetrics? getCachedBcastMetrics(String key) => _bcastMetricsCache[key];
  ManagerChatMetrics? getCachedMchatMetrics(String key) => _mchatMetricsCache[key];
  LabelMetrics? getCachedLabelMetrics(String key) => _labelMetricsCache[key];
  PredictiveMetrics? getCachedPredMetrics(String key) => _predMetricsCache[key];

  String _cacheKey(String clientId, DateTime? start, DateTime? end) =>
      '${clientId}_${start?.toIso8601String() ?? 'all'}_${end?.toIso8601String() ?? 'all'}';

  /// Fetch ALL rows from a Supabase table, paginating in chunks of 1000.
  /// Supabase default limit is 1000 rows — this fetches everything.
  Future<List<dynamic>> _fetchAllRows(
    String table,
    String columns, {
    DateTime? start,
    DateTime? end,
    String dateColumn = 'created_at',
    String? orderBy,
  }) async {
    const pageSize = 1000;
    final allRows = <dynamic>[];
    int offset = 0;
    while (true) {
      var q = SupabaseService.adminClient
          .from(table)
          .select(columns);
      if (start != null) q = q.gte(dateColumn, start.toIso8601String());
      if (end != null) q = q.lte(dateColumn, end.toIso8601String());
      final List<dynamic> rows;
      if (orderBy != null) {
        rows = await q.order(orderBy, ascending: true).range(offset, offset + pageSize - 1);
      } else {
        rows = await q.range(offset, offset + pageSize - 1);
      }
      allRows.addAll(rows);
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return allRows;
  }

  // ─── OVERVIEW ───────────────────────────────────────────────

  Future<ClientOverviewMetrics> fetchClientOverview(
      Client client, {DateTime? start, DateTime? end}) async {
    final key = _cacheKey(client.id, start, end);
    try {
      int totalMessages = 0;
      int uniqueCustomers = 0;
      int totalBroadcasts = 0;
      int totalManagerQueries = 0;

      // Messages (paginated — no 1000-row cap)
      final msgTable = _getMessagesTable(client);
      try {
        final msgs = await _fetchAllRows(msgTable, 'customer_phone', start: start, end: end);
        totalMessages = msgs.length;
        final phones = <String>{};
        for (final m in msgs) {
          final p = m['customer_phone'] as String?;
          if (p != null && p.isNotEmpty) phones.add(p);
        }
        uniqueCustomers = phones.length;
      } catch (_) {}

      // Broadcasts (paginated)
      if (client.hasFeature('broadcasts')) {
        try {
          final bcast = await _fetchAllRows(_getBroadcastsTable(client), 'id', start: start, end: end, dateColumn: 'sent_at');
          totalBroadcasts = bcast.length;
        } catch (_) {}
      }

      // Manager chat (paginated)
      if (client.hasFeature('manager_chat') && client.managerChatsTable != null) {
        try {
          final mc = await _fetchAllRows(client.managerChatsTable!, 'id', start: start, end: end);
          totalManagerQueries = mc.length;
        } catch (_) {}
      }

      final coreFeatures = ['conversations', 'broadcasts', 'manager_chat'];
      final enabledCount = coreFeatures.where((f) => client.hasFeature(f)).length;

      final result = ClientOverviewMetrics(
        daysActive: client.createdAt != null
            ? DateTime.now().difference(client.createdAt!).inDays
            : 0,
        enabledFeatureCount: enabledCount,
        totalMessages: totalMessages,
        uniqueCustomers: uniqueCustomers,
        totalBroadcasts: totalBroadcasts,
        totalManagerQueries: totalManagerQueries,
      );
      _overviewCache[key] = result;
      notifyListeners();
      return result;
    } catch (e) {
      print('ANALYTICS: overview error for ${client.name}: $e');
      rethrow;
    }
  }

  // ─── CONVERSATION METRICS ──────────────────────────────────

  Future<ConversationMetrics> fetchConversationMetrics(
      Client client, {DateTime? start, DateTime? end}) async {
    final key = _cacheKey(client.id, start, end);
    try {
      final msgTable = _getMessagesTable(client);

      // Fetch ALL messages (paginated — no 1000-row cap)
      final cols = 'customer_phone,customer_name,customer_message,ai_response,manager_response,sent_by,created_at,is_voice_message,media_url,customer_sent_at,ai_responded_at';
      List<dynamic> rows;
      try {
        rows = await _fetchAllRows(msgTable, cols, start: start, end: end, orderBy: 'created_at');
      } catch (_) {
        // Fallback without optional columns
        rows = await _fetchAllRows(msgTable, 'customer_phone,customer_name,customer_message,ai_response,manager_response,created_at', start: start, end: end, orderBy: 'created_at');
      }

      int inbound = 0, outbound = 0, aiMsgs = 0, humanMsgs = 0, handoff = 0;
      int textMsgs = 0, voiceMsgs = 0, mediaMsgs = 0;
      bool hasMediaCols = false, hasTimestamps = false, hasSentBy = false;
      final phones = <String>{};
      final phoneFirstSeen = <String, DateTime>{};
      final phoneMonths = <String, Set<String>>{};
      final hourCounts = <int, int>{};
      final dowCounts = <int, int>{};
      final dailyCounts = <String, int>{};
      final monthlyNew = <String, int>{};
      final agentMsgs = <String, List<Map<String, dynamic>>>{};
      final responseTimes = <Duration>[];

      for (final r in rows) {
        final phone = r['customer_phone'] as String? ?? '';
        final custMsg = r['customer_message'] as String? ?? '';
        final aiResp = r['ai_response'] as String? ?? '';
        final manResp = r['manager_response'] as String? ?? '';
        final sentBy = r['sent_by'] as String?;
        final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '');

        if (custMsg.isNotEmpty) inbound++;
        if (aiResp.isNotEmpty || manResp.isNotEmpty) outbound++;
        if (aiResp.isNotEmpty) aiMsgs++;
        if (manResp.isNotEmpty) humanMsgs++;
        if (aiResp.isNotEmpty && manResp.isNotEmpty) handoff++;

        // Media detection
        final mediaUrl = r['media_url'] as String?;
        final isVoice = r['is_voice_message'];
        if (mediaUrl != null || isVoice != null) hasMediaCols = true;
        if (isVoice == true) {
          voiceMsgs++;
        } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
          mediaMsgs++;
        } else {
          textMsgs++;
        }

        // Phone tracking
        if (phone.isNotEmpty) {
          phones.add(phone);
          if (createdAt != null) {
            if (!phoneFirstSeen.containsKey(phone) || createdAt.isBefore(phoneFirstSeen[phone]!)) {
              phoneFirstSeen[phone] = createdAt;
            }
            final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
            phoneMonths.putIfAbsent(phone, () => {}).add(monthKey);
          }
        }

        // Time patterns
        if (createdAt != null) {
          hourCounts[createdAt.hour] = (hourCounts[createdAt.hour] ?? 0) + 1;
          dowCounts[createdAt.weekday] = (dowCounts[createdAt.weekday] ?? 0) + 1;
          final dayKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
        }

        // Sent by tracking
        if (sentBy != null && sentBy.isNotEmpty) {
          hasSentBy = true;
          agentMsgs.putIfAbsent(sentBy, () => []).add(r);
        }

        // Response time
        final custSentAt = r['customer_sent_at']?.toString();
        final aiRespondedAt = r['ai_responded_at']?.toString();
        if (custSentAt != null && aiRespondedAt != null) {
          hasTimestamps = true;
          final sent = DateTime.tryParse(custSentAt);
          final responded = DateTime.tryParse(aiRespondedAt);
          if (sent != null && responded != null && responded.isAfter(sent)) {
            final diff = responded.difference(sent);
            if (diff.inMinutes < 5) responseTimes.add(diff);
          }
        }
      }

      // Compute new vs returning
      final now = DateTime.now();
      final thisMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      int newThisMonth = 0;
      for (final entry in phoneFirstSeen.entries) {
        final firstMonth = '${entry.value.year}-${entry.value.month.toString().padLeft(2, '0')}';
        if (firstMonth == thisMonth) newThisMonth++;
        final m = firstMonth;
        monthlyNew[m] = (monthlyNew[m] ?? 0) + 1;
      }
      final returning = phoneMonths.values.where((months) => months.length >= 2).length;

      // Avg response time
      Duration avgResp = Duration.zero;
      if (responseTimes.isNotEmpty) {
        final totalMs = responseTimes.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
        avgResp = Duration(milliseconds: totalMs ~/ responseTimes.length);
      }

      // Agent performance
      final agents = <AgentPerformance>[];
      if (hasSentBy) {
        for (final entry in agentMsgs.entries) {
          final days = <String>{};
          for (final m in entry.value) {
            final ca = DateTime.tryParse(m['created_at']?.toString() ?? '');
            if (ca != null) days.add('${ca.year}-${ca.month}-${ca.day}');
          }
          agents.add(AgentPerformance(
            name: entry.key,
            messageCount: entry.value.length,
            avgResponseTime: Duration.zero, // Would need per-agent timestamps
            activeDays: days.length,
          ));
        }
        agents.sort((a, b) => b.messageCount.compareTo(a.messageCount));
      }

      // Top customers
      final phoneCounts = <String, int>{};
      final phoneNames = <String, String>{};
      for (final r in rows) {
        final p = r['customer_phone'] as String? ?? '';
        if (p.isEmpty) continue;
        phoneCounts[p] = (phoneCounts[p] ?? 0) + 1;
        final n = r['customer_name'] as String?;
        if (n != null && n.isNotEmpty) phoneNames[p] = n;
      }
      final sortedPhones = phoneCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCusts = sortedPhones.take(10).map((e) => TopCustomerInfo(
            phone: e.key,
            name: phoneNames[e.key],
            messageCount: e.value,
            clientName: client.name,
          )).toList();

      // Customer lifetime
      double avgLifetime = 0;
      int singleMsg = 0;
      for (final p in phones) {
        final count = phoneCounts[p] ?? 0;
        if (count <= 1) singleMsg++;
      }
      if (phoneFirstSeen.length > 1) {
        double totalDays = 0;
        int counted = 0;
        for (final p in phones) {
          final first = phoneFirstSeen[p];
          if (first != null) {
            totalDays += now.difference(first).inDays;
            counted++;
          }
        }
        if (counted > 0) avgLifetime = totalDays / counted;
      }

      final totalOutbound = aiMsgs + humanMsgs;
      final result = ConversationMetrics(
        inboundMessages: inbound,
        outboundMessages: outbound,
        uniqueCustomers: phones.length,
        newCustomersThisMonth: newThisMonth,
        returningCustomers: returning,
        automationRate: totalOutbound > 0 ? (aiMsgs / totalOutbound) * 100 : 0,
        aiMessages: aiMsgs,
        humanMessages: humanMsgs,
        handoffCount: handoff,
        avgFirstResponseTime: avgResp,
        hasTimestampColumns: hasTimestamps,
        perAgentResponseTime: const {},
        messagesByHour: hourCounts,
        messagesByDayOfWeek: dowCounts,
        dailyVolume: dailyCounts,
        monthlyNewCustomers: monthlyNew,
        textMessages: textMsgs,
        voiceMessages: voiceMsgs,
        mediaMessages: mediaMsgs,
        hasMediaColumns: hasMediaCols,
        agentPerformance: agents,
        hasSentByData: hasSentBy,
        topCustomers: topCusts,
        avgCustomerLifetimeDays: avgLifetime,
        singleMessageCustomers: singleMsg,
      );
      _convMetricsCache[key] = result;
      notifyListeners();
      print('ANALYTICS: conversation metrics loaded for ${client.name} (${rows.length} msgs)');
      return result;
    } catch (e) {
      print('ANALYTICS: conversation metrics error for ${client.name}: $e');
      rethrow;
    }
  }

  // ─── BROADCAST METRICS ─────────────────────────────────────

  Future<BroadcastMetrics> fetchBroadcastMetrics(
      Client client, {DateTime? start, DateTime? end}) async {
    final key = _cacheKey(client.id, start, end);
    try {
      final bcastTable = _getBroadcastsTable(client);
      final recipTable = _getRecipientsTable(client);

      // Fetch ALL broadcasts (paginated)
      final broadcasts = await _fetchAllRows(bcastTable, '*', start: start, end: end, dateColumn: 'sent_at', orderBy: 'sent_at');

      final campaignList = <CampaignSummary>[];
      double totalOffer = 0;
      int offerCount = 0;

      // Fetch all recipients
      List<dynamic> allRecipients = [];
      if (recipTable != null && broadcasts.isNotEmpty) {
        final bcastIds = broadcasts.map((b) => b['id'].toString()).toList();
        try {
          // Paginate recipients — can be large
          const rPageSize = 1000;
          int rOffset = 0;
          while (true) {
            final batch = await SupabaseService.adminClient
                .from(recipTable)
                .select()
                .inFilter('broadcast_id', bcastIds)
                .range(rOffset, rOffset + rPageSize - 1);
            allRecipients.addAll(batch as List);
            if ((batch).length < rPageSize) break;
            rOffset += rPageSize;
          }
        } catch (_) {}
      }

      // Group recipients by broadcast
      final recipByBcast = <String, List<dynamic>>{};
      for (final r in allRecipients) {
        final bid = r['broadcast_id']?.toString() ?? '';
        recipByBcast.putIfAbsent(bid, () => []).add(r);
      }

      int totalRecipients = 0, accepted = 0, delivered = 0, sent = 0, failed = 0;
      final allPhones = <String>{};
      final phoneAppearances = <String, int>{};
      final phoneFailed = <String, int>{};
      final phoneBcastCount = <String, int>{};

      for (final b in broadcasts) {
        final bid = b['id'].toString();
        final recips = recipByBcast[bid] ?? [];
        final bcastRecipCount = recips.length;
        totalRecipients += bcastRecipCount;

        int bDelivered = 0, bFailed = 0;
        for (final r in recips) {
          final status = (r['status'] as String? ?? '').toLowerCase();
          final phone = r['customer_phone'] as String? ?? '';
          if (phone.isNotEmpty) {
            allPhones.add(phone);
            phoneAppearances[phone] = (phoneAppearances[phone] ?? 0) + 1;
            phoneBcastCount[phone] = (phoneBcastCount[phone] ?? 0) + 1;
          }
          if (status == 'accepted') { accepted++; bDelivered++; }
          else if (status == 'delivered' || status == 'read') { delivered++; bDelivered++; }
          else if (status == 'sent') { sent++; bDelivered++; }
          else if (status == 'failed') {
            failed++;
            bFailed++;
            if (phone.isNotEmpty) phoneFailed[phone] = (phoneFailed[phone] ?? 0) + 1;
          }
        }

        final offer = (b['offer_amount'] as num?)?.toDouble();
        if (offer != null && offer > 0) {
          totalOffer += offer;
          offerCount++;
        }

        final dRate = bcastRecipCount > 0 ? ((bDelivered) / bcastRecipCount * 100) : 0.0;
        campaignList.add(CampaignSummary(
          name: b['campaign_name'] as String? ?? 'Unnamed',
          date: DateTime.tryParse(b['sent_at']?.toString() ?? '') ?? DateTime.now(),
          recipients: bcastRecipCount,
          deliveryRate: dRate,
        ));
      }

      final totalSent = accepted + delivered + sent + failed;
      final dRate = totalSent > 0 ? ((accepted + delivered + sent) / totalSent * 100) : 0.0;
      final fRate = totalSent > 0 ? (failed / totalSent * 100) : 0.0;
      final repeat = phoneAppearances.values.where((c) => c >= 2).length;
      final unreachable = phoneFailed.entries
          .where((e) => e.value == phoneBcastCount[e.key])
          .length;

      // Broadcast-driven conversations (messages within 48h of broadcast)
      int drivenConvs = 0;
      if (client.hasFeature('conversations')) {
        try {
          final msgTable = _getMessagesTable(client);
          for (final b in broadcasts) {
            final sentAt = DateTime.tryParse(b['sent_at']?.toString() ?? '');
            if (sentAt == null) continue;
            final cutoff = sentAt.add(const Duration(hours: 48));
            final msgs = await SupabaseService.adminClient
                .from(msgTable)
                .select('customer_phone')
                .gte('created_at', sentAt.toIso8601String())
                .lte('created_at', cutoff.toIso8601String());
            final recPhones = (recipByBcast[b['id'].toString()] ?? [])
                .map((r) => r['customer_phone'] as String? ?? '')
                .toSet();
            for (final m in (msgs as List)) {
              if (recPhones.contains(m['customer_phone'])) drivenConvs++;
            }
          }
        } catch (_) {}
      }

      final result = BroadcastMetrics(
        totalCampaigns: broadcasts.length,
        totalRecipientsReached: totalRecipients,
        deliveryRate: dRate,
        failRate: fRate,
        avgCampaignSize: broadcasts.isNotEmpty
            ? totalRecipients / broadcasts.length
            : 0,
        totalOfferValue: totalOffer,
        avgOfferPerCampaign: offerCount > 0 ? totalOffer / offerCount : 0,
        broadcastDrivenConversations: drivenConvs,
        acceptedCount: accepted,
        deliveredCount: delivered,
        sentCount: sent,
        failedCount: failed,
        campaigns: campaignList,
        repeatRecipients: repeat,
        uniqueReach: allPhones.length,
        unreachableCount: unreachable,
      );
      _bcastMetricsCache[key] = result;
      notifyListeners();
      print('ANALYTICS: broadcast metrics loaded for ${client.name} (${broadcasts.length} campaigns)');
      return result;
    } catch (e) {
      print('ANALYTICS: broadcast metrics error for ${client.name}: $e');
      rethrow;
    }
  }

  // ─── MANAGER CHAT METRICS ─────────────────────────────────

  Future<ManagerChatMetrics> fetchManagerChatMetrics(
      Client client, {DateTime? start, DateTime? end}) async {
    final key = _cacheKey(client.id, start, end);
    final table = client.managerChatsTable;
    if (table == null || table.isEmpty) {
      return const ManagerChatMetrics(totalQueries: 0, uniqueUsers: 0);
    }
    try {
      final rows = await _fetchAllRows(table, 'user_name,created_at', start: start, end: end, orderBy: 'created_at');

      final userMap = <String, List<DateTime>>{};
      final dailyUsage = <String, int>{};
      final hourUsage = <int, int>{};

      for (final r in rows) {
        final user = r['user_name'] as String? ?? 'Unknown';
        final ca = DateTime.tryParse(r['created_at']?.toString() ?? '');
        userMap.putIfAbsent(user, () => []);
        if (ca != null) {
          userMap[user]!.add(ca);
          final dayKey = '${ca.year}-${ca.month.toString().padLeft(2, '0')}-${ca.day.toString().padLeft(2, '0')}';
          dailyUsage[dayKey] = (dailyUsage[dayKey] ?? 0) + 1;
          hourUsage[ca.hour] = (hourUsage[ca.hour] ?? 0) + 1;
        }
      }

      final perUser = userMap.entries.map((e) => UserQuerySummary(
            userName: e.key,
            queryCount: e.value.length,
            lastQuery: e.value.isNotEmpty ? e.value.last : DateTime.now(),
          )).toList()
        ..sort((a, b) => b.queryCount.compareTo(a.queryCount));

      final result = ManagerChatMetrics(
        totalQueries: rows.length,
        uniqueUsers: userMap.length,
        perUserBreakdown: perUser,
        dailyUsage: dailyUsage,
        usageByHour: hourUsage,
      );
      _mchatMetricsCache[key] = result;
      notifyListeners();
      print('ANALYTICS: manager chat metrics loaded for ${client.name} (${rows.length} queries)');
      return result;
    } catch (e) {
      print('ANALYTICS: manager chat metrics error for ${client.name}: $e');
      rethrow;
    }
  }

  // ─── LABEL METRICS ────────────────────────────────────────

  Future<LabelMetrics?> fetchLabelMetrics(
      Client client, {DateTime? start, DateTime? end}) async {
    final key = _cacheKey(client.id, start, end);
    final msgTable = _getMessagesTable(client);
    try {
      final rows = await _fetchAllRows(msgTable, 'label,customer_phone,created_at', start: start, end: end);

      final dist = <String, int>{};
      final uniquePerLabel = <String, Set<String>>{};
      final weeklyTrend = <String, Map<String, int>>{};

      for (final r in rows) {
        final label = r['label'] as String? ?? '';
        if (label.isEmpty) continue;
        dist[label] = (dist[label] ?? 0) + 1;
        final phone = r['customer_phone'] as String? ?? '';
        if (phone.isNotEmpty) {
          uniquePerLabel.putIfAbsent(label, () => {}).add(phone);
        }
        final ca = DateTime.tryParse(r['created_at']?.toString() ?? '');
        if (ca != null) {
          // ISO week key
          final weekNum = ((ca.difference(DateTime(ca.year, 1, 1)).inDays) / 7).floor() + 1;
          final weekKey = '${ca.year}-W${weekNum.toString().padLeft(2, '0')}';
          weeklyTrend.putIfAbsent(weekKey, () => {});
          weeklyTrend[weekKey]![label] = (weeklyTrend[weekKey]![label] ?? 0) + 1;
        }
      }

      if (dist.isEmpty) return null; // No label data

      final byUnique = uniquePerLabel.map((k, v) => MapEntry(k, v.length));

      final result = LabelMetrics(
        labelDistribution: dist,
        labelByUniqueCustomer: byUnique,
        weeklyLabelTrend: weeklyTrend,
      );
      _labelMetricsCache[key] = result;
      notifyListeners();
      print('ANALYTICS: label metrics loaded for ${client.name} (${dist.length} labels)');
      return result;
    } catch (e) {
      // Column doesn't exist
      print('ANALYTICS: label metrics not available for ${client.name}: $e');
      return null;
    }
  }

  // ─── PREDICTIVE METRICS ───────────────────────────────────

  Future<PredictiveMetrics?> fetchPredictiveMetrics(Client client) async {
    final key = _cacheKey(client.id, null, null);
    final table = client.customerPredictionsTable;
    if (table == null || table.isEmpty) return null;
    try {
      final rows = await _fetchAllRows(table, '*');

      final catDist = <String, int>{};
      final services = <String, int>{};
      int atRisk = 0, lapsed = 0, dueThisWeek = 0, overdue = 0;
      double totalGap = 0;
      int gapCount = 0;
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      for (final r in rows) {
        final cat = r['category'] as String? ?? 'Unknown';
        catDist[cat] = (catDist[cat] ?? 0) + 1;
        if (cat == 'At Risk') atRisk++;
        if (cat == 'Lapsed') lapsed++;

        final service = r['primary_service'] as String?;
        if (service != null && service.isNotEmpty) {
          services[service] = (services[service] ?? 0) + 1;
        }

        final gap = (r['avg_gap_days'] as num?)?.toDouble();
        if (gap != null && gap > 0) {
          totalGap += gap;
          gapCount++;
        }

        final predicted = DateTime.tryParse(r['predicted_next_visit']?.toString() ?? '');
        if (predicted != null) {
          if (predicted.isBefore(now)) overdue++;
          else if (predicted.isBefore(weekFromNow)) dueThisWeek++;
        }
      }

      final total = rows.length;
      final regularReturning = (catDist['Regular'] ?? 0) + (catDist['Returning'] ?? 0);
      final retention = total > 0 ? (regularReturning / total * 100) : 0.0;

      final result = PredictiveMetrics(
        categoryDistribution: catDist,
        retentionRate: retention,
        atRiskCount: atRisk,
        lapsedCount: lapsed,
        dueThisWeek: dueThisWeek,
        overdueCount: overdue,
        topServices: services,
        avgGapDays: gapCount > 0 ? totalGap / gapCount : 0,
        totalCustomers: total,
      );
      _predMetricsCache[key] = result;
      notifyListeners();
      print('ANALYTICS: predictive metrics loaded for ${client.name} ($total predictions)');
      return result;
    } catch (e) {
      print('ANALYTICS: predictive metrics error for ${client.name}: $e');
      return null;
    }
  }

  void clearFeatureCache() {
    _overviewCache.clear();
    _convMetricsCache.clear();
    _bcastMetricsCache.clear();
    _mchatMetricsCache.clear();
    _labelMetricsCache.clear();
    _predMetricsCache.clear();
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