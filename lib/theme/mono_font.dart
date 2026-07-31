import 'package:flutter/painting.dart';

/// The monospace face used wherever mask syntax is shown.
///
/// `'monospace'` on its own is an Android-only alias: it is resolved by
/// Android's font config and names no family on iOS, macOS, Windows or Linux,
/// where the text silently falls back to the proportional default. Mask syntax
/// is exactly the content where column alignment carries meaning, so the alias
/// is kept first — it is the right answer on Android — and the families that
/// mean the same thing on the other platforms follow it.
///
/// Nothing is bundled: every entry below ships with its platform, so the app
/// stays the same size and no font licence has to travel with the repo.
abstract final class MonoFont {
  static const String family = 'monospace';

  /// Tried in order after [family], first match wins.
  static const List<String> familyFallback = <String>[
    'Menlo', // iOS, macOS
    'Consolas', // Windows
    'DejaVu Sans Mono', // Linux
    'Courier New', // last resort, present nearly everywhere
  ];

  /// For callers with no base style to merge into; merge this into one when
  /// there is, so the base's size and colour survive.
  static const TextStyle style = TextStyle(
    fontFamily: family,
    fontFamilyFallback: familyFallback,
  );
}
