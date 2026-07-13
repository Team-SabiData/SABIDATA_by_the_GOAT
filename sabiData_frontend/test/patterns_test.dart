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
