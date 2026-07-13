import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_thread.dart';
import '../data/prefs/dialect_prefs.dart';
import '../data/auth/auth_session.dart';
import '../data/api/auth_api.dart';
import '../data/api/api_exception.dart';

/// Écran de démarrage — révèle la marque sur un motif textile, puis redirige
/// automatiquement selon l'état (onboarding, authentification, profil).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _scrim = Color(0xFF3D0605);

  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _rise = Tween(begin: 16.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _navigate();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final isAuthenticated = AuthSession.instance.isAuthenticated;
    final onboardingDone = DialectPrefs.onboardingDone;

    if (isAuthenticated) {
      try {
        await AuthApi().refreshMe();
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token restauré périmé/invalide → déconnecter proprement.
          AuthSession.instance.clear();
          if (!mounted) return;
          context.go(onboardingDone ? '/preview' : '/onboarding');
          return;
        }
        // Autre erreur (réseau) : garder la session, router sur le dernier état.
      }
      if (!mounted) return;
      context.go(AuthSession.instance.profileComplete ? '/dashboard' : '/profile-setup');
    } else {
      context.go(onboardingDone ? '/preview' : '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scrim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Motif textile (colombes — « la voix s'envole »)
          Image.asset('assets/motifs/motif_voix.png', fit: BoxFit.cover, alignment: Alignment.center),
          // Voile marque
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _scrim.withValues(alpha: 0.82),
                  _scrim.withValues(alpha: 0.68),
                  _scrim.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Marque
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: AnimatedBuilder(
                animation: _rise,
                builder: (_, child) => Transform.translate(offset: Offset(0, _rise.value), child: child),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text('SabiData',
                            style: AppText.display(44, color: Colors.white, weight: FontWeight.w800)),
                        Positioned(
                          left: 64, top: 4,
                          child: Transform.rotate(
                            angle: 0.785398,
                            child: Container(width: 9, height: 9, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const GoldThread(width: 64, height: 3, bright: true),
                    const SizedBox(height: 16),
                    Text('Ta voix a de la valeur',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.88),
                        )),
                  ],
                ),
              ),
            ),
          ),
          // Chargement, ancré bas
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
