import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/generation_mode.dart';

/// The generation mode picker: one chip per mode, wrapping when they no longer
/// fit across.
///
/// This replaced a vertical radio group. Six modes stacked at one row each ate
/// 204dp before any content on a phone, pushing the result past the fold, and
/// every mode added since has made that worse. Chips keep all six visible and
/// one tap away in about two rows, and carry the same selected/unselected
/// semantics a radio does.
class ModeSelector extends StatelessWidget {
  const ModeSelector({required this.mode, required this.onChanged, super.key});

  final GenerationMode mode;
  final ValueChanged<GenerationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in GenerationMode.values)
          ChoiceChip(
            label: Text(_label(l10n, value)),
            selected: value == mode,
            // Only ever selects: tapping the current mode must not clear it,
            // the way tapping the checked radio never did.
            onSelected: (selected) {
              if (selected) onChanged(value);
            },
          ),
      ],
    );
  }
}

/// The on-screen name of [mode].
///
/// Private to this widget for now. The saved list will want the same lookup
/// once it shows the mode of each entry — that is the moment to lift it out,
/// not before there is a second caller.
String _label(AppLocalizations l10n, GenerationMode mode) => switch (mode) {
  GenerationMode.binary => l10n.rBinary,
  GenerationMode.hexadecimal => l10n.rHexadecimal,
  GenerationMode.charClass => l10n.rClass,
  GenerationMode.manual => l10n.rManual,
  GenerationMode.uuid => l10n.rUuid,
  GenerationMode.mask => l10n.rMask,
};
