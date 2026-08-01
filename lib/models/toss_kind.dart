/// What sort of object is being tossed — which decides how it is drawn, what
/// its faces are called, and which verb tosses it.
///
/// The switches over this are exhaustive with no `default`, so a new family
/// cannot fall through and be silently drawn as a coin. A new *die*, by
/// contrast, is meant to cost one line, which is exactly why the switches key
/// off the family rather than off [TossKind].
enum TossFamily {
  /// Two faces, struck with a value.
  coin,

  /// A polyhedron numbered from 1.
  die,
}

/// A tossable object: a fixed set of equally likely faces, indexed `0` to
/// `faces - 1`.
enum TossKind {
  /// Shown as `0` and `1` — the legacy coin, and the right pair of glyphs for
  /// a binary sequence generator.
  coin(faces: 2, family: TossFamily.coin),

  d4(faces: 4, family: TossFamily.die),
  d6(faces: 6, family: TossFamily.die),
  d8(faces: 8, family: TossFamily.die),
  d10(faces: 10, family: TossFamily.die),
  d12(faces: 12, family: TossFamily.die),
  d20(faces: 20, family: TossFamily.die);

  const TossKind({required this.faces, required this.family});

  /// How many faces the object has. Handed to `TossController`, which knows
  /// nothing else about the kind.
  final int faces;

  /// How it is drawn, named and counted.
  final TossFamily family;

  /// The value shown on the face at [index].
  ///
  /// `TossController` counts faces from `0`; a coin is struck `0`/`1` and a die
  /// is numbered from `1`. This is the only place that difference lives, so a
  /// tally cannot disagree with a face about what was rolled.
  int valueOf(int index) => switch (family) {
    TossFamily.coin => index,
    TossFamily.die => index + 1,
  };

  /// The picker's label for a die, `D6`.
  ///
  /// Built in Dart rather than translated, like the tally's `×` and the mask
  /// legend's quantifier: it is a glyph, and `D20` is `D20` in every locale.
  String get shortLabel => 'D$faces';

  /// The dice, in declaration order — the contents of the picker.
  static final List<TossKind> dice = List.unmodifiable(
    values.where((kind) => kind.family == TossFamily.die),
  );
}
