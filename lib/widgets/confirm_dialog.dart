import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// A yes/no dialog, used for both delete-all and the overwrite confirmation.
///
/// Resolves to false when dismissed by a back gesture or a tap outside.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String message,
  required String confirmLabel,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
