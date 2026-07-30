import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/char_pools.dart';

/// The mask syntax, on screen.
///
/// Mask mode is the one mode whose input cannot be guessed at, so the legend is
/// shown as soon as the mode is picked rather than hidden behind a help icon.
/// The token glyphs come from code, not from the ARB: they are syntax, and every
/// placeholder here is a key of [CharPools.maskPools].
class MaskLegend extends StatelessWidget {
  const MaskLegend({super.key});

  static const double _tokenColumnWidth = 44;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final entries = <(String, String)>[
      ('#', l10n.maskTokenDigit),
      ('a', l10n.maskTokenLowercase),
      ('A', l10n.maskTokenUppercase),
      ('?', l10n.maskTokenLetter),
      ('*', l10n.maskTokenAlphanumeric),
      ('h', l10n.maskTokenHexLower),
      ('H', l10n.maskTokenHexUpper),
      ('%', l10n.maskTokenSpecial),
      (
        'a${CharPools.maskRepeatOpen}5${CharPools.maskRepeatClose}',
        l10n.maskTokenRepeat,
      ),
      (CharPools.maskEscape, l10n.maskTokenEscape),
    ];

    final tokenStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
    );
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.maskLegendTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final (token, description) in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _tokenColumnWidth,
                      child: Text(token, style: tokenStyle),
                    ),
                    Expanded(child: Text(description, style: descriptionStyle)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(l10n.maskLiteralNote, style: descriptionStyle),
            Text(l10n.maskExample, style: descriptionStyle),
          ],
        ),
      ),
    );
  }
}
