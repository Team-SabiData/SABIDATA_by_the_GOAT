# Refonte design mobile « Griot énergique » — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refondre visuellement l'onboarding + la boucle cœur de l'app Flutter SabiData (gamification énergique sur base culturelle burkinabè), sans aucun changement backend.

**Architecture:** On construit d'abord les fondations (`lib/theme/` : tokens, motion, motif tissé) puis les composants partagés (`lib/widgets/`), puis on restyle les écrans un par un en consommant exclusivement ces composants. La gamification locale (série, défi du jour) vit dans `lib/data/gamification/` sur `shared_preferences`.

**Tech Stack:** Flutter (SDK ^3.10), google_fonts (déjà présent), shared_preferences (à ajouter), go_router, record (amplitude micro), audioplayers (streams de lecture).

**Spec:** `docs/superpowers/specs/2026-07-04-mobile-redesign-griot-design.md`

## Global Constraints

- Marque inchangée : `bg #FAF7F4`, `primary #E11D28`, thème CLAIR uniquement.
- Nouveaux tokens exacts : `gold #C9922A`, `goldSoft` = or alpha 10 %, `primarySoft` = rouge alpha 10 %.
- Rayons : cartes **20**, boutons **16**, pastilles **999**. Aucune autre valeur dans les écrans.
- Durées : 150 / 250 / 400 ms via `AppMotion` uniquement ; entrée ease-out, sortie ease-in.
- Typo display : **Bricolage Grotesque** (google_fonts) pour titres et gros chiffres ; corps : Plus Jakarta Sans.
- Pas d'emoji comme icône fonctionnelle → Material Icons (rounded). Emojis autorisés en célébration seulement.
- `MediaQuery.disableAnimations` respecté par toute animation (fallback fondu/statique).
- Textes UI en français. Cibles tactiles ≥ 48 dp.
- Aucun changement backend ni de contrat API.
- Après chaque tâche : `cd sabiData_frontend && flutter analyze` (0 erreur) et `flutter test` (vert) avant commit.
- Tous les chemins ci-dessous sont relatifs à la racine du repo `/home/r_ghost/Projets/data/SABIDATA`.

---

### Task 1: Tokens de thème + typographie display + dépendance shared_preferences

**Files:**
- Modify: `sabiData_frontend/pubspec.yaml`
- Modify: `sabiData_frontend/lib/theme/app_theme.dart`
- Create: `sabiData_frontend/test/theme_test.dart`

**Interfaces:**
- Consumes: `google_fonts` (déjà en pubspec).
- Produces: `AppColors.gold`, `AppColors.goldSoft`, `AppColors.primarySoft` (Color) ; `AppRadius.card=20`, `AppRadius.button=16`, `AppRadius.pill=999` (double) ; `AppText.display(double size, {Color color, FontWeight weight})` et `AppText.numeric(double size, {Color color})` (TextStyle Bricolage Grotesque, numeric = chiffres tabulaires) ; `AppTheme.light` avec textTheme Plus Jakarta Sans.

- [ ] **Step 1: Ajouter shared_preferences**

Dans `sabiData_frontend/pubspec.yaml`, sous `permission_handler: ^11.3.1`, ajouter :

```yaml
  shared_preferences: ^2.3.2
```

Run: `cd sabiData_frontend && flutter pub get`
Expected: résolution sans erreur.

- [ ] **Step 2: Écrire le test qui échoue**

Create `sabiData_frontend/test/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/theme/app_theme.dart';

void main() {
  test('tokens or et rouge doux exposés', () {
    expect(AppColors.gold, const Color(0xFFC9922A));
    expect(AppColors.goldSoft.a, closeTo(0.10, 0.02));
    expect(AppColors.primarySoft.a, closeTo(0.10, 0.02));
  });

  test('rayons systématisés', () {
    expect(AppRadius.card, 20);
    expect(AppRadius.button, 16);
    expect(AppRadius.pill, 999);
  });

  test('styles display Bricolage Grotesque', () {
    final d = AppText.display(28);
    expect(d.fontFamily, contains('BricolageGrotesque'));
    final n = AppText.numeric(22);
    expect(n.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
```

- [ ] **Step 3: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/theme_test.dart`
Expected: FAIL — `AppRadius`/`AppText`/`gold` n'existent pas.

- [ ] **Step 4: Implémenter les tokens**

Remplacer intégralement `sabiData_frontend/lib/theme/app_theme.dart` par :

```dart
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
          fontSize: size, fontWeight: weight, color: color, height: 1.15);

  /// Chiffres tabulaires (minuteur, points, OTP) — pas de tremblement.
  static TextStyle numeric(double size,
          {Color color = AppColors.textPrimary}) =>
      GoogleFonts.bricolageGrotesque(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()]);
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
```

- [ ] **Step 5: Vérifier que le test passe**

Run: `cd sabiData_frontend && flutter test test/theme_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Analyze + tests complets + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: 0 erreur, tout vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/pubspec.yaml sabiData_frontend/pubspec.lock sabiData_frontend/lib/theme/app_theme.dart sabiData_frontend/test/theme_test.dart
git commit -m "feat(mobile): tokens or/rouge doux, rayons systématisés, typo display Bricolage"
```

---

### Task 2: Tokens de mouvement + motif tissé faso dan fani

**Files:**
- Create: `sabiData_frontend/lib/theme/motion.dart`
- Create: `sabiData_frontend/lib/theme/patterns.dart`
- Create: `sabiData_frontend/test/patterns_test.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 1).
- Produces: `AppMotion.fast/base/slow` (Duration 150/250/400 ms), `AppMotion.enter/exit` (Curve), `AppMotion.reduced(BuildContext)` (bool) ; `FasoDanFaniPainter(color, opacity)` (CustomPainter) ; `PatternBand({double height = 56, Color color = AppColors.gold, double opacity = 0.05})` (widget).

- [ ] **Step 1: Écrire le test qui échoue**

Create `sabiData_frontend/test/patterns_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/theme/motion.dart';
import 'package:sabidata_app/theme/patterns.dart';

void main() {
  test('tokens de mouvement', () {
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.base, const Duration(milliseconds: 250));
    expect(AppMotion.slow, const Duration(milliseconds: 400));
  });

  testWidgets('PatternBand se peint sans exception', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PatternBand(height: 48)),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/patterns_test.dart`
Expected: FAIL — fichiers inexistants.

- [ ] **Step 3: Implémenter motion.dart**

Create `sabiData_frontend/lib/theme/motion.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Tokens de mouvement — toutes les animations de l'app puisent ici.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;

  /// True si l'utilisateur demande moins d'animations (accessibilité).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
```

- [ ] **Step 4: Implémenter patterns.dart**

Create `sabiData_frontend/lib/theme/patterns.dart`:

```dart
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Motif géométrique inspiré du tissage faso dan fani : rangées de losanges
/// bordées de triangles, en très faible opacité. Signature culturelle de
/// l'app — teinté selon la langue active (mooré = or par défaut).
class FasoDanFaniPainter extends CustomPainter {
  final Color color;
  final double opacity;
  const FasoDanFaniPainter({required this.color, this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    const cell = 28.0; // largeur d'un losange
    final rows = (size.height / cell).ceil();
    final cols = (size.width / cell).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      final cy = r * cell + cell / 2;
      final shift = r.isOdd ? cell / 2 : 0.0;
      for (var c = 0; c < cols; c++) {
        final cx = c * cell + shift;
        final path = Path()
          ..moveTo(cx, cy - cell * 0.32)
          ..lineTo(cx + cell * 0.32, cy)
          ..lineTo(cx, cy + cell * 0.32)
          ..lineTo(cx - cell * 0.32, cy)
          ..close();
        canvas.drawPath(path, paint);
        // triangles latéraux une rangée sur deux
        if (r.isEven) {
          final tri = Path()
            ..moveTo(cx + cell * 0.38, cy - cell * 0.10)
            ..lineTo(cx + cell * 0.52, cy)
            ..lineTo(cx + cell * 0.38, cy + cell * 0.10)
            ..close();
          canvas.drawPath(tri, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(FasoDanFaniPainter old) =>
      old.color != color || old.opacity != opacity;
}

/// Bandeau horizontal de motif tissé (têtes d'écran, liserés de cartes).
class PatternBand extends StatelessWidget {
  final double height;
  final Color color;
  final double opacity;
  const PatternBand({
    super.key,
    this.height = 56,
    this.color = AppColors.gold,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: FasoDanFaniPainter(color: color, opacity: opacity),
      ),
    );
  }
}
```

- [ ] **Step 5: Vérifier que le test passe**

Run: `cd sabiData_frontend && flutter test test/patterns_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/theme/motion.dart sabiData_frontend/lib/theme/patterns.dart sabiData_frontend/test/patterns_test.dart
git commit -m "feat(mobile): tokens de mouvement + motif tissé faso dan fani"
```

---

### Task 3: SpringTap + refonte des boutons + RewardChip

**Files:**
- Create: `sabiData_frontend/lib/widgets/spring_tap.dart`
- Modify: `sabiData_frontend/lib/widgets/primary_button.dart` (réécriture complète)
- Create: `sabiData_frontend/lib/widgets/reward_chip.dart`
- Create: `sabiData_frontend/test/buttons_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppRadius`, `AppText` (Task 1), `AppMotion` (Task 2).
- Produces: `SpringTap({required Widget child, VoidCallback? onTap, bool enabled = true, bool haptic = true})` ; `PrimaryButton({required String label, VoidCallback? onTap, Color color = AppColors.primary, Color textColor = Colors.white, bool enabled = true, bool loading = false, IconData? icon})` (signature existante conservée + `loading`/`icon`) ; `SecondaryButton({required String label, VoidCallback? onTap, bool enabled = true, IconData? icon})` ; `RewardChip({required int points})`.

- [ ] **Step 1: Écrire le test qui échoue**

Create `sabiData_frontend/test/buttons_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/widgets/primary_button.dart';
import 'package:sabidata_app/widgets/reward_chip.dart';
import 'package:sabidata_app/widgets/spring_tap.dart';

void main() {
  testWidgets('SpringTap déclenche onTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: SpringTap(onTap: () => tapped++, child: const Text('go')),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('PrimaryButton désactivé ne déclenche pas', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrimaryButton(label: 'Envoyer', enabled: false, onTap: () => tapped++),
      ),
    ));
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(tapped, 0);
  });

  testWidgets('PrimaryButton loading affiche un indicateur', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PrimaryButton(label: 'Envoyer', loading: true)),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('RewardChip affiche les points', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RewardChip(points: 150)),
    ));
    expect(find.text('+150 pts'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/buttons_test.dart`
Expected: FAIL — `SpringTap`/`RewardChip` inexistants, `loading` inconnu.

- [ ] **Step 3: Implémenter SpringTap**

Create `sabiData_frontend/lib/widgets/spring_tap.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/motion.dart';

/// Enveloppe tactile universelle : écrasement léger au toucher (scale 0.96),
/// retour à ressort au relâchement, haptique légère. Tout élément tactile
/// de l'app passe par ce widget.
class SpringTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool haptic;

  const SpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.haptic = true,
  });

  @override
  State<SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (_active && !AppMotion.reduced(context)) _ctrl.forward();
  }

  void _release() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapCancel: _release,
      onTapUp: (_) => _release(),
      onTap: _active
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * Curves.easeOut.transform(_ctrl.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 4: Réécrire PrimaryButton + SecondaryButton**

Remplacer intégralement `sabiData_frontend/lib/widgets/primary_button.dart` par :

```dart
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
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
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
              Text(label,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? AppColors.primary
                          : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implémenter RewardChip**

Create `sabiData_frontend/lib/widgets/reward_chip.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pastille de récompense « +N pts » — or, partout où des points sont
/// promis ou gagnés.
class RewardChip extends StatelessWidget {
  final int points;
  const RewardChip({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('+$points pts',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.gold)),
    );
  }
}
```

- [ ] **Step 6: Vérifier que les tests passent**

Run: `cd sabiData_frontend && flutter test test/buttons_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Analyze + tests complets + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert (les écrans existants utilisent `PrimaryButton(label:, onTap:, enabled:)` — signature conservée).

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/widgets/spring_tap.dart sabiData_frontend/lib/widgets/primary_button.dart sabiData_frontend/lib/widgets/reward_chip.dart sabiData_frontend/test/buttons_test.dart
git commit -m "feat(mobile): SpringTap, boutons refondus (spring+loading), RewardChip"
```

---

### Task 4: ProgressRing + StreakBadge

**Files:**
- Create: `sabiData_frontend/lib/widgets/progress_ring.dart`
- Create: `sabiData_frontend/lib/widgets/streak_badge.dart`
- Create: `sabiData_frontend/test/gamification_widgets_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppText` (Task 1), `AppMotion` (Task 2).
- Produces: `ProgressRing({required double value, double size = 96, double stroke = 8, Color color = AppColors.primary, Widget? center})` (value clampé 0–1) ; `StreakBadge({required int days, bool highlight = false})`.

- [ ] **Step 1: Écrire le test qui échoue**

Create `sabiData_frontend/test/gamification_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/widgets/progress_ring.dart';
import 'package:sabidata_app/widgets/streak_badge.dart';

void main() {
  testWidgets('ProgressRing accepte des valeurs hors bornes', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProgressRing(value: 1.7, center: Text('2450'))),
    ));
    expect(find.text('2450'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StreakBadge affiche les jours', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StreakBadge(days: 12)),
    ));
    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/gamification_widgets_test.dart`
Expected: FAIL — fichiers inexistants.

- [ ] **Step 3: Implémenter ProgressRing**

Create `sabiData_frontend/lib/widgets/progress_ring.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Anneau de progression : arc coloré sur piste hairline, contenu au centre.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1, clampé
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.stroke = 8,
    this.color = AppColors.primary,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
                value: value.clamp(0.0, 1.0), stroke: stroke, color: color),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  _RingPainter({required this.value, required this.stroke, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = stroke / 2;
    final arcRect = rect.deflate(inset);
    final track = Paint()
      ..color = AppColors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}
```

- [ ] **Step 4: Implémenter StreakBadge**

Create `sabiData_frontend/lib/widgets/streak_badge.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Flamme de série : jours consécutifs avec contribution. Pulse doucement
/// uniquement quand [highlight] est vrai (le jour où la série s'incrémente).
class StreakBadge extends StatefulWidget {
  final int days;
  final bool highlight;
  const StreakBadge({super.key, required this.days, this.highlight = false});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.highlight && mounted && !AppMotion.reduced(context)) {
        _ctrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.06)
          .chain(CurveTween(curve: Curves.easeInOut))
          .animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 18, color: AppColors.gold),
            const SizedBox(width: 4),
            Text('${widget.days}',
                style: AppText.numeric(15, color: AppColors.gold)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Vérifier que les tests passent**

Run: `cd sabiData_frontend && flutter test test/gamification_widgets_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/widgets/progress_ring.dart sabiData_frontend/lib/widgets/streak_badge.dart sabiData_frontend/test/gamification_widgets_test.dart
git commit -m "feat(mobile): ProgressRing + StreakBadge"
```

---

### Task 5: Gamification locale (série + défi du jour + compteur validation)

**Files:**
- Create: `sabiData_frontend/lib/data/gamification/local_stats.dart`
- Create: `sabiData_frontend/test/local_stats_test.dart`

**Interfaces:**
- Consumes: `shared_preferences` (Task 1).
- Produces: fonction pure `int computeStreak(List<DateTime> days, DateTime today)` ; classe `LocalStats` avec `Future<void> recordSubmission([DateTime? now])`, `Future<void> recordValidation([DateTime? now])`, `Future<int> streak([DateTime? now])`, `Future<int> todaySubmissions([DateTime? now])`, `Future<int> todayValidations([DateTime? now])`, constante `LocalStats.dailyGoal = 5`.

- [ ] **Step 1: Écrire le test qui échoue**

Create `sabiData_frontend/test/local_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabidata_app/data/gamification/local_stats.dart';

void main() {
  final today = DateTime(2026, 7, 4);

  group('computeStreak', () {
    test('vide → 0', () {
      expect(computeStreak([], today), 0);
    });
    test('aujourd\'hui seul → 1', () {
      expect(computeStreak([DateTime(2026, 7, 4)], today), 1);
    });
    test('3 jours consécutifs finissant aujourd\'hui → 3', () {
      expect(
        computeStreak([
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
          DateTime(2026, 7, 4),
        ], today),
        3,
      );
    });
    test('série finissant hier reste vivante → 2', () {
      expect(
        computeStreak([DateTime(2026, 7, 2), DateTime(2026, 7, 3)], today),
        2,
      );
    });
    test('trou avant-hier → série cassée → 0', () {
      expect(computeStreak([DateTime(2026, 7, 1)], today), 0);
    });
  });

  group('LocalStats', () {
    test('recordSubmission incrémente le compteur du jour', () async {
      SharedPreferences.setMockInitialValues({});
      final stats = LocalStats();
      await stats.recordSubmission(today);
      await stats.recordSubmission(today);
      expect(await stats.todaySubmissions(today), 2);
      expect(await stats.streak(today), 1);
    });
    test('recordValidation compte à part', () async {
      SharedPreferences.setMockInitialValues({});
      final stats = LocalStats();
      await stats.recordValidation(today);
      expect(await stats.todayValidations(today), 1);
      expect(await stats.todaySubmissions(today), 0);
    });
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/local_stats_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter local_stats.dart**

Create `sabiData_frontend/lib/data/gamification/local_stats.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Série de jours consécutifs (avec ≥ 1 contribution) se terminant
/// aujourd'hui ou hier — une série finissant hier reste « vivante ».
int computeStreak(List<DateTime> days, DateTime today) {
  if (days.isEmpty) return 0;
  final set = days.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  final t = DateTime(today.year, today.month, today.day);
  var cursor = set.contains(t) ? t : t.subtract(const Duration(days: 1));
  if (!set.contains(cursor)) return 0;
  var streak = 0;
  while (set.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Stats de gamification purement locales (shared_preferences) : série,
/// défi du jour, compteur de validations. Aucun appel réseau — branchable
/// sur le backend plus tard s'il expose ces données.
class LocalStats {
  static const int dailyGoal = 5;
  static const _kDays = 'gamification.submission_days';
  static const _kSubs = 'gamification.today_submissions';
  static const _kVals = 'gamification.today_validations';

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> recordSubmission([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getStringList(_kDays) ?? [];
    if (!days.contains(_dayKey(d))) {
      days.add(_dayKey(d));
      // borne la liste aux 60 derniers jours enregistrés
      while (days.length > 60) {
        days.removeAt(0);
      }
      await prefs.setStringList(_kDays, days);
    }
    await prefs.setInt('$_kSubs.${_dayKey(d)}',
        (prefs.getInt('$_kSubs.${_dayKey(d)}') ?? 0) + 1);
  }

  Future<void> recordValidation([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kVals.${_dayKey(d)}',
        (prefs.getInt('$_kVals.${_dayKey(d)}') ?? 0) + 1);
  }

  Future<int> streak([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_kDays) ?? [])
        .map(DateTime.parse)
        .toList();
    return computeStreak(days, d);
  }

  Future<int> todaySubmissions([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kSubs.${_dayKey(d)}') ?? 0;
  }

  Future<int> todayValidations([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kVals.${_dayKey(d)}') ?? 0;
  }
}
```

- [ ] **Step 4: Vérifier que les tests passent**

Run: `cd sabiData_frontend && flutter test test/local_stats_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/data/gamification/local_stats.dart sabiData_frontend/test/local_stats_test.dart
git commit -m "feat(mobile): gamification locale (série, défi du jour, compteur validation)"
```

---

### Task 6: CelebrationOverlay (confettis + points volants)

**Files:**
- Create: `sabiData_frontend/lib/widgets/celebration_overlay.dart`
- Create: `sabiData_frontend/test/celebration_test.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 1), `AppMotion` (Task 2).
- Produces: `Future<void> showCelebration(BuildContext context, {required int points})` — overlay confettis ~1,2 s, interruptible au tap ; en reduced motion, simple bannière fondu « +N pts » 900 ms.

- [ ] **Step 1: Écrire le test qui échoue**

Create `sabiData_frontend/test/celebration_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/widgets/celebration_overlay.dart';

void main() {
  testWidgets('showCelebration affiche puis retire les points', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox());
      }),
    ));
    showCelebration(ctx, points: 150);
    await tester.pump();
    expect(find.text('+150 pts'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('+150 pts'), findsNothing);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/celebration_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter celebration_overlay.dart**

Create `sabiData_frontend/lib/widgets/celebration_overlay.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Célébration de réussite : pluie de confettis (couleurs marque + or)
/// et gros « +N pts » au centre. ~1,2 s, interruptible au tap.
/// Reduced motion → bannière en fondu simple.
Future<void> showCelebration(BuildContext context, {required int points}) async {
  final overlay = Overlay.of(context);
  final reduced = AppMotion.reduced(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationView(
      points: points,
      reduced: reduced,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _CelebrationView extends StatefulWidget {
  final int points;
  final bool reduced;
  final VoidCallback onDone;
  const _CelebrationView(
      {required this.points, required this.reduced, required this.onDone});

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: widget.reduced
          ? const Duration(milliseconds: 900)
          : const Duration(milliseconds: 1200));
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(60, (_) => _Particle.random(rng));
    _ctrl.forward().whenCompleteOrCancel(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _ctrl.duration = Duration.zero, // interruptible
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final fade = t < 0.15
                ? t / 0.15
                : t > 0.75
                    ? (1 - t) / 0.25
                    : 1.0;
            return Stack(
              children: [
                if (!widget.reduced)
                  CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(particles: _particles, t: t),
                  ),
                Center(
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('+${widget.points} pts',
                          style: AppText.numeric(28, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1 position horizontale
  final double speed; // vitesse de chute relative
  final double size;
  final double drift; // dérive horizontale
  final Color color;
  const _Particle(this.x, this.speed, this.size, this.drift, this.color);

  static const _colors = [
    AppColors.primary,
    AppColors.gold,
    AppColors.green,
    AppColors.blue,
  ];

  factory _Particle.random(math.Random rng) => _Particle(
        rng.nextDouble(),
        0.6 + rng.nextDouble() * 0.8,
        4 + rng.nextDouble() * 5,
        (rng.nextDouble() - 0.5) * 0.2,
        _colors[rng.nextInt(_colors.length)],
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (t * p.speed) * (size.height + 40) - 20;
      final x = (p.x + p.drift * t) * size.width;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 4 * p.drift * 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
```

- [ ] **Step 4: Vérifier que le test passe**

Run: `cd sabiData_frontend && flutter test test/celebration_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/widgets/celebration_overlay.dart sabiData_frontend/test/celebration_test.dart
git commit -m "feat(mobile): CelebrationOverlay confettis + points volants"
```

---

### Task 7: AppCard + AuthField restylé + squelettes shimmer

**Files:**
- Create: `sabiData_frontend/lib/widgets/app_card.dart`
- Modify: `sabiData_frontend/lib/widgets/auth_field.dart` (réécriture complète)
- Modify: `sabiData_frontend/lib/widgets/state_views.dart` (ajout `SkeletonBox` + restyle `AppLoadingState`)
- Create: `sabiData_frontend/test/cards_fields_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppRadius` (Task 1), `PatternBand` (Task 2).
- Produces: `AppCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(20), bool accent = false, Color accentColor = AppColors.gold})` ; `AuthField` (signature existante conservée : `label`, `hint`, `controller`, `keyboardType`, `obscure`, `errorText`) avec focus ring 2 px ; `SkeletonBox({double height = 72, double? width})` ; `AppLoadingState({String? label, bool skeleton = false})`.

- [ ] **Step 1: Écrire le test qui échoue**

Create `sabiData_frontend/test/cards_fields_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/widgets/app_card.dart';
import 'package:sabidata_app/widgets/auth_field.dart';
import 'package:sabidata_app/widgets/state_views.dart';

void main() {
  testWidgets('AppCard rend son contenu', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppCard(child: Text('contenu'))),
    ));
    expect(find.text('contenu'), findsOneWidget);
  });

  testWidgets('AuthField montre le label et l\'erreur', (tester) async {
    final ctrl = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuthField(
            label: 'Téléphone',
            hint: '70 00 00 00',
            controller: ctrl,
            errorText: 'Numéro invalide'),
      ),
    ));
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Numéro invalide'), findsOneWidget);
  });

  testWidgets('AppLoadingState skeleton affiche des SkeletonBox',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppLoadingState(skeleton: true)),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SkeletonBox), findsWidgets);
  });
}
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd sabiData_frontend && flutter test test/cards_fields_test.dart`
Expected: FAIL — `AppCard`/`SkeletonBox`/`skeleton` inexistants.

- [ ] **Step 3: Implémenter AppCard**

Create `sabiData_frontend/lib/widgets/app_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/patterns.dart';

/// Carte standard : surface blanche, radius 20, UNE seule ombre douce
/// dans toute l'app. Variante [accent] : liseré motif tissé en tête.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool accent;
  final Color accentColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent = false,
    this.accentColor = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent) PatternBand(height: 8, color: accentColor, opacity: 0.5),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Réécrire AuthField**

Remplacer intégralement `sabiData_frontend/lib/widgets/auth_field.dart` par :

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Champ étiqueté des écrans d'auth : label toujours visible au-dessus,
/// focus ring rouge 2 px, erreur sous le champ.
class AuthField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscure;
  final String? errorText;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.errorText,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.red
        : _focus.hasFocus
            ? AppColors.primary
            : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.05 * 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
                color: borderColor, width: _focus.hasFocus ? 2 : 1.5),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: widget.keyboardType,
                  obscureText: _hidden,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (widget.obscure)
                GestureDetector(
                  onTap: () => setState(() => _hidden = !_hidden),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                        _hidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(widget.errorText!,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.red,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Ajouter SkeletonBox + option skeleton dans state_views.dart**

Dans `sabiData_frontend/lib/widgets/state_views.dart`, ajouter en fin de fichier :

```dart
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
```

Puis remplacer la classe `AppLoadingState` existante par :

```dart
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
```

Ajouter l'import en tête de `state_views.dart` si absent : rien à ajouter (`app_theme.dart` déjà importé).

- [ ] **Step 6: Vérifier que les tests passent**

Run: `cd sabiData_frontend && flutter test test/cards_fields_test.dart && flutter test`
Expected: PASS partout.

- [ ] **Step 7: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze`
Expected: 0 erreur.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/widgets/app_card.dart sabiData_frontend/lib/widgets/auth_field.dart sabiData_frontend/lib/widgets/state_views.dart sabiData_frontend/test/cards_fields_test.dart
git commit -m "feat(mobile): AppCard, AuthField focus ring, squelettes shimmer"
```

---

### Task 8: Transitions de navigation + thème global

**Files:**
- Modify: `sabiData_frontend/lib/router.dart`
- Modify: `sabiData_frontend/lib/main.dart` (vérifier qu'il consomme `AppTheme.light` — ne changer que si nécessaire)

**Interfaces:**
- Consumes: `AppMotion` (Task 2).
- Produces: navigation avec glissement gauche + fondu 250 ms sur toutes les routes ; helper `CustomTransitionPage<void> _page(GoRouterState st, Widget child)` interne à `router.dart`. Les écrans gardent leurs constructeurs actuels.

- [ ] **Step 1: Réécrire router.dart avec pageBuilder**

Dans `sabiData_frontend/lib/router.dart` : ajouter l'import `import 'theme/motion.dart';` puis ajouter ce helper au-dessus de `appRouter` :

```dart
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
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
```

Puis convertir **chaque** route de `builder:` en `pageBuilder:`. Exemples exacts (appliquer le même motif aux 21 routes) :

```dart
GoRoute(path: '/', pageBuilder: (ctx, st) => _page(st, const SplashScreen())),
GoRoute(path: '/login', pageBuilder: (ctx, st) => _page(st, const LoginScreen())),
GoRoute(path: '/verify', pageBuilder: (ctx, st) => _page(st, OtpScreen(phone: st.extra as String?))),
GoRoute(path: '/recording', pageBuilder: (ctx, st) {
  final e = st.extra as Map<String, dynamic>?;
  return _page(st, RecordingScreen(
    commercialUse: e?['commercial'] as bool? ?? true,
    consentVersion: e?['consent_version'] as String? ?? 'v1',
  ));
}),
GoRoute(path: '/recording-review', pageBuilder: (ctx, st) {
  final e = st.extra as Map<String, dynamic>?;
  return _page(st, RecordingReviewScreen(
    duration: e?['duration'] as String?,
    commercialUse: e?['commercial'] as bool? ?? true,
    audioPath: e?['audio_path'] as String?,
  ));
}),
```

Les autres routes suivent le même schéma mécanique (`builder: (ctx, st) => X` devient `pageBuilder: (ctx, st) => _page(st, X)`). Ne pas toucher à `errorBuilder`.

- [ ] **Step 2: Vérifier main.dart**

Lire `sabiData_frontend/lib/main.dart`. S'il utilise déjà `theme: AppTheme.light`, ne rien changer. Sinon, brancher :

```dart
return MaterialApp.router(
  title: 'SabiData',
  theme: AppTheme.light,
  routerConfig: appRouter,
  debugShowCheckedModeBanner: false,
);
```

- [ ] **Step 3: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert (le smoke test `widget_test.dart` pompe l'app entière — il valide les transitions).

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/router.dart sabiData_frontend/lib/main.dart
git commit -m "feat(mobile): transitions glissement+fondu sur toutes les routes"
```

---

### Task 9: Splash + en-tête d'onboarding partagé

**Files:**
- Modify: `sabiData_frontend/lib/screens/splash_screen.dart`
- Modify: `sabiData_frontend/lib/widgets/onboarding_header.dart` (réécriture complète)

**Interfaces:**
- Consumes: `PatternBand`, `FasoDanFaniPainter` (Task 2), `AppText` (Task 1).
- Produces: `OnboardingHeader({required String title, String? subtitle})` — utilisé par login/register/phone/OTP (Task 10). Le splash garde sa logique de navigation existante (timer/redirect) intacte.

- [ ] **Step 1: Réécrire OnboardingHeader**

Remplacer intégralement `sabiData_frontend/lib/widgets/onboarding_header.dart` par :

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/patterns.dart';

/// En-tête commun des écrans d'onboarding : bandeau motif tissé
/// + titre display + sous-titre optionnel.
class OnboardingHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const OnboardingHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PatternBand(height: 36, color: AppColors.gold, opacity: 0.10),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.display(28)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
```

**Attention :** avant de remplacer, lire l'ancien `onboarding_header.dart` et les écrans qui l'utilisent (`grep -rn "OnboardingHeader" sabiData_frontend/lib/`). Si l'ancienne signature diffère (autres paramètres), adapter les call sites dans le même commit pour que tout compile.

- [ ] **Step 2: Restyler le splash**

Dans `sabiData_frontend/lib/screens/splash_screen.dart` : conserver **toute** la logique d'état/navigation existante (timer, redirection). Remplacer uniquement le contenu visuel du `build` par :

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.bg,
    body: Stack(
      children: [
        // Motif tissé pleine page, très discret
        Positioned.fill(
          child: CustomPaint(
            painter: const FasoDanFaniPainter(
                color: AppColors.gold, opacity: 0.05),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logotype : le point du « i » devient un losange rouge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text('SabiData', style: AppText.display(40)),
                  Positioned(
                    // losange sur le premier « i » (ajuster visuellement
                    // au device si besoin : position approx. du point)
                    left: 58,
                    top: 2,
                    child: Transform.rotate(
                      angle: 0.785398, // 45°
                      child: Container(
                          width: 8, height: 8, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Ta voix a de la valeur',
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );
}
```

Ajouter les imports nécessaires en tête du fichier :

```dart
import '../theme/patterns.dart';
```

(`app_theme.dart` déjà importé.) Supprimer du `build` uniquement ce qui est remplacé — pas les membres d'état.

- [ ] **Step 3: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/splash_screen.dart sabiData_frontend/lib/widgets/onboarding_header.dart
git commit -m "feat(mobile): splash motif tissé + en-tête onboarding display"
```

---

### Task 10: Écrans d'auth (login, inscription, téléphone) + OTP à cases

**Files:**
- Modify: `sabiData_frontend/lib/screens/login_screen.dart`
- Modify: `sabiData_frontend/lib/screens/register_screen.dart`
- Modify: `sabiData_frontend/lib/screens/phone_login_screen.dart`
- Modify: `sabiData_frontend/lib/screens/otp_screen.dart`

**Interfaces:**
- Consumes: `OnboardingHeader` (Task 9), `AuthField` (Task 7), `PrimaryButton`/`SecondaryButton` (Task 3), `AppText` (Task 1).
- Produces: écrans visuellement refondus, **logique inchangée** (contrôleurs, appels API, navigation, gestion d'erreur restent tels quels).

- [ ] **Step 1: Login / Register / PhoneLogin — en-têtes et boutons**

Pour chacun des trois écrans, opérations mécaniques (la logique d'état ne bouge pas) :

1. Remplacer le bloc titre existant en haut du `build` par `OnboardingHeader(title: ..., subtitle: ...)` avec les textes déjà présents à l'écran (ex. login : `title: 'Bon retour !'`, `subtitle: 'Connectez-vous pour continuer à contribuer.'` — reprendre les libellés existants s'ils sont bons).
2. Vérifier que tous les CTA utilisent `PrimaryButton` (avec `loading: _submitting` quand l'écran a un état de soumission — remplacer les patterns `label: _submitting ? 'Envoi…' : 'X'` par `label: 'X', loading: _submitting`).
3. Les liens secondaires (« Créer un compte », « Mot de passe oublié ») restent des textes mais enveloppés dans `SpringTap` (import `../widgets/spring_tap.dart`).
4. Champs : déjà `AuthField` — rien à faire (restylé en Task 7). Vérifier que chaque champ a un `keyboardType` sémantique (`TextInputType.phone` pour téléphone, `.emailAddress` pour email).

- [ ] **Step 2: OTP à 6 cases**

Dans `sabiData_frontend/lib/screens/otp_screen.dart` : conserver la logique de vérification existante (appel API, navigation, erreurs). Remplacer le champ de saisie unique par ce pattern (champ caché qui pilote 6 cases dessinées) :

```dart
// Champs d'état à ajouter dans le State existant :
final TextEditingController _codeCtrl = TextEditingController();
final FocusNode _codeFocus = FocusNode();

// Dans initState (garder l'existant) :
_codeCtrl.addListener(() {
  setState(() {});
  if (_codeCtrl.text.length == 6) _submit(); // _submit = méthode de vérif existante
});

// Dans dispose (garder l'existant) :
_codeCtrl.dispose();
_codeFocus.dispose();
```

Widget des cases (dans le `build`, à la place de l'ancien champ) :

```dart
GestureDetector(
  onTap: () => _codeFocus.requestFocus(),
  child: Stack(
    children: [
      // Champ réel invisible : clavier numérique, collage supporté
      Opacity(
        opacity: 0,
        child: TextField(
          controller: _codeCtrl,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final filled = i < _codeCtrl.text.length;
          final current = i == _codeCtrl.text.length;
          return Container(
            width: 48,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(
                color: current
                    ? AppColors.primary
                    : filled
                        ? AppColors.textPrimary
                        : AppColors.border,
                width: current ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Text(
              filled ? _codeCtrl.text[i] : '',
              style: AppText.numeric(22),
            ),
          );
        }),
      ),
    ],
  ),
)
```

Adapter le nom `_submit` au nom réel de la méthode de vérification de l'écran (la trouver avant d'éditer). Si l'écran soumettait via un bouton, garder le bouton en secours (`PrimaryButton`) — l'auto-submit à 6 chiffres s'y ajoute.

- [ ] **Step 3: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/login_screen.dart sabiData_frontend/lib/screens/register_screen.dart sabiData_frontend/lib/screens/phone_login_screen.dart sabiData_frontend/lib/screens/otp_screen.dart
git commit -m "feat(mobile): écrans d'auth refondus + OTP à 6 cases auto-submit"
```

---

### Task 11: Sélection de langue + consentement

**Files:**
- Modify: `sabiData_frontend/lib/screens/language_selection_screen.dart`
- Modify: `sabiData_frontend/lib/screens/consent_screen.dart`

**Interfaces:**
- Consumes: `AppCard` (Task 7), `PatternBand` (Task 2), `SpringTap` (Task 3), `AppText` (Task 1), `PrimaryButton` (Task 3).
- Produces: écrans refondus, logique de sélection/navigation inchangée. Les dégradés d'identité par langue existants (mooré=or, dioula=vert, fulfuldé=bleu, gulmancema=violet) sont conservés comme couleurs de liseré.

- [ ] **Step 1: Sélection de langue — cartes à liseré**

Dans `language_selection_screen.dart` : conserver la liste des langues et la logique de sélection. Restyler chaque carte langue : fond clair (`AppColors.surface`), et l'identité passe par un **liseré** + motif teinté au lieu d'un aplat :

```dart
// couleur = couleur d'identité de la langue (existante dans l'écran)
Widget _languageCard({
  required String name,
  required String nativeName,
  required Color color,
  required bool selected,
  required VoidCallback onTap,
}) {
  return SpringTap(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1.5),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PatternBand(height: 8, color: color, opacity: selected ? 0.6 : 0.25),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppText.display(18)),
                      const SizedBox(height: 2),
                      Text(nativeName,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: AppMotion.fast,
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

Adapter les noms de champs à ceux de l'écran existant (lire l'écran d'abord : structure de la liste, noms des variables). Imports à ajouter : `../theme/patterns.dart`, `../theme/motion.dart`, `../widgets/spring_tap.dart`.

- [ ] **Step 2: Consentement — cartes scannables + CTA collant**

Dans `consent_screen.dart` : conserver la logique (toggle usage commercial, navigation avec `extra`). Restructurer visuellement :

1. Chaque clause/section devient une `AppCard` avec une icône Material rounded à gauche (ex. `Icons.mic_rounded`, `Icons.payments_rounded`, `Icons.shield_rounded`) + phrase courte.
2. Le toggle « usage commercial » devient une `AppCard` avec un `Switch` (activeThumbColor: `AppColors.primary`) et deux lignes de texte (titre + explication).
3. Le CTA final : `PrimaryButton` dans un conteneur collant en bas (`SafeArea` + padding 24/16), séparé du scroll.

Squelette du body :

```dart
Column(
  children: [
    // ... en-tête existant ...
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(children: [/* AppCards des clauses + toggle */]),
      ),
    ),
    SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: PrimaryButton(label: 'J\'accepte et je continue', onTap: _accept),
      ),
    ),
  ],
)
```

(`_accept` = le handler de navigation existant, quel que soit son nom réel.)

- [ ] **Step 3: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/language_selection_screen.dart sabiData_frontend/lib/screens/consent_screen.dart
git commit -m "feat(mobile): sélection de langue à liserés + consentement scannable"
```

---

### Task 12: Dashboard refondu

**Files:**
- Modify: `sabiData_frontend/lib/screens/dashboard_screen.dart` (réécriture du build)

**Interfaces:**
- Consumes: `PatternBand` (Task 2), `ProgressRing`, `StreakBadge` (Task 4), `RewardChip`, `SpringTap` (Task 3), `AppCard` (Task 7), `LocalStats` (Task 5), `AppText` (Task 1).
- Produces: dashboard gamifié ; le cercle de l'action « Parler » porte `Hero(tag: 'record-cta')` (consommé Task 13). Les données mockées existantes (nom, points, dialecte) restent mockées — aucune nouvelle API.

- [ ] **Step 1: Convertir en StatefulWidget + charger les stats locales**

`DashboardScreen` devient `StatefulWidget`. Dans le State :

```dart
final LocalStats _stats = LocalStats();
int _streak = 0;
int _todayClips = 0;

@override
void initState() {
  super.initState();
  _loadStats();
}

Future<void> _loadStats() async {
  final s = await _stats.streak();
  final t = await _stats.todaySubmissions();
  if (mounted) setState(() { _streak = s; _todayClips = t; });
}
```

Imports à ajouter : `../data/gamification/local_stats.dart`, `../theme/patterns.dart`, `../widgets/app_card.dart`, `../widgets/progress_ring.dart`, `../widgets/streak_badge.dart`, `../widgets/reward_chip.dart`, `../widgets/spring_tap.dart`.

- [ ] **Step 2: Réécrire le build**

Structure complète du nouveau body (reprendre les valeurs mockées existantes — nom « Adama Ouédraogo », 1 240 points, badge bronze 67/200, dialecte Yatenga ×3) :

```dart
@override
Widget build(BuildContext context) {
  const points = 1240; // mock existant
  const nextLevelAt = 2000; // seuil niveau Argent (mock)
  return Scaffold(
    backgroundColor: AppColors.bg,
    body: AppBody(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bandeau motif + salutation + série
            Stack(
              children: [
                const PatternBand(height: 96, color: AppColors.gold, opacity: 0.10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Yambã wend,',
                                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            Text('Adama Ouédraogo', style: AppText.display(22)),
                          ],
                        ),
                      ),
                      StreakBadge(days: _streak, highlight: _todayClips > 0),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Carte héros : progression vers le prochain niveau
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppCard(
                accent: true,
                child: Row(
                  children: [
                    ProgressRing(
                      value: points / nextLevelAt,
                      size: 104,
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
                          const Text('GARDIEN BRONZE',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                  color: AppColors.bronzeBadge, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text('Niveau Argent à $nextLevelAt pts', style: AppText.display(17)),
                          const SizedBox(height: 6),
                          const Text('67 contributions validées',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      onTap: () => context.go('/consent'),
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
            // ── Cartes secondaires : reprendre ici les blocs existants
            //    (dialecte, revenus, classement) enveloppés dans AppCard,
            //    emojis remplacés par des icônes Material rounded
            //    (Icons.place_rounded, Icons.payments_rounded,
            //     Icons.leaderboard_rounded), navigation existante conservée.
          ],
        ),
      ),
    ),
  );
}
```

Et le widget privé `_ActionCard` en bas du fichier :

```dart
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
          children: [
            hero != null ? Hero(tag: hero!, child: iconCircle) : iconCircle,
            const Spacer(),
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
```

**Note :** l'action « Parler » navigue vers `/consent` si c'est le flux actuel de l'écran existant — vérifier la destination actuelle du bouton d'enregistrement et la conserver.

- [ ] **Step 3: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/dashboard_screen.dart
git commit -m "feat(mobile): dashboard gamifié (anneau, série, défi du jour, actions héros)"
```

---

### Task 13: Écran d'enregistrement — onde honnête + display

**Files:**
- Modify: `sabiData_frontend/lib/screens/recording_screen.dart`

**Interfaces:**
- Consumes: `AudioRecorder.onAmplitudeChanged` (package `record`), `AppText` (Task 1), `PatternBand` (Task 2), Hero `record-cta` (Task 12).
- Produces: forme d'onde branchée sur l'amplitude micro réelle ; l'enregistrement/navigation/multipart existants (Tasks audio déjà livrées) restent intacts.

- [ ] **Step 1: Remplacer les barres aléatoires par l'amplitude réelle**

Dans `_RecordingScreenState` : supprimer `_barControllers` (les 12 `AnimationController` aléatoires) et leur dispose. Ajouter :

```dart
import 'dart:async';

// champs
final List<double> _levels = List.filled(24, 0.05, growable: false);
StreamSubscription<Amplitude>? _ampSub;

// dans _startRecording(), après _recorder.start(...) :
_ampSub = _recorder
    .onAmplitudeChanged(const Duration(milliseconds: 120))
    .listen((amp) {
  // amp.current est en dBFS (~ -45 silence → 0 max) ; normaliser 0..1
  final v = ((amp.current + 45) / 45).clamp(0.05, 1.0);
  setState(() {
    for (var i = 0; i < _levels.length - 1; i++) {
      _levels[i] = _levels[i + 1];
    }
    // lissage : moyenne avec la valeur précédente
    _levels[_levels.length - 1] = (v + _levels[_levels.length - 2]) / 2;
  });
});

// dans dispose() et dans le stop/cancel :
_ampSub?.cancel();
```

Remplacer le widget « Waveform » (les 12 `AnimatedBuilder`) par :

```dart
SizedBox(
  height: 56,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: _levels.map((v) => Container(
      width: 4,
      height: 8 + 44 * v,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(2),
      ),
    )).toList(),
  ),
)
```

- [ ] **Step 2: Typo display + hero + filigrane**

1. Phrase à enregistrer : passer le texte de la phrase en `AppText.display(24)` (au lieu du TextStyle 22 actuel).
2. Minuteur : `Text(_time, style: AppText.numeric(24))`.
3. Envelopper le cercle rouge du bouton stop (le `Container` 72×72) dans `Hero(tag: 'record-cta', child: ...)`.
4. Sous l'en-tête, insérer `const PatternBand(height: 24, color: AppColors.red, opacity: 0.06)`.
5. Import : `../theme/patterns.dart`.

- [ ] **Step 3: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/recording_screen.dart
git commit -m "feat(mobile): onde micro réelle + hero + display sur l'enregistrement"
```

---

### Task 14: Écran de revue — lecteur réel + célébration

**Files:**
- Modify: `sabiData_frontend/lib/screens/recording_review_screen.dart`

**Interfaces:**
- Consumes: streams `audioplayers` (`onPositionChanged`, `onDurationChanged`, `onPlayerStateChanged`), `showCelebration` (Task 6), `LocalStats.recordSubmission` (Task 5), `AppCard` (Task 7), `SpringTap` (Task 3).
- Produces: lecteur avec vrai play/pause + progression réelle ; célébration et enregistrement des stats à la soumission acceptée. La logique multipart existante (`submitClip(audioPath:)`) ne bouge pas.

- [ ] **Step 1: Câbler l'état réel du lecteur**

Dans `_RecordingReviewScreenState`, ajouter :

```dart
import 'dart:async';

// champs
bool _playing = false;
Duration _pos = Duration.zero;
Duration _dur = Duration.zero;
final List<StreamSubscription> _subs = [];

@override
void initState() {
  super.initState();
  _subs.add(_player.onPlayerStateChanged.listen((s) {
    if (mounted) setState(() => _playing = s == PlayerState.playing);
  }));
  _subs.add(_player.onDurationChanged.listen((d) {
    if (mounted) setState(() => _dur = d);
  }));
  _subs.add(_player.onPositionChanged.listen((p) {
    if (mounted) setState(() => _pos = p);
  }));
}

// compléter le dispose existant :
@override
void dispose() {
  for (final s in _subs) {
    s.cancel();
  }
  _player.dispose();
  super.dispose();
}

Future<void> _togglePlay() async {
  final path = widget.audioPath;
  if (path == null) {
    showAppSnack(context, 'Aucun enregistrement à lire.');
    return;
  }
  if (_playing) {
    await _player.pause();
  } else if (_pos > Duration.zero && _pos < _dur) {
    await _player.resume();
  } else {
    await _player.play(DeviceFileSource(path));
  }
}
```

- [ ] **Step 2: Restyler la carte lecteur**

Remplacer la « Playback card » actuelle (dégradé + fausse forme d'onde figée) par :

```dart
AppCard(
  child: Row(
    children: [
      SpringTap(
        onTap: _togglePlay,
        child: Semantics(
          button: true,
          label: _playing ? 'Mettre en pause' : 'Écouter mon enregistrement',
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.button),
              boxShadow: [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: _dur.inMilliseconds == 0
                ? 0
                : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.hairline,
            color: AppColors.primary,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        _dur.inMilliseconds == 0
            ? (widget.duration ?? '00:00')
            : '${_pos.inMinutes.toString().padLeft(2, '0')}:${(_pos.inSeconds % 60).toString().padLeft(2, '0')}',
        style: AppText.numeric(14),
      ),
    ],
  ),
)
```

Imports à ajouter : `../theme/patterns.dart` (si en-tête motifé), `../widgets/app_card.dart`, `../widgets/spring_tap.dart`.

- [ ] **Step 3: Célébration + stats à la soumission acceptée**

Dans `_submit`, après `if (mounted) setState(() => _result = res);`, ajouter :

```dart
if (mounted && res['status'] != 'rejected') {
  await LocalStats().recordSubmission();
  if (mounted) showCelebration(context, points: (res['reward'] as num?)?.toInt() ?? 150);
}
```

Imports : `../data/gamification/local_stats.dart`, `../widgets/celebration_overlay.dart`.

- [ ] **Step 4: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/recording_review_screen.dart
git commit -m "feat(mobile): lecteur réel (pause/progression) + célébration à la soumission"
```

---

### Task 15: Écran de validation — lecteur, verdicts spring, compteur du jour

**Files:**
- Modify: `sabiData_frontend/lib/screens/validation_screen.dart`

**Interfaces:**
- Consumes: `ApiClient.getBytes` + `BytesSource` (déjà câblés), streams `audioplayers`, `SpringTap` (Task 3), `ProgressRing` (Task 4), `LocalStats.recordValidation`/`todayValidations` (Task 5), `showCelebration` (Task 6), `AppCard` (Task 7).
- Produces: validation avec lecteur play/pause réel, verdicts à rebond, compteur de validations du jour en anneau fin, micro-célébration +20 au vote « correct ».

- [ ] **Step 1: État lecteur + compteur du jour**

Mêmes streams que Task 14 (`_playing`, `_pos`, `_dur`, `_subs`, dispose). Le play télécharge une seule fois par clip :

```dart
Uint8List? _bytes; // cache du clip courant

Future<void> _togglePlay() async {
  final url = _clip?['audioUrl'] as String?;
  if (url == null) {
    showAppSnack(context, 'Aucun audio pour ce clip.');
    return;
  }
  if (_playing) {
    await _player.pause();
    return;
  }
  try {
    _bytes ??= await ApiClient().getBytes(url);
    await _player.play(BytesSource(_bytes!));
  } on ApiException catch (e) {
    if (mounted) showAppSnack(context, e.message);
  }
}
```

Vider le cache au changement de clip : dans `_fetchNext`, à côté de `_clip = clip;`, ajouter `_bytes = null; _pos = Duration.zero; _dur = Duration.zero;` et `await _player.stop();` en tête de méthode.

Compteur du jour : charger dans `initState` et après chaque vote :

```dart
int _todayValidations = 0;

Future<void> _loadToday() async {
  final n = await LocalStats().todayValidations();
  if (mounted) setState(() => _todayValidations = n);
}
```

Import : `dart:typed_data` (pour `Uint8List`), `../data/gamification/local_stats.dart`, `../widgets/celebration_overlay.dart`, `../widgets/spring_tap.dart`, `../widgets/progress_ring.dart`.

- [ ] **Step 2: En-tête avec anneau fin + carte lecteur**

Dans l'en-tête (Row du haut), remplacer `Text('$_validated ✓', ...)` par :

```dart
ProgressRing(
  value: _todayValidations / 20, // objectif indicatif journalier
  size: 40,
  stroke: 4,
  color: AppColors.green,
  center: Text('$_todayValidations', style: AppText.numeric(13)),
),
```

Remplacer la carte « Audio player » (dégradé + fausse barre 0.38 + faux 0:04 + fausse mini-waveform) par la même carte lecteur que Task 14 (bouton `SpringTap` play/pause bleu `AppColors.blue`, `LinearProgressIndicator` réel, temps réel `AppText.numeric`). Supprimer la mini-waveform figée.

- [ ] **Step 3: Verdicts à rebond + micro-célébration**

Dans `_VerdictButton.build`, remplacer le `GestureDetector` racine par `SpringTap` (import déjà fait) — le reste du widget ne change pas.

Dans `_vote`, après le succès du verdict (`await _api.submitVerdict(...)`), ajouter :

```dart
await LocalStats().recordValidation();
await _loadToday();
if (verdict == 'correct' && mounted) {
  showCelebration(context, points: 20);
}
```

(Garder le `showAppSnack` existant pour les autres verdicts.)

- [ ] **Step 4: Analyze + tests + commit**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/validation_screen.dart
git commit -m "feat(mobile): validation — lecteur réel, verdicts spring, compteur du jour"
```

---

### Task 16: Passe finale de cohérence + vérification device

**Files:**
- Modify (balayage) : tout `sabiData_frontend/lib/screens/` du périmètre

- [ ] **Step 1: Balayage anti-régression du périmètre**

Vérifier sur les 10 écrans du périmètre (grep + lecture) :

```bash
cd sabiData_frontend
# plus d'emojis structurels dans les écrans du périmètre :
grep -n "Text('👤\|Text('📍\|Text('🥉\|Text('▶\|Text('⭐" lib/screens/{splash,login,register,phone_login,otp,language_selection,consent,dashboard,recording,recording_review,validation}_screen.dart || true
# plus de rayons hors système (8/10/12/14/18) dans ces mêmes écrans :
grep -n "BorderRadius.circular(1[0-48]\|BorderRadius.circular(8)" lib/screens/dashboard_screen.dart || true
```

Corriger ce qui remonte (remplacer par icônes Material rounded / `AppRadius.*`). Les emojis de célébration (`🎉` dans les états succès) sont autorisés.

- [ ] **Step 2: Suite complète**

Run: `cd sabiData_frontend && flutter analyze && flutter test`
Expected: 0 erreur, tous tests verts.

- [ ] **Step 3: Commit final**

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add -A sabiData_frontend/lib
git commit -m "polish(mobile): passe de cohérence design (icônes, rayons, tokens)"
```

- [ ] **Step 4: Vérification visuelle sur device (avec l'utilisateur)**

À combiner avec la Task 12 du plan audio (toujours en attente) :

1. `cd backend && DATABASE=pg RUN_SERVER=1 ./node_modules/.bin/tsx src/server.ts`
2. `cd sabiData_frontend && flutter run` sur device physique.
3. Parcours : splash → login → dashboard (anneau, série, défi) → consentement → enregistrement (onde qui réagit à la voix, hero) → revue (play/pause réel, progression) → soumission (confettis +150) → validation avec un 2ᵉ compte (lecteur, +20 au vote).
4. Contrôles : lisibilité en luminosité max, reduced motion activé (paramètres système) → pas de confettis, cibles tactiles confortables au pouce.

---

## Self-Review

**Spec coverage :**
- Tokens couleurs (`gold`, `goldSoft`, `primarySoft`) + rayons + typo display → Task 1. ✅
- Motion tokens + motif faso dan fani → Task 2. ✅
- `SpringTap`, boutons, `RewardChip` → Task 3. ✅
- `ProgressRing`, `StreakBadge` → Task 4. ✅
- Série/défi du jour/compteur validation en local (`shared_preferences`) → Task 5. ✅
- `CelebrationOverlay` (reduced motion inclus) → Task 6. ✅
- `AppCard`, `AuthField` focus ring, squelettes shimmer → Task 7. ✅
- Transitions push/pop 250 ms + fallback fondu → Task 8. ✅
- Splash + en-tête onboarding → Task 9. ✅
- Login/inscription/téléphone/OTP à cases → Task 10. ✅
- Sélection de langue (liserés d'identité) + consentement scannable → Task 11. ✅
- Dashboard gamifié + hero source → Task 12. ✅
- Enregistrement : onde amplitude réelle + hero cible → Task 13. ✅
- Revue : lecteur réel + célébration + recordSubmission → Task 14. ✅
- Validation : lecteur réel, verdicts spring, compteur jour, +20 → Task 15. ✅
- Accessibilité (Semantics, reduced motion, contrastes, cibles ≥48) → répartie Tasks 3/6/8/14 + balayage Task 16. ✅
- Vérification device → Task 16 Step 4. ✅

**Placeholders :** les étapes des écrans d'auth (Task 10 Step 1) et des cartes secondaires du dashboard (Task 12 Step 2, commentaire) décrivent des opérations mécaniques sur du code existant à lire au moment de l'édition — le composant cible et le pattern exact sont fournis à chaque fois ; ce sont des adaptations de call sites, pas des trous de conception.

**Type consistency :** `AppRadius.card/button/pill` (Task 1) consommés Tasks 3–15 ; `AppText.display/numeric` cohérents partout ; `LocalStats.recordSubmission/recordValidation/streak/todaySubmissions/todayValidations` (Task 5) consommés Tasks 12/14/15 avec ces noms exacts ; `showCelebration(context, points:)` (Task 6) consommé Tasks 14/15 ; `PatternBand(height, color, opacity)` (Task 2) consommé Tasks 7/9/11/12/13 ; `SpringTap(child, onTap, enabled)` (Task 3) consommé Tasks 10–15 ; hero tag `'record-cta'` identique Tasks 12/13.

