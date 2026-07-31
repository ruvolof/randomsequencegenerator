import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/saved_entry.dart';
import '../services/text_actions.dart';
import '../state/saved_store_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import 'show_sequence_screen.dart';

/// The list of saved sequence names.
///
/// The rows come straight from the store's model. Deleting mutates the model
/// and notifies; the legacy version hid a recycled `ListView` row instead, so
/// the entry came back on scroll and an unrelated row vanished (bug 4).
class SavedListScreen extends StatelessWidget {
  const SavedListScreen({super.key});

  Future<void> _deleteAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);

    if (store.isEmpty) {
      // No dialog on an empty list, matching the legacy toast.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.nothingToDelete)));
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      message: l10n.areYouSure,
      confirmLabel: l10n.yesDeleteThem,
    );
    if (!confirmed) return;

    final stored = await store.deleteAll();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(stored ? l10n.allEntriesDeleted : l10n.changeNotStored),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.of(context);
    final entries = store.entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleActivityShowSaved),
        actions: [
          TextButton(
            onPressed: () => _deleteAll(context),
            child: Text(l10n.deleteAll),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                l10n.noSaved,
                style: const TextStyle(color: AppTheme.foreground),
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) => _SavedRow(entry: entries[index]),
            ),
    );
  }
}

/// One saved name, with everything you can do to it.
///
/// A tap opens the actions sheet and the eye button opens the entry. The two
/// used to be the other way round, with the actions hidden behind a long press
/// — an interaction nothing on screen advertised, and one that has no hover or
/// right-click equivalent to discover it by.
class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.entry});

  final SavedEntry entry;

  Future<void> _showActions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);

    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Which entry the actions belong to. The sheet covers the row that
            // opened it, and Delete is two taps away from a mis-hit row.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                entry.name,
                style: Theme.of(sheetContext).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            for (final item in _RowAction.values)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label(l10n)),
                onTap: () => Navigator.of(sheetContext).pop(item),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (!context.mounted) return;

    switch (action) {
      case _RowAction.copy:
        await TextActions.copyToClipboard(context, entry.sequence);
      case _RowAction.share:
        await TextActions.shareText(context, entry.sequence);
      case _RowAction.delete:
        // Confirmed, as it is on the screen showing one entry — a delete
        // cannot be undone, and this one is now reachable by a single tap on
        // a row plus a tap on a sheet that opens under the finger.
        final confirmed = await showConfirmDialog(
          context: context,
          message: l10n.deleteEntryMessage(entry.name),
          confirmLabel: l10n.delete,
        );
        if (!confirmed) return;

        final stored = await store.deleteByName(entry.name);
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      title: Text(entry.name),
      onTap: () => _showActions(context),
      trailing: IconButton(
        icon: const Icon(Icons.visibility),
        tooltip: l10n.view,
        onPressed: () => Navigator.of(context).push(
          // Typed, so the sequence cannot arrive null the way an untyped route
          // argument could.
          MaterialPageRoute<void>(
            builder: (_) => ShowSequenceScreen(entry: entry),
          ),
        ),
      ),
    );
  }
}

/// The sheet's rows, in the order they are shown: the harmless two first, the
/// irreversible one last.
enum _RowAction {
  copy(Icons.content_copy),
  share(Icons.share),
  delete(Icons.delete);

  const _RowAction(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    _RowAction.copy => l10n.copy,
    _RowAction.share => l10n.send,
    _RowAction.delete => l10n.delete,
  };
}
