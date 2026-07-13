import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'gold_thread.dart';

/// En-tête à motif textile — la signature « Faso textile » en haut des écrans
/// de contenu (dashboard, revenus, classement, profil…). Un vrai motif plein
/// cadre sous un voile teinté, avec titre, fil d'or et widget optionnel à droite.
class MotifHeader extends StatelessWidget {
  final String motif; // chemin d'asset
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  /// Affiche un bouton retour blanc intégré (si [leading] n'est pas fourni).
  final VoidCallback? onBack;
  final Color scrim;
  final double height;

  const MotifHeader({
    super.key,
    required this.motif,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.onBack,
    this.scrim = const Color(0xFF3D0605),
    this.height = 196,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? lead = leading ??
        (onBack != null
            ? GestureDetector(
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
              )
            : null);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Motif textile
            Image.asset(motif, fit: BoxFit.cover, alignment: Alignment.topCenter),
            // Voile teinté (diagonale : coins plus denses, motif visible au centre)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scrim.withValues(alpha: 0.88),
                    scrim.withValues(alpha: 0.48),
                    scrim.withValues(alpha: 0.86),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Contenu
            SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lead != null || trailing != null)
                        Row(
                          children: [
                            ?lead,
                            const Spacer(),
                            ?trailing,
                          ],
                        ),
                      const Spacer(),
                      if (subtitle != null) ...[
                        Text(subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                              shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                            )),
                        const SizedBox(height: 2),
                      ],
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.display(26, color: Colors.white, weight: FontWeight.w800)
                              .copyWith(shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2)),
                          ])),
                      const SizedBox(height: 10),
                      const GoldThread(bright: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
