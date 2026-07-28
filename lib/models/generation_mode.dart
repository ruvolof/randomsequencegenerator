/// How the character pool a sequence is drawn from gets built.
enum GenerationMode {
  binary,
  hexadecimal,

  /// The pool is the concatenation of the checked character classes.
  charClass,

  /// The pool is whatever the user typed, taken verbatim.
  manual;

  /// The value persisted alongside a saved entry. Kept independent of the
  /// declaration order so reordering the enum cannot invalidate stored data.
  String get storageKey => switch (this) {
    GenerationMode.binary => 'binary',
    GenerationMode.hexadecimal => 'hexadecimal',
    GenerationMode.charClass => 'class',
    GenerationMode.manual => 'manual',
  };

  /// Returns null for an unknown or missing key rather than throwing, so one
  /// bad entry cannot take down the whole saved list.
  static GenerationMode? tryFromStorageKey(Object? key) {
    for (final mode in GenerationMode.values) {
      if (mode.storageKey == key) return mode;
    }
    return null;
  }
}
