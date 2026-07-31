import '../models/generation_mode.dart';
import 'generated/app_localizations.dart';

/// The on-screen name of a [GenerationMode].
///
/// Lives here rather than on the enum because [GenerationMode] is pure Dart,
/// tested without a widget binding, and this needs the localizations. It was
/// private to [ModeSelector] until the show sequence screen had to name the
/// mode of a saved entry too.
extension GenerationModeLabel on GenerationMode {
  String label(AppLocalizations l10n) => switch (this) {
    GenerationMode.binary => l10n.rBinary,
    GenerationMode.hexadecimal => l10n.rHexadecimal,
    GenerationMode.charClass => l10n.rClass,
    GenerationMode.manual => l10n.rManual,
    GenerationMode.uuid => l10n.rUuid,
    GenerationMode.mask => l10n.rMask,
  };
}
