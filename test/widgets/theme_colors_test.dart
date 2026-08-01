import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/generation_mode.dart';
import 'package:random_sequence_generator/models/saved_entry.dart';
import 'package:random_sequence_generator/models/toss_kind.dart';
import 'package:random_sequence_generator/screens/saved_list_screen.dart';
import 'package:random_sequence_generator/screens/show_sequence_screen.dart';
import 'package:random_sequence_generator/screens/toss_screen.dart';
import 'package:random_sequence_generator/services/toss_controller.dart';
import 'package:random_sequence_generator/theme/app_theme.dart';
import 'package:random_sequence_generator/widgets/result_display.dart';
import 'package:random_sequence_generator/widgets/toss/coin_face.dart';

import '../support/pump_app.dart';

/// A colour no constant in the app is, so a widget rendering in it can only
/// have read it from the theme it was given.
const Color probe = Color(0xFF00FF7F);

/// The real theme with one role moved. Everything else stays as shipped, so a
/// widget that follows that role is the only thing that moves.
ThemeData themeWithScheme(ColorScheme Function(ColorScheme) move) {
  final base = AppTheme.build();
  return base.copyWith(colorScheme: move(base.colorScheme));
}

ThemeData themeWithOnSurface(Color color) =>
    themeWithScheme((scheme) => scheme.copyWith(onSurface: color));

Color? colorOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.color;

/// The digit struck on the coin, whichever face is being painted.
Finder get coinDigit =>
    find.descendant(of: find.byType(CoinFace), matching: find.byType(Text));

/// [ResultDisplay] is a `SelectableText`, which renders through an
/// `EditableText` rather than a `Text` — this is the style it ends up painting.
Color? selectableColorOf(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).style.color;

void main() {
  // D1: these widgets used to name `AppTheme.foreground` in their own
  // `TextStyle`s. It rendered identically — `onSurface` *is* that colour — so
  // nothing but a theme the constant disagrees with can tell the two apart.
  group('text colours come from the theme', () {
    testWidgets('the result display follows onSurface', (tester) async {
      await tester.pumpApp(
        const ResultDisplay(text: '10110100'),
        theme: themeWithOnSurface(probe),
      );

      expect(selectableColorOf(tester), probe);
    });

    testWidgets('the coin digit follows onSurface', (tester) async {
      final controller = TossController(
        faces: TossKind.coin.faces,
        random: Random(1),
      );
      addTearDown(controller.dispose);
      await tester.pumpApp(
        TossScreen(controller: controller),
        theme: themeWithOnSurface(probe),
      );

      await tester.tap(find.text('Flip'));
      await tester.pump();
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      expect(colorOf(tester, coinDigit), probe);
    });

    testWidgets('the coin hint follows onSurfaceVariant', (tester) async {
      // Not `onSurface`: the hint is a caption under the coin, in the same
      // secondary role every other hint and section label uses.
      await tester.pumpApp(
        TossScreen(controller: TossController(faces: 2, random: Random(1))),
        theme: themeWithScheme(
          (scheme) => scheme.copyWith(onSurfaceVariant: probe),
        ),
      );

      expect(colorOf(tester, find.text('Tap the coin to flip')), probe);
    });

    testWidgets('the coin disc and its rim come from the theme', (
      tester,
    ) async {
      // The reason the coin is drawn rather than bundled: a PNG would have
      // frozen these two colours at export time.
      await tester.pumpApp(
        TossScreen(controller: TossController(faces: 2, random: Random(1))),
        theme: themeWithScheme(
          (scheme) =>
              scheme.copyWith(surfaceContainerHighest: probe, primary: probe),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(CoinFace),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration as BoxDecoration)
          .toList();

      final disc = decorations.firstWhere((d) => d.gradient != null);
      expect((disc.gradient! as RadialGradient).colors.first, probe);

      final rim = decorations.firstWhere((d) => d.border != null);
      expect(rim.border!.top.color, probe.withValues(alpha: 0.55));
    });

    testWidgets('the empty saved list follows onSurface', (tester) async {
      await tester.pumpApp(
        const SavedListScreen(),
        theme: themeWithOnSurface(probe),
      );

      expect(colorOf(tester, find.text('No saved entries')), probe);
    });

    testWidgets('a saved entry detail line follows onSurface', (tester) async {
      await tester.pumpApp(
        ShowSequenceScreen(
          entry: SavedEntry(
            name: 'mine',
            sequence: '10110100',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
            mode: GenerationMode.binary,
          ),
        ),
        theme: themeWithOnSurface(probe),
      );

      expect(colorOf(tester, find.text('mine')), probe);
    });

    // The one place left reading `AppTheme` for a colour, and deliberately:
    // `danger` is not a `colorScheme` role, so the label on it is the
    // on-colour of that fill and does not move with the surface.
    testWidgets('the delete button keeps its pinned red', (tester) async {
      await tester.pumpApp(
        ShowSequenceScreen(
          entry: SavedEntry(
            name: 'mine',
            sequence: '10110100',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
            mode: GenerationMode.binary,
          ),
        ),
        theme: themeWithOnSurface(probe),
      );

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete'),
      );
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppTheme.danger,
      );
    });
  });
}
