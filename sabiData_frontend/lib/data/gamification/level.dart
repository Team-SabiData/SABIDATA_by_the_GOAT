import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Paliers gamifiés — miroir front des seuils backend (Argent 50, Or 200).
class LevelInfo {
  final String label;
  final IconData icon;
  final Color color;
  final int? nextAt;      // seuil du palier suivant (null si Or)
  final double progress;  // 0..1 vers le palier suivant

  const LevelInfo({
    required this.label,
    required this.icon,
    required this.color,
    required this.nextAt,
    required this.progress,
  });

  static const int argentAt = 50;
  static const int orAt = 200;

  factory LevelInfo.of(String level, int validatedCount) {
    switch (level) {
      case 'or':
        return const LevelInfo(
          label: 'Gardien Or', icon: Icons.verified_rounded, color: AppColors.gold,
          nextAt: null, progress: 1.0);
      case 'argent':
        return LevelInfo(
          label: 'Gardien Argent', icon: Icons.shield_rounded, color: const Color(0xFF9BA3B5),
          nextAt: orAt,
          progress: ((validatedCount - argentAt) / (orAt - argentAt)).clamp(0.0, 1.0));
      default: // bronze
        return LevelInfo(
          label: 'Gardien Bronze', icon: Icons.shield_outlined, color: AppColors.bronzeBadge,
          nextAt: argentAt,
          progress: (validatedCount / argentAt).clamp(0.0, 1.0));
    }
  }
}
