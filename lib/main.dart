import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/vivid_theme.dart';
import 'providers/conversations_provider.dart';
import 'providers/agent_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
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
      ],
      child: MaterialApp(
        title: 'Vivid Dashboard',
        debugShowCheckedModeBanner: false,
        theme: VividTheme.darkTheme,
        home: Consumer<AgentProvider>(
          builder: (context, agentProvider, child) {
            if (agentProvider.isAuthenticated) {
              return const DashboardScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}