import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/main.dart';

void main() {
  testWidgets('SabiData app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SabiDataApp());

    // Splash : la marque est visible pendant l'animation d'ouverture.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SabiData'), findsOneWidget);

    // La redirection automatique (prefs vierges, non authentifié) mène à
    // l'onboarding — pumpAndSettle avance au-delà du délai du splash.
    await tester.pumpAndSettle();
    expect(find.text('Passer'), findsOneWidget);
  });
}
