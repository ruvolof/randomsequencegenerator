import '../models/toss_kind.dart';
import 'generated/app_localizations.dart';

/// The strings naming a [TossKind] on screen.
///
/// Lives here for the same reason [GenerationModeLabel] does: [TossKind] is
/// pure Dart, tested without a widget binding, and these need the
/// localizations.
///
/// Both switches are exhaustive with no `default`, so adding a die is what
/// demands its title and its verb — "Roll" is not "Flip", and neither is a
/// string the compiler will let anyone forget.
extension TossKindLabel on TossKind {
  /// Title of the screen tossing this object.
  String title(AppLocalizations l10n) => switch (this) {
    TossKind.coin => l10n.titleActivityLaunchCoin,
  };

  /// Label of the button that tosses it.
  String action(AppLocalizations l10n) => switch (this) {
    TossKind.coin => l10n.flip,
  };
}
