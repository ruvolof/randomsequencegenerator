import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/dimens.dart';

/// The centred, oversized display of a sequence.
///
/// Selectable, which the legacy read-only `TextView` was not.
class ResultDisplay extends StatelessWidget {
  const ResultDisplay({required this.text, this.emptyHint, super.key});

  final String text;

  /// Shown in place of the sequence while [text] is empty.
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final hint = emptyHint;
    if (text.isEmpty && hint != null) {
      return Text(
        hint,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: Dimens.outputText,
          color: AppTheme.foreground,
        ),
      );
    }
    return SelectableText(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: Dimens.outputText,
        color: AppTheme.foreground,
      ),
    );
  }
}
