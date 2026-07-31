import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// The centred, oversized display of a sequence.
///
/// Selectable, which the legacy read-only `TextView` was not.
class ResultDisplay extends StatelessWidget {
  const ResultDisplay({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: Dimens.outputText,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
