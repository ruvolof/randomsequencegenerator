import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/toss_kind.dart';

void main() {
  group('TossKind', () {
    test('a die is numbered from one, a coin from zero', () {
      // TossController counts faces from 0 for everything. This offset is the
      // only place the difference lives, so a face and a tally cannot disagree.
      expect(TossKind.coin.valueOf(0), 0);
      expect(TossKind.coin.valueOf(1), 1);

      expect(TossKind.d6.valueOf(0), 1);
      expect(TossKind.d6.valueOf(5), 6);
      expect(TossKind.d20.valueOf(19), 20);
    });

    test('every value of a die is in one to faces', () {
      for (final kind in TossKind.dice) {
        final values = [for (var i = 0; i < kind.faces; i++) kind.valueOf(i)];
        expect(values.first, 1);
        expect(values.last, kind.faces);
        expect(values.toSet().length, kind.faces);
      }
    });

    test('the label names the face count', () {
      // The picker's labels, built in Dart rather than translated.
      expect(TossKind.dice.map((kind) => kind.shortLabel).toList(), [
        'D4',
        'D6',
        'D8',
        'D10',
        'D12',
        'D20',
      ]);
    });

    test('the dice are every die and nothing else, in declaration order', () {
      expect(TossKind.dice, isNot(contains(TossKind.coin)));
      expect(
        TossKind.dice,
        TossKind.values.where((kind) => kind.family == TossFamily.die),
      );
      expect(TossKind.dice.map((kind) => kind.faces).toList(), [
        4,
        6,
        8,
        10,
        12,
        20,
      ]);
    });

    test('the dice list is not writable from outside', () {
      expect(() => TossKind.dice.add(TossKind.coin), throwsUnsupportedError);
    });

    test('every kind has at least the two faces a toss needs', () {
      // TossController asserts this; the enum is what has to satisfy it.
      for (final kind in TossKind.values) {
        expect(kind.faces, greaterThanOrEqualTo(2));
      }
    });
  });
}
