import 'package:flutter/material.dart';

import 'game_data.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';

/// Feature gates for account-backed features (purchases, ad rewards, battles,
/// achievement claims, live leaderboards). Gameplay and offline progress stay
/// open to everyone — anything that needs a server identity requires a real
/// (non-guest) account, and guests are routed through the upgrade flow so
/// their existing progress is preserved.
Future<bool> ensureSignedIn(BuildContext context) async {
  final game = GameData.instance;
  if (game.isLoggedIn && !game.isGuest) return true;

  final isGuest = game.isLoggedIn && game.isGuest;

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(Icons.lock_rounded, size: 34, color: AppColors.purple),
            ),
            const SizedBox(height: 14),
            Text(
              isGuest ? 'Save your progress' : 'Sign in required',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isGuest
                  ? 'You are playing as a guest. Create a free account to keep your coins, streak and stars — and to use this feature.'
                  : 'This feature needs an account so your progress, purchases and rankings stay safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.ink.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, 'account'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                minimumSize: const Size(0, 50),
              ),
              child: Text(
                isGuest ? 'Create free account' : 'Sign in / Create account',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, null),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
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
