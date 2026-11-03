import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads_service.dart';
import '../core/api_client.dart';
import '../core/game_data.dart';
import '../core/sound_service.dart';
import '../theme/app_theme.dart';
import 'store_screen.dart';

/// Live 1v1 battle: match the picture to the correct word before the 30s
/// timer runs out. A wrong answer or timeout costs a heart; last player
/// standing wins.
///
/// The screen is a thin client over the poll-based battle engine: it submits
/// answers and re-reads the authoritative server state every 2s, so both
/// players converge on the same rounds without WebSockets.
class BattleGameScreen extends StatefulWidget {
  final String code;

  const BattleGameScreen({super.key, required this.code});

  @override
  State<BattleGameScreen> createState() => _BattleGameScreenState();
}

class _BattleGameScreenState extends State<BattleGameScreen> {
  static const _pollInterval = Duration(seconds: 2);
  static const _roundSeconds = 15;

  Map<String, dynamic>? _state;
  bool _loading = true;
  bool _submitting = false;
  bool _offline = false;
  String? _fatal;

  String? _selected;
  String? _feedback;
  bool _feedbackGood = false;
  int _lastRoundNo = 0;

  // Hint state, per round. The clue sentence is NOT free in battles: the
  // round payload carries it, but we only surface it after the player spends
  // a hint. All spends go through GameData.useHint() (balance-checked and
  // server-validated on sync).
  bool _hintClueRevealed = false;
  String? _hintEliminated; // a wrong option removed this round
  bool _hintNudgeUsed = false; // nudge purchased this round
  String? _nudgeFirstLetter; // from the server (word is hidden pre-answer)
  int? _nudgeLength;

  Timer? _pollTimer;
  Timer? _tickTimer;

  String? get _myId => GameData.instance.user?['id'] as String?;

  Map<String, dynamic>? get _round =>
      _state?['round'] as Map<String, dynamic>?;

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

  bool get _iAnswered => _round?['answeredByMe'] as bool? ?? true;

  @override
  void initState() {
    super.initState();
    GameData.instance.addListener(_onGameDataChanged);
    _refresh();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        // Re-render only while a live countdown is on screen.
        if (mounted && !_iAnswered && _remaining > Duration.zero) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
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

  void _applyState(Map<String, dynamic> json, {bool fromAnswer = false}) {
    final round = json['round'] as Map<String, dynamic>?;
    final no = (round?['no'] as num?)?.toInt() ?? 0;

    setState(() {
      _state = json;
      _loading = false;
      _offline = false;
      _submitting = false;

      if (no != _lastRoundNo) {
        _lastRoundNo = no;
        _selected = null;
        _feedback = null;
        _hintClueRevealed = false;
        _hintEliminated = null;
        _hintNudgeUsed = false;
        _nudgeFirstLetter = null;
        _nudgeLength = null;
      }

      if (fromAnswer && round != null) {
        final my = (round['myAnswerCorrect'] as num?)?.toInt();
        if (my == 1) {
          _feedback = '✨ Correct! +100 points';
          _feedbackGood = true;
          HapticFeedback.mediumImpact();
        } else if (my == 0) {
          _feedback = '❌ Wrong! You lost a heart';
          _feedbackGood = false;
          HapticFeedback.heavyImpact();
        }
      }
    });

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

  Future<void> _answer(String choice) async {
    final round = _round;
    if (round == null || _submitting || _iAnswered) return;
    if (_remaining <= Duration.zero) return;

    final no = (round['no'] as num).toInt();
    setState(() {
      _submitting = true;
      _selected = choice;
    });

    try {
      final json =
          await ApiClient.instance.answerBattle(widget.code, no, choice);
      if (!mounted) return;
      _applyState(json, fromAnswer: true);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _selected = null;
        _submitting = false;
      });
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                _buildPictureCard(round),
                const SizedBox(height: 16),
                _buildTimerBar(),
                const SizedBox(height: 20),
                _buildOptions(round),
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

  /// Same mechanics as the single-player hint sheet: each costs 1 hint from
  /// the wallet, enforced through GameData.useHint() (server re-validates on
  /// sync). Empty wallet opens the recovery dialog instead.
  Future<void> _openHintSheet() async {
    final round = _round;
    if (round == null || _iAnswered || _remaining <= Duration.zero) return;

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
                'Each hint costs 1 hint. They reset every round.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              _hintOption(
                sheetContext,
                kind: 'clue',
                icon: Icons.visibility_rounded,
                title: 'Reveal a clue',
                subtitle: 'Show the clue sentence for this picture.',
                used: _hintClueRevealed,
              ),
              const SizedBox(height: 10),
              _hintOption(
                sheetContext,
                kind: 'remove',
                icon: Icons.remove_circle_outline_rounded,
                title: 'Remove a wrong option',
                subtitle: 'Eliminate one wrong answer from the choices.',
                used: _hintEliminated != null,
              ),
              const SizedBox(height: 10),
              _hintOption(
                sheetContext,
                kind: 'nudge',
                icon: Icons.lightbulb_circle_rounded,
                title: 'Get a nudge',
                subtitle: 'Reveal the first letter and word length.',
                used: _hintNudgeUsed,
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
    required bool used,
  }) {
    return Material(
      color: used
          ? Colors.grey.withValues(alpha: 0.12)
          : AppColors.palePurple.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: used ? null : () => Navigator.pop(sheetContext, kind),
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
                child: Icon(icon,
                    size: 22,
                    color: used ? Colors.grey : AppColors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: used ? Colors.grey : AppColors.ink,
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
              if (used)
                const Text('Used',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey))
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.purple),
            ],
          ),
        ),
      ),
    );
  }

  /// Server-enforced spend: the endpoint debits the wallet atomically (D1)
  /// and computes the hint, because the correct word never reaches the
  /// client before the round resolves. The local mirror is updated from the
  /// server balance after every spend.
  Future<void> _spendHintAndApply(String kind) async {
    final round = _round;
    if (round == null || _submitting || !mounted) return;

    final alreadyUsed = kind == 'clue'
        ? _hintClueRevealed
        : kind == 'remove'
            ? _hintEliminated != null
            : _hintNudgeUsed;
    if (alreadyUsed) return;

    final no = (round['no'] as num).toInt();
    setState(() => _submitting = true);
    try {
      final json = await ApiClient.instance.battleHint(widget.code, no, kind);
      if (!mounted) return;
      if (json['hints'] != null) {
        GameData.instance.setHints(json['hints'] as int);
      }
      setState(() {
        _submitting = false;
        switch (kind) {
          case 'clue':
            _hintClueRevealed = true;
          case 'remove':
            _hintEliminated = json['remove'] as String?;
          case 'nudge':
            _nudgeFirstLetter = json['firstLetter'] as String?;
            _nudgeLength = json['length'] as int?;
            _hintNudgeUsed = true;
        }
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
    if (GameData.instance.coins < 50) {
      _showMessage('Need 50 coins to refill a life. Visit the store to get coins!');
      return;
    }

    try {
      final json = await ApiClient.instance.battleRefillLife(widget.code);
      if (!mounted) return;
      if (json['coins'] != null) {
        GameData.instance.setCoins(json['coins'] as int);
      } else {
        await GameData.instance.spendCoins(50);
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
          'right answer. You can buy 1 hint instantly for 150 coins, '
          'earn one free by watching a short ad, or grab a pack from the store.\n\n'
          'Coin balance: ${GameData.instance.coins} 🪙',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          if (GameData.instance.coins >= 150)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final spent = await GameData.instance.spendCoins(150);
                if (spent) {
                  await GameData.instance.addHints(1);
                  playSfx(Sfx.coin);
                  _showMessage('Purchased 1 hint for 150 coins! 🎉');
                }
              },
              icon: const Icon(Icons.stars_rounded, size: 17, color: Color(0xFFF5B82E)),
              label: const Text('Buy 1 hint (150 🪙)'),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
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

  // Nudge helpers: first letter and length from the server hint payload.
  String _firstLetter(Map<String, dynamic> round) {
    if (_nudgeFirstLetter != null && _nudgeFirstLetter!.isNotEmpty) {
      return _nudgeFirstLetter!;
    }
    return '?';
  }

  int _wordLength(Map<String, dynamic> round) {
    if (_nudgeLength != null && _nudgeLength! > 0) {
      return _nudgeLength!;
    }
    return (round['word'] as String? ?? '').length;
  }

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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 12, color: Colors.redAccent),
                        Text(
                          '+1 (50 🪙)',
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
                '$score',
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

  Widget _buildPictureCard(Map<String, dynamic> round) {
    final hint = _hintClueRevealed
        ? round['hint'] as String? ?? ''
        : ''; // clue costs a hint — hidden until purchased
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'WHICH WORD MATCHES?',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            round['picture'] as String? ?? '❓',
            style: const TextStyle(fontSize: 88, height: 1.1),
          ),
          if (_hintNudgeUsed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.palePurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Starts with "${_firstLetter(round)}" · '
                '${_wordLength(round)} letters',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
            ),
          ],
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1C9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_rounded,
                      size: 15, color: Color(0xFFB58A00)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF8A6800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    const total = Duration(seconds: _roundSeconds);
    final remaining = _remaining;
    final fraction = (remaining.inMilliseconds / total.inMilliseconds)
        .clamp(0.0, 1.0);
    final urgent = remaining.inSeconds <= 5;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(end: fraction),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: AppColors.palePurple,
              valueColor: AlwaysStoppedAnimation(
                urgent ? Colors.redAccent : AppColors.purple,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          remaining > Duration.zero
              ? '${remaining.inSeconds}s'
              : "Time's up!",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: urgent ? Colors.redAccent : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(Map<String, dynamic> round) {
    final options = (round['options'] as List<dynamic>? ?? [])
        .cast<String>()
        .toList();
    final word = round['word'] as String?; // revealed once the round is over
    final locked = _iAnswered || _submitting || _remaining <= Duration.zero;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      padding: EdgeInsets.zero,
      children: options.map((option) {
        final isSelected = _selected == option;
        final isRevealedCorrect = word != null && option == word;
        final isWrongPick = isSelected && !isRevealedCorrect && word != null;

        Color bg = Colors.white;
        Color border = AppColors.ink.withValues(alpha: 0.08);
        Color text = AppColors.ink;

        if (locked || word != null) {
          if (isRevealedCorrect) {
            bg = AppColors.paleGreen;
            border = AppColors.green;
            text = AppColors.green;
          } else if (isWrongPick || (isSelected && _feedbackGood == false)) {
            bg = const Color(0xFFFFEEEE);
            border = Colors.redAccent;
            text = Colors.redAccent;
          } else if (isSelected) {
            bg = AppColors.palePurple;
            border = AppColors.purple;
            text = AppColors.purple;
          }
        } else if (isSelected) {
          bg = AppColors.palePurple;
          border = AppColors.purple;
        }

        return Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: locked ? null : () => _answer(option),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                  ),
                  if (isRevealedCorrect && locked) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.green),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedback(Map<String, dynamic> round) {
    final opponentAnswered = round['opponentAnswered'] as bool? ?? false;
    final word = round['word'] as String?;
    final timedOut = !_iAnswered && _remaining <= Duration.zero;

    String? text;
    Color color = AppColors.purple;
    IconData icon = Icons.info_outline_rounded;

    if (_feedback != null) {
      text = _feedback;
      color = _feedbackGood ? AppColors.green : Colors.redAccent;
      icon = _feedbackGood
          ? Icons.check_circle_rounded
          : Icons.error_rounded;
    } else if (timedOut) {
      text = "⏱ Time's up! You lost a heart";
      color = Colors.redAccent;
      icon = Icons.timer_off_rounded;
    } else if (_iAnswered) {
      text =
          "Waiting for ${_opponent?['name'] as String? ?? 'your opponent'}…";
      icon = Icons.hourglass_top_rounded;
    } else if (opponentAnswered) {
      text = '⚡ Your opponent already answered — hurry!';
      color = Colors.orange;
      icon = Icons.bolt_rounded;
    }

    final showAnswerRow =
        word != null && _feedback != null && !_feedbackGood;

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
        if (showAnswerRow) ...[
          const SizedBox(height: 10),
          Text(
            'The answer was “$word”',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
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

  Widget _buildFinished() {
    final winnerId = _state?['winnerId'] as String?;
    final isDraw = winnerId == null;
    final isWin = !isDraw && winnerId == _myId;

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
                  ? '+200 bonus points · +50 coins'
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
          '$score pts',
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
