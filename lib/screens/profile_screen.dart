import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/notification_service.dart';
import '../core/game_data.dart';
import '../core/formatters.dart';
import '../theme/app_theme.dart';
import 'achievement_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';
import 'friends_screen.dart';
import 'payout_details_screen.dart';
import 'privacy_security_screen.dart';
import 'sound_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  GameData get game => GameData.instance;

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameData);
    game.refreshProfile();
  }

  @override
  void dispose() {
    game.removeListener(_onGameData);
    super.dispose();
  }

  void _onGameData() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = game.isLoggedIn;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (_showEmailVerificationBanner) ...[
                const SizedBox(height: 16),
                _buildVerificationBanner(),
              ],
              const SizedBox(height: 24),
              _buildProfileCard(),
              // Signed-out state: the profile is viewable, but account-backed
              // features get an explicit sign-in call to action.
              if (!signedIn) ...[
                const SizedBox(height: 16),
                _buildSignedOutCard(),
              ],
              const SizedBox(height: 24),
              _buildStatistics(),
              const SizedBox(height: 28),
              _buildSectionTitle('Achievements', 'View all'),
              const SizedBox(height: 14),
              _buildAchievements(),
              const SizedBox(height: 28),
              _buildSectionTitle('Account', null),
              const SizedBox(height: 14),
              _buildAccountOptions(context),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'PICTURE MATCH  •  VERSION 1.0.0',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown only when playing without an account.
  Widget _buildSignedOutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_sync_rounded, size: 20, color: AppColors.purple),
              SizedBox(width: 10),
              Text(
                'Your progress is local only',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Create a free account to sync across devices, appear on the '
            'leaderboard, battle friends and buy coins.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: const Text('Sign in / Create account',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your journey, your achievements.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.person_outline_rounded,
          size: 28,
          color: AppColors.purple,
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7057E8),
            Color(0xFF9786F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 94,
                height: 94,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD76A),
                    width: 4,
                  ),
                ),
                child: ClipOval(
                  child: _avatarContent(),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 2,
                child: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD76A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            game.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '@${game.username}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(
                  FontAwesomeIcons.medal,
                  size: 15,
                  color: Color(0xFFFFD76A),
                ),
                const SizedBox(width: 8),
                Text(
                  game.isGuest
                      ? 'Guest — tap Edit to save progress'
                      : 'Level ${_playerTitleLevel()} ${_playerTitle()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => game.isLoggedIn && !game.isGuest
                        ? const EditProfileScreen()
                        : LoginScreen(
                            isGuestUpgrade: game.isLoggedIn && game.isGuest,
                          ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(game.isLoggedIn && !game.isGuest
                  ? 'Edit Profile'
                  : 'Sign in to sync'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Uploaded photo when present, otherwise the emoji avatar.
  Widget _avatarContent() {
    final photoUrl = game.avatarNetworkUrl();
    if (photoUrl == null) {
      return Center(
        child: Text(
          game.avatarEmoji,
          style: const TextStyle(fontSize: 52),
        ),
      );
    }
    return Image.network(
      photoUrl,
      width: 94,
      height: 94,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(
        child: Text(
          game.avatarEmoji,
          style: const TextStyle(fontSize: 52),
        ),
      ),
    );
  }

  bool get _showEmailVerificationBanner =>
      game.isLoggedIn && !game.isGuest && !game.emailVerified;

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD76A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              size: 22, color: Color(0xFF9A6B00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Confirm your email to keep your account recoverable.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF7A5500),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _showVerifyEmailDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Verify',
              style: TextStyle(
                color: Color(0xFF9A6B00),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Code entry dialog for email confirmation, with resend.
  Future<void> _showVerifyEmailDialog() async {
    final codeController = TextEditingController();
    String? dialogError;
    String? dialogInfo;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Verify your email'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 6-digit code we emailed to ${game.user?['email'] ?? 'your address'}.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  border: OutlineInputBorder(),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              if (dialogInfo != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogInfo!,
                  style: const TextStyle(
                    color: Color(0xFF38B878),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() {
                        sending = true;
                        dialogError = null;
                        dialogInfo = null;
                      });
                      final err =
                          await GameData.instance.resendVerificationEmail();
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        sending = false;
                        if (err != null) {
                          dialogError = err;
                        } else {
                          dialogInfo = 'A fresh code is on its way — check your inbox.';
                        }
                      });
                    },
              child: const Text('Resend code'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) {
                        setDialogState(
                            () => dialogError = 'Enter the 6-digit code');
                        return;
                      }
                      setDialogState(() {
                        sending = true;
                        dialogError = null;
                      });
                      final err = await GameData.instance.verifyEmailCode(code);
                      if (!dialogContext.mounted) return;
                      if (err == null) {
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        _showMessage(context, 'Email verified — thanks!');
                      } else {
                        setDialogState(() {
                          sending = false;
                          dialogError = err;
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
              ),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
  }

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.stars_rounded,
            value: _formatNumber(game.totalScore),
            label: 'Total Points',
            color: const Color(0xFFFFB938),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_rounded,
            value: '${game.levelsToday + _completedLevelsCached()}',
            label: 'Levels Won',
            color: const Color(0xFF38B878),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department_rounded,
            value: '${game.streakDays} days',
            label: 'Streak',
            color: const Color(0xFFFF7959),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) => formatCount(number);

  int _completedLevelsCached() {
    var count = 0;
    for (final stars in game.bestStars.values) {
      count += stars.values.where((s) => s > 0).length;
    }
    return count;
  }

  int _playerTitleLevel() {
    final levels = _completedLevelsCached();
    return (levels / 3).floor() + 1;
  }

  String _playerTitle() {
    const titles = ['Rookie', 'Explorer', 'Adventurer', 'Master', 'Legend'];
    return titles[min(_playerTitleLevel() - 1, titles.length - 1)];
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String? action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: action == 'View all'
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AchievementsScreen()),
                    )
                : () {},
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.purple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  /// Four highlights from the real, server-computed achievement list —
  /// unlocked first, then the ones closest to unlocking. Full list in
  /// AchievementsScreen (via "View all").
  Widget _buildAchievements() {
    final byCategory = {
      'daily': (
        Icons.local_fire_department_rounded,
        const Color(0xFFFF8566),
      ),
      'battle': (
        Icons.sports_kabaddi_rounded,
        const Color(0xFF62B8FF),
      ),
      'skill': (
        Icons.bolt_rounded,
        const Color(0xFFFFC857),
      ),
      'progress': (
        Icons.workspace_premium_rounded,
        const Color(0xFFB5A0FF),
      ),
      'special': (
        Icons.auto_awesome_rounded,
        const Color(0xFF38B878),
      ),
    };

    final defs = [...game.achievements]
      ..sort((a, b) {
        // Unlocked first; within a group, closest to the target first.
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        final pa = a.progress / (a.target == 0 ? 1 : a.target);
        final pb = b.progress / (b.target == 0 ? 1 : b.target);
        return pb.compareTo(pa);
      });
    final highlights = defs.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: highlights.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final def = highlights[index];
        final (icon, color) =
            byCategory[def.category] ?? byCategory['progress']!;
        final unlocked = def.unlocked;
        final progressLabel = unlocked
            ? (def.claimed ? 'Claimed ✓' : 'Reward ready!')
            : '${def.progress}/${def.target}';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  unlocked ? color.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: unlocked ? 0.17 : 0.07,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: unlocked ? color : Colors.grey.shade400,
                  size: 23,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                def.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? AppColors.ink : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progressLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? color : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                def.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountOptions(BuildContext context) {
    final signedIn = game.isLoggedIn;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
        children: [
          Builder(builder: (_) {
            final n = NotificationService.instance;
            return _accountTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: n.reminderEnabled
                  ? 'Daily reminder at '
                      '${n.reminderHour.toString().padLeft(2, '0')}:'
                      '${n.reminderMinute.toString().padLeft(2, '0')}'
                  : 'Manage your reminders',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              ),
            );
          }),
          _divider(),
          _accountTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound & Music',
            subtitle: 'Control game sounds',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const SoundSettingsScreen()),
            ),
          ),
          _divider(),
          _accountTile(
            icon: Icons.people_alt_rounded,
            title: 'Friends',
            subtitle: 'Add friends, answer requests, battle together',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
          _divider(),
          _accountTile(
            icon: Icons.account_balance_rounded,
            title: 'Payout details',
            subtitle: 'Where your contest cash prizes are sent',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const PayoutDetailsScreen()),
            ),
          ),
          _divider(),
          _accountTile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy & Security',
            subtitle: 'Leaderboard visibility, data export, account deletion',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                  builder: (_) => const PrivacySecurityScreen()),
            ),
          ),
          _divider(),
          if (game.isLoggedIn && !game.isGuest) ...[
            _accountTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update your password and sign out other devices',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              ),
            ),
            _divider(),
          ],
          _accountTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'How to play, scoring, battles and contact',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
          if (signedIn) ...[
            _divider(),
            _accountTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Sign out of your account',
              color: Colors.redAccent,
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ],
        ),
      ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      color: Colors.grey.withValues(alpha: 0.12),
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = AppColors.purple,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: Container(
        width: 43,
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (GameData.instance.isLoggedIn) {
                GameData.instance.logout();
                _showMessage(
                  context,
                  'Logged out. Your local progress stays on this device.',
                );
              } else {
                _showMessage(
                  context,
                  'You are playing as a guest — nothing to sign out of.',
                );
              }
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
