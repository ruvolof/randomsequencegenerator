import 'package:flutter/material.dart';

/// A checkbox with its label, the whole row tappable.
///
/// Deliberately not `CheckboxListTile`, which is full-width with heavy padding
/// and nothing like the legacy `wrap_content` rows.
class LabelledCheckbox extends StatelessWidget {
  const LabelledCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(label),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
