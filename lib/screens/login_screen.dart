import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/agent_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController(text: 'manager@3bs.com');
  final _passwordController = TextEditingController(text: 'demo123');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final provider = context.read<AgentProvider>();
    final success = await provider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Login failed'),
          backgroundColor: VividColors.statusUrgent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: VividColors.darkGradient,
        ),
        child: Stack(
          children: [
            // Background glow effect
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2,
              left: MediaQuery.of(context).size.width * 0.5 - 300,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      VividColors.brightBlue.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 500;
                      final cardWidth = isNarrow
                          ? constraints.maxWidth * 0.9
                          : 440.0;
                      final padding = isNarrow ? 24.0 : 40.0;
                      final logoWidth = isNarrow ? 200.0 : 280.0;

                      return SingleChildScrollView(
                        child: Container(
                          width: cardWidth,
                          constraints: const BoxConstraints(maxWidth: 440),
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            color: VividColors.navy,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: VividColors.tealBlue.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: VividColors.darkNavy.withOpacity(0.8),
                                blurRadius: 60,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Full Logo (includes brand name)
                              VividWidgets.logo(width: logoWidth),
                              SizedBox(height: isNarrow ? 24 : 40),

                              // Welcome text
                              Text(
                                'Welcome Back',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to manage conversations',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 32),

                              // Email field
                              _buildTextField(
                                controller: _emailController,
                                label: 'EMAIL',
                                hint: 'Enter your email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20),

                              // Password field
                              _buildTextField(
                                controller: _passwordController,
                                label: 'PASSWORD',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),
                              const SizedBox(height: 32),

                              // Login button
                              Consumer<AgentProvider>(
                                builder: (context, provider, child) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: VividColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: VividColors.brightBlue.withOpacity(0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: provider.isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: provider.isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: VividColors.darkNavy,
                                                ),
                                              )
                                            : const Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: VividColors.darkNavy,
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Demo credentials hint
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: VividColors.deepBlue.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: VividColors.cyan.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: VividColors.cyan.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Demo: manager@3bs.com / demo123',
                                      style: TextStyle(
                                        color: VividColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: VividColors.textSecondary,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: const TextStyle(color: VividColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: VividColors.textMuted, size: 20),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),
      ],
    );
  }
}