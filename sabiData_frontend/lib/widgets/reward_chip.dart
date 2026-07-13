import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pastille de récompense « +N pts » — or, partout où des points sont
/// promis ou gagnés.
class RewardChip extends StatelessWidget {
  final int points;
  const RewardChip({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('+$points pts',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.gold)),
    );
  }
}
