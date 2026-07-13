import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Célébration de réussite : pluie de confettis (couleurs marque + or)
/// et gros « +N pts » au centre. ~1,2 s, interruptible au tap.
/// Reduced motion → bannière en fondu simple.
Future<void> showCelebration(BuildContext context, {required int points}) async {
  final overlay = Overlay.of(context);
  final reduced = AppMotion.reduced(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationView(
      points: points,
      reduced: reduced,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _CelebrationView extends StatefulWidget {
  final int points;
  final bool reduced;
  final VoidCallback onDone;
  const _CelebrationView(
      {required this.points, required this.reduced, required this.onDone});

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: widget.reduced
          ? const Duration(milliseconds: 900)
          : const Duration(milliseconds: 1200));
  late final List<_Particle> _particles;
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(60, (_) => _Particle.random(rng));
    _ctrl.forward().whenCompleteOrCancel(_finish);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _ctrl.stop();
          _finish();
        }, // interruptible
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final fade = t < 0.15
                ? t / 0.15
                : t > 0.75
                    ? (1 - t) / 0.25
                    : 1.0;
            return Stack(
              children: [
                if (!widget.reduced)
                  CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(particles: _particles, t: t),
                  ),
                Center(
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('+${widget.points} pts',
                          style: AppText.numeric(28, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1 position horizontale
  final double speed; // vitesse de chute relative
  final double size;
  final double drift; // dérive horizontale
  final Color color;
  const _Particle(this.x, this.speed, this.size, this.drift, this.color);

  static const _colors = [
    AppColors.primary,
    AppColors.gold,
    AppColors.green,
    AppColors.blue,
  ];

  factory _Particle.random(math.Random rng) => _Particle(
        rng.nextDouble(),
        0.6 + rng.nextDouble() * 0.8,
        4 + rng.nextDouble() * 5,
        (rng.nextDouble() - 0.5) * 0.2,
        _colors[rng.nextInt(_colors.length)],
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (t * p.speed) * (size.height + 40) - 20;
      final x = (p.x + p.drift * t) * size.width;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 4 * p.drift * 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
