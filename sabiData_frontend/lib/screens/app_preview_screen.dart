import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_thread.dart';
import '../data/auth/auth_session.dart';

/// Écran de découverte de l'app — accessible SANS compte.
/// Chaque action protégée déclenche le bottom sheet d'authentification.
class AppPreviewScreen extends StatelessWidget {
  const AppPreviewScreen({super.key});

  // Ouvre le bottom sheet d'auth si l'utilisateur n'est pas connecté.
  static void _requireAuth(BuildContext context, String destination) {
    if (AuthSession.instance.isAuthenticated) {
      context.go(destination);
      return;
    }
    _showAuthSheet(context, destination);
  }

  static void _showAuthSheet(BuildContext context, String destination) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthBottomSheet(destination: destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── App bar avec logo ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 216,
            backgroundColor: AppColors.bg,
            elevation: 0,
            pinned: false,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Motif textile de marque
                  Image.asset('assets/motifs/motif_voix.png', fit: BoxFit.cover),
                  // Voile : motif visible en haut, texte lisible en bas
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF7C0A02).withValues(alpha: 0.34),
                          const Color(0xFF7C0A02).withValues(alpha: 0.72),
                          const Color(0xFF5A0902).withValues(alpha: 0.96),
                        ],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                  // Contenu ancré en bas
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo marque + accent losange
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text('SabiData',
                                  style: AppText.display(34, color: Colors.white, weight: FontWeight.w800)
                                      .copyWith(shadows: const [
                                    Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2)),
                                  ])),
                              Positioned(
                                left: 50, top: 2,
                                child: Transform.rotate(
                                  angle: 0.785398,
                                  child: Container(width: 7, height: 7, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Préservez les langues du Burkina Faso — contribuez, gagnez.',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.94),
                              height: 1.45,
                              shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const GoldThread(bright: true),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _StatChip(label: '12 langues'),
                              const SizedBox(width: 8),
                              _StatChip(label: '13 régions'),
                              const SizedBox(width: 8),
                              _StatChip(label: '4K+ clips'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenu ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Section : Enregistrer ───────────────────────────────────
                _SectionTitle(title: 'Contribuer', subtitle: 'Enregistrez des phrases, validez, transcrivez'),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.mic_rounded,
                  iconColor: AppColors.primary,
                  title: 'Enregistrer une phrase',
                  description: 'Lisez une phrase à voix haute dans votre langue. Chaque clip est précieux.',
                  badge: 'Jusqu\'à ×3 pts',
                  badgeColor: AppColors.primary,
                  onTap: () => _requireAuth(context, '/recording'),
                ),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.green,
                  title: 'Valider des clips',
                  description: 'Écoutez et validez les enregistrements des autres contributeurs.',
                  badge: '+10 pts',
                  badgeColor: AppColors.green,
                  onTap: () => _requireAuth(context, '/validation'),
                ),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.text_fields_rounded,
                  iconColor: AppColors.blue,
                  title: 'Transcrire un clip',
                  description: 'Retranscrivez ce que vous entendez pour enrichir les données.',
                  badge: '+15 pts',
                  badgeColor: AppColors.blue,
                  onTap: () => _requireAuth(context, '/transcription'),
                ),
                const SizedBox(height: 24),

                // ── Section : Classement ────────────────────────────────────
                _SectionTitle(title: 'Classement', subtitle: 'Visible sans compte'),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.leaderboard_rounded,
                  iconColor: AppColors.yellow,
                  title: 'Classement national',
                  description: 'Voyez qui contribue le plus. Entrez dans le top 10 et remportez des récompenses.',
                  badge: 'Gratuit',
                  badgeColor: AppColors.yellow,
                  onTap: () => context.go('/leaderboard'),
                ),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.map_rounded,
                  iconColor: const Color(0xFF7B2D8B),
                  title: 'Carte des dialectes',
                  description: 'Explorez la couverture linguistique du Burkina Faso par région.',
                  badge: 'Gratuit',
                  badgeColor: const Color(0xFF7B2D8B),
                  onTap: () => context.go('/dialect-map'),
                ),
                const SizedBox(height: 24),

                // ── Section : Revenus ───────────────────────────────────────
                _SectionTitle(title: 'Vos revenus', subtitle: 'Transformez vos points en argent'),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.green,
                  title: 'Portefeuille & retraits',
                  description: 'Convertissez vos points en FCFA via Mobile Money (Orange, Moov).',
                  badge: 'Retrait dès 2000 pts',
                  badgeColor: AppColors.green,
                  onTap: () => _requireAuth(context, '/revenue'),
                ),
                const SizedBox(height: 24),

                // ── CTA principal ───────────────────────────────────────────
                _AuthCTA(
                  onRegister: () => context.go('/register'),
                  onLogin: () => context.go('/login'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(description,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCTA extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  const _AuthCTA({required this.onRegister, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE11D28), Color(0xFF9B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prêt à contribuer ?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Créez un compte gratuit et commencez à gagner des points dès maintenant.',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onRegister,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Créer un compte',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFE11D28))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onLogin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Text('Se connecter',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet affiché quand une action protégée est tentée sans compte.
class _AuthBottomSheet extends StatelessWidget {
  final String destination;
  const _AuthBottomSheet({required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.lock_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 14),
          const Text('Rejoignez SabiData',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Créez un compte gratuit pour accéder à toutes les fonctionnalités et commencer à gagner des points.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          // Register button
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.go('/register');
            },
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE11D28), Color(0xFF9B0000)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Créer un compte gratuit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Login link
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('J\'ai déjà un compte → Se connecter',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
