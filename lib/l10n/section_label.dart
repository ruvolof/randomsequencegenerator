import '../models/app_section.dart';
import 'generated/app_localizations.dart';

/// The on-screen name of an [AppSection].
///
/// Lives here for the same reason [GenerationModeLabel] and [TossKindLabel] do:
/// [AppSection] is pure Dart, tested without a widget binding, and this needs
/// the localizations.
///
/// The switch is exhaustive with no `default`, so a new section will not
/// compile until it has a name — which is what stops one appearing in the menu
/// as a blank entry.
extension AppSectionLabel on AppSection {
  String label(AppLocalizations l10n) => switch (this) {
    AppSection.strings => l10n.sectionStrings,
    AppSection.coin => l10n.coin,
    AppSection.dice => l10n.sectionDice,
  };
}
