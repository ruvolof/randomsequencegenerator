import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/mask_pattern.dart';
import 'package:random_sequence_generator/services/char_pools.dart';
import 'package:random_sequence_generator/services/sequence_generator.dart';

void main() {
  group('MaskPattern.parse', () {
    test('the output bound matches the generator', () {
      // The model keeps its own constant so it does not import the service;
      // this pins the two together.
      expect(MaskPattern.maxOutputLength, SequenceGenerator.maxLength);
    });

    test('every documented token resolves to its pool', () {
      final expected = {
        '#': CharPools.digit,
        'a': CharPools.lowercase,
        'A': CharPools.uppercase,
        '?': CharPools.lowercase + CharPools.uppercase,
        '*': CharPools.digit + CharPools.lowercase + CharPools.uppercase,
        'h': CharPools.hexLowercase,
        'H': CharPools.hex,
        '%': CharPools.special,
      };
      // Guards against a token being added to the map without a test, and
      // against the two hex pools being confused with each other.
      expect(expected.keys, unorderedEquals(CharPools.maskPools.keys));
      expect(CharPools.hexLowercase, '0123456789abcdef');
      expect(CharPools.hex, isNot(CharPools.hexLowercase));

      expected.forEach((token, pool) {
        final pattern = MaskPattern.parse(token);
        expect(pattern.isValid, isTrue, reason: token);
        expect(pattern.segments, [MaskSegment.pool(pool, 1)], reason: token);
      });
    });

    test('literals are copied through and mixed with placeholders', () {
      final pattern = MaskPattern.parse('A-#');
      expect(pattern.isValid, isTrue);
      expect(pattern.segments, [
        MaskSegment.pool(CharPools.uppercase, 1),
        MaskSegment.literal('-'.codeUnitAt(0), 1),
        MaskSegment.pool(CharPools.digit, 1),
      ]);
      expect(pattern.outputLength, 3);
    });

    test('a repetition expands the item before it', () {
      expect(MaskPattern.parse('A{2}#{3}A{2}').segments, [
        MaskSegment.pool(CharPools.uppercase, 2),
        MaskSegment.pool(CharPools.digit, 3),
        MaskSegment.pool(CharPools.uppercase, 2),
      ]);
      expect(MaskPattern.parse('A{2}#{3}A{2}').outputLength, 7);
      // Same output as spelling it out.
      expect(MaskPattern.parse('AA###AA').outputLength, 7);
    });

    test('a repetition after a literal is legal', () {
      final pattern = MaskPattern.parse('#-{3}#');
      expect(pattern.isValid, isTrue);
      expect(pattern.segments, [
        MaskSegment.pool(CharPools.digit, 1),
        MaskSegment.literal('-'.codeUnitAt(0), 3),
        MaskSegment.pool(CharPools.digit, 1),
      ]);
      expect(pattern.outputLength, 5);
    });

    test('the escape turns the next character into a literal', () {
      for (final token in ['A', '#', r'\', '{']) {
        final pattern = MaskPattern.parse('#\\$token');
        expect(pattern.isValid, isTrue, reason: token);
        expect(
          pattern.segments.last,
          MaskSegment.literal(token.codeUnitAt(0), 1),
          reason: token,
        );
      }
    });

    test('an escaped placeholder can still be repeated', () {
      expect(MaskPattern.parse('#\\A{3}').segments, [
        MaskSegment.pool(CharPools.digit, 1),
        MaskSegment.literal('A'.codeUnitAt(0), 3),
      ]);
    });

    test('a trailing lone escape is a literal backslash, not an error', () {
      final pattern = MaskPattern.parse('#\\');
      expect(pattern.isValid, isTrue);
      expect(pattern.segments, [
        MaskSegment.pool(CharPools.digit, 1),
        MaskSegment.literal(r'\'.codeUnitAt(0), 1),
      ]);
    });

    test('non-ASCII literals survive, and an emoji is not split', () {
      final pattern = MaskPattern.parse('é#🙂');
      expect(pattern.isValid, isTrue);
      expect(pattern.segments, [
        MaskSegment.literal('é'.runes.single, 1),
        MaskSegment.pool(CharPools.digit, 1),
        MaskSegment.literal('🙂'.runes.single, 1),
      ]);
      expect(pattern.outputLength, 3);
    });

    test('a mask with no placeholder is rejected, empty included', () {
      // A mask of literals only would generate the same string every time,
      // which is not what this app is for.
      for (final mask in ['', '   ', '--12', r'\A\#']) {
        expect(
          MaskPattern.parse(mask).error,
          MaskError.noPlaceholder,
          reason: 'mask "$mask"',
        );
      }
      // One placeholder anywhere is enough.
      expect(MaskPattern.parse('--1A').isValid, isTrue);
    });

    test('malformed repetitions are rejected', () {
      for (final mask in [
        '{3}', // nothing to repeat
        'a{}', // no count
        'a{0}', // zero
        'a{2x}', // not a number
        'a{ 2}', // no whitespace inside the braces
        'a{+2}', // no sign either
        'a{2', // unclosed
        'a{2}{3}', // a repetition is not an item
      ]) {
        expect(
          MaskPattern.parse(mask).error,
          MaskError.badQuantifier,
          reason: 'mask "$mask"',
        );
      }
    });

    test('an expansion past the bound is rejected at the bound', () {
      expect(MaskPattern.parse('#{4096}').isValid, isTrue);
      expect(MaskPattern.parse('#{4096}').outputLength, 4096);
      expect(MaskPattern.parse('#{4097}').error, MaskError.tooLong);
      expect(MaskPattern.parse('A{5000}').error, MaskError.tooLong);
      expect(MaskPattern.parse('#{4000}A{97}').error, MaskError.tooLong);
      // Digits only, but far past what an int holds.
      expect(
        MaskPattern.parse('#{99999999999999999999999}').error,
        MaskError.tooLong,
      );
    });

    test('an invalid pattern carries no segments and never throws', () {
      for (final mask in ['', 'a{', '{9}', 'A{9999}']) {
        final pattern = MaskPattern.parse(mask);
        expect(pattern.isValid, isFalse, reason: 'mask "$mask"');
        expect(pattern.segments, isEmpty, reason: 'mask "$mask"');
        expect(pattern.outputLength, 0, reason: 'mask "$mask"');
      }
    });

    test('segments are unmodifiable', () {
      final pattern = MaskPattern.parse('AA###AA');
      expect(
        () => pattern.segments.add(MaskSegment.literal(65, 1)),
        throwsUnsupportedError,
      );
    });

    test('equality is structural over the segments', () {
      expect(MaskPattern.parse('a{2}-#'), MaskPattern.parse('a{2}-#'));
      expect(MaskPattern.parse('a{2}-#'), isNot(MaskPattern.parse('a{3}-#')));
      // Same output, different structure: a{2} is one segment, aa is two.
      expect(MaskPattern.parse('a{2}'), isNot(MaskPattern.parse('aa')));
    });
  });
}
