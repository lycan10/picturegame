import 'package:flutter/material.dart';

import 'game_data.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';

/// Feature gates for account-backed features (purchases, ad rewards, battles,
/// achievement claims, live leaderboards). Gameplay and offline progress stay
/// open to everyone — anything that needs a server identity requires a real
/// (non-guest) account, and guests are routed through the upgrade flow so
/// their existing progress is preserved.
///
/// The gate is ONE consistent "Sign in to unlock" modal used everywhere in
/// the app (no snackbars, no bottom sheets) so the sign-in pitch always looks
/// and behaves the same.
Future<bool> ensureSignedIn(
  BuildContext context, {
  String? title,
  String? message,
}) async {
  final game = GameData.instance;
  if (game.isLoggedIn && !game.isGuest) return true;

  final isGuest = game.isLoggedIn && game.isGuest;
  final effectiveTitle = title ?? (isGuest ? 'Save your progress' : 'Sign in to unlock');
  final effectiveMessage = message ??
      (isGuest
          ? 'You are playing as a guest. Create a free account to keep your '
              'coins, streak and stars — and to use this feature.'
          : 'This feature needs an account so your progress, purchases and '
              'rankings stay safe. Sign in to unlock every world and level, '
              'battles with friends, leaderboards, achievements and daily '
              'rewards.');

  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(effectiveTitle,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      content: Text(effectiveMessage,
          style: const TextStyle(height: 1.45, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now', style: TextStyle(color: Colors.grey)),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'account'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: Text(
            isGuest ? 'Create free account' : 'Sign in',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  if (action != 'account' || !context.mounted) return false;

  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => LoginScreen(isGuestUpgrade: isGuest),
    ),
  );

  final after = GameData.instance;
  return after.isLoggedIn && !after.isGuest;
}
