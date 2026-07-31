import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/saved_entry.dart';
import '../services/text_actions.dart';
import '../state/saved_store_scope.dart';
import '../widgets/confirm_dialog.dart';
import 'show_sequence_screen.dart';

/// The list of saved sequence names.
///
/// The rows come straight from the store's model. Deleting mutates the model
/// and notifies; the legacy version hid a recycled `ListView` row instead, so
/// the entry came back on scroll and an unrelated row vanished (bug 4).
///
/// Stateful for the selection and the filter: which rows are ticked and which
/// are being looked for are this screen's business and nothing else's, so both
/// stay here rather than in the store.
class SavedListScreen extends StatefulWidget {
  const SavedListScreen({super.key});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  /// The selected entries, by name — the identity the store deletes by, and
  /// unique across the list, so an index would only be a weaker version of it.
  final Set<String> _selected = <String>{};

  /// The filter's text. Its own field rather than a `String` beside it, so
  /// there is one copy of the query and the field cannot disagree with it.
  final TextEditingController _search = TextEditingController();

  /// Whether the search field is up. Distinct from having typed something: an
  /// open field with an empty query still filters nothing but owns the app bar.
  bool _searching = false;

  /// One selected row is what puts the screen in selection mode; there is no
  /// separate flag to fall out of step with the set.
  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String name) => setState(() {
    if (!_selected.remove(name)) _selected.add(name);
  });

  /// Ticks every row the filter currently lets through — [entries] is the list
  /// on screen, not the store's. Selecting rows the user cannot see would make
  /// the count in the title, and the confirmation under it, describe entries
  /// that are nowhere on screen.
  void _selectAll(List<SavedEntry> entries) =>
      setState(() => _selected.addAll(entries.map((entry) => entry.name)));

  void _clearSelection() => setState(_selected.clear);

  void _openSearch() => setState(() => _searching = true);

  /// Closes the field *and* drops the query: leaving a filter running behind a
  /// bar that no longer shows it is how a list ends up looking half-empty for
  /// no visible reason.
  void _closeSearch() => setState(() {
    _searching = false;
    _search.clear();
  });

  /// The rows the filter lets through, by case-insensitive substring — the
  /// whole list while the query is empty.
  List<SavedEntry> _matching(List<SavedEntry> entries) {
    final query = _search.text.toLowerCase();
    if (query.isEmpty) return entries;
    return entries
        .where((entry) => entry.name.toLowerCase().contains(query))
        .toList();
  }

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
    final stored = store.entries;
    final entries = _matching(stored);

    // Both modes swallow the system back gesture, so the gesture and the
    // buttons in the bar agree on what leaving means. The selection is checked
    // first because its bar is the one on screen when both are on.
    return PopScope(
      canPop: !_selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selecting) {
          _clearSelection();
        } else {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(l10n, entries)
            : _searching
            ? _searchBar(context, l10n)
            : _plainBar(l10n, stored.isNotEmpty),
        body: entries.isEmpty
            ? Center(
                child: Text(
                  // An empty list and a filter that matches nothing are
                  // different situations: the second one is undone by clearing
                  // the query, and saying "No saved entries" over a list that
                  // has some would be a lie.
                  stored.isEmpty ? l10n.noSaved : l10n.noMatches,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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

  /// The resting bar. Its only action opens the filter, and only once there is
  /// something to filter — a search over an empty list has no answer to give.
  PreferredSizeWidget _plainBar(AppLocalizations l10n, bool hasEntries) =>
      AppBar(
        title: Text(l10n.titleActivityShowSaved),
        // Emptying the list still goes through the selection: nothing here
        // destroys entries the user has not pointed at.
        actions: [
          if (hasEntries)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.search,
              onPressed: _openSearch,
            ),
        ],
      );

  /// The filter. Typing rebuilds the list under it on every keystroke, which is
  /// affordable because the list is already in memory.
  PreferredSizeWidget _searchBar(BuildContext context, AppLocalizations l10n) =>
      AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Flutter's own string, so the exit needs no ARB key of its own.
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _closeSearch,
        ),
        title: TextField(
          controller: _search,
          autofocus: true,
          // A name is not prose, and the list is the only thing being matched.
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          style: Theme.of(context).textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: l10n.search,
            // All three, not just `border`: the app theme sets `enabledBorder`
            // and `focusedBorder`, and those win over `border` — leaving them
            // draws an underline across the app bar.
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        // No clear button in the field: the arrow beside it already empties the
        // query, and a second control doing the same thing is the one that has
        // to earn its place.
      );

  /// The contextual bar, which replaces whichever of the other two is up.
  PreferredSizeWidget _selectionBar(
    AppLocalizations l10n,
    List<SavedEntry> entries,
  ) => AppBar(
    // Replaces the back arrow, so the gesture and the button agree on what
    // leaving means while rows are ticked.
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
      TextButton(onPressed: _deleteSelected, child: Text(l10n.delete)),
    ],
  );
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
