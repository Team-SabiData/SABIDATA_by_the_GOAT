import 'package:flutter/material.dart';

/// Barre de progression réutilisable (fond + remplissage fractionnaire).
/// Remplace le `Stack(Container + FractionallySizedBox)` dupliqué dans
/// plusieurs écrans.
class AppProgressBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final Color? color;
  final Gradient? gradient;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.gradient,
  }) : assert(color != null || gradient != null, 'color ou gradient requis');

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Container(height: height, color: Colors.black.withValues(alpha: 0.08)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: gradient == null ? color : null,
                gradient: gradient,
                borderRadius: radius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
