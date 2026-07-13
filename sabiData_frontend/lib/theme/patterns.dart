import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Motif géométrique inspiré du tissage faso dan fani : rangées de losanges
/// bordées de triangles, en très faible opacité. Signature culturelle de
/// l'app — teinté selon la langue active (mooré = or par défaut).
class FasoDanFaniPainter extends CustomPainter {
  final Color color;
  final double opacity;
  const FasoDanFaniPainter({required this.color, this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    const cell = 28.0; // largeur d'un losange
    final rows = (size.height / cell).ceil();
    final cols = (size.width / cell).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      final cy = r * cell + cell / 2;
      final shift = r.isOdd ? cell / 2 : 0.0;
      for (var c = 0; c < cols; c++) {
        final cx = c * cell + shift;
        final path = Path()
          ..moveTo(cx, cy - cell * 0.32)
          ..lineTo(cx + cell * 0.32, cy)
          ..lineTo(cx, cy + cell * 0.32)
          ..lineTo(cx - cell * 0.32, cy)
          ..close();
        canvas.drawPath(path, paint);
        // triangles latéraux une rangée sur deux
        if (r.isEven) {
          final tri = Path()
            ..moveTo(cx + cell * 0.38, cy - cell * 0.10)
            ..lineTo(cx + cell * 0.52, cy)
            ..lineTo(cx + cell * 0.38, cy + cell * 0.10)
            ..close();
          canvas.drawPath(tri, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(FasoDanFaniPainter old) =>
      old.color != color || old.opacity != opacity;
}

/// Bandeau horizontal de motif tissé (têtes d'écran, liserés de cartes).
class PatternBand extends StatelessWidget {
  final double height;
  final Color color;
  final double opacity;
  const PatternBand({
    super.key,
    this.height = 56,
    this.color = AppColors.gold,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: FasoDanFaniPainter(color: color, opacity: opacity),
      ),
    );
  }
}
