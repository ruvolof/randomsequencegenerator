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

    await store.deleteAll();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.allEntriesDeleted)));
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

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.entry});

  final SavedEntry entry;

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final action = await showMenu<_RowAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: _RowAction.delete, child: Text(l10n.delete)),
        PopupMenuItem(value: _RowAction.copy, child: Text(l10n.copy)),
        PopupMenuItem(value: _RowAction.send, child: Text(l10n.send)),
      ],
    );
    if (action == null) return;
    if (!context.mounted) return;

    switch (action) {
      case _RowAction.delete:
        await store.deleteByName(entry.name);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.entryDeleted(entry.name))),
          );
      case _RowAction.copy:
        await TextActions.copyToClipboard(context, entry.sequence);
      case _RowAction.send:
        await TextActions.shareText(context, entry.sequence);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry.name),
      onTap: () => Navigator.of(context).push(
        // Typed, so the sequence cannot arrive null the way an untyped route
        // argument could.
        MaterialPageRoute<void>(
          builder: (_) => ShowSequenceScreen(entry: entry),
        ),
      ),
      onLongPress: () {
        final box = context.findRenderObject()! as RenderBox;
        _showContextMenu(
          context,
          box.localToGlobal(box.size.center(Offset.zero)),
        );
      },
    );
  }
}

enum _RowAction { delete, copy, send }
