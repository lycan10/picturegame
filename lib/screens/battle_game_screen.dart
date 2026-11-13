import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads_service.dart';
import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/game_data.dart';
import '../core/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/word_chip.dart';
import 'store_screen.dart';

/// Live 1v1 battle: a PvP replica of the single-player match game. Each round
/// shows N picture boxes (round 1 → 2, growing with the round number, capped
/// at 8) and both players drag word chips onto them. Fully matching a round
/// costs nothing; timing out with boxes left unmatched costs a heart. Last
/// player standing wins.
///
/// The screen is a thin client over the poll-based battle engine: it submits
/// matches and re-reads the authoritative server state every 2s, so both
/// players converge on the same rounds without WebSockets. The word→picture
/// mapping is never sent to the client before the round resolves — words
/// travel only in the shuffled `chips` list, so local drops are optimistic
/// and the server response (corrects or confirms) drives the feedback.
class BattleGameScreen extends StatefulWidget {
  final String code;

  const BattleGameScreen({super.key, required this.code});

  @override
  State<BattleGameScreen> createState() => _BattleGameScreenState();
}

class _BattleGameScreenState extends State<BattleGameScreen> {
  static const _pollInterval = Duration(seconds: 2);

  Map<String, dynamic>? _state;
  bool _loading = true;
  bool _submitting = false;
  bool _offline = false;
  String? _fatal;

  String? _selectedWord; // chip selected via tap (tap-to-match companion)
  String? _feedback;
  bool _feedbackGood = false;
  int _lastRoundNo = 0;

  // Per-round match state, mirroring the match screen. Local optimistic
  // matches lead; the poll's authoritative `matchedByMe` is unioned in.
  final Set<String> _myMatches = {}; // item ids matched by me
  final Map<String, String> _placedWords = {}; // itemId -> placed word
  String? _wrongTargetId; // triggers a shake/flash on a wrong drop
  String? _hintTarget; // box highlighted by clue/nudge
  bool _hintUsedThisRound = false;

  Timer? _pollTimer;
  Timer? _tickTimer;

  String? get _myId => GameData.instance.user?['id'] as String?;

  Map<String, dynamic>? get _round =>
      _state?['round'] as Map<String, dynamic>?;

  List<Map<String, dynamic>> get _roundItems =>
      ((_round?['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  List<String> get _chips =>
      (_round?['chips'] as List?)?.cast<String>() ?? const [];

  /// Chips still in the tray: every word has exactly one box, so a placed
  /// word removes its chip.
  List<String> get _remainingChips => _chips
      .where((w) => !_placedWords.containsValue(w))
      .toList();

  int get _itemTotal =>
      (_round?['itemTotal'] as num?)?.toInt() ?? _roundItems.length;

  bool get _matchedAll => _myMatches.length >= _itemTotal && _itemTotal > 0;

  Map<String, dynamic>? get _me {
    final state = _state;
    if (state == null || _myId == null) return null;
    final host = state['host'] as Map<String, dynamic>?;
    if (host != null && host['userId'] == _myId) return host;
    return state['guest'] as Map<String, dynamic>?;
  }

  Map<String, dynamic>? get _opponent {
    final state = _state;
    if (state == null || _myId == null) return null;
    final host = state['host'] as Map<String, dynamic>?;
    if (host != null && host['userId'] == _myId) {
      return state['guest'] as Map<String, dynamic>?;
    }
    return host;
  }

  Duration get _remaining {
    final expiresAt = _round?['expiresAt'] as String?;
    if (expiresAt == null) return Duration.zero;
    return DateTime.parse(expiresAt).difference(DateTime.now());
  }

  bool get _timedOut => _remaining <= Duration.zero;

  @override
  void initState() {
    // An app-open ad firing on resume mid-battle would be brutal — suppress.
    AdsService.instance.suppressAppOpen = true;
    super.initState();
    GameData.instance.addListener(_onGameDataChanged);
    _refresh();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        // Re-render only while a live countdown is on screen.
        if (mounted && !_matchedAll && !_timedOut) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    AdsService.instance.suppressAppOpen = false;
    GameData.instance.removeListener(_onGameDataChanged);
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _onGameDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_fatal != null || (_state?['status'] as String?) == 'finished') return;
    try {
      final json = await ApiClient.instance.battleState(widget.code);
      if (!mounted) return;
      _applyState(json);
    } on ApiException catch (err) {
      if (!mounted) return;
      if (err.status == 403 || err.status == 404) {
        _pollTimer?.cancel();
        _tickTimer?.cancel();
        setState(() {
          _fatal = err.message;
          _loading = false;
        });
        return;
      }
      setState(() => _offline = true);
    }
  }

  void _applyState(Map<String, dynamic> json, {bool fromMatch = false}) {
    final round = json['round'] as Map<String, dynamic>?;
    final no = (round?['no'] as num?)?.toInt() ?? 0;

    setState(() {
      _state = json;
      _loading = false;
      _offline = false;
      _submitting = false;

      if (no != _lastRoundNo) {
        _lastRoundNo = no;
        _selectedWord = null;
        _feedback = null;
        _wrongTargetId = null;
        _hintTarget = null;
        _hintUsedThisRound = false;
        _myMatches.clear();
        _placedWords.clear();
      }

      // Union the authoritative match list — covers desyncs after reconnects
      // without clobbering in-flight optimistic matches.
      _myMatches.addAll(
        ((round?['matchedByMe'] as List?) ?? []).cast<String>(),
      );

      if (fromMatch) {
        if (json['matched'] == true) {
          _feedback =
              '✨ Perfect match! +${formatCount(GameData.instance.battleAnswerPoints)} pts';
          _feedbackGood = true;
        } else {
          _feedback = '❌ Not a match — try another box!';
          _feedbackGood = false;
        }
      }
    });

    unawaited(_maybeAutoRefill());

    final status = json['status'] as String?;
    if (status == 'finished' || status == 'expired') {
      _pollTimer?.cancel();
      _tickTimer?.cancel();
    }
    if (status == 'finished') {
      // Rewards (coins, bonus points, achievements) are granted server-side;
      // pull them into the local mirror.
      unawaited(GameData.instance.trySync());
    }
  }

  /// Drop (or tap-match) a word chip onto a picture box. The server is the
  /// only judge — the client never knows the mapping — so every drop is
  /// submitted and the response drives success/wrong feedback. Wrong drops
  /// are shake-only; lives are lost solely via the round timeout.
  Future<void> _submitMatch(String itemId, String word) async {
    final round = _round;
    if (round == null || _submitting || _timedOut || _matchedAll) return;
    if (_myMatches.contains(itemId)) return;
    if (!_remainingChips.contains(word)) return;

    final no = (round['no'] as num).toInt();
    setState(() {
      _submitting = true;
      _selectedWord = null;
    });

    try {
      final json =
          await ApiClient.instance.battleMatch(widget.code, no, itemId, word);
      if (!mounted) return;
      _applyState(json, fromMatch: true);
      if (json['matched'] == true) {
        setState(() {
          _placedWords[itemId] = word;
          _myMatches.add(itemId);
          _wrongTargetId = null;
        });
        HapticFeedback.mediumImpact();
        playSfx(Sfx.success);
      } else {
        setState(() => _wrongTargetId = itemId);
        HapticFeedback.heavyImpact();
        playSfx(Sfx.wrong);
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if ((err.message).contains('timed out')) {
        setState(() => _feedback = '⏱ Too slow — you lost a heart');
      } else {
        _showMessage(err.isNetworkError
            ? 'No connection — try again'
            : err.message);
      }
    }
  }

  Future<bool> _confirmLeave() async {
    final status = _state?['status'] as String?;
    if (status == 'finished' || status == 'expired') return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Leave the battle?',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        content: const Text(
          "If you leave now you will forfeit the battle immediately, "
          "ending the game and declaring your opponent the winner.",
          style: TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay',
                style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Forfeit & Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave()) {
          _pollTimer?.cancel();
          _tickTimer?.cancel();
          try {
            await ApiClient.instance.battleForfeit(widget.code);
          } catch (_) {}
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.purple))
              : _fatal != null
                  ? _buildFatal(_fatal!)
                  : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildFatal(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😵', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Arena'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final status = _state?['status'] as String?;

    if (status == 'finished') {
      return _buildFinished();
    }
    if (status == 'expired') {
      return _buildFatal(
        'This battle was closed after 30 minutes of inactivity.',
      );
    }

    final round = _round;
    if (round == null) {
      // 'waiting' should not normally reach this screen, but if the opponent
      // left and the room reset, show a gentle waiting state.
      return Column(
        children: [
          _buildTopBar('Waiting…'),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.purple),
                  SizedBox(height: 16),
                  Text('Waiting for your opponent…',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildTopBar('Round ${round['no']}'),
        _buildPlayersBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                _buildProgressHeader(),
                const SizedBox(height: 12),
                _buildMatchGrid(),
                const SizedBox(height: 16),
                _buildTimerBar(),
                const SizedBox(height: 20),
                _buildChipTray(),
                const SizedBox(height: 16),
                _buildFeedback(round),
              ],
            ),
          ),
        ),
        if (_offline) _buildOfflineBanner(),
      ],
    );
  }

  // ---- Hints ----------------------------------------------------------------

  /// Same mechanics as the single-player hint sheet, minus "remove a wrong
  /// option" (the tray holds exactly the round's words — there are no wrong
  /// chips). Both hints target the player's first unmatched box, computed
  /// server-side because the mapping is hidden until the round resolves.
  Future<void> _openHintSheet() async {
    final round = _round;
    if (round == null || _matchedAll || _timedOut || _hintUsedThisRound) return;

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
                'Each hint costs 1 hint and targets your first unmatched picture.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              _hintOption(
                sheetContext,
                kind: 'clue',
                icon: Icons.visibility_rounded,
                title: 'Reveal a clue',
                subtitle: 'Show the clue sentence for a difficult match.',
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

    if (choice == null || !mounted) return;
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

  /// Server-enforced spend: the endpoint debits the wallet atomically (D1)
  /// and picks the target box, because the word→picture mapping never reaches
  /// the client before the round resolves. The local mirror is updated from
  /// the server balance after every spend.
  Future<void> _spendHintAndApply(String kind) async {
    final round = _round;
    if (round == null || _submitting || !mounted) return;

    final no = (round['no'] as num).toInt();
    setState(() => _submitting = true);
    try {
      final json = await ApiClient.instance.battleHint(widget.code, no, kind);
      if (!mounted) return;
      if (json['hints'] != null) {
        GameData.instance.setHints(json['hints'] as int);
      }
      final itemId = json['itemId'] as String?;
      setState(() {
        _submitting = false;
        _hintUsedThisRound = true;
        _hintTarget = itemId;
        if (kind == 'clue' && json['hint'] != null) {
          _feedback = '💡 Clue: ${json['hint']}';
        } else {
          _feedback = '🔍 Look closely at the highlighted picture.';
        }
        _feedbackGood = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (err.message.contains('Not enough hints')) {
        _showOutOfHints();
      } else if (err.isNetworkError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No connection — try again')),
        );
      } else {
        _showMessage(err.message);
      }
    }
  }

  Future<void> _refillLife() async {
    final refillCost = GameData.instance.battleLifeRefillCost;
    if (GameData.instance.coins < refillCost) {
      _showMessage('Need $refillCost coins to refill a life. Visit the store to get coins!');
      return;
    }

    try {
      final json = await ApiClient.instance.battleRefillLife(widget.code);
      if (!mounted) return;
      if (json['coins'] != null) {
        GameData.instance.setCoins(json['coins'] as int);
      } else {
        await GameData.instance.spendCoins(refillCost);
      }
      playSfx(Sfx.coin);
      HapticFeedback.mediumImpact();
      _showMessage('❤️ Life refilled (+1 life)!');
      await _refresh();
    } on ApiException catch (err) {
      if (!mounted) return;
      _showMessage(err.message);
    }
  }

  bool _autoRefilling = false;

  /// Optional setting (Profile → "Auto-refill battle lives"): when on, a
  /// player who drops to 1 life in an active battle automatically buys lives
  /// back with coins instead of being eliminated. Buys 2 lives when the
  /// balance covers both, 1 when it covers only one, nothing otherwise.
  /// Mirrors the manual refill button's server rules (only fires at exactly
  /// 1 life) — the server re-validates every buy, so a failed attempt just
  /// falls back to the manual button.
  Future<void> _maybeAutoRefill() async {
    if (!GameData.instance.battleAutoRefill || _autoRefilling) return;
    if ((_state?['status'] as String?) != 'active') return;
    final me = _me;
    if (me == null) return;
    if ((me['lives'] as num?)?.toInt() != 1) return;
    final refillCost = GameData.instance.battleLifeRefillCost;
    final coins = GameData.instance.coins;
    // Buy 2 when affordable, else 1, else nothing (no nagging).
    final amount = coins >= refillCost * 2
        ? 2
        : coins >= refillCost
            ? 1
            : 0;
    if (amount == 0) return;

    _autoRefilling = true;
    try {
      final json =
          await ApiClient.instance.battleRefillLife(widget.code, amount: amount);
      if (!mounted) return;
      if (json['coins'] != null) {
        GameData.instance.setCoins(json['coins'] as int);
      }
      playSfx(Sfx.coin);
      HapticFeedback.mediumImpact();
      _showMessage(
          '❤️ $amount ${amount == 1 ? 'life' : 'lives'} auto-refilled '
          '(−${formatCount(refillCost * amount)} 🪙)');
      await _refresh();
    } on ApiException {
      // Server rejected (race, out of coins) — the manual +1 button stays
      // available and the next poll re-checks.
    } finally {
      _autoRefilling = false;
    }
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
          'Hints reveal clues and nudge you toward the right picture. You can '
          'buy 1 hint instantly for '
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
                final spent = await GameData.instance
                    .spendCoins(GameData.instance.hintPriceCoins);
                if (spent) {
                  await GameData.instance.addHints(1);
                  playSfx(Sfx.coin);
                  _showMessage(
                      'Purchased 1 hint for ${GameData.instance.hintPriceCoins} coins! 🎉');
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

  // ---- Match board ----------------------------------------------------------

  Widget _buildTopBar(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (await _confirmLeave()) {
                _pollTimer?.cancel();
                _tickTimer?.cancel();
                if (mounted) Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _openHintSheet,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: Badge(
              isLabelVisible: GameData.instance.hints > 0,
              label: Text('${GameData.instance.hints}'),
              backgroundColor: AppColors.purple,
              textStyle:
                  const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
              child: const Icon(Icons.lightbulb_outline_rounded, size: 20),
            ),
            label: const Text('Hint'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 15, color: AppColors.purple.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(
                  widget.code,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _playerCard(_me, isMe: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.palePurple,
                shape: BoxShape.circle,
              ),
              child: const Text('VS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.purple,
                  )),
              ),
          ),
          Expanded(
            child: _playerCard(_opponent, isMe: false),
          ),
        ],
      ),
    );
  }

  Widget _playerCard(Map<String, dynamic>? p, {required bool isMe}) {
    final lives = (p?['lives'] as num?)?.toInt() ?? 0;
    final score = (p?['score'] as num?)?.toInt() ?? 0;
    final name = p == null
        ? 'Waiting…'
        : isMe
            ? 'You'
            : (p['name'] as String? ?? 'Opponent');
    final avatar = p?['avatar'] as String? ?? '❓';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? AppColors.purple.withValues(alpha: 0.35)
              : AppColors.ink.withValues(alpha: 0.06),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.palePurple,
                  shape: BoxShape.circle,
                ),
                child: Text(avatar, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _hearts(lives)),
              if (isMe && lives == 1) ...[
                InkWell(
                  onTap: _refillLife,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 12, color: Colors.redAccent),
                        Text(
                          '+1 (${formatCount(GameData.instance.battleLifeRefillCost)} 🪙)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                formatCount(score),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hearts(int lives) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 15,
            color: i < lives ? Colors.redAccent : Colors.grey.withValues(alpha: 0.35),
          ),
        );
      }),
    );
  }

  Widget _buildProgressHeader() {
    final total = _itemTotal;
    final matched = min(_myMatches.length, total);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: total == 0 ? 0 : matched / total,
            minHeight: 10,
            backgroundColor: const Color(0xFFE6E3F5),
            color: AppColors.purple,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$matched of $total matched',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                total == 0 ? '0%' : '${((matched / total) * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One picture box: accepts dropped words AND tap-matching (tap a chip,
  /// then tap its picture box) — the same mechanic as the match screen.
  Widget _buildBox(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final isMatched = _myMatches.contains(id);
    final isHinted = _hintTarget == id;
    final isWrong = _wrongTargetId == id;
    final revealedWord = item['word'] as String?; // sent once round resolves
    final locked = _submitting || _timedOut || _matchedAll;
    final placed = _placedWords[id];

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !isMatched && !locked && _remainingChips.contains(details.data),
      onAcceptWithDetails: (details) =>
          _submitMatch(id, details.data),
      builder: (context, candidates, rejected) {
        final isHovering = candidates.isNotEmpty;

        return GestureDetector(
          onTap: () {
            final word = _selectedWord;
            if (word != null && !locked) _submitMatch(id, word);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
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
                  item['picture'] as String? ?? '❓',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 8),
                if (isMatched)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.green,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          placed ?? revealedWord ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (revealedWord != null)
                  // Round resolved without a match — reveal the answer.
                  Text(
                    revealedWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
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
                          : _selectedWord != null
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

  /// Picture-box grid with the match screen's row rules: 3–4 boxes share a
  /// single row, larger sets use at most two rows.
  Widget _buildMatchGrid() {
    final items = _roundItems;
    final width = MediaQuery.sizeOf(context).width;
    var cols = items.length <= 4
        ? max(2, items.length)
        : (items.length / 2).ceil();
    if (width > 640 && items.length >= 5 && cols < 5) cols = 5;
    if (width > 900 && items.length >= 6 && cols < 6) cols = 6;
    final aspect = width > 640 ? 0.92 : (cols >= 4 ? 0.85 : 1.02);

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: aspect,
      padding: EdgeInsets.zero,
      children: items.map(_buildBox).toList(),
    );
  }

  /// Word-chip tray, identical in spirit to the match screen's: drag a chip
  /// onto its picture, or tap the chip and then tap the picture.
  Widget _buildChipTray() {
    final chips = _remainingChips;
    if (chips.isEmpty && _matchedAll) {
      return const Text(
        'All matched! 🎉',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.green,
          fontSize: 14,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: chips.map((word) {
        final isSelected = _selectedWord == word;
        final chip = isSelected
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.purple,
                    width: 2.5,
                  ),
                ),
                child: WordChip(word: word),
              )
            : WordChip(word: word);

        return Draggable<String>(
          data: word,
          feedback: Material(
            color: Colors.transparent,
            child: WordChip(word: word, dragging: true),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: WordChip(word: word),
          ),
          // Tap = select, tap the picture = match (drag also works).
          child: GestureDetector(
            onTap: () {
              if (_timedOut || _matchedAll) return;
              HapticFeedback.selectionClick();
              playSfx(Sfx.click);
              setState(() {
                _selectedWord = _selectedWord == word ? null : word;
              });
            },
            child: chip,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimerBar() {
    final itemTotal = max(2, _itemTotal);
    final total = Duration(seconds: min(15, 17 - itemTotal));
    final remaining = _remaining;
    final fraction = (remaining.inMilliseconds / total.inMilliseconds)
        .clamp(0.0, 1.0);
    final urgent = remaining.inSeconds <= 5;

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
                  remaining > Duration.zero
                      ? '${remaining.inSeconds}'
                      : '!',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: urgent ? Colors.redAccent : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            remaining > Duration.zero ? 'Time left' : "Time's up!",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: urgent ? Colors.redAccent : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(Map<String, dynamic> round) {
    final opponentMatched =
        (round['opponentMatchedCount'] as num?)?.toInt() ?? 0;
    final resolved = round['resolved'] == true;

    String? text;
    Color color = AppColors.purple;
    IconData icon = Icons.info_outline_rounded;

    if (_feedback != null) {
      text = _feedback;
      color = _feedbackGood ? AppColors.green : Colors.redAccent;
      icon = _feedbackGood
          ? Icons.check_circle_rounded
          : Icons.error_rounded;
    } else if (_timedOut && !_matchedAll) {
      text = "⏱ Time's up! You lost a heart";
      color = Colors.redAccent;
      icon = Icons.timer_off_rounded;
    } else if (_matchedAll && !resolved) {
      text =
          '🎉 All matched! Waiting for your opponent… (they have $opponentMatched/$_itemTotal)';
      icon = Icons.hourglass_top_rounded;
    } else if (!_matchedAll && opponentMatched > 0) {
      text = '⚡ Your opponent has matched $opponentMatched of $_itemTotal — hurry!';
      color = Colors.orange;
      icon = Icons.bolt_rounded;
    }

    return Column(
      children: [
        if (text != null)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.orange.withValues(alpha: 0.12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
          ),
          SizedBox(width: 10),
          Text(
            'Reconnecting…',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Result screen
  // =========================================================================

  // Post-battle "add friend" (quick match discovery). Loaded lazily when the
  // result screen shows.
  String? _friendStatus; // none | friends | incoming | outgoing
  bool _addingFriend = false;

  String? get _opponentId {
    final opp = _opponent;
    return opp?['userId'] as String?;
  }

  Future<void> _loadFriendStatus() async {
    final oppId = _opponentId;
    if (oppId == null || _friendStatus != null) return;
    try {
      final json = await ApiClient.instance.friendStatus(oppId);
      if (!mounted) return;
      setState(() => _friendStatus = json['status'] as String?);
    } on ApiException {
      // Offline — the button simply won't show.
    }
  }

  Future<void> _addOpponentAsFriend() async {
    final oppId = _opponentId;
    if (oppId == null || _addingFriend) return;
    setState(() => _addingFriend = true);
    try {
      final json = await ApiClient.instance.sendFriendRequest(oppId);
      final result = json['result'] as String? ?? 'sent';
      if (!mounted) return;
      playSfx(Sfx.success);
      setState(() {
        _friendStatus = switch (result) {
          'auto-accepted' => 'friends',
          'already-friends' => 'friends',
          _ => 'outgoing',
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            'auto-accepted' => 'You are now friends! 🎉',
            'already-friends' => 'You are already friends.',
            _ => 'Friend request sent!',
          }),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isNetworkError ? 'You are offline.' : err.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _addingFriend = false);
    }
  }

  Widget _buildFinished() {
    final winnerId = _state?['winnerId'] as String?;
    final isDraw = winnerId == null;
    final isWin = !isDraw && winnerId == _myId;
    // Load the friendship status once for the result screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _friendStatus == null) _loadFriendStatus();
    });

    final headline = isDraw ? "It's a draw!" : isWin ? 'Victory!' : 'Defeated';
    final emoji = isDraw ? '🤝' : isWin ? '🏆' : '💔';
    final bg = isDraw
        ? const [Color(0xFF546E7A), Color(0xFF37474F)]
        : isWin
            ? const [Color(0xFF7C3AED), Color(0xFF4C1D95)]
            : const [Color(0xFFE05263), Color(0xFF97266D)];

    final me = _me;
    final opp = _opponent;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bg,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 84)),
            const SizedBox(height: 16),
            Text(
              headline,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 8),
            Text(
              isWin
                  ? '+${formatCount(GameData.instance.battleWinnerBonusPoints)} bonus points · +${formatCount(GameData.instance.battleWinnerCoins)} coins'
                  : isDraw
                      ? 'Both players ran out of hearts'
                      : 'Better luck next battle!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _resultRow(
                      avatar: me?['avatar'] as String? ?? '🧑',
                      name: 'You',
                      score: (me?['score'] as num?)?.toInt() ?? 0,
                      lives: (me?['lives'] as num?)?.toInt() ?? 0,
                      highlight: isWin,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    _resultRow(
                      avatar: opp?['avatar'] as String? ?? '❓',
                      name: opp?['name'] as String? ?? 'Opponent',
                      score: (opp?['score'] as num?)?.toInt() ?? 0,
                      lives: (opp?['lives'] as num?)?.toInt() ?? 0,
                      highlight: !isWin && !isDraw,
                    ),
                    if (!isDraw &&
                        _friendStatus == 'none' &&
                        _opponentId != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _addingFriend ? null : _addOpponentAsFriend,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: _addingFriend
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.person_add_rounded, size: 17),
                          label: Text('Add ${opp?['name'] ?? 'opponent'} as friend',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bg.last,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: () {
                    // Battle-end interstitial before returning to the arena.
                    // Frequency-capped; pops immediately when no ad shows.
                    AdsService.instance.showInterstitial(
                      onDone: () {
                        if (mounted) Navigator.of(context).pop();
                      },
                    );
                  },
                  child: const Text('Back to Arena'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow({
    required String avatar,
    required String name,
    required int score,
    required int lives,
    required bool highlight,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(avatar, style: const TextStyle(fontSize: 21)),
        ),
        const SizedBox(width: 12),
          Expanded(
            child: Text(
              highlight ? '$name 👑' : name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
        ),
        Text(
          '${formatCount(score)} pts',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 52, child: _hearts(lives)),
      ],
    );
  }
}
