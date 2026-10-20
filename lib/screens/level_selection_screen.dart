import 'package:flutter/material.dart';
import '../data/game_levels.dart';
import '../models/game_level.dart';
import '../theme/app_theme.dart';
import 'match_game_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  final String category;
  final Set<int> unlockedLevels;
  final Map<int, int> bestStars;
  final void Function(int levelIndex, int points, int stars)
      onLevelCompleted;

  const LevelSelectionScreen({
    super.key,
    required this.category,
    required this.unlockedLevels,
    required this.bestStars,
    required this.onLevelCompleted,
  });

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  List<GameLevel> get levels =>
      widget.category == 'animals' ? animalLevels : countryLevels;

  String get title =>
      widget.category == 'animals' ? 'Animal Kingdom' : 'Flags of the World';

  Future<void> _openLevel(int index) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchGameScreen(
          key: ValueKey('${widget.category}-$index'),
          level: levels[index],
          levelNumber: index + 1,
          onComplete: (points, stars) {
            widget.onLevelCompleted(index, points, stars);
            if (mounted) setState(() {});
          },
          onNext: index + 1 < levels.length
              ? () {
                  Navigator.pop(context);
                  _openLevel(index + 1);
                }
              : null,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Choose a level',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete a level to unlock the next one.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: levels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final isUnlocked = widget.unlockedLevels.contains(index);
              final stars = widget.bestStars[index] ?? 0;

              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: isUnlocked ? () => _openLevel(index) : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? Colors.white
                        : const Color(0xFFEDEEF4),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isUnlocked
                          ? const Color(0xFFE5E2F7)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            backgroundColor: isUnlocked
                                ? const Color(0xFFECE8FF)
                                : const Color(0xFFDFE1E8),
                            child: Icon(
                              isUnlocked
                                  ? Icons.extension_rounded
                                  : Icons.lock_rounded,
                              color: isUnlocked ? AppColors.purple : Colors.grey,
                            ),
                          ),
                          Text(
                            'LEVEL ${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        levels[index].title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '⭐' * stars + '☆' * (3 - stars),
                        style: const TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
