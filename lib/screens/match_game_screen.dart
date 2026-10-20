import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_level.dart';
import '../models/match_item.dart';
import '../theme/app_theme.dart';
import '../widgets/word_chip.dart';

class MatchGameScreen extends StatefulWidget {
  final GameLevel level;
  final int levelNumber;
  final void Function(int points, int stars) onComplete;
  final VoidCallback? onNext;

  const MatchGameScreen({
    super.key,
    required this.level,
    required this.levelNumber,
    required this.onComplete,
    required this.onNext,
  });

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen> {
  final Set<String> matched = {};
  final Map<String, String> placedWords = {};
  late List<MatchItem> shuffledWords;

  int firstAttemptCorrect = 0;
  int attempts = 0;
  int hintsUsed = 0;
  int points = 0;
  String feedback = 'Drag each word to its matching picture.';
  bool isComplete = false;
  bool completionReported = false;
  String? hintTarget;

  @override
  void initState() {
    super.initState();
    shuffledWords = List<MatchItem>.from(widget.level.items)
      ..shuffle(Random());
  }

  void _dropWord(MatchItem word, MatchItem target) {
    if (isComplete || matched.contains(target.id)) return;

    setState(() {
      attempts++;

      if (word.id == target.id) {
        if (matched.add(word.id)) {
          placedWords[target.id] = word.word;
          points += 100;
          firstAttemptCorrect++;
          feedback = 'Perfect match! +100 points';
        }
      } else {
        feedback = 'Not quite! Try another picture.';
      }

      hintTarget = null;

      if (matched.length == widget.level.items.length) {
        _finishLevel();
      }
    });
  }

  void _useHint() {
    if (isComplete || matched.length == widget.level.items.length) return;

    final remaining = widget.level.items
        .where((item) => !matched.contains(item.id))
        .toList();
    final target = remaining.first;

    setState(() {
      hintsUsed++;
      points = max(0, points - 25);
      hintTarget = target.id;
      feedback = 'Hint: ${target.hint}';
    });
  }

  void _finishLevel() {
    isComplete = true;

    final accuracy = attempts == 0 ? 0.0 : firstAttemptCorrect / attempts;
    final stars = accuracy == 1.0 && hintsUsed == 0
        ? 3
        : accuracy >= 0.8
            ? 2
            : 1;

    if (!completionReported) {
      completionReported = true;
      widget.onComplete(points, stars);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 12),
              const Text(
                'Level completed!',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You earned $points points',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Text(
                '⭐' * stars + '☆' * (3 - stars),
                style: const TextStyle(fontSize: 35),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (widget.onNext != null) {
                      widget.onNext!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    widget.onNext == null ? 'Finish' : 'Next level',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.level.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Level ${widget.levelNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                '$points pts',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.level.title,
                    style: const TextStyle(
                      fontSize: 25,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Drag each word onto the correct picture.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: matched.length / items.length,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE6E3F5),
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${matched.length} of ${items.length} matched',
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: items.length > 4 ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: items.length > 4 ? 0.85 : 1.05,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isMatched = matched.contains(item.id);
                  final isHinted = hintTarget == item.id;

                  return DragTarget<MatchItem>(
                    onWillAcceptWithDetails: (details) =>
                        !isMatched && !isComplete,
                    onAcceptWithDetails: (details) =>
                        _dropWord(details.data, item),
                    builder: (context, candidates, rejected) {
                      final isHovering = candidates.isNotEmpty;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? AppColors.paleGreen
                              : isHinted
                                  ? const Color(0xFFFFF1C9)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMatched
                                ? AppColors.green
                                : isHovering || isHinted
                                    ? AppColors.purple
                                    : const Color(0xFFE8E8F1),
                            width: isHovering || isHinted ? 2.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.picture,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 8),
                            if (isMatched)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.green,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      placedWords[item.id] ?? item.word,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                isHovering ? 'Drop here!' : 'Match me',
                                style: TextStyle(
                                  color: isHovering
                                      ? AppColors.purple
                                      : Colors.black38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        color: AppColors.purple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feedback,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _useHint,
                        child: const Text('Hint'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    alignment: WrapAlignment.center,
                    children: shuffledWords
                        .where((word) => !matched.contains(word.id))
                        .map((word) {
                      return Draggable<MatchItem>(
                        data: word,
                        feedback: Material(
                          color: Colors.transparent,
                          child: WordChip(word: word.word, dragging: true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.25,
                          child: WordChip(word: word.word),
                        ),
                        child: WordChip(word: word.word),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
