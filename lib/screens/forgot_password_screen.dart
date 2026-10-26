import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';

/// Two-step password reset: request an emailed 6-digit code, then set a new
/// password with it. Uses [ApiClient] directly — no session involved.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool codeSent = false;
  bool busy = false;
  String? error;

  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => error = 'Enter the email address on your account');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final json = await ApiClient.instance.forgotPassword(email);
      if (!mounted) return;
      final devCode = json['devCode'] as String?;
      final delivered = json['emailDelivered'] != false;
      setState(() {
        codeSent = true;
        busy = false;
      });
      if (devCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dev mode (SMTP off) — your code is $devCode'),
        ));
      } else if (!delivered) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'We created your code but the email could not be sent right now. '
            'Please try again in a minute.',
          ),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('If that email is registered, a 6-digit code is on its way.'),
        ));
      }
    } on ApiException catch (err) {
      setState(() {
        busy = false;
        error = err.message;
      });
    }
  }

  Future<void> _resetPassword() async {
    final code = codeController.text.trim();
    final password = passwordController.text;
    if (code.length != 6) {
      setState(() => error = 'Enter the 6-digit code from the email');
      return;
    }
    if (password.length < 8) {
      setState(() => error = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirmController.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ApiClient.instance.resetPassword(
        email: emailController.text.trim(),
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password updated — sign in with the new one.'),
      ));
      Navigator.pop(context);
    } on ApiException catch (err) {
      setState(() {
        busy = false;
        error = err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          codeSent ? 'Check your email' : 'Reset password',
          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              codeSent
                  ? 'Enter the 6-digit code we emailed to ${emailController.text.trim()} and choose a new password. The code expires in 30 minutes.'
                  : "Enter your account email and we'll send you a 6-digit code to reset your password.",
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: 0.65),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (!codeSent) ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 8 characters',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : (codeSent ? _resetPassword : _requestCode),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                minimumSize: const Size(0, 52),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      codeSent ? 'Set new password' : 'Send code',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            if (codeSent) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : _requestCode,
                child: const Text(
                  'Resend code',
                  style: TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
