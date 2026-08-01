import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// How this session's tosses came out, per face.
///
/// In memory only.
class TossTally extends StatelessWidget {
  const TossTally({required this.faces, required this.history, super.key});

  final int faces;

  /// The settled results, oldest first. Only its contents matter here.
  final List<int> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final counts = List<int>.filled(faces, 0);
    for (final face in history) {
      counts[face]++;
    }

    return Column(
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var face = 0; face < faces; face++)
              // A digit and U+00D7 MULTIPLICATION SIGN: nothing here needs
              // translating, so the tally costs one string rather than one
              // per face.
              Text(
                '$face × ${counts[face]}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tossCount(history.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
