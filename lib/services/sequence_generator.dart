import 'dart:math';

import '../models/class_selection.dart';
import '../models/generation_mode.dart';
import '../models/mask_pattern.dart';
import '../models/uuid_options.dart';
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

  /// The longest mask the UI lets the user type. What that mask *expands* to is
  /// bounded separately, by [MaskPattern.maxOutputLength].
  static const int maxMaskLength = 256;

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
    // Not an oversight: a UUID is not drawn from a pool. [generateUuid] is the
    // entry point for that mode.
    GenerationMode.uuid => '',
    // Nor is a mask, which has one pool per position rather than one overall.
    // [generateFromMask] is the entry point for that mode.
    GenerationMode.mask => '',
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

  /// The string [pattern] describes: each placeholder filled from its own pool,
  /// each literal copied through.
  ///
  /// Returns `''` for an invalid pattern rather than throwing, the same way
  /// [generate] handles an empty pool. Delegates every draw to [generate], so
  /// mask output inherits its uniform, cryptographically secure randomness.
  String generateFromMask(MaskPattern pattern) {
    if (!pattern.isValid) return '';
    final buffer = StringBuffer();
    for (final segment in pattern.segments) {
      final pool = segment.pool;
      if (pool != null) {
        buffer.write(generate(pool: pool, length: segment.count));
      } else {
        for (var i = 0; i < segment.count; i++) {
          buffer.writeCharCode(segment.literal!);
        }
      }
    }
    return buffer.toString();
  }

  /// A version 4 (random) UUID, rendered according to [options].
  ///
  /// Drawn from the same injected [Random] as [generate] — [Random.secure] in
  /// the app, because a UUID used as a token or a key is as much a secret as a
  /// generated password.
  String generateUuid(UuidOptions options) {
    final bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    // The six bits RFC 4122 pins down: version 4 in the high nibble of octet 6,
    // variant 10xx in the two high bits of octet 8. Everything else is random.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) => [
      for (var i = start; i < end; i++)
        bytes[i].toRadixString(16).padLeft(2, '0'),
    ].join();

    final groups = [hex(0, 4), hex(4, 6), hex(6, 8), hex(8, 10), hex(10, 16)];
    var uuid = groups.join(options.hyphens ? '-' : '');
    if (options.uppercase) uuid = uuid.toUpperCase();
    return options.braces ? '{$uuid}' : uuid;
  }
}
