import 'package:flutter/material.dart';
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

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementCategory selectedCategory = AchievementCategory.all;

  final Set<String> claimedRewards = {};

  final List<Achievement> achievements = const [
    // Daily rewards and streaks
    Achievement(
      id: 'first_login',
      title: 'Welcome Back',
      description: 'Log in for the first time.',
      icon: Icons.waving_hand_rounded,
      category: AchievementCategory.daily,
      progress: 1,
      target: 1,
      points: 50,
    ),
    Achievement(
      id: 'three_day_streak',
      title: 'Getting Consistent',
      description: 'Log in for 3 consecutive days.',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.daily,
      progress: 2,
      target: 3,
      points: 100,
    ),
    Achievement(
      id: 'seven_day_streak',
      title: 'Week Warrior',
      description: 'Maintain a 7-day login streak.',
      icon: Icons.calendar_month_rounded,
      category: AchievementCategory.daily,
      progress: 4,
      target: 7,
      points: 250,
    ),
    Achievement(
      id: 'thirty_day_streak',
      title: 'Unstoppable',
      description: 'Log in for 30 consecutive days.',
      icon: Icons.bolt_rounded,
      category: AchievementCategory.daily,
      progress: 4,
      target: 30,
      points: 1000,
      isSpecial: true,
    ),

    // Battle achievements
    Achievement(
      id: 'first_battle',
      title: 'Into the Arena',
      description: 'Complete your first battle.',
      icon: Icons.sports_esports_rounded,
      category: AchievementCategory.battle,
      progress: 1,
      target: 1,
      points: 100,
    ),
    Achievement(
      id: 'five_wins',
      title: 'Rising Champion',
      description: 'Win 5 battles.',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.battle,
      progress: 3,
      target: 5,
      points: 250,
    ),
    Achievement(
      id: 'twenty_five_wins',
      title: 'Battle Legend',
      description: 'Win 25 battles.',
      icon: Icons.military_tech_rounded,
      category: AchievementCategory.battle,
      progress: 8,
      target: 25,
      points: 750,
      isSpecial: true,
    ),
    Achievement(
      id: 'ten_win_streak',
      title: 'Win Streak',
      description: 'Win 10 battles in a row.',
      icon: Icons.whatshot_rounded,
      category: AchievementCategory.battle,
      progress: 2,
      target: 10,
      points: 500,
    ),
    Achievement(
      id: 'comeback',
      title: 'The Comeback',
      description: 'Win a battle with only one heart remaining.',
      icon: Icons.favorite_rounded,
      category: AchievementCategory.battle,
      progress: 0,
      target: 1,
      points: 300,
    ),
    Achievement(
      id: 'perfect_battle',
      title: 'Untouchable',
      description: 'Win a battle without losing a heart.',
      icon: Icons.shield_rounded,
      category: AchievementCategory.battle,
      progress: 0,
      target: 1,
      points: 350,
    ),

    // Skill achievements
    Achievement(
      id: 'first_perfect',
      title: 'Sharp Mind',
      description: 'Answer 10 questions correctly in a row.',
      icon: Icons.psychology_rounded,
      category: AchievementCategory.skill,
      progress: 7,
      target: 10,
      points: 200,
    ),
    Achievement(
      id: 'speedster',
      title: 'Speedster',
      description: 'Answer 10 questions within 3 seconds each.',
      icon: Icons.speed_rounded,
      category: AchievementCategory.skill,
      progress: 4,
      target: 10,
      points: 250,
    ),
    Achievement(
      id: 'hundred_correct',
      title: 'Word Wizard',
      description: 'Match 100 pictures correctly.',
      icon: Icons.auto_awesome_rounded,
      category: AchievementCategory.skill,
      progress: 63,
      target: 100,
      points: 400,
    ),
    Achievement(
      id: 'flawless_round',
      title: 'Perfect Round',
      description: 'Complete 20 matches without a mistake.',
      icon: Icons.stars_rounded,
      category: AchievementCategory.skill,
      progress: 0,
      target: 20,
      points: 500,
    ),

    // General progress
    Achievement(
      id: 'first_hundred',
      title: 'Point Collector',
      description: 'Earn your first 100 points.',
      icon: Icons.brightness_7_rounded,
      category: AchievementCategory.progress,
      progress: 100,
      target: 100,
      points: 50,
    ),
    Achievement(
      id: 'five_thousand',
      title: 'High Scorer',
      description: 'Earn 5,000 total points.',
      icon: Icons.trending_up_rounded,
      category: AchievementCategory.progress,
      progress: 2450,
      target: 5000,
      points: 300,
    ),
    Achievement(
      id: 'animal_expert',
      title: 'Animal Expert',
      description: 'Correctly identify 50 animals.',
      icon: Icons.pets_rounded,
      category: AchievementCategory.progress,
      progress: 31,
      target: 50,
      points: 200,
    ),
    Achievement(
      id: 'flag_master',
      title: 'Flag Master',
      description: 'Correctly identify 50 country flags.',
      icon: Icons.flag_rounded,
      category: AchievementCategory.progress,
      progress: 12,
      target: 50,
      points: 200,
    ),

    // Special challenges
    Achievement(
      id: 'comeback_kid',
      title: 'Never Give Up',
      description: 'Return to the game after a 7-day absence.',
      icon: Icons.restart_alt_rounded,
      category: AchievementCategory.special,
      progress: 0,
      target: 1,
      points: 150,
      isSpecial: true,
    ),
    Achievement(
      id: 'all_rounder',
      title: 'All-Rounder',
      description: 'Earn an achievement in every category.',
      icon: Icons.workspace_premium_rounded,
      category: AchievementCategory.special,
      progress: 2,
      target: 5,
      points: 600,
      isSpecial: true,
    ),
    Achievement(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Complete a match before 8 AM.',
      icon: Icons.wb_sunny_rounded,
      category: AchievementCategory.special,
      progress: 0,
      target: 1,
      points: 100,
      isSpecial: true,
    ),
  ];

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
        .where((item) => claimedRewards.contains(item.id))
        .fold(0, (sum, item) => sum + item.points);
  }

  void _claimReward(Achievement achievement) {
    if (!achievement.isUnlocked || claimedRewards.contains(achievement.id)) {
      return;
    }

    setState(() {
      claimedRewards.add(achievement.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
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
        SizedBox(
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Login Reward',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Come back every day to build your streak.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 7),
                Row(
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
    final claimed = claimedRewards.contains(achievement.id);
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
