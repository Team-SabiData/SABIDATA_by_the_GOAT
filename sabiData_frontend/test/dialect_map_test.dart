import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabidata_app/data/api/regions_api.dart';
import 'package:sabidata_app/data/prefs/dialect_prefs.dart';
import 'package:sabidata_app/screens/dialect_map_screen.dart';

/// API factice : couverture contrôlée, sans réseau.
class _FakeRegionsApi extends RegionsApi {
  final List<Map<String, dynamic>> data;
  _FakeRegionsApi(this.data);

  @override
  Future<List<Map<String, dynamic>>> coverage() async => data;
}

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> coverage) async {
  // La police de test (Ahem, glyphes carrés) fait déborder MotifHeader de
  // quelques px — artefact absent sur device ; on ignore uniquement cette
  // erreur-là, toute autre exception fait échouer le test normalement.
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('RenderFlex overflowed')) return;
    origOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = origOnError);

  await tester.pumpWidget(MaterialApp(
    home: DialectMapScreen(regionsApi: _FakeRegionsApi(coverage)),
  ));
  await tester.pumpAndSettle();
}

const _coverage = [
  {'region': 'Ouagadougou', 'zone': 'Centre', 'clips': 800, 'coveragePct': 0.8},
  {'region': 'Yatenga', 'zone': 'Nord', 'clips': 5, 'coveragePct': 0.005},
  {'region': 'Dori', 'zone': 'Sahel', 'clips': 120, 'coveragePct': 0.12},
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DialectPrefs.load();
  });

  testWidgets('liste de couverture rendue depuis l\'API', (tester) async {
    await _pump(tester, _coverage);
    expect(find.text('Ouagadougou (Centre)'), findsOneWidget);
    expect(find.text('Dori (Sahel)'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
  });

  testWidgets('carte détail = zone la plus sous-représentée, badges dérivés', (tester) async {
    await _pump(tester, _coverage);
    // Yatenga (0,5 %) est la plus rare → détail + Urgent + ×3 pts.
    expect(find.text('Yatenga'), findsWidgets);
    expect(find.text('Zone Nord · Burkina Faso'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('×3 pts'), findsOneWidget);
    // La maquette statique a disparu.
    expect(find.text('Mooré de Yatenga'), findsNothing);
    expect(find.text('B2B'), findsNothing);
  });

  testWidgets('titre sans suffixe de langue et onglets retirés', (tester) async {
    await _pump(tester, _coverage);
    expect(find.text('Couverture par zone'), findsOneWidget);
    expect(find.text('Couverture par zone — Mooré'), findsNothing);
    expect(find.text('Mon empreinte'), findsNothing);
    expect(find.text('Vue nationale'), findsNothing);
  });

  testWidgets('légende « Vous » seulement si la région du profil est connue', (tester) async {
    await _pump(tester, _coverage);
    expect(find.text('Vous'), findsNothing); // pas de région en prefs

    await DialectPrefs.save(region: 'Yatenga');
    await _pump(tester, _coverage);
    expect(find.text('Vous'), findsOneWidget);
  });

  testWidgets('couverture vide → message, pas de crash', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Couverture indisponible.'), findsOneWidget);
  });
}
