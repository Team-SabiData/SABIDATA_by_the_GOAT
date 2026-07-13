import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Retour visuel léger pour les actions sans backend (lecture audio,
/// détection GPS, retrait…). Remplace les handlers vides / boutons morts.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
