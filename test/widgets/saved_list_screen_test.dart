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

    testWidgets('the app bar carries no delete action of its own', (
      tester,
    ) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      // "Delete all" is gone for good: emptying the list goes through the
      // selection, so nothing on this screen destroys entries the user has not
      // pointed at.
      expect(find.text('Delete all'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
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

    group('selection', () {
      /// Long-presses [name], which is what puts the screen in selection mode.
      Future<void> select(WidgetTester tester, String name) async {
        await tester.longPress(find.text(name));
        await tester.pumpAndSettle();
      }

      /// The names of the rows currently ticked.
      Iterable<String> selectedNames(WidgetTester tester) => tester
          .widgetList<ListTile>(find.byType(ListTile))
          .where((tile) => tile.selected)
          .map((tile) => (tile.title! as Text).data!);

      testWidgets('a long press selects the row and swaps the app bar', (
        tester,
      ) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        // Nothing about selection is on screen until a row is held.
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('Select all'), findsNothing);

        await select(tester, 'second');

        // The gesture is back, but not the popup menu it used to open.
        expect(find.byType(PopupMenuItem<Object?>), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(selectedNames(tester), ['second']);
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.text('Select all'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
        // The contextual bar replaces the normal one entirely.
        expect(find.text('Saved Sequences'), findsNothing);
        // A checkbox on every row, ticked on the selected one: the affordance
        // saying the other two can join the selection.
        expect(find.byType(Checkbox), findsNWidgets(3));
        expect(
          tester
              .widgetList<Checkbox>(find.byType(Checkbox))
              .map((box) => box.value),
          [false, true, false],
        );
      });

      testWidgets('while selecting, a tap ticks a row instead of opening it', (
        tester,
      ) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        await tester.tap(find.text('third'));
        await tester.pumpAndSettle();

        expect(selectedNames(tester), ['second', 'third']);
        expect(find.text('2 selected'), findsOneWidget);
        // The sheet belongs to one entry; it stays out of the way here.
        expect(find.byType(BottomSheet), findsNothing);
      });

      testWidgets('unticking the last row leaves selection mode', (
        tester,
      ) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        await tester.tap(find.text('second'));
        await tester.pumpAndSettle();

        expect(selectedNames(tester), isEmpty);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('Saved Sequences'), findsOneWidget);
        expect(find.text('Select all'), findsNothing);
      });

      testWidgets('the ✕ drops the selection without leaving the screen', (
        tester,
      ) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(selectedNames(tester), isEmpty);
        expect(find.text('Saved Sequences'), findsOneWidget);
        expect(find.byType(SavedListScreen), findsOneWidget);
      });

      testWidgets('system back drops the selection before the screen', (
        tester,
      ) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        // The PopScope swallows this one...
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(selectedNames(tester), isEmpty);
        expect(find.text('Saved Sequences'), findsOneWidget);
        expect(find.byType(SavedListScreen), findsOneWidget);
      });

      testWidgets('Select all ticks every row', (tester) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();

        expect(selectedNames(tester), ['first', 'second', 'third']);
        expect(find.text('3 selected'), findsOneWidget);
      });

      testWidgets('Select all then Delete empties the list', (tester) async {
        final store = await threeEntries();
        await tester.pumpApp(const SavedListScreen(), store: store);

        // The replacement for the deleted "Delete all": same outcome, three
        // deliberate steps instead of one, and it says how much is going.
        await select(tester, 'second');
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 3 entries?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
        await tester.pumpAndSettle();

        expect(store.entries, isEmpty);
        expect(find.text('No saved entries'), findsOneWidget);
        expect(find.text('Deleted 3 entries'), findsOneWidget);
      });

      testWidgets('the eye still opens an entry mid-selection', (tester) async {
        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        await tester.tap(find.byTooltip('View').first);
        await tester.pumpAndSettle();

        final screen = tester.widget<ShowSequenceScreen>(
          find.byType(ShowSequenceScreen),
        );
        expect(screen.entry.name, 'first');
      });

      testWidgets('Delete removes only the selected rows, after confirming', (
        tester,
      ) async {
        final store = await threeEntries();
        await tester.pumpApp(const SavedListScreen(), store: store);

        await select(tester, 'first');
        await tester.tap(find.text('third'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 2 entries?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
        await tester.pumpAndSettle();

        expect(store.entries.map((e) => e.name), ['second']);
        expect(find.text('Deleted 2 entries'), findsOneWidget);
        // The selection went with the rows, so the normal bar is back.
        expect(find.text('Saved Sequences'), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
      });

      testWidgets('one selected row reads in the singular', (tester) async {
        final store = await threeEntries();
        await tester.pumpApp(const SavedListScreen(), store: store);

        await select(tester, 'second');
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 1 entry?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
        await tester.pumpAndSettle();

        expect(store.entries.map((e) => e.name), ['first', 'third']);
        expect(find.text('Deleted 1 entry'), findsOneWidget);
      });

      testWidgets('Cancel keeps both the entries and the selection', (
        tester,
      ) async {
        final store = await threeEntries();
        await tester.pumpApp(const SavedListScreen(), store: store);

        await select(tester, 'second');
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(store.entries, hasLength(3));
        // Still ticked: a cancelled dialog undoes the delete, not the choosing.
        expect(selectedNames(tester), ['second']);
      });

      testWidgets('a selection delete that cannot be written says so', (
        tester,
      ) async {
        final backing = FakeKeyValueStore();
        final store = await threeEntries(backing);
        await tester.pumpApp(const SavedListScreen(), store: store);
        backing.failWrites = true;

        await select(tester, 'second');
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
        await tester.pumpAndSettle();

        expect(find.text('Deleted 1 entry'), findsNothing);
        expect(find.textContaining('Storage is unavailable'), findsOneWidget);
        expect(store.entries.map((e) => e.name), ['first', 'third']);
      });

      testWidgets('the contextual bar fits a 320dp viewport', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpApp(
          const SavedListScreen(),
          store: await threeEntries(),
        );

        await select(tester, 'second');
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();

        // Three digits' worth of title plus two actions is the widest this bar
        // ever gets, and it has to survive the fat test font.
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.widgetWithText(TextButton, 'Delete')).right,
          lessThanOrEqualTo(320),
        );
      });
    });
  });
}
