import 'toss_kind.dart';

/// A top-level place in the app, reachable from the menu in every app bar.
///
/// Distinct from `GenerationMode`, which is how [strings] builds a character
/// pool. This enum sits one level above that: the word "Mode" belongs to the
/// generator's own picker and is deliberately not reused here.
///
/// Pure Dart, like `GenerationMode` and `TossKind` — the names live in
/// `l10n/section_label.dart`.
enum AppSection {
  /// The generator. The app's home, and the only section that is not pushed.
  strings(kind: null),

  /// The coin.
  coin(kind: TossKind.coin),

  /// The dice. [kind] is where the section *opens*; the picker on the screen
  /// moves between the six from there.
  dice(kind: TossKind.d6);

  const AppSection({required this.kind});

  /// What this section tosses, or null for [strings], which tosses nothing.
  ///
  /// Null is what tells `SectionMenu` that this section is the root of the
  /// stack, so it is reached by popping rather than by pushing. Making it a
  /// field rather than a switch in the menu keeps the "is it a toss section"
  /// question answerable without a `default` arm or a throw.
  final TossKind? kind;

  /// The section that tosses [kind]. Its rough inverse, for a toss screen that
  /// knows what it is tossing and has to tell the menu where it is.
  ///
  /// Matches on the *family*, not on the kind: the dice section opens on a d6
  /// but is still the dice section once the picker has moved to a d20.
  static AppSection forKind(TossKind kind) =>
      values.firstWhere((section) => section.kind?.family == kind.family);
}
