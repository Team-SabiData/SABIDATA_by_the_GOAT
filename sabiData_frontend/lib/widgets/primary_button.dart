import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'spring_tap.dart';

/// Bouton principal : rouge plein, hauteur 56, rebond au toucher,
/// état de chargement intégré.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final bool enabled;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
    this.enabled = true,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading && onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      child: SpringTap(
        enabled: active,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: active || loading ? color : color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: textColor),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: textColor),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textColor)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Bouton secondaire : contour, mêmes dimensions que PrimaryButton.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      child: SpringTap(
        enabled: active,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 20,
                    color: active ? AppColors.primary : AppColors.textMuted),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.primary
                            : AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
