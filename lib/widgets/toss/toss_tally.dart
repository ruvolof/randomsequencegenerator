import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/toss_label.dart';
import '../../models/toss_kind.dart';

/// How this session's tosses came out, per face.
///
/// In memory only.
class TossTally extends StatelessWidget {
  const TossTally({required this.kind, required this.history, super.key});

  /// Takes the kind rather than a face count so the labels can be the values
  /// actually printed on the object — a d6 tallies `1 … 6`, never `0 … 5` —
  /// and so the total can say "rolls" where a coin says "flips".
  final TossKind kind;

  /// The settled results, oldest first. Only its contents matter here.
  final List<int> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final counts = List<int>.filled(kind.faces, 0);
    for (final face in history) {
      counts[face]++;
    }

    // A d20 has ten times a coin's entries. Tightening the type and the gaps
    // past a handful keeps twenty of them to about three rows, so the tally
    // does not push the die itself off a phone.
    final crowded = kind.faces > 8;

    return Column(
      children: [
        Wrap(
          spacing: crowded ? 12 : 20,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var face = 0; face < kind.faces; face++)
              // A number and U+00D7 MULTIPLICATION SIGN: nothing here needs
              // translating, so the tally costs one string rather than one
              // per face.
              Text(
                '${kind.valueOf(face)} × ${counts[face]}',
                style:
                    (crowded
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.titleMedium)
                        ?.copyWith(color: theme.colorScheme.onSurface),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          kind.count(l10n, history.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
