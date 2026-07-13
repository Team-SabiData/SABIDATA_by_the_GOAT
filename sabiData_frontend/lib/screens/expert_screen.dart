import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';

/// Espace Linguiste / Expert (README phase 2). Réservé aux contributeurs
/// `standard`. Regroupe : le suivi des tiers du dataset (recherche doc 2) et
/// la file des conversions Bronze → Or à réaliser.
class ExpertScreen extends StatelessWidget {
  const ExpertScreen({super.key});

  // Répartition des tiers (mock = agrégat serveur GET /dataset/tiers).
  static const _tiers = [
    {'icon': Icons.verified_rounded, 'label': 'Or', 'count': 312, 'color': 0xFFF5C518},
    {'icon': Icons.shield_rounded, 'label': 'Argent', 'count': 540, 'color': 0xFF9BA3B5},
    {'icon': Icons.shield_outlined, 'label': 'Bronze', 'count': 186, 'color': 0xFFB87333},
    {'icon': Icons.circle_outlined, 'label': 'Brut', 'count': 94, 'color': 0xFF5A6A82},
  ];

  // File des conversions en attente (transcriptions phonétiques cohérentes).
  static const _tasks = [
    {'lang': 'Mooré', 'dialect': 'Yatenga', 'snippet': 'keere wa, sigida be se…', 'dur': '0:06'},
    {'lang': 'Dioula', 'dialect': 'Ouest', 'snippet': 'i ni ce, an be taa…', 'dur': '0:09'},
    {'lang': 'Mooré', 'dialect': 'Centre', 'snippet': 'wend na koed-e…', 'dur': '0:05'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            MotifHeader(
              motif: 'assets/motifs/motif_dialecte.png',
              title: 'Espace Linguiste',
              height: 128,
              scrim: const Color(0xFF07223B),
              onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tier summary
                    const Text('Qualité du dataset — Mooré',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: _tiers.map((t) {
                        final color = Color(t['color'] as int);
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Icon(t['icon'] as IconData, size: 20, color: color),
                                const SizedBox(height: 6),
                                Text('${t['count']}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                                const SizedBox(height: 2),
                                Text(t['label'] as String,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Le Bronze n\'est pas perdu : convertissez les transcriptions phonétiques cohérentes en standard pour les faire monter en Or.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Text('Conversions en attente',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('${_tasks.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._tasks.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => context.go('/conversion'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                child: const Center(child: Icon(Icons.shield_outlined, size: 18, color: AppColors.orange)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text('${t['lang']} · ${t['dialect']}',
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(t['dur'] as String,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text('"${t['snippet']}"',
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    )),
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
