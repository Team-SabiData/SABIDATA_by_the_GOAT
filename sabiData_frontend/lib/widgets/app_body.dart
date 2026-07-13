import 'package:flutter/material.dart';

/// Enveloppe responsive commune à tous les écrans.
///
/// - [SafeArea] gère la vraie barre de statut / l'encoche de l'OS
///   (remplace l'ancienne fausse `AppStatusBar`).
/// - Sur grand écran (tablette, paysage large), le contenu est centré et
///   contraint à [maxWidth] au lieu d'être étiré sur toute la largeur.
///
/// La hauteur reste contrainte (tight) pour que les `Column` à `Expanded`
/// des écrans continuent de fonctionner sous le centrage horizontal.
class AppBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppBody({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
