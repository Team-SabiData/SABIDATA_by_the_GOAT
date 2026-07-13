import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_body.dart';
import '../widgets/app_card.dart';
import '../widgets/motif_header.dart';
import '../widgets/progress_ring.dart';
import '../widgets/streak_badge.dart';
import '../widgets/reward_chip.dart';
import '../widgets/spring_tap.dart';
import '../data/gamification/local_stats.dart';
import '../data/gamification/level.dart';
import '../data/auth/auth_session.dart';
import '../data/api/auth_api.dart';
import '../data/outbox/outbox_service.dart';
import '../data/prefs/dialect_prefs.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocalStats _stats = LocalStats();
  int _streak = 0;
  int _todayClips = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    AuthApi().refreshMe().catchError((_) {}); // meilleure-effort : garde les valeurs connues
  }

  Future<void> _loadStats() async {
    try {
      final s = await _stats.streak();
      final t = await _stats.todaySubmissions();
      if (mounted) {
        setState(() {
          _streak = s;
          _todayClips = t;
        });
      }
    } catch (e, st) {
      debugPrint('[DashboardScreen] _loadStats error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête à motif : salutation + série
              ValueListenableBuilder<UserProfile?>(
                valueListenable: AuthSession.instance.user,
                builder: (_, profile, __) => MotifHeader(
                  motif: 'assets/motifs/motif_voix.png',
                  subtitle: 'Bienvenue,',
                  title: profile?.name ?? 'Contributeur',
                  height: 176,
                  onTap: () => context.go('/profile'),
                  trailing: StreakBadge(days: _streak, highlight: _todayClips > 0),
                ),
              ),
              const SizedBox(height: 16),
              // Bandeau : enregistrements hors-ligne en attente de synchronisation
              ValueListenableBuilder<int>(
                valueListenable: OutboxService.instance.pendingCount,
                builder: (_, n, _) => n == 0
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_upload_rounded, size: 18, color: AppColors.gold),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$n enregistrement${n > 1 ? 's' : ''} en attente de synchronisation',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              // ── Carte héros : progression vers le prochain niveau
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ValueListenableBuilder<UserProfile?>(
                  valueListenable: AuthSession.instance.user,
                  builder: (_, profile, __) {
                    final points = profile?.points ?? 0;
                    final count = profile?.contributionsValidated ?? 0;
                    final lvl = LevelInfo.of(profile?.level ?? 'bronze', count);
                    return AppCard(
                      accent: true,
                      child: Row(
                        children: [
                          ProgressRing(
                            value: lvl.progress,
                            size: 104,
                            color: lvl.color,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$points', style: AppText.numeric(24)),
                                const Text('points',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lvl.label.toUpperCase(),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                        color: lvl.color, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Text(
                                    lvl.nextAt == null
                                        ? 'Niveau maximum atteint'
                                        : 'Prochain palier à ${lvl.nextAt} contributions',
                                    style: AppText.display(17)),
                                const SizedBox(height: 6),
                                Text('$count contributions validées',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // ── Deux grosses actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        hero: 'record-cta',
                        filled: true,
                        icon: Icons.mic_rounded,
                        label: 'Parler',
                        points: 150,
                        onTap: () => context.go('/recording'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        filled: false,
                        icon: Icons.task_alt_rounded,
                        label: 'Valider',
                        points: 20,
                        onTap: () => context.go('/validation'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Défi du jour
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: AppColors.gold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Défi du jour', style: AppText.display(15)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: LinearProgressIndicator(
                                value: (_todayClips / LocalStats.dailyGoal).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: AppColors.hairline,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$_todayClips/${LocalStats.dailyGoal}',
                          style: AppText.numeric(17, color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Explorer : toutes les destinations de l'ancien écran qui
              //    n'ont pas de carte dédiée (modules, espaces, carte).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Explorer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04 * 12)),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.3,
                      children: [
                        _ExploreTile(
                          icon: Icons.edit_note_rounded,
                          label: 'Transcrire',
                          onTap: () => context.go('/transcription'),
                        ),
                        _ExploreTile(
                          icon: Icons.school_rounded,
                          label: 'Espace linguiste',
                          onTap: () => context.go('/expert'),
                        ),
                        _ExploreTile(
                          icon: Icons.groups_rounded,
                          label: 'Classroom',
                          onTap: () => context.go('/classroom'),
                        ),
                        _ExploreTile(
                          icon: Icons.map_rounded,
                          label: 'Carte des dialectes',
                          onTap: () => context.go('/dialect-map'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Cartes secondaires : blocs existants (dialecte, revenus,
              //    classement) enveloppés dans AppCard, emojis remplacés par
              //    des icônes Material rounded, navigation existante conservée.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 20, color: AppColors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Builder(builder: (_) {
                          final lang    = DialectPrefs.lang    ?? 'Mooré';
                          final dialect = DialectPrefs.dialect ?? 'Yatenga';
                          final region  = DialectPrefs.region  ?? 'Nord';
                          return RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              children: [
                                TextSpan(text: '$lang · $dialect '),
                                TextSpan(
                                  text: '— dialecte $region',
                                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      if (DialectPrefs.rare > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                DialectPrefs.rareLabel,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SpringTap(
                  onTap: () => context.go('/revenue'),
                  child: AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.payments_rounded, size: 22, color: AppColors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Revenus', style: AppText.display(15)),
                              const SizedBox(height: 2),
                              const Text('Suivre tes gains et retraits',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SpringTap(
                  onTap: () => context.go('/leaderboard'),
                  child: AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.leaderboard_rounded, size: 22, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Classement', style: AppText.display(15)),
                              const SizedBox(height: 2),
                              const Text('Voir ton rang parmi les contributeurs',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExploreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String? hero;
  final bool filled;
  final IconData icon;
  final String label;
  final int points;
  final VoidCallback onTap;

  const _ActionCard({
    this.hero,
    required this.filled,
    required this.icon,
    required this.label,
    required this.points,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconCircle = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: filled ? Colors.white.withValues(alpha: 0.2) : AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 26, color: filled ? Colors.white : AppColors.primary),
    );
    return SpringTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 132),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.surface,
          border: filled ? null : Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: filled
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20, offset: const Offset(0, 8))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            hero != null ? Hero(tag: hero!, child: iconCircle) : iconCircle,
            const SizedBox(height: 12),
            Text(label,
                style: AppText.display(17,
                    color: filled ? Colors.white : AppColors.primary)),
            const SizedBox(height: 4),
            RewardChip(points: points),
          ],
        ),
      ),
    );
  }
}
