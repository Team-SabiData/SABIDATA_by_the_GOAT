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

  testWidgets('StreakBadge pulse démarre quand highlight passe à true',
      (tester) async {
    Widget build(bool highlight) => MaterialApp(
          home: Scaffold(body: StreakBadge(days: 3, highlight: highlight)),
        );
    await tester.pumpWidget(build(false));
    var state = tester.state(find.byType(StreakBadge)) as dynamic;
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.isPulsing as bool, isFalse);
    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 50));
    state = tester.state(find.byType(StreakBadge)) as dynamic;
    expect(state.isPulsing as bool, isTrue);
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.isPulsing as bool, isFalse);
  });
}
