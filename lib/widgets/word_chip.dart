import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WordChip extends StatelessWidget {
  final String word;
  final bool dragging;

  const WordChip({
    super.key,
    required this.word,
    this.dragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: dragging ? AppColors.purple : AppColors.palePurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dragging ? AppColors.purple : const Color(0xFFD8D0FF),
        ),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Text(
        word,
        style: TextStyle(
          color: dragging ? Colors.white : AppColors.ink,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
