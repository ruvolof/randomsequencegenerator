import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/generation_mode.dart';
import 'package:random_sequence_generator/models/saved_entry.dart';
import 'package:random_sequence_generator/screens/show_sequence_screen.dart';

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
  });
}
