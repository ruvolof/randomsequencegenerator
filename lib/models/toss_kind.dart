/// A tossable object: a fixed set of equally likely faces, indexed `0` to
/// `faces - 1`.
///
/// One value today. A die lands here as `d6(faces: 6)`, and the switches that
/// name it and draw it are exhaustive with no `default`, so the enum value will
/// not compile until its label and its face exist.
enum TossKind {
  /// Two faces, shown as `0` and `1` — the legacy coin, and the right pair of
  /// glyphs for a binary sequence generator.
  coin(faces: 2);

  const TossKind({required this.faces});

  /// How many faces the object has. Handed to `TossController`, which knows
  /// nothing else about the kind.
  final int faces;
}
