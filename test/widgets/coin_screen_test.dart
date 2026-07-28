import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/screens/coin_screen.dart';
import 'package:random_sequence_generator/services/coin_flip_controller.dart';

import '../support/pump_app.dart';

/// Advances one tick at a time. `pumpAndSettle` never terminates while a
/// periodic timer is running, so the flip has to be driven explicitly.
Future<void> advanceFlip(WidgetTester tester, {int ticks = 40}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(CoinFlipController.tick);
  }
}

bool flipEnabled(WidgetTester tester) =>
    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Flip'))
        .onPressed !=
    null;

void main() {
  group('CoinScreen', () {
    testWidgets('starts on the hint with Flip enabled', (tester) async {
      await tester.pumpApp(
        CoinScreen(controller: CoinFlipController(random: Random(1))),
      );

      expect(find.text('Launch Coin'), findsOneWidget);
      expect(find.text('Click on flip'), findsOneWidget);
      expect(flipEnabled(tester), isTrue);
    });

    testWidgets('Flip replaces the hint with a digit and disables the button', (
      tester,
    ) async {
      final controller = CoinFlipController(random: Random(1));
      addTearDown(controller.dispose);
      await tester.pumpApp(CoinScreen(controller: controller));

      await tester.tap(find.text('Flip'));
      await tester.pump();

      expect(find.text('Click on flip'), findsNothing);
      expect(find.text('0'), findsOneWidget);
      expect(flipEnabled(tester), isFalse);

      await advanceFlip(tester);

      expect(flipEnabled(tester), isTrue);
      expect(find.textContaining(RegExp('[01]')), findsOneWidget);
    });

    testWidgets('bug 5 — the digit renders large and is never clipped', (
      tester,
    ) async {
      final controller = CoinFlipController(random: Random(2));
      addTearDown(controller.dispose);
      await tester.pumpApp(CoinScreen(controller: controller));

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await advanceFlip(tester);

      // The legacy code fed a px dimension to an sp setter, producing roughly
      // 480sp and clipping the glyph.
      expect(tester.takeException(), isNull);
      final digit = find.textContaining(RegExp('^[01]\$'));
      final rect = tester.getRect(digit);
      final coinArea = tester.getRect(find.byType(FittedBox));
      expect(rect.height, greaterThan(100));
      expect(rect.top, greaterThanOrEqualTo(coinArea.top - 0.5));
      expect(rect.bottom, lessThanOrEqualTo(coinArea.bottom + 0.5));
    });

    testWidgets('settles on the value the controller decided', (tester) async {
      final controller = CoinFlipController(random: Random(5));
      addTearDown(controller.dispose);
      await tester.pumpApp(CoinScreen(controller: controller));

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await advanceFlip(tester);

      expect(controller.isFlipping, isFalse);
      expect(find.text('${controller.face}'), findsOneWidget);
    });

    testWidgets('unmounting mid-flip leaves no pending timer', (tester) async {
      await tester.pumpApp(
        CoinScreen(controller: CoinFlipController(random: Random(9))),
      );

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await tester.pump(CoinFlipController.tick);

      // Replacing the tree disposes the screen; the legacy CountDownTimer
      // outlived onDestroy and kept touching a dead view.
      await tester.pumpApp(const SizedBox.shrink());
      await tester.pump(CoinFlipController.tick * 40);

      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen disposes a controller it owns', (tester) async {
      await tester.pumpApp(const CoinScreen());

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await tester.pumpApp(const SizedBox.shrink());
      await tester.pump(CoinFlipController.tick * 40);

      expect(tester.takeException(), isNull);
    });
  });
}
