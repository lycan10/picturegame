import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/game_data.dart';
import '../core/sound_service.dart';
import '../theme/app_theme.dart';
import 'battle_game_screen.dart';
import 'battle_screen.dart';

enum InviteState { loading, open, taken, gone, isHost, notEnoughCoins }

/// Confirmation screen shown when a player taps a quick-match or friend
/// battle push notification. Shows the host and the entry cost; joining
/// claims the slot — for friend battles the joiner then waits in the lobby
/// until the host starts the battle.
class QuickMatchInviteScreen extends StatefulWidget {
  final String code;

  const QuickMatchInviteScreen({super.key, required this.code});

  @override
  State<QuickMatchInviteScreen> createState() => _QuickMatchInviteScreenState();
}

class _QuickMatchInviteScreenState extends State<QuickMatchInviteScreen> {
  Map<String, dynamic>? _info;
  InviteState _state = InviteState.loading;
  String? _error;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = InviteState.loading;
      _error = null;
    });
    try {
      final json = await ApiClient.instance.battleInviteInfo(widget.code);
      if (!mounted) return;
      setState(() {
        _info = json;
        _state = json['isHost'] as bool? ?? false
            ? InviteState.isHost
            : (json['open'] as bool? ?? false)
                ? (GameData.instance.coins >= (json['cost'] as num? ?? 0)
                    ? InviteState.open
                    : InviteState.notEnoughCoins)
                : InviteState.taken;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _state = err.status == 404 ? InviteState.gone : InviteState.taken;
        _error = err.isNetworkError
            ? 'You are offline — try again once connected.'
            : null;
      });
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final json = await ApiClient.instance.joinBattleRoom(widget.code);
      if (!mounted) return;
      playSfx(Sfx.coin);
      // Quick rooms go live immediately; friend rooms drop the joiner into
      // the lobby until the host starts the battle.
      final inLobby = json['inLobby'] as bool? ?? false;
      await Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(
          builder: (_) => inLobby
              ? BattleScreen(rejoinCode: widget.code, rejoinAsHost: false)
              : BattleGameScreen(code: widget.code),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isNetworkError
              ? 'You are offline — joining needs a connection.'
              : err.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Someone else may have grabbed the room while we were on this screen.
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick match invite',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case InviteState.loading:
        return const CircularProgressIndicator();
      case InviteState.gone:
        return _messageCard(
          icon: Icons.history_rounded,
          color: Colors.grey,
          title: 'Invite no longer available',
          message: _error ?? 'This quick match has expired or was cancelled.',
        );
      case InviteState.taken:
        return _messageCard(
          icon: Icons.block_rounded,
          color: Colors.redAccent,
          title: 'Match already taken',
          message: 'Someone else joined this quick match first. '
              'Try a new quick match from the Battles tab!',
        );
      case InviteState.isHost:
        return _messageCard(
          icon: Icons.person_rounded,
          color: AppColors.purple,
          title: 'This is your match',
          message: 'You created this quick match — keep the Battles tab open, '
              'an opponent will join soon.',
        );
      case InviteState.notEnoughCoins:
        return _messageCard(
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFFEF4444),
          title: 'Not enough coins',
          message: 'Joining this match costs '
              '${formatCount(_info?['cost'] as num? ?? 0)} coins and you have '
              '${formatCount(GameData.instance.coins)}. Get more coins in the store!',
        );
      case InviteState.open:
        return _openCard();
    }
  }

  Widget _openCard() {
    final info = _info!;
    final host = info['host'] as Map<String, dynamic>;
    final cost = (info['cost'] as num?)?.toInt() ?? 0;
    final isQuick = (info['mode'] as String? ?? 'quick') == 'quick';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7057E8), Color(0xFF9D7BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                isQuick ? '⚔️ QUICK MATCH' : '⚔️ FRIEND BATTLE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Text(
                  host['avatar'] as String? ?? '🧑',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                host['name'] as String? ?? 'A player',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${formatCount((host['points'] as num?)?.toInt() ?? 0)} pts · wants to battle now!',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          isQuick
              ? 'Joining costs ${formatCount(cost)} coins (both players pay). '
                  'Once you join, the match is full — first come, first served!'
              : 'Joining costs ${formatCount(cost)} coins (both players pay). '
                  'You will wait in the lobby until your friend starts the battle.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _joining ? null : _join,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _joining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bolt_rounded),
            label: Text(
              _joining ? 'Joining…' : 'Join match (${formatCount(cost)} 🪙)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Not now'),
        ),
      ],
    );
  }

  Widget _messageCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDEEF4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: color),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.4)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
