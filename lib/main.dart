import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/supabase_service.dart';
import 'providers/conversations_provider.dart';
import 'providers/agent_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/broadcast_analytics_provider.dart';
import 'providers/admin_analytics_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/ai_settings_provider.dart';
import 'providers/broadcasts_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/manager_chat_provider.dart';
import 'providers/user_management_provider.dart';
import 'providers/booking_reminders_provider.dart';
import 'providers/activity_logs_provider.dart';
import 'models/models.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/broadcast_analytics_screen.dart';
import 'screens/admin_panel.dart';
import 'widgets/sidebar.dart';
import 'widgets/broadcasts_panel.dart';
import 'widgets/manager_chat_panel.dart';
import 'widgets/booking_reminders_panel.dart';
import 'widgets/activity_logs_panel.dart';
import 'theme/vivid_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const VividDashboardApp());
}

class VividDashboardApp extends StatelessWidget {
  const VividDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AgentProvider()),
        ChangeNotifierProvider(create: (_) => ConversationsProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => BroadcastAnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => AdminAnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AiSettingsProvider()),
        ChangeNotifierProvider(create: (_) => BroadcastsProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ManagerChatProvider()),
        ChangeNotifierProvider(create: (_) => UserManagementProvider()),
        ChangeNotifierProvider(create: (_) => BookingRemindersProvider()),
        ChangeNotifierProvider(create: (_) => ActivityLogsProvider()),
      ],
      child: MaterialApp(
        title: 'Vivid Dashboard',
        debugShowCheckedModeBanner: false,
        theme: VividTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Handles auth state and routes to appropriate screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Attempt to restore session from sessionStorage
    final agentProvider = context.read<AgentProvider>();
    Future.microtask(() => agentProvider.restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final agentProvider = context.watch<AgentProvider>();

    // Show loading indicator while checking session
    if (agentProvider.isRestoringSession) {
      return const Scaffold(
        backgroundColor: VividColors.darkNavy,
        body: Center(
          child: CircularProgressIndicator(color: VividColors.tealBlue),
        ),
      );
    }

    if (!agentProvider.isAuthenticated) {
      return const LoginScreen();
    }

    // Route based on user type
    // Only Vivid super admins (admin role + NO client_id) go to AdminPanel
    // Client admins (admin role + HAS client_id) go to MainScaffold like other client users
    if (ClientConfig.isVividAdmin) {
      return const AdminPanel();
    } else {
      return const MainScaffold();
    }
  }
}

/// Main app scaffold with sidebar and content area (for client users)
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  NavDestination? _currentDestination;

  @override
  void initState() {
    super.initState();
    // Set default destination based on enabled AND configured features
    _setDefaultDestination();
    
    // Initialize providers ONLY for properly configured features
    Future.microtask(() {
      // Only initialize conversations if properly configured
      if (_isFeatureConfigured('conversations')) {
        context.read<ConversationsProvider>().initialize();
        context.read<NotificationProvider>().initialize();
        context.read<AiSettingsProvider>().fetchAllSettings();
      }
      
      // Only initialize broadcasts if properly configured
      if (_isFeatureConfigured('broadcasts')) {
        context.read<BroadcastsProvider>().fetchBroadcasts();
        context.read<BroadcastAnalyticsProvider>().fetchAnalytics();
      }
      
      // Only initialize booking reminders if properly configured
      if (_isFeatureConfigured('booking_reminders')) {
        final tableName = ClientConfig.bookingsTable;
        if (tableName != null && tableName.isNotEmpty) {
          context.read<BookingRemindersProvider>().initialize(tableName);
        }
      }
      
      // Initialize activity logs for client admins
      if (ClientConfig.isClientAdmin) {
        context.read<ActivityLogsProvider>().fetchLogs(clientId: ClientConfig.currentClient?.id);
      }
    });
  }

  /// Check if feature is enabled AND has required configuration (webhook/phone)
  /// IMPORTANT: Only check per-feature fields, not legacy fields (which might be shared across clients)
  bool _isFeatureConfigured(String feature) {
    if (!ClientConfig.hasFeature(feature)) return false;
    
    final client = ClientConfig.currentClient;
    if (client == null) return false;
    
    switch (feature) {
      case 'conversations':
        // Must have dedicated conversations phone to load conversation data
        final hasPhone = client.conversationsPhone != null && client.conversationsPhone!.isNotEmpty;
        return hasPhone;
        
      case 'broadcasts':
        // Must have dedicated broadcasts phone/webhook
        final hasWebhook = client.broadcastsWebhookUrl != null && client.broadcastsWebhookUrl!.isNotEmpty;
        final hasPhone = client.broadcastsPhone != null && client.broadcastsPhone!.isNotEmpty;
        return hasWebhook || hasPhone;
        
      case 'booking_reminders':
        final hasTable = client.bookingsTable != null && client.bookingsTable!.isNotEmpty;
        return hasTable;
        
      case 'manager_chat':
        // Must have dedicated manager chat webhook
        final hasWebhook = client.managerChatWebhookUrl != null && client.managerChatWebhookUrl!.isNotEmpty;
        return hasWebhook;
        
      case 'analytics':
        // Analytics is available if ANY feature with data is configured
        return _isFeatureConfigured('conversations') || _isFeatureConfigured('broadcasts');
        
      default:
        return true;
    }
  }

  void _setDefaultDestination() {
    // Set first available AND configured feature as default
    if (ClientConfig.hasFeature('conversations') && _isFeatureConfigured('conversations')) {
      _currentDestination = NavDestination.conversations;
    } else if (ClientConfig.hasFeature('broadcasts') && _isFeatureConfigured('broadcasts')) {
      _currentDestination = NavDestination.broadcasts;
    } else if (ClientConfig.hasFeature('booking_reminders') && _isFeatureConfigured('booking_reminders')) {
      _currentDestination = NavDestination.bookingReminders;
    } else if (ClientConfig.hasFeature('manager_chat') && _isFeatureConfigured('manager_chat')) {
      _currentDestination = NavDestination.managerChat;
    } else if (ClientConfig.hasFeature('analytics')) {
      _currentDestination = NavDestination.analytics;
    } else if (ClientConfig.isClientAdmin) {
      // Client admins can always see activity logs
      _currentDestination = NavDestination.activityLogs;
    } else {
      // Fall back to first enabled feature even if not configured
      if (ClientConfig.hasFeature('conversations')) {
        _currentDestination = NavDestination.conversations;
      } else if (ClientConfig.hasFeature('broadcasts')) {
        _currentDestination = NavDestination.broadcasts;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VividColors.darkNavy,
      body: Row(
        children: [
          // Sidebar
          Sidebar(
            currentDestination: _currentDestination ?? NavDestination.conversations,
            onDestinationChanged: (destination) {
              setState(() {
                _currentDestination = destination;
              });
            },
          ),
          
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentDestination) {
      case NavDestination.conversations:
        return _buildConversationsContent();
      case NavDestination.broadcasts:
        return _buildBroadcastsContent();
      case NavDestination.bookingReminders:
        return _buildBookingRemindersContent();
      case NavDestination.managerChat:
        return _buildManagerChatContent();
      case NavDestination.analytics:
        // Show broadcast analytics for broadcast clients, regular for conversation clients
        if (ClientConfig.hasFeature('broadcasts') && !ClientConfig.hasFeature('conversations')) {
          return const BroadcastAnalyticsScreen();
        }
        return const AnalyticsScreen();
      case NavDestination.activityLogs:
        return _buildActivityLogsContent();
      default:
        return const Center(
          child: Text(
            'No features enabled',
            style: TextStyle(color: VividColors.textMuted),
          ),
        );
    }
  }

  /// Build conversations content with configuration check
  Widget _buildConversationsContent() {
    if (!_isFeatureConfigured('conversations')) {
      return _buildNotConfiguredPage(
        icon: Icons.chat_bubble_outline,
        title: 'Conversations Not Configured',
        description: 'Please contact your administrator to set up the conversations webhook and phone number.',
      );
    }
    return const DashboardScreen();
  }

  /// Build broadcasts content with read-only handling and configuration check
  Widget _buildBroadcastsContent() {
    if (!_isFeatureConfigured('broadcasts')) {
      return _buildNotConfiguredPage(
        icon: Icons.campaign_outlined,
        title: 'Broadcasts Not Configured',
        description: 'Please contact your administrator to set up the broadcasts webhook and phone number.',
      );
    }
    if (ClientConfig.currentUser?.isReadOnly ?? false) {
      return _buildReadOnlyWrapper(
        child: const BroadcastsPanel(),
        featureName: 'Broadcasts',
      );
    }
    return const BroadcastsPanel();
  }

  /// Build booking reminders content with configuration check
  Widget _buildBookingRemindersContent() {
    final tableName = ClientConfig.bookingsTable;
    if (tableName == null || tableName.isEmpty) {
      return _buildNotConfiguredPage(
        icon: Icons.calendar_month,
        title: 'Booking Reminders Not Configured',
        description: 'Please contact your administrator to set up the bookings table.',
      );
    }
    return BookingRemindersPanel(tableName: tableName);
  }

  /// Build manager chat content with permission handling and configuration check
  Widget _buildManagerChatContent() {
    if (!_isFeatureConfigured('manager_chat')) {
      return _buildNotConfiguredPage(
        icon: Icons.smart_toy_outlined,
        title: 'AI Assistant Not Configured',
        description: 'Please contact your administrator to set up the AI assistant webhook.',
      );
    }
    if (!ClientConfig.canPerformAction('use_manager_chat')) {
      return _buildReadOnlyWrapper(
        child: const ManagerChatPanel(),
        featureName: 'AI Assistant',
      );
    }
    return const ManagerChatPanel();
  }

  /// Build activity logs content for client admins
  Widget _buildActivityLogsContent() {
    if (!ClientConfig.isClientAdmin) {
      return _buildNotConfiguredPage(
        icon: Icons.lock_outline,
        title: 'Access Restricted',
        description: 'Activity logs are only available for administrators.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ActivityLogsPanel(
        clientId: ClientConfig.currentClient?.id,
        clientName: ClientConfig.currentClient?.name,
      ),
    );
  }

  /// Generic "Not Configured" page
  Widget _buildNotConfiguredPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: VividColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: VividColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: VividColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Wrapper to show read-only indicator
  Widget _buildReadOnlyWrapper({
    required Widget child,
    required String featureName,
  }) {
    return Stack(
      children: [
        child,
        // Read-only banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: VividColors.navy,
              border: Border(
                bottom: BorderSide(color: VividColors.tealBlue.withOpacity(0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: VividColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Viewing $featureName in read-only mode',
                  style: const TextStyle(
                    color: VividColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}