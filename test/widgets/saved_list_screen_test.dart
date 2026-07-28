import 'package:flutter/material.dart';
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
Future<SavedStore> threeEntries() async {
  final store = SavedStore(FakeKeyValueStore());
  await store.upsert(entry('first', '111', 100));
  await store.upsert(entry('second', '222', 200));
  await store.upsert(entry('third', '333', 300));
  return store;
}

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

    testWidgets('tapping a row opens it with that entry', (tester) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await tester.tap(find.text('second'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ShowSequenceScreen>(
        find.byType(ShowSequenceScreen),
      );
      expect(screen.entry.name, 'second');
      expect(screen.entry.sequence, '222');
    });

    testWidgets(
      'bug 4 — deleting the middle row leaves the other two correctly labelled',
      (tester) async {
        final store = await threeEntries();
        await tester.pumpApp(const SavedListScreen(), store: store);

        await tester.longPress(find.text('second'));
        await tester.pumpAndSettle();
        expect(find.text('Delete'), findsOneWidget);

        await tester.tap(find.text('Delete'));
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

    testWidgets('the long-press menu offers Delete, Copy and Send', (
      tester,
    ) async {
      await tester.pumpApp(
        const SavedListScreen(),
        store: await threeEntries(),
      );

      await tester.longPress(find.text('first'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
    });

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
