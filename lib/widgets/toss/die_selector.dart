import 'package:flutter/material.dart';

import '../../models/toss_kind.dart';

/// The die picker: one chip per die, wrapping when they no longer fit across.
///
/// The same `Wrap` of `ChoiceChip`s [ModeSelector] uses on the main screen, for
/// the same reason — six options one tap away in a couple of rows, with 48dp
/// targets. `chipTheme` already pins the colours to the app's ramp, so this
/// costs no theme work, and the labels are glyphs, so it costs no strings.
class DieSelector extends StatelessWidget {
  const DieSelector({required this.kind, required this.onChanged, super.key});

  final TossKind kind;
  final ValueChanged<TossKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final value in TossKind.dice)
          ChoiceChip(
            label: Text(value.shortLabel),
            selected: value == kind,
            // Only ever selects: tapping the current die must not clear it,
            // the way tapping the checked radio never did.
            onSelected: (selected) {
              if (selected) onChanged(value);
            },
          ),
      ],
    );
  }
}
