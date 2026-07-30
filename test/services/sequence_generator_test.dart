import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/class_selection.dart';
import 'package:random_sequence_generator/models/generation_mode.dart';
import 'package:random_sequence_generator/models/mask_pattern.dart';
import 'package:random_sequence_generator/models/uuid_options.dart';
import 'package:random_sequence_generator/services/char_pools.dart';
import 'package:random_sequence_generator/services/sequence_generator.dart';

void main() {
  group('CharPools', () {
    test('match the legacy Java constants verbatim', () {
      expect(CharPools.binary, '01');
      expect(CharPools.hex, '0123456789ABCDEF');
      expect(CharPools.digit, '0123456789');
      expect(CharPools.lowercase, 'qwertyuiopasdfghjklzxcvbnm');
      expect(CharPools.uppercase, 'QWERTYUIOPASDFGHJKLZXCVBNM');
      expect(CharPools.special, r'$%&()=?@#<>_£[]*');
    });
  });

  group('poolFor', () {
    String poolFor(
      GenerationMode mode, {
      ClassSelection classes = ClassSelection.none,
      String manualText = '',
    }) => SequenceGenerator.poolFor(
      mode: mode,
      classes: classes,
      manualText: manualText,
    );

    test('binary and hexadecimal ignore the other inputs', () {
      expect(
        poolFor(
          GenerationMode.binary,
          classes: const ClassSelection(digits: true),
          manualText: 'ignored',
        ),
        CharPools.binary,
      );
      expect(
        poolFor(GenerationMode.hexadecimal, manualText: 'ignored'),
        CharPools.hex,
      );
    });

    test('manual takes the field verbatim — no trim, no dedup', () {
      expect(poolFor(GenerationMode.manual, manualText: '  aab  '), '  aab  ');
      expect(poolFor(GenerationMode.manual, manualText: ''), '');
    });

    test('class mode concatenates in DIGIT, LAZ, CAZ, SPECIAL order '
        'for all 16 combinations', () {
      for (var bits = 0; bits < 16; bits++) {
        final classes = ClassSelection(
          digits: bits & 1 != 0,
          lowercase: bits & 2 != 0,
          uppercase: bits & 4 != 0,
          special: bits & 8 != 0,
        );
        final expected = [
          if (classes.digits) CharPools.digit,
          if (classes.lowercase) CharPools.lowercase,
          if (classes.uppercase) CharPools.uppercase,
          if (classes.special) CharPools.special,
        ].join();
        expect(
          poolFor(GenerationMode.charClass, classes: classes),
          expected,
          reason: 'combination $classes',
        );
      }
    });

    test('the tick order does not affect the pool order', () {
      // Whichever order the user ticks them in, the result is the same string.
      const all = ClassSelection(
        digits: true,
        lowercase: true,
        uppercase: true,
        special: true,
      );
      final built = const ClassSelection()
          .copyWith(special: true)
          .copyWith(uppercase: true)
          .copyWith(digits: true)
          .copyWith(lowercase: true);
      expect(
        poolFor(GenerationMode.charClass, classes: built),
        poolFor(GenerationMode.charClass, classes: all),
      );
      expect(
        poolFor(GenerationMode.charClass, classes: all),
        '${CharPools.digit}${CharPools.lowercase}'
        '${CharPools.uppercase}${CharPools.special}',
      );
    });

    test('class mode with nothing checked yields an empty pool', () {
      expect(poolFor(GenerationMode.charClass), isEmpty);
    });

    test('uuid mode has no pool — generateUuid is its entry point', () {
      expect(
        poolFor(
          GenerationMode.uuid,
          classes: const ClassSelection(digits: true),
          manualText: 'ignored',
        ),
        isEmpty,
      );
    });
  });

  group('generate', () {
    final generator = SequenceGenerator(random: Random(1));

    test('honours the requested length at the boundaries', () {
      for (final length in [1, 32, 4096]) {
        expect(
          generator.generate(pool: CharPools.hex, length: length).length,
          length,
        );
      }
    });

    test('every character comes from the pool', () {
      const pool = CharPools.special;
      final result = generator.generate(pool: pool, length: 500);
      for (final rune in result.runes) {
        expect(pool.runes, contains(rune));
      }
    });

    test('returns empty for an empty pool or a non-positive length', () {
      expect(generator.generate(pool: '', length: 32), '');
      expect(generator.generate(pool: CharPools.hex, length: 0), '');
      expect(generator.generate(pool: CharPools.hex, length: -5), '');
      expect(generator.generate(pool: '', length: 0), '');
    });

    test('bug 2 — the distribution is uniform across the whole pool', () {
      // The legacy Math.round(Math.random() * lastIndex) gave the first and
      // last pool characters half the weight of every other character.
      const perSymbol = 10000;
      const total = perSymbol * 16;
      final result = SequenceGenerator(
        random: Random(42),
      ).generate(pool: CharPools.hex, length: total);

      final counts = <int, int>{};
      for (final rune in result.runes) {
        counts[rune] = (counts[rune] ?? 0) + 1;
      }

      expect(counts.length, 16);
      for (final rune in CharPools.hex.runes) {
        final count = counts[rune] ?? 0;
        expect(
          count,
          inInclusiveRange(perSymbol * 0.96, perSymbol * 1.04),
          reason:
              'symbol ${String.fromCharCode(rune)} landed at $count, '
              'outside 4% of $perSymbol',
        );
      }
    });

    test('draws whole code points, never lone surrogates', () {
      final result = generator.generate(pool: '🙂🙃', length: 10);
      expect(result.runes.length, 10);
      // Two UTF-16 code units per emoji, so no rune was split in half.
      expect(result.length, 20);
      for (final rune in result.runes) {
        expect('🙂🙃'.runes, contains(rune));
      }
    });

    test(
      'a repeated character biases the output, as the legacy app allowed',
      () {
        final result = generator.generate(pool: 'aab', length: 2000);
        final aCount = 'a'.allMatches(result).length;
        // Two thirds of a uniform draw over ['a', 'a', 'b'].
        expect(aCount, inInclusiveRange(2000 * 0.6, 2000 * 0.73));
      },
    );
  });

  group('generateUuid', () {
    final generator = SequenceGenerator(random: Random(7));

    // The canonical form, with the version nibble and the variant bits pinned
    // where RFC 4122 puts them.
    final canonical = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('defaults to the canonical RFC 4122 rendering', () {
      for (var i = 0; i < 200; i++) {
        final uuid = generator.generateUuid(UuidOptions.defaults);
        expect(uuid, matches(canonical), reason: 'draw $i');
      }
    });

    test('the version and variant survive every option combination', () {
      for (var bits = 0; bits < 8; bits++) {
        final options = UuidOptions(
          uppercase: bits & 1 != 0,
          hyphens: bits & 2 != 0,
          braces: bits & 4 != 0,
        );
        final uuid = generator.generateUuid(options);

        // Strip the rendering back to the canonical form and check that.
        var bare = uuid;
        if (options.braces) {
          expect(bare.startsWith('{'), isTrue, reason: '$options');
          expect(bare.endsWith('}'), isTrue, reason: '$options');
          bare = bare.substring(1, bare.length - 1);
        } else {
          expect(bare, isNot(contains('{')), reason: '$options');
        }
        if (options.uppercase) {
          expect(bare, bare.toUpperCase(), reason: '$options');
          bare = bare.toLowerCase();
        } else {
          expect(bare, bare.toLowerCase(), reason: '$options');
        }
        if (!options.hyphens) {
          expect(bare, hasLength(32), reason: '$options');
          bare =
              '${bare.substring(0, 8)}-${bare.substring(8, 12)}-'
              '${bare.substring(12, 16)}-${bare.substring(16, 20)}-'
              '${bare.substring(20)}';
        }

        expect(bare, matches(canonical), reason: '$options');
        expect(
          uuid.length,
          (options.hyphens ? 36 : 32) + (options.braces ? 2 : 0),
          reason: '$options',
        );
      }
    });

    test('renders the GUID style when uppercase and braces are ticked', () {
      final uuid = generator.generateUuid(
        const UuidOptions(uppercase: true, braces: true),
      );
      expect(
        uuid,
        matches(
          RegExp(
            r'^\{[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-'
            r'[89AB][0-9A-F]{3}-[0-9A-F]{12}\}$',
          ),
        ),
      );
    });

    test('a seeded Random makes it reproducible', () {
      final first = SequenceGenerator(
        random: Random(11),
      ).generateUuid(UuidOptions.defaults);
      final second = SequenceGenerator(
        random: Random(11),
      ).generateUuid(UuidOptions.defaults);
      expect(first, second);
    });

    test('draws are distinct', () {
      final seen = {
        for (var i = 0; i < 200; i++)
          SequenceGenerator().generateUuid(UuidOptions.defaults),
      };
      expect(seen, hasLength(200));
    });
  });

  group('poolFor mask', () {
    test('has no pool — generateFromMask is its entry point', () {
      expect(
        SequenceGenerator.poolFor(
          mode: GenerationMode.mask,
          classes: const ClassSelection(digits: true),
          manualText: 'ignored',
        ),
        isEmpty,
      );
    });
  });

  group('generateFromMask', () {
    final generator = SequenceGenerator(random: Random(42));

    test('output length equals the pattern length', () {
      for (final mask in ['AA###AA', 'a{5}#{3}', 'h{4}:H{4}', '#-{3}#']) {
        final pattern = MaskPattern.parse(mask);
        expect(
          generator.generateFromMask(pattern).length,
          pattern.outputLength,
          reason: mask,
        );
      }
    });

    test('every placeholder character comes from its own pool', () {
      // One draw per token, generously long, each checked against its pool.
      final byToken = {
        '#': CharPools.digit,
        'a': CharPools.lowercase,
        'A': CharPools.uppercase,
        '?': CharPools.lowercase + CharPools.uppercase,
        '*': CharPools.digit + CharPools.lowercase + CharPools.uppercase,
        'h': CharPools.hexLowercase,
        'H': CharPools.hex,
        '%': CharPools.special,
      };
      byToken.forEach((token, pool) {
        final result = generator.generateFromMask(
          MaskPattern.parse('$token{200}'),
        );
        for (final rune in result.runes) {
          expect(
            pool.runes,
            contains(rune),
            reason: 'token $token produced ${String.fromCharCode(rune)}',
          );
        }
      });
    });

    test('literals land at the right offsets, whatever is drawn', () {
      for (var i = 0; i < 50; i++) {
        final result = generator.generateFromMask(MaskPattern.parse('AA-###'));
        expect(result, matches(RegExp(r'^[A-Z]{2}-\d{3}$')), reason: 'draw $i');
      }
    });

    test('a plate mask keeps its shape over many draws', () {
      final plate = RegExp(r'^[A-Z]{2}\d{3}[A-Z]{2}$');
      final pattern = MaskPattern.parse('AA###AA');
      for (var i = 0; i < 500; i++) {
        expect(generator.generateFromMask(pattern), matches(plate));
      }
    });

    test('the two hex tokens keep their case apart', () {
      final result = generator.generateFromMask(MaskPattern.parse('h{8}H{8}'));
      expect(result.substring(0, 8), matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(result.substring(8), matches(RegExp(r'^[0-9A-F]{8}$')));
    });

    test('an invalid pattern generates nothing rather than throwing', () {
      for (final mask in ['', 'bcd', 'a{0}', 'A{9999}']) {
        expect(
          generator.generateFromMask(MaskPattern.parse(mask)),
          isEmpty,
          reason: 'mask "$mask"',
        );
      }
    });

    test('draws vary — the mask is filled at random, not fixed', () {
      final pattern = MaskPattern.parse('AA###AA');
      final seen = {
        for (var i = 0; i < 100; i++) generator.generateFromMask(pattern),
      };
      // 7 random positions over large pools: collisions are vanishingly rare.
      expect(seen.length, greaterThan(90));
    });
  });
}
