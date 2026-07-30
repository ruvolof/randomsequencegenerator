/// How the character pool a sequence is drawn from gets built.
enum GenerationMode {
  binary,
  hexadecimal,

  /// The pool is the concatenation of the checked character classes.
  charClass,

  /// The pool is whatever the user typed, taken verbatim.
  manual,

  /// The odd one out: no pool and no length, a version 4 UUID rendered
  /// according to the ticked format options.
  uuid,

  /// The pool changes from position to position: the user writes a template and
  /// each placeholder in it is filled from its own pool.
  mask;

  /// The value persisted alongside a saved entry. Kept independent of the
  /// declaration order so reordering the enum cannot invalidate stored data.
  String get storageKey => switch (this) {
    GenerationMode.binary => 'binary',
    GenerationMode.hexadecimal => 'hexadecimal',
    GenerationMode.charClass => 'class',
    GenerationMode.manual => 'manual',
    GenerationMode.uuid => 'uuid',
    GenerationMode.mask => 'mask',
  };

  /// Whether the mode draws a sequence to the length the user asks for, and so
  /// needs the length field. A UUID is 128 bits whatever anyone wants and a
  /// mask carries its own length, so for those two the field would be a dead
  /// control.
  bool get usesLength =>
      this != GenerationMode.uuid && this != GenerationMode.mask;

  /// Returns null for an unknown or missing key rather than throwing, so one
  /// bad entry cannot take down the whole saved list.
  static GenerationMode? tryFromStorageKey(Object? key) {
    for (final mode in GenerationMode.values) {
      if (mode.storageKey == key) return mode;
    }
    return null;
  }
}
