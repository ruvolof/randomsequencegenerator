import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/mask_pattern.dart';
import '../services/sequence_generator.dart';

/// The mask template field.
///
/// Like `LengthField` it renders the validation the caller has already done —
/// [error] comes from [MaskPattern.parse] — so the field itself stays a dumb
/// widget and Create can be disabled from the same parsed value.
class MaskField extends StatelessWidget {
  const MaskField({
    required this.controller,
    required this.onChanged,
    required this.error,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Null shows no error, which is also how the caller keeps the field quiet
  /// until the user has typed something.
  final MaskError? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      // A mask is syntax, not prose: autocapitalizing or "correcting" it would
      // silently change what it generates.
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      inputFormatters: [
        LengthLimitingTextInputFormatter(SequenceGenerator.maxMaskLength),
      ],
      style: const TextStyle(fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText: l10n.maskHint,
        hintStyle: const TextStyle(fontFamily: 'monospace'),
        errorText: switch (error) {
          null => null,
          MaskError.noPlaceholder => l10n.maskErrorNoPlaceholder,
          MaskError.badQuantifier => l10n.maskErrorQuantifier,
          MaskError.tooLong => l10n.maskErrorTooLong(
            MaskPattern.maxOutputLength,
          ),
        },
      ),
    );
  }
}
