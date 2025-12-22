import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/supabase_service.dart';
import 'providers/conversations_provider.dart';
import 'providers/agent_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/ai_settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'widgets/sidebar.dart';
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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AiSettingsProvider()),
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

/// Handles auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final agentProvider = context.watch<AgentProvider>();

    if (agentProvider.isAuthenticated) {
      return const MainScaffold();
    } else {
      return const LoginScreen();
    }
  }
}

/// Main app scaffold with sidebar and content area
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  NavDestination _currentDestination = NavDestination.conversations;

  @override
  void initState() {
    super.initState();
    // Initialize providers
    Future.microtask(() {
      context.read<ConversationsProvider>().initialize();
      context.read<NotificationProvider>().initialize();
      context.read<AiSettingsProvider>().fetchAllSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VividColors.darkNavy,
      body: Row(
        children: [
          // Sidebar
          Sidebar(
            currentDestination: _currentDestination,
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
      case NavDestination.analytics:
        return const AnalyticsScreen();
    }
  }
}