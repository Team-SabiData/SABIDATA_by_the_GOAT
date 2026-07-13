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
