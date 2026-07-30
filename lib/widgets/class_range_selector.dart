import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/class_selection.dart';
import 'labelled_checkbox.dart';

/// The four character-class checkboxes: three across one row and the special
/// characters on a second row beneath, as in the legacy layout.
class ClassRangeSelector extends StatelessWidget {
  const ClassRangeSelector({
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final ClassSelection selection;
  final ValueChanged<ClassSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final digits = LabelledCheckbox(
      label: l10n.rangeDigit,
      value: selection.digits,
      onChanged: (value) => onChanged(selection.copyWith(digits: value)),
    );
    final lowercase = LabelledCheckbox(
      label: l10n.rangeLowercase,
      value: selection.lowercase,
      onChanged: (value) => onChanged(selection.copyWith(lowercase: value)),
    );
    final uppercase = LabelledCheckbox(
      label: l10n.rangeUppercase,
      value: selection.uppercase,
      onChanged: (value) => onChanged(selection.copyWith(uppercase: value)),
    );
    final special = LabelledCheckbox(
      label: l10n.rangeSpecial,
      value: selection.special,
      onChanged: (value) => onChanged(selection.copyWith(special: value)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The one place a LayoutBuilder is needed: when three labels cannot fit
        // across, wrap instead of letting [A–Z] overflow.
        LayoutBuilder(
          builder: (context, constraints) {
            final children = [digits, lowercase, uppercase];
            if (constraints.maxWidth < 320) {
              return Wrap(children: children);
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            );
          },
        ),
        special,
      ],
    );
  }
}
