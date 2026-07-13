import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/prefs/dialect_prefs.dart';

/// 3 pages d'onboarding — chaque page est portée par un vrai motif textile
/// africain plein cadre, fondu vers un bandeau de contenu lisible.
/// Affichées uniquement à la 1ère installation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _ctrl = PageController();
  int _page = 0;

  // Fil d'or unificateur (Faso Dan Fani) sous chaque titre.
  static const _gold = Color(0xFFF0B429);

  static const _pages = [
    _PageData(
      image: 'assets/motifs/motif_voix.png',
      accent: Color(0xFFE11D28), // rouge marque
      scrim: Color(0xFF3D0605),
      badge: 'Mission culturelle',
      title: 'Votre voix\na de la valeur',
      subtitle:
          'Les langues du Burkina disparaissent faute de données. Chaque phrase que vous enregistrez les préserve pour demain.',
    ),
    _PageData(
      image: 'assets/motifs/motif_dialecte.png',
      accent: Color(0xFF2A6BB0),
      scrim: Color(0xFF07223B),
      badge: 'Rareté = plus de points',
      title: 'Chaque dialecte\nest unique',
      subtitle:
          'Mooré, Dioula, Fulfuldé… Votre dialecte régional est précieux. Les zones peu couvertes rapportent jusqu\'à ×3 points.',
    ),
    _PageData(
      image: 'assets/motifs/motif_grandir.png',
      accent: Color(0xFFB8801F), // or bogolan
      scrim: Color(0xFF241608),
      badge: 'Récompenses réelles',
      title: 'Contribuez,\ngagnez, grandissez',
      subtitle:
          'Accumulez des points, montez dans le classement et transformez vos contributions en argent réel via Mobile Money.',
    ),
  ];

  Future<void> _finish() async {
    await DialectPrefs.save(onboardingDone: true);
    if (mounted) context.go('/preview');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pages[_page].accent;
    return Scaffold(
      backgroundColor: _pages[_page].scrim,
      body: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _OnboardPage(data: _pages[i], gold: _gold),
          ),

          // Skip (haut droite)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Passer',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),

          // Contrôles bas (dots + bouton)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? _gold : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        if (_page < _pages.length - 1) {
                          _ctrl.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _finish();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _page < _pages.length - 1 ? 'Suivant →' : 'Commencer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page individuelle ────────────────────────────────────────────────────────

class _OnboardPage extends StatefulWidget {
  final _PageData data;
  final Color gold;
  const _OnboardPage({required this.data, required this.gold});

  @override
  State<_OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<_OnboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Motif textile plein cadre
        FadeTransition(
          opacity: _fade,
          child: Image.asset(
            d.image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),

        // 2. Voile dégradé : lisibilité du texte + petite ombre en haut pour « Passer »
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.30),
                Colors.transparent,
                d.scrim.withValues(alpha: 0.88),
                d.scrim,
              ],
              stops: const [0.0, 0.26, 0.55, 1.0],
            ),
          ),
        ),

        // 3. Contenu ancré en bas
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 168),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: Text(d.badge.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.0)),
                        ),
                        const SizedBox(height: 18),
                        // Titre
                        Text(d.title,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.12,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 2)),
                              ],
                            )),
                        const SizedBox(height: 14),
                        // Fil d'or (signature Faso Dan Fani)
                        Container(width: 52, height: 3, color: widget.gold),
                        const SizedBox(height: 16),
                        // Sous-titre
                        Text(d.subtitle,
                            style: TextStyle(
                              fontSize: 15.5,
                              color: Colors.white.withValues(alpha: 0.90),
                              height: 1.55,
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 1)),
                              ],
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PageData {
  final String image;
  final Color accent;
  final Color scrim;
  final String badge;
  final String title;
  final String subtitle;
  const _PageData({
    required this.image,
    required this.accent,
    required this.scrim,
    required this.badge,
    required this.title,
    required this.subtitle,
  });
}
