import 'package:flutter/widgets.dart';

/// Tokens de mouvement — toutes les animations de l'app puisent ici.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;

  /// True si l'utilisateur demande moins d'animations (accessibilité).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
