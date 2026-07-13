import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/patterns.dart';

/// Carte standard : surface blanche, radius 20, UNE seule ombre douce
/// dans toute l'app. Variante [accent] : liseré motif tissé en tête.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool accent;
  final Color accentColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = false,
    this.accentColor = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent) PatternBand(height: 8, color: accentColor, opacity: 0.5),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

