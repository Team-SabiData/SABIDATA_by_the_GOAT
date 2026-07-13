import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Thème clair « Sahel » : fond blanc chaud, accent rouge vif.
  static const Color bg = Color(0xFFFAF7F4);
  static const Color bgDeep = Color(0xFFF2EDE7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAE4DC);

  static const Color primary = Color(0xFFE11D28);
  static const Color primaryDark = Color(0xFFB3141E);
  static const Color primarySoft = Color(0x1AE11D28); // rouge 10 %
  static const Color gold = Color(0xFFC9922A); // série, récompenses, rareté
  static const Color goldSoft = Color(0x1AC9922A); // or 10 %
  static const Color green = Color(0xFF12876A);
  static const Color blue = Color(0xFF2E6FD0);
  static const Color red = Color(0xFFD11A25);
  static const Color orange = Color(0xFFC2410C);
  static const Color yellow = Color(0xFFB7791F);
  static const Color silverBadge = Color(0xFF8A93A6);
  static const Color bronzeBadge = Color(0xFFB87333);

  static const Color textPrimary = Color(0xFF1A1A1F);
  static const Color textSecondary = Color(0xFF5C6473);
  static const Color textMuted = Color(0xFF8B93A0);

  // Overlays sur fond clair (bordures, séparateurs, remplissages subtils).
  static const Color hairline = Color(0x14000000); // ~8 % noir
  static const Color overlay = Color(0x0D000000); //  ~5 % noir
}

/// Rayons systématisés — aucune autre valeur dans les écrans.
class AppRadius {
  static const double card = 20;
  static const double button = 16;
  static const double pill = 999;
}

/// Styles typographiques. Display = Bricolage Grotesque (titres, gros
/// chiffres) ; le corps reste Plus Jakarta Sans via le textTheme global.
class AppText {
  static TextStyle display(double size,
          {Color color = AppColors.textPrimary,
          FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.bricolageGrotesque(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.15,
      ).copyWith(fontFamilyFallback: const ['Roboto', 'sans-serif']);

  /// Chiffres tabulaires (minuteur, points, OTP) — pas de tremblement.
  static TextStyle numeric(double size,
          {Color color = AppColors.textPrimary}) =>
      GoogleFonts.bricolageGrotesque(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
      ).copyWith(fontFamilyFallback: const ['Roboto', 'sans-serif']);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.surface,
          onPrimary: Colors.white,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
      );
}
