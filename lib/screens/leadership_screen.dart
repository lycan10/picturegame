import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int selectedTab = 2;

  final List<Map<String, dynamic>> players = [
    {
      'name': 'Sophia',
      'username': '@sophia_play',
      'score': 12500,
      'emoji': '👩🏻',
    },
    {
      'name': 'Ethan',
      'username': '@ethan_gamer',
      'score': 10850,
      'emoji': '👨🏽',
    },
    {
      'name': 'Olivia',
      'username': '@olivia_match',
      'score': 9200,
      'emoji': '👩🏽',
    },
    {
      'name': 'Noah',
      'username': '@noah_play',
      'score': 8750,
      'emoji': '👨🏻',
    },
    {
      'name': 'Ava',
      'username': '@ava_games',
      'score': 7600,
      'emoji': '👩🏾',
    },
    {
      'name': 'Liam',
      'username': '@liam_match',
      'score': 6900,
      'emoji': '👨🏼',
    },
    {
      'name': 'Mia',
      'username': '@mia_play',
      'score': 5800,
      'emoji': '👩🏼',
    },
    {
      'name': 'Lucas',
      'username': '@lucas_games',
      'score': 4650,
      'emoji': '👨🏿',
    },
  ];

  List<Map<String, dynamic>> get rankedPlayers {
    final result = List<Map<String, dynamic>>.from(players);

    if (selectedTab == 0) {
      for (final player in result) {
        player['score'] = (player['score'] as int) ~/ 8;
      }
    } else if (selectedTab == 1) {
      for (final player in result) {
        player['score'] = (player['score'] as int) ~/ 3;
      }
    }

    result.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = rankedPlayers;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildPeriodSelector(),
            _buildPodium(ranked),
            Expanded(
              child: _buildRankingList(ranked),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.purple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const FaIcon(
              FontAwesomeIcons.trophy,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'See who is leading the game',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const tabs = ['Daily', 'Weekly', 'All Time'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final selected = selectedTab == index;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedTab = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.purple : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> ranked) {
    final first = ranked[0];
    final second = ranked[1];
    final third = ranked[2];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 22),
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF0ECFF),
            Color(0xFFFAF9FF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Text(
            'TOP PLAYERS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildPodiumPlayer(
                  player: second,
                  rank: 2,
                  avatarSize: 60,
                  podiumHeight: 76,
                  color: const Color(0xFFB8C2D6),
                ),
              ),
              Expanded(
                child: _buildPodiumPlayer(
                  player: first,
                  rank: 1,
                  avatarSize: 78,
                  podiumHeight: 104,
                  color: const Color(0xFFFFC94D),
                ),
              ),
              Expanded(
                child: _buildPodiumPlayer(
                  player: third,
                  rank: 3,
                  avatarSize: 60,
                  podiumHeight: 60,
                  color: const Color(0xFFCE936B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlayer({
    required Map<String, dynamic> player,
    required int rank,
    required double avatarSize,
    required double podiumHeight,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rank == 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: FaIcon(
              FontAwesomeIcons.crown,
              color: Color(0xFFFFB92E),
              size: 22,
            ),
          ),
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Text(
            player['emoji'] as String,
            style: TextStyle(fontSize: avatarSize * 0.48),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          player['name'] as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _formatScore(player['score'] as int),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: podiumHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: AppColors.ink.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> ranked) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Text(
              'All Players',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              itemCount: ranked.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final player = ranked[index];
                final rank = index + 1;

                return _buildPlayerRow(
                  player: player,
                  rank: rank,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow({
    required Map<String, dynamic> player,
    required int rank,
  }) {
    final isTopThree = rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isTopThree ? const Color(0xFFF7F5FF) : AppColors.canvas,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isTopThree
              ? AppColors.purple.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isTopThree ? AppColors.purple : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAE5FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              player['emoji'] as String,
              style: const TextStyle(fontSize: 25),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  player['username'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatScore(player['score'] as int),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'POINTS',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatScore(int score) {
    return score.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]},',
        );
  }
}
