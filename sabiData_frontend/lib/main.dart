import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'data/prefs/dialect_prefs.dart';
import 'data/auth/auth_session.dart';
import 'data/outbox/outbox_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Activer le cache disque Google Fonts → polices disponibles hors-ligne
  // après le premier chargement réseau.
  GoogleFonts.config.allowRuntimeFetching = true;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  // Charger les préférences persistantes + restaurer la session avant le
  // premier rendu (l'utilisateur reste connecté entre deux lancements).
  await DialectPrefs.load();
  await AuthSession.instance.restore();
  // File d'attente offline : écoute le réseau et synchronise les enregistrements
  // en attente dès que la connexion revient.
  await OutboxService.instance.init();
  runApp(const SabiDataApp());
}

class SabiDataApp extends StatelessWidget {
  const SabiDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.light;
    return MaterialApp.router(
      title: 'SabiData',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
