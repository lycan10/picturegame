import 'package:flutter/material.dart';

import '../core/game_data.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';

/// Sign-in sheet shown from the profile screen. Supports login, registration
/// and upgrading the current guest account (keeping all progress).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.isGuestUpgrade = false});

  /// When true the screen is presented as "save your progress" for a guest.
  final bool isGuestUpgrade;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  bool isRegisterMode = false;
  bool busy = false;
  bool _obscurePassword = true;
  String? error;

  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final focusNodeEmail = FocusNode();
  final focusNodeUsername = FocusNode();
  final focusNodePassword = FocusNode();

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    focusNodeEmail.dispose();
    focusNodeUsername.dispose();
    focusNodePassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear any previous submit error message first
    if (error != null) {
      setState(() => error = null);
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      busy = true;
    });

    final game = GameData.instance;
    String? err;
    try {
      if (isRegisterMode) {
        err = await game.register(
          emailController.text.trim(),
          usernameController.text.trim().toLowerCase(),
          passwordController.text,
        );
      } else {
        err = await game.login(
          emailController.text.trim(),
          passwordController.text,
        );
      }
    } catch (e) {
      err = e.toString();
    }

    if (!mounted) return;

    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Signed in — progress synced!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      setState(() {
        busy = false;
        error = err;
      });
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon, color: AppColors.ink.withValues(alpha: 0.5), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.purple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          widget.isGuestUpgrade
              ? 'Save Your Progress'
              : (isRegisterMode ? 'Create Account' : 'Welcome Back'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subtitle / Header info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isGuestUpgrade
                            ? Icons.cloud_upload_rounded
                            : Icons.sports_esports_rounded,
                        color: AppColors.purple,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.isGuestUpgrade
                              ? 'Create a free account to keep your coins, streak and stars safe across devices and win cash prizes.'
                              : 'Sign in to sync your progress and win cash prizes.',
                          style: TextStyle(
                            color: AppColors.ink.withValues(alpha: 0.8),
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Email field
                TextFormField(
                  controller: emailController,
                  focusNode: focusNodeEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction:
                      isRegisterMode ? TextInputAction.next : TextInputAction.next,
                  enabled: !busy,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex =
                        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  decoration: _buildInputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                ),

                // Animated username field (only visible in register mode)
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: isRegisterMode
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextFormField(
                      controller: usernameController,
                      focusNode: focusNodeUsername,
                      textInputAction: TextInputAction.next,
                      enabled: !busy && isRegisterMode,
                      validator: (value) {
                        if (!isRegisterMode) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a username';
                        }
                        final username = value.trim();
                        if (username.length < 3 || username.length > 20) {
                          return 'Username must be 3-20 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                          return 'Only letters, numbers, and underscores allowed';
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        label: 'Username',
                        icon: Icons.person_outline_rounded,
                        helperText: '3-20 characters: a-z, 0-9, underscore',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: passwordController,
                  focusNode: focusNodePassword,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  enabled: !busy,
                  onFieldSubmitted: (_) => busy ? null : _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (isRegisterMode && value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                  decoration: _buildInputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    helperText:
                        isRegisterMode ? 'At least 8 characters' : null,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.ink.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                // Dynamic Error Banner
                if (error != null) ...[
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Submit Button
                FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    disabledBackgroundColor:
                        AppColors.purple.withValues(alpha: 0.6),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.purple.withValues(alpha: 0.4),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isRegisterMode ? 'Create Account' : 'Sign In',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Secondary Navigation Action Buttons
                if (!isRegisterMode)
                  Center(
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen(),
                                ),
                              ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                Center(
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              isRegisterMode = !isRegisterMode;
                              error = null;
                            });
                          },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.ink.withValues(alpha: 0.7),
                        ),
                        children: [
                          TextSpan(
                            text: isRegisterMode
                                ? 'Already have an account? '
                                : 'New here? ',
                          ),
                          TextSpan(
                            text: isRegisterMode ? 'Sign In' : 'Create an Account',
                            style: const TextStyle(
                              color: AppColors.purple,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}