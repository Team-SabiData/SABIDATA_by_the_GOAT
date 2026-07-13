import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Flamme de série : jours consécutifs avec contribution. Pulse doucement
/// uniquement quand [highlight] est vrai (le jour où la série s'incrémente).
class StreakBadge extends StatefulWidget {
  final int days;
  final bool highlight;
  const StreakBadge({super.key, required this.days, this.highlight = false});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @visibleForTesting
  bool get isPulsing => _ctrl.isAnimating;

  void _syncPulse() {
    if (widget.highlight && !AppMotion.reduced(context)) {
      if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPulse();
    });
  }

  @override
  void didUpdateWidget(covariant StreakBadge old) {
    super.didUpdateWidget(old);
    if (old.highlight != widget.highlight) _syncPulse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.06)
          .chain(CurveTween(curve: Curves.easeInOut))
          .animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 18, color: AppColors.gold),
            const SizedBox(width: 4),
            Text('${widget.days}',
                style: AppText.numeric(15, color: AppColors.gold)),
          ],
        ),
      ),
    );
  }
}
