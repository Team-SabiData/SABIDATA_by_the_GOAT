import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabidata_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
