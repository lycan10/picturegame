import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ads_service.dart';
import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/game_data.dart';
import '../core/sound_service.dart';
import '../models/game_level.dart';
import '../models/match_item.dart';
import '../theme/app_theme.dart';
import '../widgets/word_chip.dart';
import 'store_screen.dart';

class MatchGameScreen extends StatefulWidget {
  final GameLevel level;
  final int levelNumber;
  final void Function(int points, int stars) onComplete;
  final VoidCallback? onNext;

  const MatchGameScreen({
    super.key,
    required this.level,
    required this.levelNumber,
    required this.onComplete,
    required this.onNext,
  });

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> matched = {};
  final Map<String, String> placedWords = {};
  late List<MatchItem> shuffledWords;

  // Hint bookkeeping. Hints are a consumable wallet item (1 per use, enforced
  // server-side too); the three mechanics mirror the store's "How hints work":
  //   reveal a clue  — shows the item's extra clue sentence
  //   remove a wrong option — marks one word that does NOT fit the hint box
  //   get a nudge — highlights the picture box for an unmatched word
  final Map<String, Set<String>> eliminatedForBox = {};
  String? revealedClueBoxId;

  int firstAttemptCorrect = 0;
  int attempts = 0;
  int hintsUsed = 0;
  int points = 0;
  String feedback = 'Drag each word to its matching picture.';
  bool isSuccessFeedback = false;
  bool isComplete = false;
  bool completionReported = false;
  String? hintTarget;
  String? wrongTargetId; // Triggers a quick shake/flash effect on failure
  // Tap-to-select companion to drag-and-drop: tap a word chip, then tap its
  // picture box. Young kids and users who struggle with dragging need this.
  String? selectedWordId;

  // Countdown, battle-style: the total budget shrinks as the box count grows
  // (2 boxes → 15s, 8 boxes → 9s), matching the battle screen's curve.
  int get _totalSeconds => min(15, 17 - playItems.length);
  late int _timeLeft;
  Timer? _countdown;
  bool _timeUp = false;

  // Playable set grows with the level: level 1 → 2 boxes, one more each
  // level, capped at 8 — identical curve to battle rounds.
  late final List<MatchItem> playItems =
      widget.level.items.take(min(8, widget.levelNumber + 1)).toList();

  @override
  void initState() {
    super.initState();
    GameData.instance.addListener(_onGameDataChanged);
    shuffledWords = List<MatchItem>.from(playItems)
      ..shuffle(Random());
    _startTimer();
  }

  @override
  void dispose() {
    GameData.instance.removeListener(_onGameDataChanged);
    _countdown?.cancel();
    super.dispose();
  }

  void _onGameDataChanged() {
    if (mounted) setState(() {});
  }

  void _startTimer({int? startFromSeconds}) {
    _countdown?.cancel();
    _timeUp = false;
    // Purchased boosts resume from the remaining+boosted budget; a fresh
    // level (or retry) always starts from the full allowance.
    _timeLeft = startFromSeconds ?? _totalSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || isComplete || _timeUp) {
        timer.cancel();
        return;
      }
      setState(() => _timeLeft = max(0, _timeLeft - 1));
      if (_timeLeft == 0) _onTimeUp();
    });
  }

  void _onTimeUp() {
    _countdown?.cancel();
    setState(() => _timeUp = true);
    HapticFeedback.heavyImpact();
    playSfx(Sfx.wrong);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏱️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              "Time's up!",
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You matched ${matched.length} of ${playItems.length}. Try again — faster!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (GameData.instance.coins >= GameData.instance.timeBoostCostCoins) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.stars_rounded, color: Color(0xFFF5B82E)),
                  label: Text(
                    '+${GameData.instance.timeBoostSeconds} Seconds (${formatCount(GameData.instance.timeBoostCostCoins)} 🪙)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    // Spend FIRST (server-validated — a local-only debit is
                    // refunded by the next sync snapshot), pop only on
                    // success. Offline falls back to the local mirror.
                    final messenger = ScaffoldMessenger.of(dialogContext);
                    bool spent = false;
                    try {
                      final json = await ApiClient.instance
                          .spend('coins', GameData.instance.timeBoostCostCoins);
                      if (json['coins'] != null) {
                        GameData.instance.setCoins(json['coins'] as int);
                      }
                      spent = true;
                    } on ApiException catch (err) {
                      if (!err.isNetworkError) {
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text(err.message),
                              behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      // Offline — keep playing with the local mirror.
                      spent = await GameData.instance
                          .spendCoins(GameData.instance.timeBoostCostCoins);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (!spent) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Not enough coins for a time boost.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    playSfx(Sfx.coin);
                    setState(() {
                      _timeUp = false;
                      _timeLeft += GameData.instance.timeBoostSeconds;
                    });
                    _startTimer(startFromSeconds: _timeLeft);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            '+${GameData.instance.timeBoostSeconds} seconds added to your time! ⚡'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _restartLevel();
                },
                child: const Text(
                  'Try again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                child: const Text('Back to levels'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fresh attempt at the same level after a timeout.
  void _restartLevel() {
    setState(() {
      matched.clear();
      placedWords.clear();
      eliminatedForBox.clear();
      revealedClueBoxId = null;
      firstAttemptCorrect = 0;
      attempts = 0;
      hintsUsed = 0;
      points = 0;
      feedback = 'Drag each word to its matching picture.';
      isSuccessFeedback = false;
      isComplete = false;
      completionReported = false;
      hintTarget = null;
      wrongTargetId = null;
      selectedWordId = null;
      shuffledWords = List<MatchItem>.from(playItems)
        ..shuffle(Random());
    });
    _startTimer();
  }

  void _onTapWord(MatchItem word) {
    if (isComplete || matched.contains(word.id)) return;
    if (selectedWordId == word.id) {
      setState(() => selectedWordId = null);
      return;
    }
    HapticFeedback.selectionClick();
    playSfx(Sfx.click);
    setState(() => selectedWordId = word.id);
  }

  /// Tapping a picture box with a selected word behaves exactly like a drop.
  void _onTapBox(MatchItem target) {
    if (selectedWordId == null) return;
    final matches = playItems.where((i) => i.id == selectedWordId);
    if (matches.isEmpty) {
      setState(() => selectedWordId = null);
      return;
    }
    final word = matches.first;
    setState(() => selectedWordId = null);
    _dropWord(word, target);
  }

  void _dropWord(MatchItem word, MatchItem target) {
    if (isComplete || matched.contains(target.id)) return;

    setState(() {
      attempts++;

      if (word.id == target.id) {
        if (matched.add(word.id)) {
          placedWords[target.id] = word.word;
          points += 100;
          firstAttemptCorrect++;
          feedback = '✨ Perfect match! +100 points';
          isSuccessFeedback = true;
          wrongTargetId = null;
          selectedWordId = null;
          // Hint aids for this box are no longer relevant.
          eliminatedForBox.remove(target.id);
          if (revealedClueBoxId == target.id) revealedClueBoxId = null;
          HapticFeedback.mediumImpact();
          playSfx(Sfx.success);
        }
      } else {
        wrongTargetId = target.id;
        feedback = '❌ Not quite! Try another picture.';
        isSuccessFeedback = false;
        HapticFeedback.heavyImpact();
        playSfx(Sfx.wrong);
      }

      hintTarget = null;

      if (matched.length == playItems.length) {
        _finishLevel();
      }
    });
  }

  // ---- Hints ---------------------------------------------------------------

  /// The player's first unmatched box, or null when everything is matched.
  /// Nullable because the game can complete between a hint tap and the
  /// wallet spend completing.
  MatchItem? get _nextUnmatchedTarget {
    for (final item in playItems) {
      if (!matched.contains(item.id)) return item;
    }
    return null;
  }

  /// Entry point of the Hint button: opens the mechanic sheet, or the
  /// out-of-hints recovery dialog when the wallet is empty.
  Future<void> _openHintSheet() async {
    if (isComplete || matched.length == playItems.length) return;

    if (GameData.instance.hints < 1) {
      _showOutOfHints();
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choose a hint',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.palePurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            size: 14, color: AppColors.purple),
                        const SizedBox(width: 4),
                        Text(
                          '${GameData.instance.hints} left',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Each hint costs 1 hint and −25 points.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              _hintOption(
                sheetContext,
                kind: 'clue',
                icon: Icons.visibility_rounded,
                title: 'Reveal a clue',
                subtitle: 'Show an extra clue for a difficult match.',
              ),
              const SizedBox(height: 10),
              _hintOption(
                sheetContext,
                kind: 'remove',
                icon: Icons.remove_circle_outline_rounded,
                title: 'Remove a wrong option',
                subtitle: 'Eliminate one word that does not fit the box.',
              ),
              const SizedBox(height: 10),
              _hintOption(
                sheetContext,
                kind: 'nudge',
                icon: Icons.lightbulb_circle_rounded,
                title: 'Get a nudge',
                subtitle: 'Highlight a picture box without revealing the word.',
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || isComplete || _timeUp) return;
    await _spendHintAndApply(choice);
  }

  Widget _hintOption(
    BuildContext sheetContext, {
    required String kind,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: AppColors.palePurple.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(sheetContext, kind),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: AppColors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.purple),
            ],
          ),
        ),
      ),
    );
  }

  /// Enforced spend: the wallet balance is checked and debounced through
  /// GameData (which also queues the server-validated op). Nothing applies
  /// unless the spend succeeds.
  Future<void> _spendHintAndApply(String kind) async {
    final spent = await GameData.instance.useHint();
    if (!mounted) return;
    if (!spent) {
      _showOutOfHints();
      return;
    }
    // The level may have completed (or timed out) while the sheet was open —
    // hand the hint back rather than spending it into a frozen game.
    if (isComplete || _timeUp) {
      await GameData.instance.addHints(1);
      return;
    }

    setState(() {
      hintsUsed++;
      points = max(0, points - 25);
      playSfx(Sfx.click);
      hintTarget = null;

      switch (kind) {
        case 'clue':
          _applyRevealClue();
        case 'remove':
          _applyRemoveWrongOption();
        case 'nudge':
          _applyNudge();
      }
    });
  }

  void _applyRevealClue() {
    final target = _nextUnmatchedTarget;
    if (target == null) return;
    revealedClueBoxId = target.id;
    hintTarget = target.id;
    feedback = '💡 Clue: ${target.hint}';
    isSuccessFeedback = false;
  }

  void _applyNudge() {
    final target = _nextUnmatchedTarget;
    if (target == null) return;
    hintTarget = target.id;
    feedback = '🔍 Look closely at the highlighted picture.';
    isSuccessFeedback = false;
  }

  void _applyRemoveWrongOption() {
    final target = _nextUnmatchedTarget;
    if (target == null) return;
    final candidates = shuffledWords
        .where((word) => word.id != target.id && !matched.contains(word.id))
        .toList();
    if (candidates.isEmpty) {
      // Fall back to a nudge when there is nothing to eliminate.
      _applyNudge();
      return;
    }
    final wrong = candidates[Random().nextInt(candidates.length)];
    eliminatedForBox.putIfAbsent(target.id, () => {}).add(wrong.id);
    hintTarget = target.id;
    feedback = '✗ "${wrong.word}" does not match the highlighted picture.';
    isSuccessFeedback = false;
  }

  void _showOutOfHints() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: AppColors.purple),
            SizedBox(width: 10),
            Text("You're out of hints"),
          ],
        ),
        content: Text(
          'Hints reveal clues, remove wrong options and nudge you toward the '
          'right picture. You can buy 1 hint instantly for '
          '${GameData.instance.hintPriceCoins} coins, '
          'earn one free by watching a short ad, or grab a pack from the store.\n\n'
          'Coin balance: ${formatCount(GameData.instance.coins)} 🪙',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          if (GameData.instance.coins >= GameData.instance.hintPriceCoins)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                // Server-validated buy: the store wallet is the source of
                // truth; a local grant would be wiped by the next sync.
                try {
                  final json = await ApiClient.instance.buyHints();
                  if (!mounted) return;
                  if (json['coins'] != null) {
                    GameData.instance.setCoins(json['coins'] as int);
                  }
                  if (json['hints'] != null) {
                    GameData.instance.setHints(json['hints'] as int);
                  }
                  playSfx(Sfx.coin);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Purchased 1 hint for ${formatCount(GameData.instance.hintPriceCoins)} coins! 🎉'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } on ApiException catch (err) {
                  if (!mounted) return;
                  if (err.isNetworkError) {
                    // Offline: keep the local-only mirror behaviour.
                    final spent = await GameData.instance
                        .spendCoins(GameData.instance.hintPriceCoins);
                    if (spent) {
                      await GameData.instance.addHints(1);
                      playSfx(Sfx.coin);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(err.message),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
              icon: const Icon(Icons.stars_rounded, size: 17, color: Color(0xFFF5B82E)),
              label: Text('Buy 1 hint (${formatCount(GameData.instance.hintPriceCoins)} 🪙)'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _earnHintViaAd();
            },
            icon: const Icon(Icons.play_circle_fill_rounded, size: 17),
            label: const Text('Watch ad +1'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
            ),
            child: const Text('Store'),
          ),
        ],
      ),
    );
  }

  Future<void> _earnHintViaAd() async {
    final earned = await AdsService.instance.showRewarded(
      onEarned: () {
        // Grant is server-side and daily-capped.
        GameData.instance.watchAdReward('hints');
      },
      onClosed: () {},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          earned
              ? 'Reward confirmed — your hint will land in a moment.'
              : 'No ad available right now. Try again soon or visit the store.',
        ),
      ),
    );
  }

  void _finishLevel() {
    isComplete = true;
    _countdown?.cancel();
    playSfx(Sfx.complete);

    // Star rule: one star lost per miss (a wrong drop), floored at 1.
    // 0 misses + no hints → 3; miss 1 → 2; miss 2+ → 1.
    final misses = attempts - firstAttemptCorrect;
    final stars = misses == 0 && hintsUsed == 0
        ? 3
        : (3 - misses).clamp(1, 2);

    if (!completionReported) {
      completionReported = true;
      widget.onComplete(points, stars);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text(
                'Fantastic Job!',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.palePurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+$points Points Earned',
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '⭐' * stars + '☆' * (3 - stars),
                style: const TextStyle(fontSize: 38),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    // Level-finish interstitial: shown after the celebration
                    // dialog closes, before moving on. Frequency-capped, and a
                    // no-op (navigation proceeds) when no ad is ready.
                    AdsService.instance.showInterstitial(onDone: () {
                      if (!mounted) return;
                      if (widget.onNext != null) {
                        widget.onNext!();
                      } else {
                        Navigator.pop(context);
                      }
                    });
                  },
                  child: Text(
                    widget.onNext == null ? 'Finish Level' : 'Next Level ➔',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Compact circular countdown, mirroring the battle screen's timer UI.
  Widget _buildTimerBar() {
    final fraction = (_timeLeft / _totalSeconds).clamp(0.0, 1.0);
    final urgent = _timeLeft <= 10;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(end: fraction),
      builder: (context, value, _) => Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3.5,
                  backgroundColor: AppColors.palePurple,
                  valueColor: AlwaysStoppedAnimation(
                    urgent ? Colors.redAccent : AppColors.purple,
                  ),
                ),
                Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: urgent ? Colors.redAccent : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _timeUp ? "Time's up!" : '${_totalSeconds}s total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: urgent || _timeUp ? Colors.redAccent : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// One picture box: accepts drops AND taps (tap-to-select flow).
  Widget _pictureBox(MatchItem item) {
    final isMatched = matched.contains(item.id);
    final isHinted = hintTarget == item.id;
    final isWrong = wrongTargetId == item.id;

    return DragTarget<MatchItem>(
      onWillAcceptWithDetails: (details) => !isMatched && !isComplete,
      onAcceptWithDetails: (details) => _dropWord(details.data, item),
      builder: (context, candidates, rejected) {
        final isHovering = candidates.isNotEmpty;

        return GestureDetector(
          onTap: () => _onTapBox(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMatched
                  ? AppColors.paleGreen
                  : isWrong
                      ? const Color(0xFFFFEEEE)
                      : isHinted
                          ? const Color(0xFFFFF1C9)
                          : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isMatched
                    ? AppColors.green
                    : isWrong
                        ? Colors.redAccent
                        : isHovering || isHinted
                            ? AppColors.purple
                            : const Color(0xFFE8E8F1),
                width: isHovering || isHinted || isWrong ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.picture,
                  style: const TextStyle(fontSize: 46),
                ),
                const SizedBox(height: 10),
                if (isMatched)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          placedWords[item.id] ?? item.word,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isHovering
                          ? AppColors.palePurple
                          : Colors.grey.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isHovering
                          ? 'Drop here!'
                          : selectedWordId != null
                              ? 'Tap to match'
                              : 'Match me',
                      style: TextStyle(
                        color: isHovering
                            ? AppColors.purple
                            : Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Quitting mid-level asks first; a confirmed exit is followed by a
  // frequency-capped interstitial (no-op when nothing is ready).
  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Leave this level?'),
        content: const Text('Your progress in this level will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit != true || !mounted) return;
    Navigator.pop(context);
    AdsService.instance.showInterstitial();
  }

  @override
  Widget build(BuildContext context) {
    final items = playItems;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || isComplete) return;
        _confirmQuit();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Level ${widget.levelNumber}',
          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.palePurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 16, color: AppColors.purple),
                    const SizedBox(width: 4),
                    Text(
                      '$points pts',
                      style: const TextStyle(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Info & Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Builder(builder: (context) {
                // Defensive: an empty playable set (stale cached manifest) must
                // not produce 0/0 → NaN.toInt(), which throws during build.
                final progress =
                    items.isEmpty ? 0.0 : matched.length / items.length;
                return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.level.title,
                    style: const TextStyle(
                      fontSize: 24,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Drag each word chip onto its matching picture box.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE6E3F5),
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${matched.length} of ${items.length} matched',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTimerBar(),
                ],
                );
              }),
            ),

            // Main Picture Grid Cards
            Expanded(
              child: Builder(builder: (context) {
                // Row rules: 3-4 boxes share a single row; larger sets use at
                // most two rows (ceil(count / 2) columns). Wide screens widen
                // the rows instead of blowing giant cells up, keeping the
                // two-row cap.
                final width = MediaQuery.sizeOf(context).width;
                var cols = items.length <= 4
                    ? max(2, items.length)
                    : (items.length / 2).ceil();
                if (width > 640 && items.length >= 5 && cols < 5) cols = 5;
                if (width > 900 && items.length >= 6 && cols < 6) cols = 6;
                final aspect = width > 640 ? 0.92 : (cols >= 4 ? 0.85 : 1.02);

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: aspect,
                  ),
                  itemBuilder: (context, index) => _pictureBox(items[index]),
                );
              }),
            ),

  // Bottom Tray & Feedback Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccessFeedback
                            ? Icons.check_circle_rounded
                            : Icons.tips_and_updates_rounded,
                        color: isSuccessFeedback
                            ? AppColors.green
                            : AppColors.purple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feedback,
                          style: TextStyle(
                            color: isSuccessFeedback
                                ? AppColors.green
                                : AppColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openHintSheet,
                        icon: Badge(
                          isLabelVisible: GameData.instance.hints > 0,
                          label: Text('${GameData.instance.hints}'),
                          backgroundColor: AppColors.purple,
                          textStyle: const TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800),
                          child: const Icon(Icons.lightbulb_outline_rounded,
                              size: 16),
                        ),
                        label: const Text('Hint'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.purple,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: shuffledWords
                        .where((word) => !matched.contains(word.id))
                        .map((word) {
                      // A word eliminated for the currently hinted box stays
                      // draggable (it fits another box) but is annotated.
                      final eliminatedForHintedBox =
                          hintTarget != null &&
                              (eliminatedForBox[hintTarget]
                                      ?.contains(word.id) ==
                                  true);

                      final isSelected = selectedWordId == word.id;
                      final chip = isSelected
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.purple,
                                  width: 2.5,
                                ),
                              ),
                              child: WordChip(word: word.word),
                            )
                          : WordChip(word: word.word);

                      return Draggable<MatchItem>(
                        data: word,
                        feedback: Material(
                          color: Colors.transparent,
                          child: WordChip(word: word.word, dragging: true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: WordChip(word: word.word),
                        ),
                        // Tap = select, tap the picture = match (drag also works).
                        child: GestureDetector(
                          onTap: () => _onTapWord(word),
                          child: eliminatedForHintedBox
                              ? Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Opacity(
                                      opacity: 0.45,
                                      child: chip,
                                    ),
                                    Positioned(
                                      right: -4,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            size: 10, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                )
                              : chip,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            NativeAdWidget(),
          ],
        ),
      ),
      ),
    );
  }
}