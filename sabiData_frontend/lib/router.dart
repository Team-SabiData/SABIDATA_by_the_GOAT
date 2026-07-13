import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';
import 'widgets/state_views.dart';
import 'data/auth/auth_session.dart';

// ── Écrans ───────────────────────────────────────────────────────────────────
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_preview_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/phone_login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/recording_review_screen.dart';
import 'screens/validation_screen.dart';
import 'screens/transcription_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/revenue_screen.dart';
import 'screens/withdraw_screen.dart';
import 'screens/dialect_map_screen.dart';
import 'screens/expert_screen.dart';
import 'screens/conversion_screen.dart';
import 'screens/classroom_screen.dart';

// ── Transition ───────────────────────────────────────────────────────────────
CustomTransitionPage<void> _page(GoRouterState st, Widget child) {
  return CustomTransitionPage<void>(
    key: st.pageKey,
    child: child,
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondary, child) {
      if (AppMotion.reduced(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      final slide = Tween(begin: const Offset(0.06, 0), end: Offset.zero)
          .chain(CurveTween(curve: AppMotion.enter))
          .animate(animation);
      return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
    },
  );
}

// ── Groupes de routes ────────────────────────────────────────────────────────

/// Routes 100% publiques — accessibles sans token ni profil.
const _publicRoutes = {
  '/',
  '/onboarding',
  '/preview',
  '/login',
  '/register',
  '/phone-login',
  '/verify',
  '/leaderboard',
  '/dialect-map',
};

/// Routes nécessitant un compte mais PAS le profil complet (lecture seule OK).
const _authRoutes = {
  '/dashboard',
  '/profile',
  '/profile-setup',
  '/revenue',
  '/classroom',
  '/conversion',
  '/expert',
};

/// Routes nécessitant le profil complet ET le consentement (activités).
const _activityRoutes = {
  '/recording',
  '/recording-review',
  '/validation',
  '/transcription',
  '/withdraw',
};

// ── Router ───────────────────────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final path           = state.matchedLocation;
    final isAuthenticated = AuthSession.instance.isAuthenticated;
    final canActivities  = AuthSession.instance.canDoActivities;

    // 1. Routes publiques — toujours accessibles
    if (_publicRoutes.contains(path)) return null;

    // 2. Routes d'activité — nécessitent auth + profil + consentement
    if (_activityRoutes.contains(path)) {
      if (!isAuthenticated) return '/preview';
      if (!canActivities) return '/profile-setup';
      return null;
    }

    // 3. Routes auth — nécessitent un compte mais pas le profil
    if (_authRoutes.contains(path)) {
      if (!isAuthenticated) return '/preview';
      return null;
    }

    // 4. Route inconnue sans token → preview
    if (!isAuthenticated) return '/preview';

    return null;
  },
  routes: [
    // ── Flux de démarrage ──────────────────────────────────────────────────
    GoRoute(path: '/',            pageBuilder: (c, s) => _page(s, const SplashScreen())),
    GoRoute(path: '/onboarding',  pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
    GoRoute(path: '/preview',     pageBuilder: (c, s) => _page(s, const AppPreviewScreen())),

    // ── Authentification ───────────────────────────────────────────────────
    GoRoute(path: '/login',       pageBuilder: (c, s) => _page(s, const LoginScreen())),
    GoRoute(path: '/register',    pageBuilder: (c, s) => _page(s, const RegisterScreen())),
    GoRoute(path: '/phone-login', pageBuilder: (c, s) => _page(s, const PhoneLoginScreen())),
    GoRoute(path: '/verify',      pageBuilder: (c, s) => _page(s, OtpScreen(phone: s.extra as String?))),

    // ── Setup profil post-auth ─────────────────────────────────────────────
    GoRoute(path: '/profile-setup', pageBuilder: (c, s) => _page(s, const ProfileSetupScreen())),

    // ── App principale ─────────────────────────────────────────────────────
    GoRoute(path: '/dashboard',   pageBuilder: (c, s) => _page(s, const DashboardScreen())),
    GoRoute(path: '/profile',     pageBuilder: (c, s) => _page(s, const ProfileScreen())),

    // ── Activités (nécessitent consentement) ───────────────────────────────
    GoRoute(path: '/recording', pageBuilder: (c, s) {
      final e = s.extra as Map<String, dynamic>?;
      return _page(s, RecordingScreen(
        commercialUse:   e?['commercial']      as bool?   ?? true,
        consentVersion:  e?['consent_version'] as String? ?? 'v1',
      ));
    }),
    GoRoute(path: '/recording-review', pageBuilder: (c, s) {
      final e = s.extra as Map<String, dynamic>?;
      return _page(s, RecordingReviewScreen(
        duration:     e?['duration']    as String?,
        commercialUse: e?['commercial'] as bool?   ?? true,
        audioPath:    e?['audio_path']  as String?,
      ));
    }),
    GoRoute(path: '/validation',    pageBuilder: (c, s) => _page(s, const ValidationScreen())),
    GoRoute(path: '/transcription', pageBuilder: (c, s) => _page(s, const TranscriptionScreen())),
    GoRoute(path: '/withdraw',      pageBuilder: (c, s) => _page(s, WithdrawScreen(provider: s.extra as String?))),

    // ── Classement & carte (publics) ───────────────────────────────────────
    GoRoute(path: '/leaderboard',  pageBuilder: (c, s) => _page(s, const LeaderboardScreen())),
    GoRoute(path: '/dialect-map',  pageBuilder: (c, s) => _page(s, const DialectMapScreen())),

    // ── Revenus & extras ───────────────────────────────────────────────────
    GoRoute(path: '/revenue',    pageBuilder: (c, s) => _page(s, const RevenueScreen())),
    GoRoute(path: '/expert',     pageBuilder: (c, s) => _page(s, const ExpertScreen())),
    GoRoute(path: '/conversion', pageBuilder: (c, s) => _page(s, const ConversionScreen())),
    GoRoute(path: '/classroom',  pageBuilder: (c, s) => _page(s, const ClassroomScreen())),
  ],
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
      child: AppErrorState(
        title: 'Page introuvable',
        message: 'La page « ${state.uri} » n\'existe pas.',
        actionLabel: 'Retour à l\'accueil',
        onAction: () => context.go('/'),
      ),
    ),
  ),
);
