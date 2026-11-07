import 'package:flutter/material.dart';
import '../core/ads_service.dart';
import '../core/game_data.dart';
import '../core/login_gate.dart';
import '../models/game_level.dart';
import '../theme/app_theme.dart';
import 'match_game_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  final String category;
  final Set<int> unlockedLevels;
  final Map<int, int> bestStars;
  final void Function(int levelIndex, int points, int stars)
      onLevelCompleted;

  const LevelSelectionScreen({
    super.key,
    required this.category,
    required this.unlockedLevels,
    required this.bestStars,
    required this.onLevelCompleted,
  });

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  final GameData game = GameData.instance;

  List<GameLevel> get levels => game.levelsFor(widget.category);

  /// Effective unlock set: guests are capped to the free-sample levels.
  Set<int> get effectiveUnlocked => game.unlockedLevelsFor(widget.category);

  /// Opens a level. Guests first watch a rewarded interstitial (the "ticket"
  /// for playing without an account); when no ad fills, they play anyway.
  Future<void> _openLevelAsGuest(int index) async {
    await AdsService.instance.showRewardedInterstitial(
      onDone: () => _openLevel(index),
    );
    if (mounted) setState(() {});
  }

  /// Explains the guest free sample and offers sign-in (shared modal).
  Future<void> _showGuestUpgradeDialog() async {
    await ensureSignedIn(
      context,
      title: 'Sign in to unlock',
      message:
          'You are playing as a guest — the first ${game.guestFreeLevels} levels '
          'of ${widget.category == 'countries' ? 'Flags of the World' : 'Animal Kingdom'} '
          'are free.\n\nSign in to unlock ALL levels and worlds, battles with friends, '
          'leaderboards, achievements and daily rewards.',
    );
    if (mounted) setState(() {});
  }

  String get title =>
      widget.category == 'animals' ? 'Animal Kingdom' : 'Flags of the World';

  Future<void> _openLevel(int index) async {
    // Server-enforced too; this guard keeps the UI honest.
    if (!game.canPlayLevel(widget.category, index)) {
      await _showGuestUpgradeDialog();
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchGameScreen(
          key: ValueKey('${widget.category}-$index'),
          level: levels[index],
          levelNumber: index + 1,
          onComplete: (points, stars) {
            widget.onLevelCompleted(index, points, stars);
            if (mounted) setState(() {});
          },
          onNext: index + 1 < levels.length
              ? () {
                  Navigator.pop(context);
                  _openLevel(index + 1);
                }
              : null,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Choose a level',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete a level to unlock the next one.',
            style: TextStyle(color: Colors.black54),
          ),
          if (game.isGuestLike) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF5B82E).withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFB77900), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Guest mode: the first ${game.guestFreeLevels} levels are free. '
                      'Sign in to unlock every level, world, battle and reward!',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await ensureSignedIn(context);
                      if (mounted) setState(() {});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 34),
                    ),
                    child: const Text('Sign in',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: levels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final isUnlocked = effectiveUnlocked.contains(index);
              final stars = widget.bestStars[index] ?? 0;
              final guestLocked = game.isGuestLike && !game.canPlayLevel(widget.category, index);

              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  if (game.isGuestLike) {
                    // Guests: playable free levels open through a rewarded
                    // interstitial; anything else pitches sign-in.
                    if (game.canPlayLevel(widget.category, index)) {
                      _openLevelAsGuest(index);
                    } else {
                      _showGuestUpgradeDialog();
                    }
                    return;
                  }
                  if (isUnlocked) _openLevel(index);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? Colors.white
                        : const Color(0xFFEDEEF4),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isUnlocked
                          ? const Color(0xFFE5E2F7)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            backgroundColor: isUnlocked
                                ? const Color(0xFFECE8FF)
                                : const Color(0xFFDFE1E8),
                            child: Icon(
                              isUnlocked
                                  ? Icons.extension_rounded
                                  : Icons.lock_rounded,
                              color: isUnlocked ? AppColors.purple : Colors.grey,
                            ),
                          ),
                          if (guestLocked)
                            const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.purple,
                              ),
                            ),
                          Text(
                            'LEVEL ${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        levels[index].title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '⭐' * stars + '☆' * (3 - stars),
                        style: const TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
          ),
          NativeAdWidget(),
        ],
      ),
    );
  }
}
