import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/game_data.dart';
import '../core/login_gate.dart';
import '../theme/app_theme.dart';
import 'change_password_screen.dart';
import 'data_export_screen.dart';

/// Privacy & Security — real account controls:
///  • leaderboard visibility (enforced server-side on every ranking query)
///  • data export (everything the server stores about you)
///  • sign out everywhere (revokes all sessions)
///  • delete account (permanent, cascades all data)
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  GameData get game => GameData.instance;

  bool get _hasAccount => game.isLoggedIn && !game.isGuest;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _deleteAccount() async {
    if (!await ensureSignedIn(context)) return;
    if (!mounted) return;

    TextEditingController passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes your account, progress, coins, '
              'achievements and battle history. It cannot be undone.',
              style: TextStyle(height: 1.45, fontSize: 13.5),
            ),
            if (!game.isGuest) ...[
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm with your password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ApiClient.instance.deleteAccount(
        password: game.isGuest ? null : passwordController.text,
      );
      await game.logout();
      _message('Your account and data were deleted. Local progress stays on this device.');
    } on ApiException catch (err) {
      _message(err.isNetworkError
          ? 'You need a connection to delete your account.'
          : err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Privacy & Security',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _group(
            title: 'Visibility',
            children: [
              SwitchTile(
                icon: Icons.leaderboard_rounded,
                title: 'Show me on the leaderboard',
                subtitle: game.isLoggedIn
                    ? 'When off, other players will not see you in any ranking.'
                    : 'Sign in to control whether other players can see you.',
                value: game.isLoggedIn ? game.leaderboardPublic : false,
                onChanged: _hasAccount
                    ? (value) async {
                        await game.setLeaderboardPublic(value);
                        _message(value
                            ? 'You are visible on leaderboards again.'
                            : 'You are hidden from leaderboards.');
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _group(
            title: 'Your data',
            children: [
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppColors.purple),
                title: const Text('Download my data',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text(
                    'Export everything the server stores about your account.',
                    style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () async {
                  if (!await ensureSignedIn(context)) return;
                  if (!context.mounted) return;
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DataExportScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _group(
            title: 'Security',
            children: [
              if (_hasAccount) ...[
                ListTile(
                  leading: const Icon(Icons.password_rounded, color: AppColors.purple),
                  title: const Text('Change password',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Also signs out your other devices.',
                      style: TextStyle(fontSize: 11)),
                  trailing:
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.devices_rounded, color: AppColors.purple),
                  title: const Text('Sign out everywhere',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text(
                      'Revoke every session, including this device.',
                      style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () async {
                    final ok = await _confirm(
                      'Sign out everywhere?',
                      'Every signed-in device will be logged out, including this one.',
                    );
                    if (ok != true) return;
                    await ApiClient.instance.logoutAll();
                    await game.logout();
                    _message('All sessions revoked — you are signed out.');
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: Colors.grey),
                  title: const Text('Account security',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text(
                      'Sign in to manage passwords and sessions.',
                      style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => ensureSignedIn(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _group(
            title: 'Danger zone',
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text('Delete account',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.redAccent)),
                subtitle: const Text(
                    'Permanently remove your account and all its data.',
                    style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: _deleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.4, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _group({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink.withValues(alpha: 0.5))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.purple, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.purple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
