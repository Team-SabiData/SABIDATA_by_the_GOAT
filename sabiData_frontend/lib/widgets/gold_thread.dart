import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Fil d'or Faso Dan Fani — accent-signature récurrent sous les titres et
/// en-têtes de section dans toute l'app.
class GoldThread extends StatelessWidget {
  final double width;
  final double height;

  /// Variante claire (or vif) pour poser sur fond sombre / motif ;
  /// par défaut l'or profond de la marque pour les surfaces claires.
  final bool bright;

  const GoldThread({super.key, this.width = 52, this.height = 3, this.bright = false});

  @override
  Widget build(BuildContext context) {
    final c = bright ? const Color(0xFFF0B429) : AppColors.gold;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.55)]),
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}
