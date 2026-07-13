import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';

/// Vues d'état partagées (vide / chargement / erreur).
///
/// Le front mock affiche toujours des données pleines ; ces vues comblent les
/// trois états que la collecte réelle rencontrera (file épuisée, fetch en
/// cours, échec réseau). Prêtes à être branchées sur les futurs appels API.

class AppLoadingState extends StatelessWidget {
  final String? label;
  final bool skeleton;
  const AppLoadingState({super.key, this.label, this.skeleton = false});

  @override
  Widget build(BuildContext context) {
    if (skeleton) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: const [
            SkeletonBox(height: 120),
            SizedBox(height: 12),
            SkeletonBox(height: 88),
            SizedBox(height: 12),
            SkeletonBox(height: 88),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34, height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(label!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(label: actionLabel!, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const AppErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    required this.message,
    this.actionLabel = 'Réessayer',
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.error_outline_rounded, size: 38, color: AppColors.red),
            ),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: 24),
            PrimaryButton(label: actionLabel, onTap: onAction),
          ],
        ),
      ),
    );
  }
}

/// Bloc squelette shimmer — chargements > 300 ms.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  const SkeletonBox({super.key, this.height = 72, this.width});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_ctrl),
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}
