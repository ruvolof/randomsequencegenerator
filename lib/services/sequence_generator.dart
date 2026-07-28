import 'dart:math';

import '../models/class_selection.dart';
import '../models/generation_mode.dart';
import 'char_pools.dart';

/// Builds character pools and draws sequences from them.
///
/// [random] is injectable so tests can be deterministic; the app always uses
/// the default, which is [Random.secure] — this is effectively a password
/// generator and the legacy `Math.random()` was not suitable for that.
class SequenceGenerator {
  SequenceGenerator({Random? random}) : _random = random ?? Random.secure();

  /// The shortest sequence the UI accepts.
  static const int minLength = 1;

  /// The longest sequence the UI accepts. The legacy app had no bound at all
  /// and crashed on anything unparseable.
  static const int maxLength = 4096;

  final Random _random;

  /// The pool for [mode].
  ///
  /// In [GenerationMode.charClass] the checked sets are concatenated in the
  /// fixed order digits, lowercase, uppercase, special — the order the user
  /// ticked them in is irrelevant, matching the legacy behaviour.
  static String poolFor({
    required GenerationMode mode,
    required ClassSelection classes,
    required String manualText,
  }) => switch (mode) {
    GenerationMode.binary => CharPools.binary,
    GenerationMode.hexadecimal => CharPools.hex,
    // Verbatim: no trim and no dedup. Repeating a character is a legitimate
    // way to bias the output and the legacy app allowed it.
    GenerationMode.manual => manualText,
    GenerationMode.charClass => [
      if (classes.digits) CharPools.digit,
      if (classes.lowercase) CharPools.lowercase,
      if (classes.uppercase) CharPools.uppercase,
      if (classes.special) CharPools.special,
    ].join(),
  };

  /// A sequence of [length] characters drawn uniformly from [pool].
  ///
  /// Returns `''` for an empty pool or a non-positive length rather than
  /// throwing. Iterates runes, not code units, so a pasted emoji cannot be
  /// split into lone surrogates.
  String generate({required String pool, required int length}) {
    if (pool.isEmpty || length <= 0) return '';
    final codePoints = pool.runes.toList(growable: false);
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      // nextInt is uniform. The legacy `Math.round(Math.random() * lastIndex)`
      // gave the first and last pool characters half the weight of the rest.
      buffer.writeCharCode(codePoints[_random.nextInt(codePoints.length)]);
    }
    return buffer.toString();
  }
}
