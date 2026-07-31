import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/generation_mode.dart';
import 'package:random_sequence_generator/screens/coin_screen.dart';
import 'package:random_sequence_generator/screens/main_screen.dart';
import 'package:random_sequence_generator/screens/saved_list_screen.dart';
import 'package:random_sequence_generator/services/char_pools.dart';
import 'package:random_sequence_generator/services/saved_store.dart';
import 'package:random_sequence_generator/services/sequence_generator.dart';

import '../support/fake_key_value_store.dart';
import '../support/pump_app.dart';

Widget mainScreen() =>
    MainScreen(generator: SequenceGenerator(random: Random(7)));

/// The generated sequence currently on screen, or null when none is shown.
String? shownResult(WidgetTester tester) {
  final finder = find.byType(SelectableText);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<SelectableText>(finder).data;
}

void main() {
  group('MainScreen', () {
    testWidgets('starts on Binary with both conditional blocks hidden', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      expect(find.text('Binary'), findsOneWidget);
      expect(find.text('Hexadecimal'), findsOneWidget);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('UUID/GUID'), findsOneWidget);

      // None of the mode-specific blocks are present.
      expect(find.text('[0–9]'), findsNothing);
      expect(find.text('abcd078[]'), findsNothing);
      expect(find.text('Hyphens'), findsNothing);

      // The empty-state hint stands in for the result.
      expect(
        find.text('Click menu button to go to saved sequences'),
        findsOneWidget,
      );
    });

    testWidgets('the length field defaults to 32', (tester) async {
      await tester.pumpApp(mainScreen());
      expect(find.widgetWithText(TextField, '32'), findsOneWidget);
    });

    testWidgets('Class reveals the checkboxes and Manual the text field', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      expect(find.text('[0–9]'), findsOneWidget);
      expect(find.text('[a–z]'), findsOneWidget);
      expect(find.text('[A–Z]'), findsOneWidget);
      expect(find.text(r'[$%&()=?@#<>_£[]*]'), findsOneWidget);
      expect(find.text('abcd078[]'), findsNothing);

      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      expect(find.text('[0–9]'), findsNothing);
      expect(find.text('abcd078[]'), findsOneWidget);
    });

    testWidgets('Create yields 32 binary characters and reveals the actions', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      expect(find.byTooltip('Copy'), findsNothing);
      expect(find.byTooltip('Save'), findsNothing);
      expect(find.byTooltip('Send'), findsNothing);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final result = shownResult(tester)!;
      expect(result.length, 32);
      for (final rune in result.runes) {
        expect(CharPools.binary.runes, contains(rune));
      }

      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Save'), findsOneWidget);
      expect(find.byTooltip('Send'), findsOneWidget);
    });

    testWidgets(
      'bug 1 — an unusable length disables Create and shows an error',
      (tester) async {
        await tester.pumpApp(mainScreen());
        // In Binary mode the length field is the only text field on the screen;
        // a widgetWithText finder would go stale as soon as the text changes.
        final field = find.byType(TextField);

        Future<void> enter(String text) async {
          await tester.enterText(field, text);
          await tester.pumpAndSettle();
        }

        const error = 'Enter a number between 1 and 4096';

        // Empty, non-numeric, zero and over the ceiling all fail the same way —
        // the legacy Integer.parseInt crashed on the first two.
        for (final bad in ['', 'abc', '0', '4097']) {
          await enter(bad);
          expect(find.text(error), findsOneWidget, reason: 'input "$bad"');
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Create'),
                )
                .onPressed,
            isNull,
            reason: 'input "$bad"',
          );
        }

        await enter('64');
        expect(find.text(error), findsNothing);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create'),
              )
              .onPressed,
          isNotNull,
        );

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(shownResult(tester)!.length, 64);
      },
    );

    testWidgets('bug 7 — the result and the buttons survive a rotation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpApp(mainScreen());
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final before = shownResult(tester);

      // Landscape.
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();

      expect(shownResult(tester), before);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Save'), findsOneWidget);
      expect(find.byTooltip('Send'), findsOneWidget);
    });

    testWidgets('an empty pool reports it and keeps the buttons hidden', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      // Nothing ticked.
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Select at least one character set'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsNothing);
      expect(shownResult(tester), isNull);
    });

    testWidgets('an empty manual field is treated the same way', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Select at least one character set'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsNothing);
    });

    testWidgets('a generated result hides again when the pool empties', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copy'), findsOneWidget);

      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Copy'), findsNothing);
    });

    testWidgets('Copy puts the sequence on the clipboard', (tester) async {
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

      await tester.pumpApp(mainScreen());
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final result = shownResult(tester);

      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();

      expect(copied, [result]);
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    group('saving', () {
      Future<SavedStore> pumpWithStore(
        WidgetTester tester,
        FakeKeyValueStore backing,
      ) async {
        final store = await tester.pumpApp(
          mainScreen(),
          store: SavedStore(backing),
        );
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        return store;
      }

      Future<void> saveAs(WidgetTester tester, String name) async {
        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, name);
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
      }

      testWidgets('stores the sequence under the entered name', (tester) async {
        final backing = FakeKeyValueStore();
        final store = await pumpWithStore(tester, backing);
        final result = shownResult(tester);

        await saveAs(tester, 'mine');

        expect(store.entries.single.name, 'mine');
        expect(store.entries.single.sequence, result);
        expect(find.text('Saved as "mine"'), findsOneWidget);
        // And it reached the backing store.
        expect(
          jsonDecode(backing.values[SavedStore.storageKey]!),
          hasLength(1),
        );
      });

      testWidgets('stamps the mode that generated the sequence, not the one '
          'selected when Save is pressed', (tester) async {
        final store = await pumpWithStore(tester, FakeKeyValueStore());
        final result = shownResult(tester);

        // The result outlives the radio moving off Binary, so the entry has to
        // remember where it came from.
        await tester.tap(find.text('Hexadecimal'));
        await tester.pumpAndSettle();
        expect(shownResult(tester), result);

        await saveAs(tester, 'mine');

        expect(store.entries.single.sequence, result);
        expect(store.entries.single.mode, GenerationMode.binary);
      });

      testWidgets('bug 8 — a blank name is rejected inside the dialog', (
        tester,
      ) async {
        final store = await pumpWithStore(tester, FakeKeyValueStore());

        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '   ');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        // The dialog is still up and nothing was stored.
        expect(find.text('Enter a name'), findsWidgets);
        expect(store.entries, isEmpty);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
      });

      testWidgets('bug 8 — Cancel on the overwrite dialog keeps the original', (
        tester,
      ) async {
        final store = await pumpWithStore(tester, FakeKeyValueStore());
        await saveAs(tester, 'x');
        final first = store.entries.single.sequence;

        // A second, different sequence under the same name.
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'x');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text('Overwrite?'), findsOneWidget);
        expect(find.text('"x" already exists. Replace it?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(store.entries.single.sequence, first);
      });

      testWidgets('bug 8 — Replace swaps the sequence and keeps one entry', (
        tester,
      ) async {
        final store = await pumpWithStore(tester, FakeKeyValueStore());
        await saveAs(tester, 'x');
        final first = store.entries.single.sequence;

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        final second = shownResult(tester);
        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'x');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Replace'));
        await tester.pumpAndSettle();

        expect(store.entries, hasLength(1));
        expect(store.entries.single.sequence, second);
        expect(store.entries.single.sequence, isNot(first));
      });
    });

    group('UUID mode', () {
      // The canonical rendering, which is what the default checkboxes produce.
      final canonical = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
        r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      Future<void> selectUuid(WidgetTester tester) async {
        await tester.tap(find.text('UUID/GUID'));
        await tester.pumpAndSettle();
      }

      testWidgets('reveals the format checkboxes and hides the length row', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        expect(find.text('Length'), findsOneWidget);

        await selectUuid(tester);

        expect(find.text('Uppercase'), findsOneWidget);
        expect(find.text('Hyphens'), findsOneWidget);
        expect(find.text('Braces'), findsOneWidget);
        expect(find.text('Length'), findsNothing);
        expect(find.byType(TextField), findsNothing);

        // And back again.
        await tester.tap(find.text('Binary'));
        await tester.pumpAndSettle();
        expect(find.text('Uppercase'), findsNothing);
        expect(find.text('Length'), findsOneWidget);
      });

      testWidgets('Create yields a v4 UUID and reveals the actions', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        await selectUuid(tester);

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(shownResult(tester), matches(canonical));
        expect(find.byTooltip('Copy'), findsOneWidget);
        expect(find.byTooltip('Save'), findsOneWidget);
        expect(find.byTooltip('Send'), findsOneWidget);
      });

      testWidgets('the checkboxes change the rendering', (tester) async {
        await tester.pumpApp(mainScreen());
        await selectUuid(tester);

        await tester.tap(find.text('Uppercase'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Braces'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(
          shownResult(tester),
          matches(
            RegExp(
              r'^\{[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-'
              r'[89AB][0-9A-F]{3}-[0-9A-F]{12}\}$',
            ),
          ),
        );

        await tester.tap(find.text('Hyphens'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(shownResult(tester), matches(RegExp(r'^\{[0-9A-F]{32}\}$')));
      });

      testWidgets('an unusable length left behind does not disable Create', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create'),
              )
              .onPressed,
          isNull,
        );

        await selectUuid(tester);

        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(shownResult(tester), matches(canonical));
      });

      testWidgets('a UUID saves like any other sequence', (tester) async {
        final store = await tester.pumpApp(
          mainScreen(),
          store: SavedStore(FakeKeyValueStore()),
        );
        await selectUuid(tester);
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        final result = shownResult(tester);

        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'id');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(store.entries.single.sequence, result);
        expect(store.entries.single.mode, GenerationMode.uuid);
      });
    });

    group('Mask mode', () {
      final plate = RegExp(r'^[A-Z]{2}\d{3}[A-Z]{2}$');

      Future<void> selectMask(WidgetTester tester) async {
        await tester.tap(find.text('Mask'));
        await tester.pumpAndSettle();
      }

      // The mask field is the only TextField on screen in this mode; enter its
      // text and let the screen re-parse.
      Future<void> enterMask(WidgetTester tester, String mask) async {
        await tester.enterText(find.byType(TextField), mask);
        await tester.pumpAndSettle();
      }

      bool createEnabled(WidgetTester tester) =>
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create'),
              )
              .onPressed !=
          null;

      testWidgets('reveals the field and the legend, hides the length row', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        expect(find.text('Length'), findsOneWidget);

        await selectMask(tester);

        expect(find.text('How to write a mask'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Length'), findsNothing);

        await tester.tap(find.text('Binary'));
        await tester.pumpAndSettle();
        expect(find.text('How to write a mask'), findsNothing);
        expect(find.text('Length'), findsOneWidget);
      });

      testWidgets('the legend lists every mask token', (tester) async {
        await tester.pumpApp(mainScreen());
        await selectMask(tester);

        // A drift guard: every pool token the parser understands is documented.
        for (final token in CharPools.maskPools.keys) {
          expect(
            find.text(token),
            findsWidgets,
            reason: 'token $token missing from the legend',
          );
        }
      });

      testWidgets('Create is disabled until a usable mask is typed', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        await selectMask(tester);
        expect(createEnabled(tester), isFalse);

        await enterMask(tester, 'AA###AA');
        expect(createEnabled(tester), isTrue);

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(shownResult(tester), matches(plate));
        expect(find.byTooltip('Copy'), findsOneWidget);
        expect(find.byTooltip('Save'), findsOneWidget);
        expect(find.byTooltip('Send'), findsOneWidget);
      });

      testWidgets('a mask with no placeholder shows the error and blocks '
          'Create', (tester) async {
        await tester.pumpApp(mainScreen());
        await selectMask(tester);

        await enterMask(tester, 'xyz-');
        expect(
          find.text('Add at least one placeholder, like AA###AA'),
          findsOneWidget,
        );
        expect(createEnabled(tester), isFalse);
      });

      testWidgets('a repetition fills the right number of characters', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        await selectMask(tester);

        await enterMask(tester, 'a{5}');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(shownResult(tester), matches(RegExp(r'^[a-z]{5}$')));
      });

      testWidgets('a stale unusable length does not disable Create', (
        tester,
      ) async {
        await tester.pumpApp(mainScreen());
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(createEnabled(tester), isFalse);

        await selectMask(tester);
        await enterMask(tester, 'AA###AA');
        expect(createEnabled(tester), isTrue);
      });

      testWidgets('a mask result saves with the mask mode', (tester) async {
        final store = await tester.pumpApp(
          mainScreen(),
          store: SavedStore(FakeKeyValueStore()),
        );
        await selectMask(tester);
        await enterMask(tester, 'AA###AA');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        final result = shownResult(tester);

        // The legend makes the column taller than the test viewport, so the
        // action row can sit below the fold — scroll it in before tapping.
        await tester.ensureVisible(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        // The save dialog's field is now also on screen; it is the last one.
        await tester.enterText(find.byType(TextField).last, 'plate');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(store.entries.single.sequence, result);
        expect(store.entries.single.mode, GenerationMode.mask);
      });
    });

    testWidgets('the app bar pushes the saved list and the coin screen', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedListScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coin'));
      await tester.pumpAndSettle();
      expect(find.byType(CoinScreen), findsOneWidget);
    });
  });
}
