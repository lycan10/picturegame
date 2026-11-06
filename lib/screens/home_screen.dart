import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:picture_match/core/ads_service.dart';
import 'package:picture_match/core/api_client.dart';
import 'package:picture_match/core/formatters.dart';
import 'package:picture_match/core/game_data.dart';
import 'package:picture_match/core/sound_service.dart';
import 'package:picture_match/screens/achievement_screen.dart';
import 'package:picture_match/screens/battle_screen.dart';
import 'package:picture_match/screens/leadership_screen.dart';
import 'package:picture_match/screens/page_transitions.dart';
import 'package:picture_match/screens/profile_screen.dart';
import 'package:picture_match/screens/store_screen.dart';
import '../theme/app_theme.dart';
import 'contest_screen.dart';
import 'level_selection_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // All player state lives in GameData (persisted locally, synced with the
  // backend when online). This screen just renders it.
  GameData get game => GameData.instance;

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameDataChanged);
    // Ads on open: the dedicated app-open ad first (waits briefly for its
    // preload); the every-3rd-launch interstitial only fires when no
    // app-open ad is available, so opens never stack two ads.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AdsService.instance.showAppOpenOnLaunch();
      AdsService.instance.maybeShowAppOpenInterstitial();
    });
  }

  @override
  void dispose() {
    game.removeListener(_onGameDataChanged);
    super.dispose();
  }

  void _onGameDataChanged() {
    if (mounted) setState(() {});
  }

  bool _isWorldUnlocked(String category) =>
      game.isWorldUnlocked(category) && !game.guestWorldLocked(category);

  // ---- Category metadata -----------------------------------------------
  static const _worlds = <String, _WorldInfo>{
    'animals': _WorldInfo(
      emoji: '🦁',
      title: 'Animal Kingdom',
      subtitle: 'Meet animals from around the world',
      tint: Color(0xFFE3F6EA),
      accent: Color(0xFF2E9E5B),
    ),
    'countries': _WorldInfo(
      emoji: '🌍',
      title: 'Flags of the World',
      subtitle: 'Spot countries by their flags',
      tint: Color(0xFFE5ECFF),
      accent: Color(0xFF3F6BE0),
    ),
  };

  int get selectedIndex => _selectedIndex;
  int _selectedIndex = 0;

  List<dynamic> _levelsFor(String category) => game.levelsFor(category);

  int _starsEarned(String category) =>
      (game.bestStars[category] ?? {}).values.fold(0, (a, b) => a + b);

  int _maxStars(String category) =>
      _levelsFor(category).length * GameData.maxStarsPerLevel;

  int _furthestLevel(String category) {
    final u = game.unlockedLevelsFor(category);
    return u.reduce((a, b) => a > b ? a : b);
  }

  // ---- Actions ----------------------------------------------------------
  Future<void> _openCategory(String category) async {
    game.setLastCategory(category);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LevelSelectionScreen(
          category: category,
          unlockedLevels: game.unlockedLevelsFor(category),
          bestStars: game.bestStars[category] ?? {},
          onLevelCompleted: (levelIndex, points, stars) {
            game.completeLevel(category, levelIndex, points, stars);
          },
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  void _openStore() => Navigator.push(
        context,
        PageTransitions.slideFromRight(const StoreScreen()),
      );

  void _openAchievements() => Navigator.push(
        context,
        PageTransitions.slideFromRight(const AchievementsScreen()),
      );

  void _showStreakDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final streak = game.streakDays;
        final coins = game.coins;
        final cost = game.streakRepairCost;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF8A3D), size: 28),
              SizedBox(width: 8),
              Text('Streak Saver', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Streak: $streak day${streak == 1 ? '' : 's'} 🔥',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Did you miss a day or want to protect and extend your streak? '
                'You can repair your streak for $cost coins — but only if it '
                'broke within the last 7 days.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 20, color: Color(0xFFF5B82E)),
                  const SizedBox(width: 6),
                  Text(
                    'Your balance: $coins coins',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (coins < cost) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You need at least $cost coins to repair your streak.'),
                      action: SnackBarAction(
                        label: 'Get Coins',
                        onPressed: _openStore,
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  final res = await ApiClient.instance.repairStreak();
                  if (!mounted) return;
                  if (res['streakDays'] != null) {
                    game.setStreak(res['streakDays'] as int);
                  }
                  if (res['coins'] != null) {
                    game.setCoins(res['coins'] as int);
                  }
                  playSfx(Sfx.coin);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Streak repaired to ${res['streakDays'] ?? (streak + 1)} days! 🔥'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } on ApiException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              },
              icon: const Icon(Icons.shield_rounded, size: 18),
              label: Text('Repair ($cost 🪙)'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A3D),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---- Build ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      const BattleScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: selectedIndex, children: pages)),
          // Native ad on the home tab only — gameplay and real-time
          // battle tabs stay ad-free to avoid stealing interaction.
          if (selectedIndex == 0) NativeAdWidget(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.purple.withValues(alpha: 0.14),
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports_rounded),
            label: 'Battle',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Leaderboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final goalDone = game.levelsToday >= game.dailyGoal;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _buildTopBar(),
          const SizedBox(height: 22),
          _buildContinueCard(),
          const SizedBox(height: 16),
          _DailyGoalCard(
            completed: game.levelsToday.clamp(0, game.dailyGoal),
            goal: game.dailyGoal,
            done: goalDone,
            streakDays: game.streakDays,
          ),
          const SizedBox(height: 16),
          _ContestBanner(),
          const SizedBox(height: 28),
          const Text(
            'Choose your world',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
        for (final entry in _worlds.entries) ...[
          _WorldCard(
            info: entry.value,
            starsEarned: _starsEarned(entry.key),
            maxStars: _maxStars(entry.key),
            unlockedCount: (game.unlocked[entry.key] ?? {0}).length,
            totalLevels: _levelsFor(entry.key).length,
            isUnlocked: _isWorldUnlocked(entry.key), // Pass lock status
            onTap: _isWorldUnlocked(entry.key)
                ? () => _openCategory(entry.key)
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Complete all levels in the previous world to unlock!')),
                    );
                  },
          ),
          const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  // Top bar: streak + coins on the left, trophy on the right.
  Widget _buildTopBar() {
    return Row(
      children: [
        _StatChip(
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFFF8A3D),
          label: '${game.streakDays}',
          semanticLabel: '${game.streakDays} day streak. Tap to repair streak',
          onTap: _showStreakDialog,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.stars_rounded,
          iconColor: const Color(0xFFF5B82E),
          label: formatCount(game.coins),
          semanticLabel: '${game.coins} coins. Open store',
          trailing: const Icon(Icons.add_circle_rounded,
              size: 18, color: AppColors.purple),
          onTap: _openStore,
        ),
        const Spacer(),
        // Notification inbox: contest invites, match reminders, results.
        Semantics(
          button: true,
          label: 'Notifications',
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openNotifications,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_rounded,
                        color: AppColors.ink, size: 21),
                    if (game.unreadNotifications > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            game.unreadNotifications > 9
                                ? '9+'
                                : '${game.unreadNotifications}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Achievements',
          child: Material(
            color: AppColors.purple,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openAchievements,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.trophy,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      PageTransitions.slideFromRight(const NotificationsScreen()),
    );
  }

  // Single, obvious primary action: resume where the player left off.
  Widget _buildContinueCard() {
    final info = _worlds[game.lastCategory]!;
    final levels = _levelsFor(game.lastCategory);
    final level = _furthestLevel(game.lastCategory);
    final hasStarted = (game.bestStars[game.lastCategory] ?? {}).isNotEmpty;
    final finishedAll =
        (game.unlocked[game.lastCategory] ?? {0}).length >= levels.length &&
            (game.bestStars[game.lastCategory] ?? {}).length >= levels.length;

    final headline = finishedAll
        ? 'You finished ${info.title}!'
        : hasStarted
            ? 'Welcome back!'
            : 'Ready to play?';
    final body = finishedAll
        ? 'Replay levels to earn more stars.'
        : 'Up next: ${info.title}, level ${level + 1}';
    final cta = finishedAll
        ? 'Replay'
        : hasStarted
            ? 'Continue'
            : 'Start playing';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B4FE6), Color(0xFF9786F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        size: 20, color: Color(0xFFFFD76A)),
                    const SizedBox(width: 6),
                    Text(
                      '${formatCount(game.totalScore)} points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _openCategory(game.lastCategory),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(cta),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.purple,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(info.emoji, style: const TextStyle(fontSize: 44)),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Supporting widgets
// =========================================================================

class _WorldInfo {
  final String emoji;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;

  const _WorldInfo({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
  });
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String semanticLabel;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.semanticLabel,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE9E6F5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Daily goal: gives players a reason to come back tomorrow.
class _DailyGoalCard extends StatelessWidget {
  final int completed;
  final int goal;
  final bool done;
  final int streakDays;

  const _DailyGoalCard({
    required this.completed,
    required this.goal,
    required this.done,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = goal - completed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E6F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: done ? const Color(0xFFE3F6EA) : const Color(0xFFFFF1E3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.local_fire_department_rounded,
              color: done ? const Color(0xFF2E9E5B) : const Color(0xFFFF8A3D),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Daily goal complete!' : "Today's goal",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Your $streakDays-day streak is safe. See you tomorrow!'
                      : 'Play $remaining more ${remaining == 1 ? 'level' : 'levels'} to keep your streak',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.ink.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < goal; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < completed
                                ? const Color(0xFFFF8A3D)
                                : const Color(0xFFEDEAF7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      if (i < goal - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Category card with visible progress so players see what they've achieved.
class _WorldCard extends StatelessWidget {
  final _WorldInfo info;
  final int starsEarned;
  final int maxStars;
  final int unlockedCount;
  final int totalLevels;
  final bool isUnlocked; // Add this parameter
  final VoidCallback onTap;

  const _WorldCard({
    required this.info,
    required this.starsEarned,
    required this.maxStars,
    required this.unlockedCount,
    required this.totalLevels,
    required this.isUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxStars == 0 ? 0.0 : starsEarned / maxStars;

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6, // Dim locked worlds
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE9E6F5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: info.tint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUnlocked ? info.emoji : '🔒', // Show lock emoji if locked
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUnlocked ? info.subtitle : 'Complete previous world to unlock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.ink.withValues(alpha: 0.65),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: info.tint,
                          valueColor: AlwaysStoppedAnimation(info.accent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16, color: Color(0xFFF5B82E)),
                          const SizedBox(width: 3),
                          Text(
                            '$starsEarned/$maxStars',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Level $unlockedCount',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.ink.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isUnlocked ? Icons.chevron_right_rounded : Icons.lock_rounded,
                  color: AppColors.ink.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Compact contest teaser under the daily goal — opens the contest screen.
class _ContestBanner extends StatelessWidget {
  final GameData game = GameData.instance;

  _ContestBanner();

  String get _money =>
      '${formatCashMinor(game.contestWinnerCashMinor, game.contestCurrency)} + ${formatCount(game.contestWinnerCoins)} coins';

  @override
  Widget build(BuildContext context) {
    if (!game.contestEnabled) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        if (!game.contestEnabled) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () {
            if (!game.isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign in to join the bi-weekly contest!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            Navigator.push(
              context,
              PageTransitions.slideFromRight(const ContestScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1065), Color(0xFF7057E8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bi-weekly Contest',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Top 10 players battle · 5 winners',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Win $_money',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFFF5B82E),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        );
      },
    );
  }
}