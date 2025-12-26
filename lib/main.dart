import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/supabase_service.dart';
import 'providers/conversations_provider.dart';
import 'providers/agent_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/broadcast_analytics_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/ai_settings_provider.dart';
import 'providers/broadcasts_provider.dart';
import 'providers/admin_provider.dart';
import 'models/models.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/broadcast_analytics_screen.dart';
import 'screens/admin_panel.dart';
import 'widgets/sidebar.dart';
import 'widgets/broadcasts_panel.dart';
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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AiSettingsProvider()),
        ChangeNotifierProvider(create: (_) => BroadcastsProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
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
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final agentProvider = context.watch<AgentProvider>();

    if (!agentProvider.isAuthenticated) {
      return const LoginScreen();
    }

    // Route based on user type
    if (agentProvider.isAdmin) {
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
    // Set default destination based on enabled features
    _setDefaultDestination();
    
    // Initialize providers based on enabled features
    Future.microtask(() {
      if (ClientConfig.hasFeature('conversations')) {
        context.read<ConversationsProvider>().initialize();
        context.read<NotificationProvider>().initialize();
        context.read<AiSettingsProvider>().fetchAllSettings();
      }
      if (ClientConfig.hasFeature('broadcasts')) {
        context.read<BroadcastsProvider>().fetchBroadcasts();
        context.read<BroadcastAnalyticsProvider>().fetchAnalytics();
      }
    });
  }

  void _setDefaultDestination() {
    // Set first available feature as default
    if (ClientConfig.hasFeature('conversations')) {
      _currentDestination = NavDestination.conversations;
    } else if (ClientConfig.hasFeature('broadcasts')) {
      _currentDestination = NavDestination.broadcasts;
    } else if (ClientConfig.hasFeature('analytics')) {
      _currentDestination = NavDestination.analytics;
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
        return const DashboardScreen();
      case NavDestination.broadcasts:
        return const BroadcastsPanel();
      case NavDestination.analytics:
        // Show broadcast analytics for broadcast clients, regular for conversation clients
        if (ClientConfig.hasFeature('broadcasts') && !ClientConfig.hasFeature('conversations')) {
          return const BroadcastAnalyticsScreen();
        }
        return const AnalyticsScreen();
      default:
        return const Center(
          child: Text(
            'No features enabled',
            style: TextStyle(color: VividColors.textMuted),
          ),
        );
    }
  }
}