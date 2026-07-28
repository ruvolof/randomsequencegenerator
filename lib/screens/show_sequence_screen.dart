import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/saved_entry.dart';
import '../services/text_actions.dart';
import '../theme/dimens.dart';
import '../widgets/icon_action_button.dart';
import '../widgets/result_display.dart';

/// Displays one saved sequence.
///
/// [entry] is a required constructor argument rather than an untyped route
/// argument — the legacy `getStringExtra` returned null when the extra was
/// missing and the activity crashed on it (bug 6).
class ShowSequenceScreen extends StatelessWidget {
  const ShowSequenceScreen({required this.entry, super.key});

  final SavedEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleActivityShowSingle)),
      body: Column(
        children: [
          const SizedBox(height: Dimens.mainPadding),
          // The legacy layout gave these 200dp side margins, tuned for a
          // tablet, which pushed them off a narrow phone. A centred row with a
          // fixed gap fits at any width.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconActionButton(
                icon: Icons.content_copy,
                label: l10n.copy,
                onPressed: () =>
                    TextActions.copyToClipboard(context, entry.sequence),
              ),
              const SizedBox(width: Dimens.showSequenceButtonGap),
              IconActionButton(
                icon: Icons.share,
                label: l10n.send,
                onPressed: () => TextActions.shareText(context, entry.sequence),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimens.mainPadding),
              child: ResultDisplay(text: entry.sequence),
            ),
          ),
        ],
      ),
    );
  }
}
