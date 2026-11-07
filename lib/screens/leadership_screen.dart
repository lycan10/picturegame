import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/game_data.dart';
import '../core/login_gate.dart';
import '../core/formatters.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int selectedTab = 2;
  bool loading = false;
  bool offline = false;

  // Sample roster used until the backend responds (and while offline).
  final List<Map<String, dynamic>> players = [
    {'name': 'Sophia', 'username': '@sophia_play', 'score': 12500, 'emoji': '👩🏻', 'isMe': false},
    {'name': 'Ethan', 'username': '@ethan_gamer', 'score': 10850, 'emoji': '👨🏽', 'isMe': false},
    {'name': 'Olivia', 'username': '@olivia_match', 'score': 9200, 'emoji': '👩🏽', 'isMe': false},
    {'name': 'Noah', 'username': '@noah_play', 'score': 8750, 'emoji': '👨🏻', 'isMe': false},
    {'name': 'Ava', 'username': '@ava_games', 'score': 7600, 'emoji': '👩🏾', 'isMe': false},
    {'name': 'Liam', 'username': '@liam_match', 'score': 6900, 'emoji': '👨🏼', 'isMe': false},
    {'name': 'Mia', 'username': '@mia_play', 'score': 5800, 'emoji': '👩🏼', 'isMe': false},
    {'name': 'Lucas', 'username': '@lucas_games', 'score': 4650, 'emoji': '👨🏿', 'isMe': false},
  ];

  static const _periods = ['daily', 'weekly', 'all'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<String> _friendIds = {};

  Future<void> _load() async {
    if (!GameData.instance.isLoggedIn) return;
    setState(() => loading = true);
    try {
      // Friend ids in parallel so rows can offer "add friend" (discovery).
      unawaited(ApiClient.instance.friends().then((json) {
        if (!mounted) return;
        setState(() {
          _friendIds = ((json['friends'] as List? ?? [])
                  .whereType<Map>()
                  .map((f) => f['userId'] as String?))
              .whereType<String>()
              .toSet();
        });
      }).catchError((Object _) {}));
      final json = await ApiClient.instance.leaderboard(_periods[selectedTab]);
      final entries = (json['entries'] as List)
          .map((e) => {
                'name': e['name'] as String,
                'username': e['username'] as String,
                'score': e['score'] as int,
                'emoji': e['avatar'] as String,
                'photo': e['avatarUrl'] as String?,
                'isMe': e['isMe'] as bool? ?? false,
                'userId': e['userId'] as String?,
              })
          .take(10)
          .toList();
      if (mounted) {
        setState(() {
          players
            ..clear()
            ..addAll(entries);
          offline = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => offline = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Discovery: add a player from the leaderboard as a friend. Guests are
  /// routed through the consistent sign-in modal first.
  Future<void> _addFriend(Map<String, dynamic> player) async {
    final userId = player['userId'] as String?;
    if (userId == null) return;
    if (GameData.instance.isGuestLike) {
      final signedIn = await ensureSignedIn(
        context,
        title: 'Sign in to unlock',
        message:
            'Friends are for signed-in players — add the people you meet in '
            'battles and on the leaderboard, then challenge them anytime!',
      );
      if (!signedIn || !mounted) return;
    }
    try {
      final json = await ApiClient.instance.sendFriendRequest(userId);
      final result = json['result'] as String? ?? 'sent';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            'auto-accepted' => 'You are now friends with ${player['name']}! 🎉',
            'already-friends' => 'Already friends with ${player['name']}.',
            _ => 'Friend request sent to ${player['name']}!',
          }),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result == 'auto-accepted') {
        setState(() => _friendIds.add(userId));
      } else {
        setState(() => _friendIds.add(userId)); // pending — hide the button
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isNetworkError ? 'You are offline.' : err.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Player avatar: uploaded photo when present, emoji otherwise.
  Widget _playerAvatar(Map<String, dynamic> player, double size, Color border) {
    final photoPath = player['photo'] as String?;
    final Widget content;
    if (photoPath != null && photoPath.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          '${AppConfig.baseUrl}$photoPath',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emojiAvatar(player, size),
        ),
      );
    } else {
      content = _emojiAvatar(player, size);
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _emojiAvatar(Map<String, dynamic> player, double size) {
    return Text(
      player['emoji'] as String? ?? '👤',
      style: TextStyle(fontSize: size * 0.48),
    );
  }

  List<Map<String, dynamic>> get rankedPlayers {
    final result = List<Map<String, dynamic>>.from(players);
    result.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = rankedPlayers;
    final signedIn = GameData.instance.isLoggedIn;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.purple,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Top Header Section
              SliverToBoxAdapter(child: _buildHeader()),

              // Guest prompt banner
              if (!signedIn)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: Material(
                      color: AppColors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          if (!await ensureSignedIn(context)) return;
                          if (mounted) _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.purple.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.lock_rounded, size: 16, color: AppColors.purple),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sample Rankings Shown',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Sign in to compete & win cash prizes',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.purple),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Period Selector Tabs
              SliverToBoxAdapter(child: _buildPeriodSelector()),

              // Offline/Error state banner indicator
              if (offline)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing offline roster cached data.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Podium Section
              SliverToBoxAdapter(child: _buildPodium(ranked)),

              // Sticky or Scrolling Header for All Players section
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Players',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${ranked.length} competitors',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Player Roster List (Seamlessly scrolling within the parent scroll view)
              ranked.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_off_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No rankings available',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final player = ranked[index];
                          final rank = index + 1;

                          // Wrap items in container to maintain white background backing the list section
                          return Container(
                            color: Colors.white,
                            padding: EdgeInsets.fromLTRB(
                              22,
                              0,
                              22,
                              index == ranked.length - 1 ? 32 : 8,
                            ),
                            child: _buildPlayerRow(
                              player: player,
                              rank: rank,
                            ),
                          );
                        },
                        childCount: ranked.length,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.purple,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const FaIcon(
              FontAwesomeIcons.trophy,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loading ? 'Updating rankings...' : 'See who is leading the game',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.purple),
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
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.purple : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink.withValues(alpha: 0.7),
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
    final safe = [
      ...ranked,
      for (var i = ranked.length; i < 3; i++)
        {'name': '—', 'username': '', 'score': 0, 'emoji': '❓', 'isMe': false},
    ];
    final first = safe[0];
    final second = safe[1];
    final third = safe[2];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF3EFFF),
            Color(0xFFFAFAFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.purple),
              const SizedBox(width: 6),
              const Text(
                'TOP PLAYERS PODIUM',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildPodiumPlayer(
                  player: second,
                  rank: 2,
                  avatarSize: 58,
                  podiumHeight: 72,
                  color: const Color(0xFFB8C2D6),
                ),
              ),
              Expanded(
                child: _buildPodiumPlayer(
                  player: first,
                  rank: 1,
                  avatarSize: 74,
                  podiumHeight: 98,
                  color: const Color(0xFFFFC94D),
                ),
              ),
              Expanded(
                child: _buildPodiumPlayer(
                  player: third,
                  rank: 3,
                  avatarSize: 58,
                  podiumHeight: 56,
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
              size: 20,
            ),
          ),
        _playerAvatar(player, avatarSize, color),
        const SizedBox(height: 8),
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
        const SizedBox(height: 2),
        Text(
          _formatScore(player['score'] as int),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: podiumHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.ink.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerRow({
    required Map<String, dynamic> player,
    required int rank,
  }) {
    final isTopThree = rank <= 3;
    final isMe = player['isMe'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.purple.withValues(alpha: 0.08)
            : (isTopThree ? const Color(0xFFF9F7FF) : AppColors.canvas),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.purple.withValues(alpha: 0.4)
              : (isTopThree ? AppColors.purple.withValues(alpha: 0.1) : Colors.transparent),
          width: isMe ? 1.5 : 1,
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
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isTopThree ? AppColors.purple : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _playerAvatar(player, 42, isMe ? AppColors.purple : const Color(0xFFEAE5FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isMe ? AppColors.purple : AppColors.ink,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  player['username'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Discovery: offer "add friend" for players we're not connected to.
          if (!isMe &&
              (player['userId'] as String?) != null &&
              !_friendIds.contains(player['userId']) &&
              GameData.instance.isLoggedIn)
            IconButton(
              tooltip: 'Add friend',
              icon: Icon(Icons.person_add_rounded,
                  size: 20, color: Colors.grey.shade600),
              onPressed: () => _addFriend(player),
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatScore(player['score'] as int),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'POINTS',
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.8,
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

  String _formatScore(int score) => formatCount(score);
}