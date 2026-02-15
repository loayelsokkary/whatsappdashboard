import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/agent_provider.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
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
                              _buildPasswordField(),
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
                              const SizedBox(height: 16),

                              // Forgot password link
                              Align(
                                alignment: Alignment.center,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    foregroundColor: VividColors.textMuted,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(fontSize: 13),
                                  ),
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

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSWORD',
          style: TextStyle(
            color: VividColors.textSecondary,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          style: const TextStyle(color: VividColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline, color: VividColors.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: VividColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
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

// ============================================
// FORGOT PASSWORD DIALOG (3-step flow)
// ============================================

enum _ResetStep { email, code, newPassword }

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  _ResetStep _step = _ResetStep.email;
  bool _isLoading = false;
  String? _error;
  String _email = '';
  String _generatedCode = '';

  // Controllers
  final _emailController = TextEditingController();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Resend cooldown
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _tickCooldown();
  }

  void _tickCooldown() {
    if (!mounted || _resendCooldown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _resendCooldown--);
      _tickCooldown();
    });
  }

  String _generateCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final service = SupabaseService.instance;

    // Check if email exists
    final userId = await service.getUserIdByEmail(email);
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No account found with this email';
      });
      return;
    }

    // Generate and save code
    _generatedCode = _generateCode();
    _email = email;

    final saved = await service.saveResetCode(email, _generatedCode);
    if (!saved) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to generate reset code. Try again.';
      });
      return;
    }

    // Send email via webhook
    final sent = await service.sendResetCodeEmail(email, _generatedCode);
    if (!sent) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to send reset email. Try again.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _step = _ResetStep.code;
    });
    _startResendCooldown();
  }

  Future<void> _handleResendCode() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _generatedCode = _generateCode();
    final service = SupabaseService.instance;

    final saved = await service.saveResetCode(_email, _generatedCode);
    if (!saved) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to generate new code';
      });
      return;
    }

    final sent = await service.sendResetCodeEmail(_email, _generatedCode);
    setState(() {
      _isLoading = false;
      _error = sent ? null : 'Failed to resend code';
    });
    if (sent) _startResendCooldown();
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final valid = await SupabaseService.instance.verifyResetCode(_email, code);
    if (!valid) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid or expired code. Please try again.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _step = _ResetStep.newPassword;
    });
  }

  Future<void> _handleResetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final code = _codeControllers.map((c) => c.text).join();
    final success = await SupabaseService.instance
        .resetPasswordByEmail(_email, newPassword, code);

    if (!success) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to reset password. Try again.';
      });
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! You can now sign in.'),
          backgroundColor: VividColors.statusSuccess,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VividColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (_step != _ResetStep.email)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: VividColors.textMuted, size: 20),
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _error = null;
                        if (_step == _ResetStep.code) {
                          _step = _ResetStep.email;
                        } else {
                          _step = _ResetStep.code;
                        }
                      });
                    },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (_step != _ResetStep.email) const SizedBox(width: 8),
          Text(
            _step == _ResetStep.email
                ? 'Reset Password'
                : _step == _ResetStep.code
                    ? 'Enter Code'
                    : 'New Password',
            style: const TextStyle(color: VividColors.textPrimary, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == _ResetStep.email) _buildEmailStep(),
            if (_step == _ResetStep.code) _buildCodeStep(),
            if (_step == _ResetStep.newPassword) _buildNewPasswordStep(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: VividColors.statusUrgent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleStepAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: VividColors.brightBlue,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _step == _ResetStep.email
                      ? 'Send Code'
                      : _step == _ResetStep.code
                          ? 'Verify'
                          : 'Reset Password',
                ),
        ),
      ],
    );
  }

  void _handleStepAction() {
    switch (_step) {
      case _ResetStep.email:
        _handleSendCode();
        break;
      case _ResetStep.code:
        _handleVerifyCode();
        break;
      case _ResetStep.newPassword:
        _handleResetPassword();
        break;
    }
  }

  Widget _buildEmailStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter your email and we\'ll send you a verification code to reset your password.',
          style: TextStyle(color: VividColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: VividColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icon(Icons.email_outlined, color: VividColors.textMuted, size: 20),
          ),
          onSubmitted: (_) => _handleSendCode(),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A 6-digit code has been sent to $_email',
          style: const TextStyle(color: VividColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              child: TextField(
                controller: _codeControllers[i],
                focusNode: _codeFocusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  color: VividColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: VividColors.brightBlue, width: 2),
                  ),
                  filled: true,
                  fillColor: VividColors.deepBlue,
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && i < 5) {
                    _codeFocusNodes[i + 1].requestFocus();
                  } else if (value.isEmpty && i > 0) {
                    _codeFocusNodes[i - 1].requestFocus();
                  }
                  // Auto-verify when all 6 digits are entered
                  if (i == 5 && value.isNotEmpty) {
                    final code = _codeControllers.map((c) => c.text).join();
                    if (code.length == 6) _handleVerifyCode();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _resendCooldown > 0 || _isLoading ? null : _handleResendCode,
            child: Text(
              _resendCooldown > 0
                  ? 'Resend code in ${_resendCooldown}s'
                  : 'Resend Code',
              style: TextStyle(
                color: _resendCooldown > 0 ? VividColors.textMuted : VividColors.brightBlue,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create a new password for your account.',
          style: TextStyle(color: VividColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newPasswordController,
          obscureText: !_showNewPassword,
          style: const TextStyle(color: VividColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'New password (min 6 characters)',
            prefixIcon: const Icon(Icons.lock_outline, color: VividColors.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _showNewPassword ? Icons.visibility_off : Icons.visibility,
                color: VividColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_showConfirmPassword,
          style: const TextStyle(color: VividColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Confirm new password',
            prefixIcon: const Icon(Icons.lock_outline, color: VividColors.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: VividColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
          ),
          onSubmitted: (_) => _handleResetPassword(),
        ),
      ],
    );
  }
}