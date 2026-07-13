import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bouton retour partagé.
///
/// Garantit une cible tactile de 48x48 dp et une sémantique de bouton
/// (annoncé par les lecteurs d'écran, focusable) via [IconButton] —
/// contrairement à l'ancien `GestureDetector` autour d'une icône de 28 dp.
class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 28),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tooltip: 'Retour',
    );
  }
}
