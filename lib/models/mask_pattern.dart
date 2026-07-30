import 'package:flutter/foundation.dart';

import '../services/char_pools.dart';

/// Why a mask could not be used.
enum MaskError {
  /// The mask contains no placeholder at all, so it would generate nothing
  /// random. The empty mask lands here too.
  noPlaceholder,

  /// A repetition is malformed: nothing to repeat before it, an unclosed brace,
  /// or a count that is not a positive number.
  badQuantifier,

  /// The mask expands past [MaskPattern.maxOutputLength].
  tooLong,
}

/// One item of a parsed mask, plus how many times it repeats.
///
/// Either [pool] or [literal] is non-null, never both.
@immutable
class MaskSegment {
  /// `count` characters drawn from [pool].
  const MaskSegment.pool(String this.pool, this.count) : literal = null;

  /// The code point [literal], repeated `count` times verbatim.
  const MaskSegment.literal(int this.literal, this.count) : pool = null;

  final String? pool;
  final int? literal;
  final int count;

  bool get isPlaceholder => pool != null;

  /// The same item with a repetition count of [count] — how a `{n}` quantifier
  /// is applied to the item it follows.
  MaskSegment withCount(int count) => pool != null
      ? MaskSegment.pool(pool!, count)
      : MaskSegment.literal(literal!, count);

  @override
  bool operator ==(Object other) =>
      other is MaskSegment &&
      other.pool == pool &&
      other.literal == literal &&
      other.count == count;

  @override
  int get hashCode => Object.hash(pool, literal, count);

  @override
  String toString() => pool != null
      ? 'MaskSegment.pool($pool, $count)'
      : 'MaskSegment.literal(${String.fromCharCode(literal!)}, $count)';
}

/// A mask parsed into the segments it generates from.
///
/// Parsing is kept out of `SequenceGenerator` so it can be tested without a
/// `Random` and so the screen can validate the field as the user types — the
/// same split as `LengthField.parse`.
///
/// The syntax, in full:
///
/// - a key of [CharPools.maskPools] (`#`, `a`, `A`, `?`, `*`, `h`, `H`, `%`) is
///   one character drawn from that pool;
/// - `{n}` repeats the item immediately before it `n` times, whether that item
///   is a placeholder or a literal;
/// - [CharPools.maskEscape] makes the character after it a literal;
/// - anything else is a literal.
@immutable
class MaskPattern {
  const MaskPattern._(this.segments, this.error);

  /// The longest string a mask may expand to. The same bound as
  /// `SequenceGenerator.maxLength`, held separately so a model does not have to
  /// import the service that consumes it; a test pins the two together.
  static const int maxOutputLength = 4096;

  /// A count is decimal digits and nothing else — `int.tryParse` would also
  /// accept `+5` and `-5`.
  static final RegExp _count = RegExp(r'^[0-9]+$');

  static const MaskPattern _noPlaceholder = MaskPattern._(
    [],
    MaskError.noPlaceholder,
  );
  static const MaskPattern _badQuantifier = MaskPattern._(
    [],
    MaskError.badQuantifier,
  );
  static const MaskPattern _tooLong = MaskPattern._([], MaskError.tooLong);

  /// The segments to generate from, in order. Empty when [error] is set.
  final List<MaskSegment> segments;

  /// Null when the mask is usable.
  final MaskError? error;

  bool get isValid => error == null;

  /// How many characters the mask expands to.
  int get outputLength =>
      segments.fold(0, (total, segment) => total + segment.count);

  /// Parses [mask]. Never throws; an unusable mask comes back with [error] set.
  static MaskPattern parse(String mask) {
    // Runes, not code units, so a pasted emoji literal cannot be split into
    // lone surrogates — the same property SequenceGenerator.generate has.
    final runes = mask.runes.toList(growable: false);
    final segments = <MaskSegment>[];
    var hasPlaceholder = false;
    var length = 0;
    // A quantifier repeats an item, and a quantifier is not an item: this is
    // what makes `a{2}{3}` an error rather than 6 letters.
    var justQuantified = false;
    var i = 0;

    while (i < runes.length) {
      final rune = runes[i];
      final char = String.fromCharCode(rune);

      if (char == CharPools.maskEscape) {
        // A trailing lone escape is a literal backslash rather than an error:
        // the user is most likely still typing.
        final escaped = i + 1 < runes.length ? runes[i + 1] : rune;
        segments.add(MaskSegment.literal(escaped, 1));
        length += 1;
        justQuantified = false;
        i += i + 1 < runes.length ? 2 : 1;
        continue;
      }

      if (char == CharPools.maskRepeatOpen) {
        if (segments.isEmpty || justQuantified) return _badQuantifier;
        final close = runes.indexOf(
          CharPools.maskRepeatClose.codeUnitAt(0),
          i + 1,
        );
        if (close < 0) return _badQuantifier;
        final digits = String.fromCharCodes(runes.sublist(i + 1, close));
        if (!_count.hasMatch(digits)) return _badQuantifier;
        final count = int.tryParse(digits);
        // Digits only, but too many of them to be an int — that can only mean an
        // absurd length.
        if (count == null) return _tooLong;
        if (count < 1) return _badQuantifier;

        final item = segments.removeLast();
        segments.add(item.withCount(count));
        length += count - item.count;
        if (length > maxOutputLength) return _tooLong;
        justQuantified = true;
        i = close + 1;
        continue;
      }

      final pool = CharPools.maskPools[char];
      if (pool != null) {
        segments.add(MaskSegment.pool(pool, 1));
        hasPlaceholder = true;
      } else {
        segments.add(MaskSegment.literal(rune, 1));
      }
      length += 1;
      justQuantified = false;
      i += 1;
    }

    if (!hasPlaceholder) return _noPlaceholder;
    if (length > maxOutputLength) return _tooLong;
    return MaskPattern._(List.unmodifiable(segments), null);
  }

  @override
  bool operator ==(Object other) =>
      other is MaskPattern &&
      other.error == error &&
      listEquals(other.segments, segments);

  @override
  int get hashCode => Object.hash(error, Object.hashAll(segments));

  @override
  String toString() => 'MaskPattern(error: $error, segments: $segments)';
}
