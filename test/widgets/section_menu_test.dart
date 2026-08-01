import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/app_section.dart';
import 'package:random_sequence_generator/models/toss_kind.dart';
import 'package:random_sequence_generator/screens/main_screen.dart';
import 'package:random_sequence_generator/screens/toss_screen.dart';
import 'package:random_sequence_generator/services/sequence_generator.dart';
import 'package:random_sequence_generator/widgets/section_menu.dart';

import '../support/pump_app.dart';

Widget mainScreen() =>
    MainScreen(generator: SequenceGenerator(random: Random(7)));

/// Opens the menu in whichever app bar is on screen.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(SectionMenu));
  await tester.pumpAndSettle();
}

/// A menu entry, as opposed to the button's own label — both carry the name of
/// the section you are in.
Finder menuItem(String label) =>
    find.widgetWithText(CheckedPopupMenuItem<AppSection>, label);

Future<void> chooseSection(WidgetTester tester, String label) async {
  await openMenu(tester);
  await tester.tap(menuItem(label));
  await tester.pumpAndSettle();
}

bool isChecked(WidgetTester tester, String label) =>
    tester.widget<CheckedPopupMenuItem<AppSection>>(menuItem(label)).checked;

void main() {
  group('SectionMenu', () {
    testWidgets('the button names the section you are in', (tester) async {
      await tester.pumpApp(mainScreen());

      expect(
        find.descendant(
          of: find.byType(SectionMenu),
          matching: find.text('Strings'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the menu lists every section and checks the current one', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());
      await openMenu(tester);

      // One entry per section, so a new one cannot be added to the enum and
      // left out of the menu.
      expect(
        find.byType(CheckedPopupMenuItem<AppSection>),
        findsNWidgets(AppSection.values.length),
      );
      expect(menuItem('Strings'), findsOneWidget);
      expect(menuItem('Coin'), findsOneWidget);

      expect(isChecked(tester, 'Strings'), isTrue);
      expect(isChecked(tester, 'Coin'), isFalse);
    });

    testWidgets('choosing a toss section pushes it', (tester) async {
      await tester.pumpApp(mainScreen());

      await chooseSection(tester, 'Coin');

      final screen = tester.widget<TossScreen>(find.byType(TossScreen));
      expect(screen.kind, TossKind.coin);
      // Pushed, not replaced: the generator is still under it.
      expect(find.byType(MainScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('choosing Strings from a toss section pops back to it', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());
      await chooseSection(tester, 'Coin');
      expect(find.byType(TossScreen), findsOneWidget);

      await chooseSection(tester, 'Strings');

      expect(find.byType(TossScreen), findsNothing);
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('choosing the section you are already in does nothing', (
      tester,
    ) async {
      await tester.pumpApp(mainScreen());

      await chooseSection(tester, 'Strings');

      // The menu closed and nothing was pushed on top of the generator.
      expect(find.byType(CheckedPopupMenuItem<AppSection>), findsNothing);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(TossScreen), findsNothing);
    });

    testWidgets('the app bar fits a 320dp-wide screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(mainScreen());

      // Saved and the menu share the right-hand side of a narrow bar.
      final menu = tester.getRect(find.byType(SectionMenu));
      expect(menu.right, lessThanOrEqualTo(320));
      expect(menu.left, greaterThanOrEqualTo(0));
      // A 48dp tap target, not just the line of text.
      expect(menu.height, greaterThanOrEqualTo(48));
    });
  });
}
