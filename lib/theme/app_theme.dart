import 'package:flutter/material.dart';

/// The Holo-era palette the legacy app used, rebuilt on Material 3.
///
/// Seeding alone never lands on `#333333` — it produces `#141218`-ish tonal
/// surfaces — so the neutral roles are overridden explicitly.
abstract final class AppTheme {
  /// Background of every screen. The legacy `colors.xml` value.
  static const Color background = Color(0xFF333333);

  /// Foreground of every screen. The legacy `colors.xml` value.
  static const Color foreground = Color(0xFFFFFFFF);

  /// The Holo accent the original inherited from `Theme.Holo`.
  static const Color holoAccent = Color(0xFF33B5E5);

  /// Fill of a destructive button. Pinned like the rest of the palette rather
  /// than taken from `colorScheme.error`, which the dark seed resolves to a
  /// pale pink that does not read as a warning next to the accent.
  static const Color danger = Color(0xFFC62828);

  static const Color _surfaceContainerLowest = Color(0xFF262626);
  static const Color _surfaceContainerLow = Color(0xFF2B2B2B);
  static const Color _surfaceContainer = Color(0xFF333333);
  static const Color _surfaceContainerHigh = Color(0xFF3A3A3A);
  static const Color _surfaceContainerHighest = Color(0xFF404040);
  static const Color _onSurfaceVariant = Color(0xFFCCCCCC);
  static const Color _outline = Color(0xFF8A8A8A);

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: holoAccent,
        brightness: Brightness.dark,
      ).copyWith(
        surface: background,
        onSurface: foreground,
        surfaceContainerLowest: _surfaceContainerLowest,
        surfaceContainerLow: _surfaceContainerLow,
        surfaceContainer: _surfaceContainer,
        surfaceContainerHigh: _surfaceContainerHigh,
        surfaceContainerHighest: _surfaceContainerHighest,
        onSurfaceVariant: _onSurfaceVariant,
        outline: _outline,
      );

  static ThemeData build() {
    final scheme = colorScheme;
    final textTheme = Typography.whiteMountainView;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        // Without these the app bar tints lighter as content scrolls under it.
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      // M3 tints dialog and menu surfaces from the seed unless they are pinned.
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: foreground),
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: foreground),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyLarge?.copyWith(color: foreground),
      ),
      // The saved list's actions sheet, pinned for the same reason the dialog
      // and the menu above are, and to the same surface: it is the menu the
      // long press used to open, in a place a tap can reach.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        // The M3 affordance saying the sheet can be swiped away — worth having
        // when the only other way out is a tap on the scrim.
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: foreground),
        behavior: SnackBarBehavior.floating,
      ),
      // The generation mode chips. M3 would colour them from the seeded tonal
      // palette, which does not belong to the pinned #333333 ramp, so every
      // role is set explicitly — as the checkboxes below already are.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: holoAccent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
        shape: const StadiumBorder(),
        // ChoiceChip takes its selected label from secondaryLabelStyle. Leaving
        // it to inherit gives white on #33B5E5, which is about 2.3:1; the dark
        // label below is 5.5:1.
        labelStyle: textTheme.labelLarge?.copyWith(color: foreground),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: background),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide.none
              : const BorderSide(color: _outline),
        ),
        // The fill already carries the selection, and the checkmark costs width
        // in a row of six chips.
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          // An unchecked M3 checkbox draws only its outline in `fillColor`;
          // a checked one fills the whole box, which then needs a dark glyph.
          if (states.contains(WidgetState.selected)) return holoAccent;
          return Colors.transparent;
        }),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? _outline
                : foreground,
            width: 2,
          ),
        ),
        checkColor: WidgetStatePropertyAll(background),
        // Keeps three checkboxes across on a phone.
        visualDensity: VisualDensity.compact,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: _outline),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _outline),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: holoAccent, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: foreground,
        iconColor: foreground,
        // A selected row in the saved list. The tint carries the selection, so
        // the label stays white: M3's default `selectedColor` is `primary`,
        // which would paint it the same accent as the wash behind it.
        selectedColor: foreground,
        selectedTileColor: holoAccent.withValues(alpha: 0.16),
      ),
      iconTheme: const IconThemeData(color: foreground),
      dividerTheme: const DividerThemeData(color: _outline),
    );
  }
}
