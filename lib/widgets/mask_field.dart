import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/mask_pattern.dart';
import '../services/sequence_generator.dart';
import '../theme/mono_font.dart';

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
      // Tapping the background dismisses the keyboard, which Flutter does not
      // do for touch on mobile. See `LengthField` for why.
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      // A mask is syntax, not prose: autocapitalizing or "correcting" it would
      // silently change what it generates.
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      inputFormatters: [
        LengthLimitingTextInputFormatter(SequenceGenerator.maxMaskLength),
      ],
      style: MonoFont.style,
      decoration: InputDecoration(
        hintText: l10n.maskHint,
        // No `hintStyle`: the field's `style` reaches the hint on its own —
        // `TextField` passes it to the decorator as `baseStyle`, which the hint
        // merges under (`input_decorator.dart:2199-2210`) — so naming the font
        // again here only displaces the app theme's hint colour with M3's
        // default, leaving this the one hint in the app that is not `_outline`.
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
