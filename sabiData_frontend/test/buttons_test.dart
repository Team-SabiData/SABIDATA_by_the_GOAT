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
