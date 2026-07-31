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
///
/// Stateful for the selection alone: which rows are ticked is this screen's
/// business and nothing else's, so it stays here rather than in the store.
class SavedListScreen extends StatefulWidget {
  const SavedListScreen({super.key});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  /// The selected entries, by name — the identity the store deletes by, and
  /// unique across the list, so an index would only be a weaker version of it.
  final Set<String> _selected = <String>{};

  /// One selected row is what puts the screen in selection mode; there is no
  /// separate flag to fall out of step with the set.
  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String name) => setState(() {
    if (!_selected.remove(name)) _selected.add(name);
  });

  void _selectAll(List<SavedEntry> entries) =>
      setState(() => _selected.addAll(entries.map((entry) => entry.name)));

  void _clearSelection() => setState(_selected.clear);

  /// Deletes the selection, confirming with its size first.
  ///
  /// The only way to empty the whole list is now Select all followed by this:
  /// the screen no longer carries a `Delete all` that destroys entries the user
  /// never pointed at, and a full wipe costs the same two deliberate taps as
  /// any other multi-row delete.
  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    // The button exists only while something is selected, so the count is
    // never zero and there is no empty-list case to report.
    final names = Set.of(_selected);

    final confirmed = await showConfirmDialog(
      context: context,
      message: l10n.deleteEntriesMessage(names.length),
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;

    final stored = await store.deleteByNames(names);
    // Whatever was selected is gone, so the mode goes with it.
    _clearSelection();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            stored ? l10n.entriesDeleted(names.length) : l10n.changeNotStored,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = SavedStoreScope.of(context);
    final entries = store.entries;

    // Three ways out of selection mode, and this is the one for the system back
    // gesture: swallow the pop and drop the selection instead of leaving the
    // screen, which is what every list with a contextual bar does.
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                // Replaces the back arrow, so the gesture and the button agree
                // on what leaving means while rows are ticked.
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.cancel,
                  onPressed: _clearSelection,
                ),
                title: Text(l10n.selectedCount(_selected.length)),
                actions: [
                  TextButton(
                    onPressed: () => _selectAll(entries),
                    child: Text(l10n.selectAll),
                  ),
                  TextButton(
                    onPressed: _deleteSelected,
                    child: Text(l10n.delete),
                  ),
                ],
              )
            // No actions of its own: emptying the list goes through the
            // selection like every other delete.
            : AppBar(title: Text(l10n.titleActivityShowSaved)),
        body: entries.isEmpty
            ? Center(
                child: Text(
                  l10n.noSaved,
                  style: const TextStyle(color: AppTheme.foreground),
                ),
              )
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _SavedRow(
                    entry: entry,
                    selecting: _selecting,
                    selected: _selected.contains(entry.name),
                    onToggle: () => _toggle(entry.name),
                  );
                },
              ),
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
///
/// The long press is back, on the one job it is good at: starting a selection.
/// Once [selecting], a plain tap ticks a row instead of opening its actions —
/// the sheet acts on one entry, and reaching it mid-selection would mean
/// choosing between two entries the screen has already been told about.
class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.entry,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final SavedEntry entry;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

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
      onTap: selecting ? onToggle : () => _showActions(context),
      onLongPress: onToggle,
      selected: selected,
      // Only while selecting: a checkbox on a row that cannot be ticked would
      // advertise a mode the screen is not in.
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onToggle())
          : null,
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
