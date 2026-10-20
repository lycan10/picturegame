import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:picture_match/screens/achievement_screen.dart';
import 'package:picture_match/screens/battle_screen.dart';
import 'package:picture_match/screens/leadership_screen.dart';
import 'package:picture_match/screens/pageTransition.dart';
import 'package:picture_match/screens/profile_screen.dart';
import 'package:picture_match/screens/store_screen.dart';
import '../data/game_levels.dart';
import '../theme/app_theme.dart';
import '../widgets/category_card.dart';
import 'level_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int totalScore = 0;
  int selectedIndex = 0;

  final Map<String, Set<int>> unlocked = {
    'animals': {0},
    'countries': {0},
  };

  final Map<String, Map<int, int>> bestStars = {
    'animals': {},
    'countries': {},
  };

  Future<void> _openCategory(String category) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LevelSelectionScreen(
          category: category,
          unlockedLevels: unlocked[category]!,
          bestStars: bestStars[category]!,
          onLevelCompleted: (levelIndex, points, stars) {
            setState(() {
              totalScore += points;

              final levels =
                  category == 'animals' ? animalLevels : countryLevels;

              final nextIndex = levelIndex + 1;

              if (nextIndex < levels.length) {
                unlocked[category]!.add(nextIndex);
              }

              final previous = bestStars[category]![levelIndex] ?? 0;

              bestStars[category]![levelIndex] =
                  previous > stars ? previous : stars;
            });
          },
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      const BattleScreen(),
      const LeaderboardScreen(),
      const ProfileScreen()
    ];

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.purple.withValues(alpha: 0.14),
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                spacing: 5,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.canvas,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransitions.slideFromRight(
                              const StoreScreen(),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.stars_rounded,
                          size: 40,
                          color: Color(0xFFFFD76A),
                        ),
                      ),
                      const Text(
                        '0',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransitions.slideFromRight(
                          const AchievementsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 35,
                      height: 35,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.purple,
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.trophy,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7057E8),
                  Color(0xFF9786F5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to play?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Match the words to the pictures and collect stars!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '🦁   🐘   🦒   🇯🇵   🇧🇷',
                  style: TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFFFD76A),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$totalScore points earned',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          CategoryCard(
            emoji: '🦁',
            title: 'Animal Kingdom',
            subtitle: 'Discover animals from around the world',
            color: const Color(0xFFE3F6EA),
            onTap: () => _openCategory('animals'),
          ),
          const SizedBox(height: 14),
          CategoryCard(
            emoji: '🌍',
            title: 'Flags of the World',
            subtitle: 'Learn to recognize countries and flags',
            color: const Color(0xFFE5ECFF),
            onTap: () => _openCategory('countries'),
          ),
        ],
      ),
    );
  }
}
