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

  testWidgets('le tap interrompt la célébration immédiatement', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
    showCelebration(ctx, points: 20);
    await tester.pump();
    expect(find.text('+20 pts'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('+20 pts'), findsNothing);
  });

  testWidgets('reduced motion: bannière sans confettis', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox.expand());
        }),
      ),
    ));
    showCelebration(ctx, points: 20);
    await tester.pump();
    expect(find.text('+20 pts'), findsOneWidget);
    // pas de CustomPaint de confettis en reduced motion
    expect(
      find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_ConfettiPainter'),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('+20 pts'), findsNothing);
  });
}
