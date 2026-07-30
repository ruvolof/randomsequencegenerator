import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/uuid_options.dart';
import 'labelled_checkbox.dart';

/// The three UUID rendering checkboxes, laid out like [ClassRangeSelector]:
/// across one row, wrapping when the labels cannot fit.
class UuidOptionsSelector extends StatelessWidget {
  const UuidOptionsSelector({
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final UuidOptions selection;
  final ValueChanged<UuidOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final children = [
      LabelledCheckbox(
        label: l10n.uuidUppercase,
        value: selection.uppercase,
        onChanged: (value) => onChanged(selection.copyWith(uppercase: value)),
      ),
      LabelledCheckbox(
        label: l10n.uuidHyphens,
        value: selection.hyphens,
        onChanged: (value) => onChanged(selection.copyWith(hyphens: value)),
      ),
      LabelledCheckbox(
        label: l10n.uuidBraces,
        value: selection.braces,
        onChanged: (value) => onChanged(selection.copyWith(braces: value)),
      ),
    ];

    // These labels are words rather than the short [a–z] ranges, so they run
    // out of room sooner than the class checkboxes do.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Wrap(children: children);
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        );
      },
    );
  }
}
