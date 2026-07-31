import 'package:flutter/material.dart';

/// A label and a hairline rule introducing a group of controls.
///
/// The main screen is a flat stack on a single background colour, with no cards
/// to group anything, so the heading is what tells the user that what follows
/// belongs together. `labelLarge` is the same style [MaskLegend] gives its own
/// title, so the two agree on what a heading looks like.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // The theme's divider colour at half strength: a full-width rule at the
        // full #8A8A8A reads louder than the label above it.
        Divider(
          height: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
