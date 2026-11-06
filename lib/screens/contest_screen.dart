import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../theme/app_theme.dart';
import 'battle_game_screen.dart';
import 'payout_details_screen.dart';

/// The bi-weekly global contest: top-10 selection, 5 knockout matches,
/// prizes and results. Data comes from GET /contest/current; matches are
/// real battle rooms — playing one opens BattleGameScreen directly.
class ContestScreen extends StatefulWidget {
  const ContestScreen({super.key});

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _entering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await ApiClient.instance.contestCurrent();
      if (!mounted) return;
      setState(() {
        _data = json;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.isNetworkError
            ? 'You are offline — the contest needs a connection.'
            : err.message;
        _loading = false;
      });
    }
  }

  String _money(num minor, String currency) => formatCashMinor(minor, currency);

  String _countdownTo(String? iso) {
    final t = DateTime.tryParse(iso ?? '');
    if (t == null) return '';
    final diff = t.difference(DateTime.now());
    if (diff.isNegative) return 'ended';
    if (diff.inDays >= 1) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  Future<void> _playMatch(Map<String, dynamic> match) async {
    if (_entering) return;
    setState(() => _entering = true);
    try {
      final json = await ApiClient.instance.enterContestMatch(match['id'] as String);
      final code = json['code'] as String;
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => BattleGameScreen(code: code)),
      );
      await _load();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isNetworkError
              ? 'You are offline — matches need a connection.'
              : err.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bi-weekly Contest',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: _buildBody(),
                  ),
                ),
    );
  }

  List<Widget> _buildBody() {
    final data = _data!;
    final prizes = data['prizes'] as Map<String, dynamic>;
    final contest = data['contest'] as Map<String, dynamic>?;
    final standings = (data['standings'] as List? ?? []);
    final lastResults = data['lastResults'] as Map<String, dynamic>?;

    return [
      // Prize banner
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7057E8), Color(0xFF9D7BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏆 GLOBAL BI-WEEKLY CONTEST',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_money(prizes['winnerCashMinor'] as num, prizes['currency'] as String)} + ${formatCount(prizes['winnerCoins'] as num)} coins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'for each of the 5 knockout winners · next contest in ${_countdownTo(data['nextSelectionAt'] as String?)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),

      // Winners get cash — nudge players without payout details.
      if (data['payoutConfigured'] == false)
        GestureDetector(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PayoutDetailsScreen()),
            );
            await _load();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF5B82E).withValues(alpha: 0.45)),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance_rounded, color: Color(0xFFB77900), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Set up your payout details so a cash prize can be sent to your bank account.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Color(0xFFB77900)),
              ],
            ),
          ),
        ),
      if (data['payoutConfigured'] == false) const SizedBox(height: 14),

      if (contest != null) ...[
        _sectionTitle('Knockout bracket'),
        const SizedBox(height: 4),
        Text(
          contest['status'] == 'completed'
              ? 'Contest finished'
              : 'Play before the deadline — ${_countdownTo(contest['resolveDeadline'] as String?)} left. If your opponent never shows up, you win!',
          style: const TextStyle(color: Colors.black54, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        ...(contest['matches'] as List? ?? []).map(
          (m) => _matchCard(m as Map<String, dynamic>),
        ),
        const SizedBox(height: 22),
      ] else ...[
        _sectionTitle('Top 10 standings this period'),
        const SizedBox(height: 4),
        const Text(
          'Finish in the top 10 when the period ends to enter the knockout.',
          style: TextStyle(color: Colors.black54, fontSize: 12.5),
        ),
      ],
      const SizedBox(height: 14),

      _standingsCard(standings),
      if (lastResults != null && (lastResults['winners'] as List? ?? []).isNotEmpty) ...[
        const SizedBox(height: 22),
        _sectionTitle('Last contest winners'),
        const SizedBox(height: 10),
        _winnersCard(lastResults),
      ],
      const SizedBox(height: 30),
    ];
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );

  Widget _playerRow(
    Map<String, dynamic>? player, {
    required int rank,
    bool isWinner = false,
  }) {
    if (player == null) {
      return const Text('TBD', style: TextStyle(color: Colors.black38));
    }
    final isMe = player['isMe'] as bool? ?? false;
    return Row(
      children: [
        if (rank > 0) ...[
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isMe ? AppColors.purple : Colors.black38,
            ),
          ),
          const SizedBox(width: 8),
        ],
        CircleAvatar(
          radius: 14,
          backgroundColor: isMe ? AppColors.purple.withValues(alpha: 0.15) : const Color(0xFFEDEEF4),
          child: Text(player['avatar'] as String? ?? '🧑', style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${player['name']}${isMe ? ' (you)' : ''}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isMe ? AppColors.purple : AppColors.ink,
            ),
          ),
        ),
        if (isWinner)
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFF5B82E), size: 18),
      ],
    );
  }

  String winnerName(
    String? winnerId,
    Map<String, dynamic>? host,
    Map<String, dynamic>? guest,
  ) {
    if (host != null && winnerId == host['userId']) return host['name'] as String? ?? '';
    if (guest != null && winnerId == guest['userId']) return guest['name'] as String? ?? '';
    return '';
  }

  Widget _matchCard(Map<String, dynamic> match) {
    final canEnter = match['canEnter'] as bool? ?? false;
    final iEntered = match['iEntered'] as bool? ?? false;
    final winnerId = match['winnerId'] as String?;
    final status = match['status'] as String? ?? 'waiting';
    final host = match['host'] as Map<String, dynamic>?;
    final guest = match['guest'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canEnter ? AppColors.purple : const Color(0xFFEDEEF4),
          width: canEnter ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _playerRow(host, rank: 0)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.black38)),
              ),
              Expanded(child: _playerRow(guest, rank: 0)),
            ],
          ),
          const SizedBox(height: 10),
          if (winnerId != null)
            Text(
              '✅ ${winnerName(winnerId, host, guest)} won'
              '${status == 'walkover' ? ' (walkover)' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Color(0xFF10B981),
              ),
            )
          else if (canEnter)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _entering ? null : () => _playMatch(match),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _entering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: const Text('Play match',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            )
          else if (iEntered && status == 'active' && match['battleCode'] != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _entering
                    ? null
                    : () async {
                        final code = match['battleCode'] as String;
                        await Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                              builder: (_) => BattleGameScreen(code: code)),
                        );
                        await _load();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Rejoin match',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            )
          else
            Text(
              status == 'active'
                  ? 'Match in progress — waiting for both players'
                  : 'Waiting to start',
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
        ],
      ),
    );
  }

  Widget _standingsCard(List<dynamic> standings) {
    if (standings.isEmpty) {
      return const Text(
        'No points earned yet this period — play levels and battles to qualify!',
        style: TextStyle(color: Colors.black38, fontSize: 13),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEEF4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < standings.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: _playerRow(
                standings[i] as Map<String, dynamic>,
                rank: i + 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _winnersCard(Map<String, dynamic> lastResults) {
    final winners = (lastResults['winners'] as List? ?? []);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5B82E).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (final w in winners)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: _playerRow(w as Map<String, dynamic>, rank: 0, isWinner: true),
            ),
        ],
      ),
    );
  }
}
