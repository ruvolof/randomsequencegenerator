import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/sequence_generator.dart';

/// The numeric length field.
///
/// The legacy screen ran `Integer.parseInt` on an unvalidated `numberDecimal`
/// field, so an empty value or `3.5` crashed the app. Here the input is
/// restricted to digits, parsed defensively, and range-checked; [onChanged]
/// reports null whenever the value is unusable so the caller can disable
/// Create.
class LengthField extends StatelessWidget {
  const LengthField({
    required this.controller,
    required this.onChanged,
    required this.hasError,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<int?> onChanged;
  final bool hasError;

  /// The parsed value of [text], or null when it is missing or out of range.
  static int? parse(String text) {
    final value = int.tryParse(text.trim());
    if (value == null) return null;
    if (value < SequenceGenerator.minLength ||
        value > SequenceGenerator.maxLength) {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      // Flutter's default tap-outside handler deliberately ignores touch events
      // on Android and iOS, so a field otherwise keeps focus until some other
      // control takes it. That is merely tedious on Android, where Back closes
      // the keyboard — but iOS renders `TextInputType.number` as the plain
      // number pad, which has no Return key to dismiss with either, so without
      // this the keyboard cannot be closed at all.
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      textAlign: TextAlign.start,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) => onChanged(parse(value)),
      decoration: InputDecoration(
        isDense: true,
        errorText: hasError
            ? l10n.lengthInvalid(
                SequenceGenerator.minLength,
                SequenceGenerator.maxLength,
              )
            : null,
      ),
    );
  }
}
