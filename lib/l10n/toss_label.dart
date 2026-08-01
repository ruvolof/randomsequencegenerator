import '../models/toss_kind.dart';
import 'generated/app_localizations.dart';

/// The strings naming a [TossKind] on screen.
///
/// Lives here for the same reason [GenerationModeLabel] does: [TossKind] is
/// pure Dart, tested without a widget binding, and these need the
/// localizations.
///
/// Every switch keys off [TossFamily] and is exhaustive with no `default` — a
/// new family will not compile until it has a verb, a hint and a plural, while
/// a seventh die costs none of them. "Roll" is not "Flip", and a d20 does not
/// land "7 flips".
///
/// There is no title here: every screen's app bar carries the app's name, and
/// the section menu in its top right is what says which object is on screen.
extension TossKindLabel on TossKind {
  /// Label of the button that tosses it.
  String action(AppLocalizations l10n) => switch (family) {
    TossFamily.coin => l10n.flip,
    TossFamily.die => l10n.roll,
  };

  /// Hint shown in place of the tally, before the first toss of the session.
  String hint(AppLocalizations l10n) => switch (family) {
    TossFamily.coin => l10n.clickOnFlip,
    TossFamily.die => l10n.tapToRoll,
  };

  /// How many tosses this session, under the per-face tally.
  String count(AppLocalizations l10n, int total) => switch (family) {
    TossFamily.coin => l10n.tossCount(total),
    TossFamily.die => l10n.rollCount(total),
  };
}
