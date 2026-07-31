import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/mode_label.dart';
import '../models/saved_entry.dart';
import '../services/text_actions.dart';
import '../state/saved_store_scope.dart';
import '../theme/app_theme.dart';
import '../theme/dimens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/icon_action_button.dart';
import '../widgets/result_display.dart';
import '../widgets/section_header.dart';

/// Displays one saved sequence.
///
/// [entry] is a required constructor argument rather than an untyped route
/// argument — the legacy `getStringExtra` returned null when the extra was
/// missing and the activity crashed on it (bug 6).
class ShowSequenceScreen extends StatelessWidget {
  const ShowSequenceScreen({required this.entry, super.key});

  final SavedEntry entry;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showConfirmDialog(
      context: context,
      message: l10n.deleteEntryMessage(entry.name),
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;

    final stored = await store.deleteByName(entry.name);
    // Nothing is left to show, so this screen goes with the entry. The
    // messenger belongs to the app, not to this Scaffold, so the confirmation
    // survives the pop and appears over the list.
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            stored ? l10n.entryDeleted(entry.name) : l10n.changeNotStored,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleActivityShowSingle)),
      // The stored entry is more than its sequence, and the same headed
      // sections the main screen groups its controls with are what say so here.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimens.mainPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(l10n.sectionName),
            const SizedBox(height: 8),
            _Detail(entry.name),
            const SizedBox(height: 20),
            SectionHeader(l10n.sectionMode),
            const SizedBox(height: 8),
            _Detail(entry.mode.label(l10n)),
            const SizedBox(height: 20),
            SectionHeader(l10n.sectionSaved),
            const SizedBox(height: 8),
            // Both halves are the same instant; the ARB splits them only so the
            // date and the time each get their own locale-aware format.
            _Detail(l10n.savedAt(entry.createdAt, entry.createdAt)),
            const SizedBox(height: 20),
            SectionHeader(l10n.sectionValue),
            const SizedBox(height: 8),
            ResultDisplay(text: entry.sequence),
          ],
        ),
      ),
      // The same bottom bar the main screen builds around its result: the
      // actions sit in the same place on both screens and stay put while a long
      // sequence scrolls. The legacy layout put them at the top with 200dp side
      // margins, tuned for a tablet, which pushed them off a narrow phone.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.mainPadding),
          // heightFactor keeps the bar exactly as tall as its content. Without
          // it Center fills the whole Scaffold and leaves the body no height.
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              // Same width as on the main screen, so copy and share land on the
              // button's left and right edges there and here alike.
              width: Dimens.createButton,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconActionButton(
                        icon: Icons.content_copy,
                        label: l10n.copy,
                        onPressed: () => TextActions.copyToClipboard(
                          context,
                          entry.sequence,
                        ),
                      ),
                      IconActionButton(
                        icon: Icons.share,
                        label: l10n.send,
                        onPressed: () =>
                            TextActions.shareText(context, entry.sequence),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Where Create sits on the main screen, and red because this
                  // one cannot be undone.
                  ElevatedButton(
                    onPressed: () => _delete(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: AppTheme.foreground,
                    ),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of detail under a [SectionHeader].
///
/// Left aligned at body size, which leaves the centred 30sp [ResultDisplay] as
/// the one thing on the screen that looks like the sequence itself.
class _Detail extends StatelessWidget {
  const _Detail(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: AppTheme.foreground),
    );
  }
}
