import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/toss_kind.dart';
import 'package:random_sequence_generator/screens/toss_screen.dart';
import 'package:random_sequence_generator/services/toss_controller.dart';
import 'package:random_sequence_generator/widgets/toss/coin_face.dart';

import '../support/pump_app.dart';

TossController coinController(int seed) =>
    TossController(faces: TossKind.coin.faces, random: Random(seed));

/// Drives a whole toss. `pumpAndSettle` never terminates while the toss keeps
/// rescheduling timers, and the gaps between faces are no longer a fixed tick,
/// so neither a settle nor a fixed count of pumps at one duration will do.
Future<void> advanceToss(WidgetTester tester) async {
  const slice = Duration(milliseconds: 25);
  for (var i = 0; i < 400; i++) {
    await tester.pump(slice);
  }
}

bool flipEnabled(WidgetTester tester) =>
    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Flip'))
        .onPressed !=
    null;

/// The digit struck on the coin, whichever face is being painted.
Finder get coinDigit =>
    find.descendant(of: find.byType(CoinFace), matching: find.byType(Text));

/// The hint keeps its place through the first toss so the coin does not resize
/// mid-flip, so "gone" during that toss means invisible, not absent.
double hintOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(
        of: find.text('Tap the coin to flip'),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  group('TossScreen', () {
    testWidgets('starts on the hint with Flip enabled', (tester) async {
      await tester.pumpApp(TossScreen(controller: coinController(1)));

      expect(find.text('Launch Coin'), findsOneWidget);
      expect(find.text('Tap the coin to flip'), findsOneWidget);
      expect(flipEnabled(tester), isTrue);
      // The coin is on screen from the start, dimmed — the hint tells the user
      // to tap it, so there has to be something there to tap.
      expect(find.byType(CoinFace), findsOneWidget);
    });

    testWidgets(
      'Flip replaces the hint with the tally and disables the button',
      (tester) async {
        final controller = coinController(1);
        addTearDown(controller.dispose);
        await tester.pumpApp(TossScreen(controller: controller));

        expect(hintOpacity(tester), 1);

        await tester.tap(find.text('Flip'));
        await tester.pump();

        // Invisible but still measured, so the coin keeps its size.
        expect(hintOpacity(tester), 0);
        expect(tester.widget<Text>(coinDigit).data, '0');
        expect(flipEnabled(tester), isFalse);

        await advanceToss(tester);

        // Once there is a result the hint is gone outright, replaced by the
        // tally.
        expect(find.text('Tap the coin to flip'), findsNothing);
        expect(flipEnabled(tester), isTrue);
        expect(tester.widget<Text>(coinDigit).data, matches(RegExp(r'^[01]$')));
      },
    );

    testWidgets('tapping the coin tosses it', (tester) async {
      final controller = coinController(3);
      addTearDown(controller.dispose);
      await tester.pumpApp(TossScreen(controller: controller));

      await tester.tap(find.byType(CoinFace));
      await tester.pump();

      expect(controller.isTossing, isTrue);
      expect(hintOpacity(tester), 0);

      await advanceToss(tester);
      expect(controller.history, hasLength(1));
    });

    testWidgets('a tap on the coin mid-toss does not restart it', (
      tester,
    ) async {
      final controller = coinController(3);
      addTearDown(controller.dispose);
      await tester.pumpApp(TossScreen(controller: controller));

      await tester.tap(find.text('Flip'));
      await tester.pump(TossController.firstTick * 2);
      await tester.tap(find.byType(CoinFace));
      await advanceToss(tester);

      // One toss, not two.
      expect(controller.history, hasLength(1));
    });

    testWidgets('bug 5 — the digit renders large and is never clipped', (
      tester,
    ) async {
      final controller = coinController(2);
      addTearDown(controller.dispose);
      await tester.pumpApp(TossScreen(controller: controller));

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await advanceToss(tester);

      // The legacy code fed a px dimension to an sp setter, producing roughly
      // 480sp and clipping the glyph.
      expect(tester.takeException(), isNull);
      final digit = tester.getRect(coinDigit);
      final coin = tester.getRect(find.byType(CoinFace));
      expect(digit.height, greaterThan(100));
      expect(digit.top, greaterThanOrEqualTo(coin.top - 0.5));
      expect(digit.bottom, lessThanOrEqualTo(coin.bottom + 0.5));
    });

    testWidgets('settles on the value the controller decided', (tester) async {
      final controller = coinController(5);
      addTearDown(controller.dispose);
      await tester.pumpApp(TossScreen(controller: controller));

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await advanceToss(tester);

      expect(controller.isTossing, isFalse);
      expect(tester.widget<Text>(coinDigit).data, '${controller.face}');
    });

    testWidgets('the tally counts this session, face by face', (tester) async {
      final controller = coinController(5);
      addTearDown(controller.dispose);
      await tester.pumpApp(TossScreen(controller: controller));

      expect(find.textContaining('×'), findsNothing);

      await tester.tap(find.text('Flip'));
      await advanceToss(tester);

      expect(find.text('1 flip'), findsOneWidget);
      expect(
        find.text('0 × ${controller.history.where((f) => f == 0).length}'),
        findsOneWidget,
      );

      await tester.tap(find.text('Flip'));
      await advanceToss(tester);

      expect(find.text('2 flips'), findsOneWidget);
      final zeros = controller.history.where((face) => face == 0).length;
      expect(find.text('0 × $zeros'), findsOneWidget);
      expect(find.text('1 × ${2 - zeros}'), findsOneWidget);
    });

    testWidgets('a landscape phone does not overflow', (tester) async {
      // The regression guard for the layout this redesign replaced: a fixed
      // 280dp coin area plus the button did not fit a 360dp-tall landscape
      // phone, and a non-scrolling Column has nowhere to put the excess.
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = coinController(1);
      addTearDown(controller.dispose);
      await tester.pumpApp(TossScreen(controller: controller));

      expect(tester.takeException(), isNull);

      final button = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Flip'),
      );
      expect(button.bottom, lessThanOrEqualTo(360));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(640));
      expect(tester.getRect(find.byType(CoinFace)).height, greaterThan(0));
    });

    testWidgets('the coin is capped at 280 on a phone and 360 on a tablet', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      tester.view.physicalSize = const Size(400, 900);
      await tester.pumpApp(TossScreen(controller: coinController(1)));
      expect(tester.getRect(find.byType(CoinFace)).width, 280);

      tester.view.physicalSize = const Size(800, 1200);
      await tester.pumpApp(TossScreen(controller: coinController(1)));
      expect(tester.getRect(find.byType(CoinFace)).width, 360);
    });

    testWidgets('unmounting mid-toss leaves no pending timer', (tester) async {
      await tester.pumpApp(TossScreen(controller: coinController(9)));

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await tester.pump(TossController.firstTick);

      // Replacing the tree disposes the screen; the legacy CountDownTimer
      // outlived onDestroy and kept touching a dead view.
      await tester.pumpApp(const SizedBox.shrink());
      await advanceToss(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen disposes a controller it owns', (tester) async {
      await tester.pumpApp(const TossScreen());

      await tester.tap(find.text('Flip'));
      await tester.pump();
      await tester.pumpApp(const SizedBox.shrink());
      await advanceToss(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
