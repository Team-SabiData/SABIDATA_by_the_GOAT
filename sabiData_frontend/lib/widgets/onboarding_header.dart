import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'gold_thread.dart';

/// En-tête commun des écrans d'auth : bandeau à motif textile (motif + voile),
/// bouton retour intégré, titre display blanc, fil d'or et sous-titre optionnel.
/// Le formulaire reste sur surface claire en dessous.
class OnboardingHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String motif;
  final Color scrim;

  const OnboardingHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.motif = 'assets/motifs/motif_voix.png',
    this.scrim = const Color(0xFF3D0605),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: subtitle == null ? 138 : 168,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(motif, fit: BoxFit.cover, alignment: Alignment.center),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scrim.withValues(alpha: 0.86),
                    scrim.withValues(alpha: 0.5),
                    scrim.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onBack != null)
                      GestureDetector(
                        onTap: onBack,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppText.display(26, color: Colors.white, weight: FontWeight.w800)
                                  .copyWith(shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2)),
                              ])),
                          const SizedBox(height: 10),
                          const GoldThread(bright: true),
                          if (subtitle != null) ...[
                            const SizedBox(height: 10),
                            Text(subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.4,
                                  shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                                )),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
