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

final SavedEntry testEntry = SavedEntry(
  name: 'mine',
  sequence: '10110100',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
  mode: GenerationMode.binary,
);

void main() {
  group('ShowSequenceScreen', () {
    testWidgets('shows the sequence of the entry it was given', (tester) async {
      await tester.pumpApp(ShowSequenceScreen(entry: testEntry));

      expect(find.text('Show Sequences'), findsOneWidget);
      expect(find.text('10110100'), findsOneWidget);
    });

    testWidgets('heads the name, mode, timestamp and value, in that order', (
      tester,
    ) async {
      await tester.pumpApp(ShowSequenceScreen(entry: testEntry));

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('mine'), findsOneWidget);
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Binary'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Value'), findsOneWidget);

      final tops = [
        'Name',
        'Mode',
        'Saved',
        'Value',
      ].map((heading) => tester.getRect(find.text(heading)).top).toList();
      expect(tops, orderedEquals(<double>[...tops]..sort()));
      // And the sequence is the last thing, under the final heading.
      expect(tops.last, lessThan(tester.getRect(find.text('10110100')).top));
    });

    testWidgets('shows when the entry was saved, date and time', (
      tester,
    ) async {
      // Constructed rather than taken from an epoch offset: this is a local
      // time by construction, so the formatted result does not move with the
      // machine's zone.
      await tester.pumpApp(
        ShowSequenceScreen(
          entry: testEntry.copyWith(createdAt: DateTime(2026, 7, 31, 14, 5)),
        ),
      );

      expect(find.text('Saved'), findsOneWidget);
      // The space before PM is U+202F NARROW NO-BREAK SPACE — what CLDR, and so
      // `intl`, puts there.
      expect(find.text('Jul 31, 2026 at 2:05\u202fPM'), findsOneWidget);
    });

    testWidgets('names the mode the entry was stored with', (tester) async {
      await tester.pumpApp(
        ShowSequenceScreen(
          entry: testEntry.copyWith(mode: GenerationMode.mask),
        ),
      );

      expect(find.text('Mask'), findsOneWidget);
      expect(find.text('Binary'), findsNothing);
    });

    testWidgets('the actions sit under the sequence, with Delete last', (
      tester,
    ) async {
      await tester.pumpApp(ShowSequenceScreen(entry: testEntry));

      final sequence = tester.getRect(find.text('10110100'));
      final copy = tester.getRect(find.byTooltip('Copy'));
      final share = tester.getRect(find.byTooltip('Send'));
      final delete = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Delete'),
      );

      // The same order the main screen puts them in: the result, then the row
      // of actions, then the full-width button.
      expect(copy.top, greaterThan(sequence.bottom));
      expect(copy.center.dy, share.center.dy);
      expect(delete.top, greaterThanOrEqualTo(copy.bottom));
    });

    testWidgets('bug 6 — both buttons stay inside a 320dp viewport', (
      tester,
    ) async {
      // The legacy layout gave them 200dp side margins, so on a narrow phone
      // they were pushed off screen entirely.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(ShowSequenceScreen(entry: testEntry));

      final copy = tester.getRect(find.byTooltip('Copy'));
      final share = tester.getRect(find.byTooltip('Send'));

      expect(copy.left, greaterThanOrEqualTo(0));
      expect(copy.right, lessThanOrEqualTo(320));
      expect(share.left, greaterThanOrEqualTo(0));
      expect(share.right, lessThanOrEqualTo(320));
      // And they do not overlap each other.
      expect(copy.right, lessThan(share.left));
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

      await tester.pumpApp(ShowSequenceScreen(entry: testEntry));
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();

      expect(copied, ['10110100']);
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('a long sequence scrolls rather than overflowing', (
      tester,
    ) async {
      final long = SavedEntry(
        name: 'long',
        sequence: '0' * 4096,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        mode: GenerationMode.binary,
      );
      await tester.pumpApp(ShowSequenceScreen(entry: long));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('Delete', () {
      /// The store the list screen is pumped with, holding [testEntry], with
      /// its row already tapped — so the screen under test sits on a route that
      /// can be popped, as it does in the app.
      Future<SavedStore> openFromList(WidgetTester tester) async {
        final store = fakeStore();
        await store.upsert(testEntry);
        await tester.pumpApp(const SavedListScreen(), store: store);
        await tester.tap(find.text('mine'));
        await tester.pumpAndSettle();
        return store;
      }

      testWidgets('confirming removes the entry and returns to the list', (
        tester,
      ) async {
        final store = await openFromList(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete "mine"?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(store.entries, isEmpty);
        expect(find.byType(ShowSequenceScreen), findsNothing);
        expect(find.text('No saved entries'), findsOneWidget);
        expect(find.text('Deleted "mine"'), findsOneWidget);
      });

      testWidgets('Cancel keeps the entry and the screen', (tester) async {
        final store = await openFromList(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(store.entries, hasLength(1));
        expect(find.byType(ShowSequenceScreen), findsOneWidget);
        expect(find.text('10110100'), findsOneWidget);
      });

      testWidgets('a delete that cannot be written says so', (tester) async {
        final backing = FakeKeyValueStore();
        final store = SavedStore(backing);
        await store.upsert(testEntry);
        await tester.pumpApp(const SavedListScreen(), store: store);
        await tester.tap(find.text('mine'));
        await tester.pumpAndSettle();
        backing.failWrites = true;

        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Deleted "mine"'), findsNothing);
        expect(find.textContaining('Storage is unavailable'), findsOneWidget);
        // Gone from the list anyway: the message is about the restart, not
        // about the delete having been refused.
        expect(store.entries, isEmpty);
      });
    });
  });
}
