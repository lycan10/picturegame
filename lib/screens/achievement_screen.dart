import 'package:flutter/material.dart';
import '../core/game_data.dart';
import '../core/login_gate.dart';
import '../theme/app_theme.dart';

enum AchievementCategory {
  all,
  daily,
  battle,
  skill,
  progress,
  special,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final int progress;
  final int target;
  final int points;
  final bool claimed;
  final bool isSpecial;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.progress,
    required this.target,
    required this.points,
    this.claimed = false,
    this.isSpecial = false,
  });

  bool get isUnlocked => progress >= target;
  double get progressValue =>
      target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}

const Map<String, AchievementCategory> _categoryMap = {
  'daily': AchievementCategory.daily,
  'battle': AchievementCategory.battle,
  'skill': AchievementCategory.skill,
  'progress': AchievementCategory.progress,
  'special': AchievementCategory.special,
};

const Map<AchievementCategory, IconData> _categoryIcons = {
  AchievementCategory.daily: Icons.local_fire_department_rounded,
  AchievementCategory.battle: Icons.sports_esports_rounded,
  AchievementCategory.skill: Icons.psychology_rounded,
  AchievementCategory.progress: Icons.trending_up_rounded,
  AchievementCategory.special: Icons.workspace_premium_rounded,
};

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementCategory selectedCategory = AchievementCategory.all;

  GameData get game => GameData.instance;

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameData);
    // Pull fresh server-computed progress.
    game.refreshProfile();
  }

  @override
  void dispose() {
    game.removeListener(_onGameData);
    super.dispose();
  }

  void _onGameData() {
    if (mounted) setState(() {});
  }

  /// Server-driven achievement progress; falls back to the built-in catalog
  /// while offline (progress then comes from the last cached sync).
  List<Achievement> get achievements => game.achievements
      .map((def) => Achievement(
            id: def.id,
            title: def.title,
            description: def.description,
            icon: _categoryIcons[_categoryMap[def.category]] ??
                Icons.emoji_events_rounded,
            category: _categoryMap[def.category] ?? AchievementCategory.special,
            progress: def.progress,
            target: def.target,
            points: def.points,
            claimed: def.claimed,
            isSpecial: def.isSpecial,
          ))
      .toList();

  List<Achievement> get filteredAchievements {
    if (selectedCategory == AchievementCategory.all) {
      return achievements;
    }

    return achievements
        .where((item) => item.category == selectedCategory)
        .toList();
  }

  int get unlockedCount => achievements.where((item) => item.isUnlocked).length;

  int get totalPoints => achievements.fold(0, (sum, item) => sum + item.points);

  int get claimedPoints {
    return achievements
        .where((item) => item.claimed)
        .fold(0, (sum, item) => sum + item.points);
  }

  Future<void> _claimReward(Achievement achievement) async {
    if (!achievement.isUnlocked || achievement.claimed) return;
    // Claiming credits points to an account — sign in first.
    if (!await ensureSignedIn(context)) return;

    final error = await game.claimAchievement(achievement.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              '+${achievement.points} points claimed for ${achievement.title}!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProgressCard(),
              const SizedBox(height: 24),
              _buildDailyReward(),
              const SizedBox(height: 28),
              _buildSectionHeader(),
              const SizedBox(height: 16),
              _buildCategoryFilters(),
              const SizedBox(height: 18),
              ...filteredAchievements.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAchievementCard(achievement),
                ),
              ),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        const SizedBox(
          width: 3,
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.purple,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Awards & Achievements',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Every match brings a new milestone.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final progress =
        achievements.isEmpty ? 0.0 : unlockedCount / achievements.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7C3AED),
            Color(0xFF4C1D95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: Colors.amber,
                size: 26,
              ),
              SizedBox(width: 10),
              Text(
                'YOUR ACHIEVEMENT JOURNEY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlockedCount / ${achievements.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Achievements unlocked',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Completion',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$claimedPoints points claimed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '$totalPoints possible',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReward() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE4A3)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFB77900),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Login Reward',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Come back every day to build your streak.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                const Row(
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFB77900),
                      size: 16,
                    ),
                    SizedBox(width: 5),
                    Text(
                      '+25 points daily',
                      style: TextStyle(
                        color: Color(0xFF9A6700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      // Daily rewards live on the account — sign in first.
                      if (!await ensureSignedIn(context)) return;
                      final error = await game.claimDailyReward();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error ?? 'Daily reward claimed! +25 points'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.redeem_rounded, size: 17),
                    label: const Text('Claim today'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB77900),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.deepOrange,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR COLLECTION',
          style: TextStyle(
            color: AppColors.purple,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Achievements',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    final filters = [
      (AchievementCategory.all, 'All'),
      (AchievementCategory.daily, 'Daily'),
      (AchievementCategory.battle, 'Battle'),
      (AchievementCategory.skill, 'Skill'),
      (AchievementCategory.progress, 'Progress'),
      (AchievementCategory.special, 'Special'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = selectedCategory == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedCategory = filter.$1;
                });
              },
              selectedColor: AppColors.purple,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected
                    ? AppColors.purple
                    : Colors.grey.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final unlocked = achievement.isUnlocked;
    final claimed = achievement.claimed;
    final color =
        achievement.isSpecial ? const Color(0xFFB77900) : AppColors.purple;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.22)
              : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: unlocked
                  ? color.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              achievement.icon,
              size: 27,
              color: unlocked ? color : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (unlocked)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: color,
                      )
                    else
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: Colors.grey,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                if (!unlocked) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: achievement.progressValue,
                            minHeight: 6,
                            backgroundColor:
                                Colors.grey.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${achievement.progress}/${achievement.target}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFE5A000),
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${achievement.points} points',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9A6700),
                      ),
                    ),
                    const Spacer(),
                    if (unlocked)
                      claimed
                          ? const Text(
                              'CLAIMED',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () => _claimReward(achievement),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.purple,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Claim',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                    else
                      Text(
                        achievement.isSpecial ? 'SPECIAL' : 'LOCKED',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.purple,
            size: 23,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep playing, practice your matching skills, and '
              'challenge friends to unlock more achievements. '
              'Your next milestone is waiting!',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
