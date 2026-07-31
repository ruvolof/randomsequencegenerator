import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/generation_mode.dart';
import 'package:random_sequence_generator/models/saved_entry.dart';
import 'package:random_sequence_generator/screens/saved_list_screen.dart';
import 'package:random_sequence_generator/screens/show_sequence_screen.dart';
import 'package:random_sequence_generator/services/saved_store.dart';

import '../support/fake_key_value_store.dart';
import '../support/pump_app.dart';

SavedEntry entry(String name, String sequence, int millis) => SavedEntry(
  name: name,
  sequence: sequence,
  createdAt: DateTime.fromMillisecondsSinceEpoch(millis),
  mode: GenerationMode.binary,
);

/// A store already holding first, second and third, in that order.
Future<SavedStore> threeEntries([FakeKeyValueStore? backing]) async {
  final store = SavedStore(backing ?? FakeKeyValueStore());
  await store.upsert(entry('first', '111', 100));
  await store.upsert(entry('second', '222', 200));
  await store.upsert(entry('third', '333', 300));
  return store;
}

/// Taps the row named [name] and settles its actions sheet.
Future<void> openSheet(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// The sheet's row for [action], distinct from the list row of the same name
/// underneath it.
Finder sheetAction(String action) => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.widgetWithText(ListTile, action),
);

void main() {
  group('SavedListScreen', () {
    testWidgets('an empty list shows the empty state', (tester) async {
      await tester.pumpApp(const SavedListScreen());

      expect(find.text('No saved entries'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('lists the saved names in store order', (tester) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      expect(find.text('No saved entries'), findsNothing);
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title! as Text).data),
        ['first', 'second', 'third'],
      );
    });

    testWidgets("the eye button opens that row's entry", (tester) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await tester.tap(find.byTooltip('View').at(1));
      await tester.pumpAndSettle();

      final screen = tester.widget<ShowSequenceScreen>(
        find.byType(ShowSequenceScreen),
      );
      expect(screen.entry.name, 'second');
      expect(screen.entry.sequence, '222');
    });

    testWidgets('tapping a row opens the actions, not the entry', (
      tester,
    ) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await openSheet(tester, 'second');

      expect(find.byType(ShowSequenceScreen), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      // The sheet names the entry it acts on, over the row it covers.
      expect(find.text('second'), findsNWidgets(2));
    });

    testWidgets('the sheet offers Copy, Share and Delete, in that order', (
      tester,
    ) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await openSheet(tester, 'first');

      expect(sheetAction('Copy'), findsOneWidget);
      expect(sheetAction('Share'), findsOneWidget);
      expect(sheetAction('Delete'), findsOneWidget);
      // Destructive last, furthest from the header the eye has just been read.
      expect(
        tester.getRect(sheetAction('Copy')).top,
        lessThan(tester.getRect(sheetAction('Share')).top),
      );
      expect(
        tester.getRect(sheetAction('Share')).top,
        lessThan(tester.getRect(sheetAction('Delete')).top),
      );
    });

    testWidgets('a long press no longer opens a popup menu', (tester) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await tester.longPress(find.text('first'));
      await tester.pumpAndSettle();

      // The row has no long-press handler left, so the tap recognizer takes the
      // gesture on release and a long press lands on the same sheet a tap does.
      // Nothing is lost by that; what matters is that the menu is gone.
      expect(find.byType(PopupMenuItem<Object?>), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('Copy puts the stored sequence on the clipboard', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await openSheet(tester, 'second');
      await tester.tap(sheetAction('Copy'));
      await tester.pumpAndSettle();

      expect(copied, ['222']);
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('Cancel on the delete confirmation keeps the entry', (
      tester,
    ) async {
      final store = await threeEntries();
      await tester.pumpApp(const SavedListScreen(), store: store);

      await openSheet(tester, 'second');
      await tester.tap(sheetAction('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "second"?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(store.entries.map((e) => e.name), ['first', 'second', 'third']);
    });

    testWidgets(
      'bug 4 — deleting the middle row leaves the other two correctly labelled',
      (tester) async {
        final store = await threeEntries();
        await tester.pumpApp(const SavedListScreen(), store: store);

        await openSheet(tester, 'second');
        await tester.tap(sheetAction('Delete'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        // The legacy code hid a recycled row: the wrong entry disappeared and
        // the deleted one came back on scroll.
        expect(
          tester
              .widgetList<ListTile>(find.byType(ListTile))
              .map((tile) => (tile.title! as Text).data),
          ['first', 'third'],
        );
        expect(store.entries.map((e) => e.name), ['first', 'third']);
        expect(find.text('Deleted "second"'), findsOneWidget);
      },
    );

    testWidgets('Delete all confirms, then empties the list', (tester) async {
      final store = await threeEntries();
      await tester.pumpApp(const SavedListScreen(), store: store);

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);

      await tester.tap(find.text('Yes, delete them!'));
      await tester.pumpAndSettle();

      expect(store.entries, isEmpty);
      expect(find.text('No saved entries'), findsOneWidget);
      expect(find.text('All saved entries deleted'), findsOneWidget);
    });

    testWidgets('a delete that cannot be written says so', (tester) async {
      final backing = FakeKeyValueStore();
      final store = await threeEntries(backing);
      await tester.pumpApp(const SavedListScreen(), store: store);
      backing.failWrites = true;

      await openSheet(tester, 'second');
      await tester.tap(sheetAction('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Deleted "second"'), findsNothing);
      expect(
        find.text(
          'Storage is unavailable — this change will be lost when the app '
          'restarts',
        ),
        findsOneWidget,
      );
      // The row is gone from the list anyway: the message is about the restart,
      // not about the delete having been refused.
      expect(store.entries.map((e) => e.name), ['first', 'third']);
    });

    testWidgets('a Delete all that cannot be written says so', (tester) async {
      final backing = FakeKeyValueStore();
      final store = await threeEntries(backing);
      await tester.pumpApp(const SavedListScreen(), store: store);
      backing.failWrites = true;

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, delete them!'));
      await tester.pumpAndSettle();

      expect(find.text('All saved entries deleted'), findsNothing);
      expect(find.textContaining('Storage is unavailable'), findsOneWidget);
    });

    testWidgets('Cancel on the confirmation keeps every entry', (tester) async {
      final store = await threeEntries();
      await tester.pumpApp(const SavedListScreen(), store: store);

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(store.entries, hasLength(3));
    });

    testWidgets('Delete all on an empty list reports it and shows no dialog', (
      tester,
    ) async {
      await tester.pumpApp(const SavedListScreen());

      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();

      expect(find.text('There are no saved entries.'), findsOneWidget);
      expect(find.text('Are you sure?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
