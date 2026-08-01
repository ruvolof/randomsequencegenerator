import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/toss_kind.dart';
import 'package:random_sequence_generator/services/toss_controller.dart';

/// Long enough for the longest possible toss, whatever the schedule.
const Duration wholeToss = Duration(seconds: 10);

TossController coin(int seed) =>
    TossController(faces: TossKind.coin.faces, random: Random(seed));

/// Records the faces shown, in order, for one complete toss.
List<int> runToss(TossController controller) {
  final faces = <int>[];
  controller.addListener(() {
    final face = controller.face;
    if (face != null) faces.add(face);
  });
  fakeAsync((async) {
    controller.toss();
    async.elapse(wholeToss);
    expect(async.pendingTimers, isEmpty);
  });
  return faces;
}

/// The wall-clock gaps between the faces of one toss, in microseconds.
List<int> runGaps(TossController controller) {
  final gaps = <int>[];
  fakeAsync((async) {
    var last = async.elapsed;
    controller.addListener(() {
      gaps.add((async.elapsed - last).inMicroseconds);
      last = async.elapsed;
    });
    controller.toss();
    async.elapse(wholeToss);
  });
  // The first entry is the immediate face, which no gap precedes.
  return gaps.skip(1).toList();
}

void main() {
  group('TossController', () {
    test('shows nothing before the first toss', () {
      final controller = coin(1);
      addTearDown(controller.dispose);
      expect(controller.face, isNull);
      expect(controller.isTossing, isFalse);
      expect(controller.history, isEmpty);
    });

    test('renders the first face immediately, without waiting a tick', () {
      final controller = coin(1);
      addTearDown(controller.dispose);
      fakeAsync((async) {
        controller.toss();
        expect(controller.face, 0);
        expect(controller.isTossing, isTrue);
        async.elapse(wholeToss);
      });
    });

    test('the tick count always lands in [minTicks, maxTicks]', () {
      for (var seed = 0; seed < 25; seed++) {
        final controller = coin(seed);
        final faces = runToss(controller);
        controller.dispose();
        expect(
          faces.length,
          inInclusiveRange(TossController.minTicks, TossController.maxTicks),
          reason: 'seed $seed produced ${faces.length} faces',
        );
      }
    });

    test('a coin alternates 0, 1, 0, 1 … up to the settled value', () {
      for (var seed = 0; seed < 10; seed++) {
        final controller = coin(seed);
        final faces = runToss(controller);
        controller.dispose();

        expect(faces.first, 0, reason: 'seed $seed');
        // Every face except the last is the alternation; the last is the
        // decided value, which may or may not continue it.
        for (var i = 1; i < faces.length - 1; i++) {
          expect(faces[i], i.isEven ? 0 : 1, reason: 'seed $seed, face $i');
        }
      }
    });

    test(
      'a die shows faces in range, and never the same one twice running',
      () {
        for (final sides in [6, 20]) {
          for (var seed = 0; seed < 10; seed++) {
            final controller = TossController(
              faces: sides,
              random: Random(seed),
            );
            final faces = runToss(controller);
            controller.dispose();

            for (var i = 0; i < faces.length; i++) {
              expect(
                faces[i],
                inInclusiveRange(0, sides - 1),
                reason: 'd$sides',
              );
              // A repeat would read as the object sticking mid-toss.
              if (i > 0) {
                expect(
                  faces[i],
                  isNot(faces[i - 1]),
                  reason: 'd$sides seed $seed',
                );
              }
            }
          }
        }
      },
    );

    test('a die tumbles rather than counting up to its result', () {
      // The defect this replaced: `(face + 1) % faces` is invisible on a coin —
      // it *is* the legacy 0, 1, 0, 1 — but on a d20 it showed 1, 2, 3, 4 …
      // running up to an answer, which gives away that the answer was already
      // decided.
      for (final sides in [12, 20]) {
        for (var seed = 0; seed < 10; seed++) {
          final controller = TossController(faces: sides, random: Random(seed));
          final faces = runToss(controller);
          controller.dispose();

          final ascending = [
            for (var i = 0; i < faces.length; i++) (faces.first + i) % sides,
          ];
          expect(faces, isNot(ascending), reason: 'd$sides seed $seed');
        }
      }
    });

    test('the last face before a die settles is not the settled value', () {
      // Otherwise the final change is invisible and the toss looks like it
      // stopped a beat early.
      for (var seed = 0; seed < 25; seed++) {
        final controller = TossController(faces: 20, random: Random(seed));
        final faces = runToss(controller);
        controller.dispose();

        expect(
          faces[faces.length - 2],
          isNot(faces.last),
          reason: 'seed $seed',
        );
      }
    });

    test('a die draws over its whole range, not a corner of it', () {
      // A weak uniformity guard: across a few hundred drawn faces every side of
      // a d20 should come up, which a biased or truncated draw would fail.
      final seen = <int>{};
      for (var seed = 0; seed < 40; seed++) {
        final controller = TossController(faces: 20, random: Random(seed));
        seen.addAll(runToss(controller));
        controller.dispose();
      }

      expect(seen.length, 20);
    });

    test('settles on the value decided up front', () {
      for (var seed = 0; seed < 25; seed++) {
        // The controller draws the tick count first, then the outcome, so the
        // same sequence from an identical Random predicts the final face.
        final oracle = Random(seed)
          ..nextInt(TossController.maxTicks - TossController.minTicks + 1);
        final expected = oracle.nextInt(TossKind.coin.faces);

        final controller = coin(seed);
        final faces = runToss(controller);
        controller.dispose();

        expect(faces.last, expected, reason: 'seed $seed');
        expect(controller.isTossing, isFalse);
        expect(controller.face, expected);
      }
    });

    test('the gaps between faces grow, from firstTick to lastTick', () {
      for (var seed = 0; seed < 10; seed++) {
        final controller = coin(seed);
        final gaps = runGaps(controller);
        controller.dispose();

        expect(gaps.first, TossController.firstTick.inMicroseconds);
        expect(gaps.last, TossController.lastTick.inMicroseconds);
        for (var i = 1; i < gaps.length; i++) {
          expect(
            gaps[i],
            greaterThanOrEqualTo(gaps[i - 1]),
            reason: 'seed $seed sped up at gap $i',
          );
        }
      }
    });

    test('a whole toss takes between 0.8 and 2.5 seconds', () {
      // Short enough not to make anyone wait on a coin, long enough to read as
      // a toss rather than as a state change.
      for (var seed = 0; seed < 25; seed++) {
        final controller = coin(seed);
        final total = runGaps(controller).fold(0, (sum, gap) => sum + gap);
        controller.dispose();
        expect(
          total,
          inInclusiveRange(800000, 2500000),
          reason: 'seed $seed took ${total ~/ 1000}ms',
        );
      }
    });

    test('history collects the settled faces, oldest first', () {
      final controller = coin(4);
      addTearDown(controller.dispose);
      final settled = <int>[];

      fakeAsync((async) {
        for (var i = 0; i < 3; i++) {
          controller.toss();
          async.elapse(wholeToss);
          settled.add(controller.face!);
          expect(controller.history, settled);
        }
      });

      expect(controller.history, hasLength(3));
    });

    test('history is not writable from outside', () {
      final controller = coin(4);
      addTearDown(controller.dispose);
      expect(() => controller.history.add(1), throwsUnsupportedError);
    });

    test('toss() mid-toss is a no-op', () {
      final controller = coin(3);
      addTearDown(controller.dispose);
      fakeAsync((async) {
        controller.toss();
        async.elapse(TossController.firstTick * 2);
        final faceBefore = controller.face;

        controller.toss();

        expect(controller.face, faceBefore);
        expect(async.pendingTimers.length, 1);
        async.elapse(wholeToss);
      });
    });

    test('dispose mid-toss cancels the timer and silences notifications', () {
      var notifications = 0;
      fakeAsync((async) {
        final controller = coin(7);
        controller.addListener(() => notifications++);

        controller.toss();
        async.elapse(TossController.firstTick * 2);
        final before = notifications;

        controller.dispose();

        expect(async.pendingTimers, isEmpty);
        async.elapse(wholeToss);
        expect(notifications, before);
      });
    });

    test('toss() after dispose does nothing', () {
      final controller = coin(2)..dispose();
      fakeAsync((async) {
        controller.toss();
        expect(controller.face, isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
