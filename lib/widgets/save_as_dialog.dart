import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// The "Save as…" dialog.
///
/// Resolves to the entered name, or null when cancelled. A blank name is
/// rejected inside the dialog rather than being stored, which the legacy
/// version allowed.
Future<String?> showSaveAsDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _SaveAsDialog(),
  );
}

class _SaveAsDialog extends StatefulWidget {
  const _SaveAsDialog();

  @override
  State<_SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<_SaveAsDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.saveAs),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              // The legacy save_as_dialog.xml carried this hint but was never
              // inflated, so it never reached the screen.
              hintText: l10n.saveHint,
              errorText: _showError ? l10n.nameRequired : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
