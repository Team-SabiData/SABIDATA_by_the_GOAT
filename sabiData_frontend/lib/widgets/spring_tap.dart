import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/motion.dart';

/// Enveloppe tactile universelle : écrasement léger au toucher (scale 0.96),
/// retour à ressort au relâchement, haptique légère. Tout élément tactile
/// de l'app passe par ce widget.
class SpringTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool haptic;

  const SpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.haptic = true,
  });

  @override
  State<SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (_active && !AppMotion.reduced(context)) _ctrl.forward();
  }

  void _release() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapCancel: _release,
      onTapUp: (_) => _release(),
      onTap: _active
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * Curves.easeOut.transform(_ctrl.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
