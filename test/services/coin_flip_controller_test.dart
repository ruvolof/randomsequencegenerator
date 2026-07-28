import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/services/coin_flip_controller.dart';

/// Records the faces shown, in order, for one complete flip.
List<int> runFlip(CoinFlipController controller) {
  final faces = <int>[];
  controller.addListener(() {
    final face = controller.face;
    if (face != null) faces.add(face);
  });
  fakeAsync((async) {
    controller.flip();
    // Long enough for the longest possible flip (30 ticks).
    async.elapse(CoinFlipController.tick * (CoinFlipController.maxFlips + 5));
    expect(async.pendingTimers, isEmpty);
  });
  return faces;
}

void main() {
  group('CoinFlipController', () {
    test('shows nothing before the first flip', () {
      final controller = CoinFlipController(random: Random(1));
      addTearDown(controller.dispose);
      expect(controller.face, isNull);
      expect(controller.isFlipping, isFalse);
    });

    test('renders the first face immediately, without waiting a tick', () {
      final controller = CoinFlipController(random: Random(1));
      addTearDown(controller.dispose);
      fakeAsync((async) {
        controller.flip();
        expect(controller.face, 0);
        expect(controller.isFlipping, isTrue);
        async.elapse(
          CoinFlipController.tick * (CoinFlipController.maxFlips + 5),
        );
      });
    });

    test('the tick count always lands in [minFlips, maxFlips]', () {
      for (var seed = 0; seed < 25; seed++) {
        final controller = CoinFlipController(random: Random(seed));
        final faces = runFlip(controller);
        controller.dispose();
        expect(
          faces.length,
          inInclusiveRange(
            CoinFlipController.minFlips,
            CoinFlipController.maxFlips,
          ),
          reason: 'seed $seed produced ${faces.length} faces',
        );
      }
    });

    test('alternates 0, 1, 0, 1 … up to the settled value', () {
      for (var seed = 0; seed < 10; seed++) {
        final controller = CoinFlipController(random: Random(seed));
        final faces = runFlip(controller);
        controller.dispose();

        expect(faces.first, 0, reason: 'seed $seed');
        // Every face except the last is the alternation; the last is the
        // decided value, which may or may not continue it.
        for (var i = 1; i < faces.length - 1; i++) {
          expect(faces[i], i.isEven ? 0 : 1, reason: 'seed $seed, face $i');
        }
      }
    });

    test('settles on the value decided up front', () {
      for (var seed = 0; seed < 25; seed++) {
        // The controller draws the flip count first, then the outcome, so the
        // same sequence from an identical Random predicts the final face.
        final oracle = Random(seed)
          ..nextInt(
            CoinFlipController.maxFlips - CoinFlipController.minFlips + 1,
          );
        final expected = oracle.nextInt(2);

        final controller = CoinFlipController(random: Random(seed));
        final faces = runFlip(controller);
        controller.dispose();

        expect(faces.last, expected, reason: 'seed $seed');
        expect(controller.isFlipping, isFalse);
        expect(controller.face, expected);
      }
    });

    test('flip() mid-flip is a no-op', () {
      final controller = CoinFlipController(random: Random(3));
      addTearDown(controller.dispose);
      fakeAsync((async) {
        controller.flip();
        async.elapse(CoinFlipController.tick * 2);
        final faceBefore = controller.face;

        controller.flip();

        expect(controller.face, faceBefore);
        expect(async.pendingTimers.length, 1);
        async.elapse(
          CoinFlipController.tick * (CoinFlipController.maxFlips + 5),
        );
      });
    });

    test('dispose mid-flip cancels the timer and silences notifications', () {
      var notifications = 0;
      fakeAsync((async) {
        final controller = CoinFlipController(random: Random(7));
        controller.addListener(() => notifications++);

        controller.flip();
        async.elapse(CoinFlipController.tick * 2);
        final before = notifications;

        controller.dispose();

        expect(async.pendingTimers, isEmpty);
        async.elapse(
          CoinFlipController.tick * (CoinFlipController.maxFlips + 5),
        );
        expect(notifications, before);
      });
    });

    test('flip() after dispose does nothing', () {
      final controller = CoinFlipController(random: Random(2))..dispose();
      fakeAsync((async) {
        controller.flip();
        expect(controller.face, isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
