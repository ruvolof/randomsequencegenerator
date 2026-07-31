/// The legacy `dimens.xml` values. Flutter logical pixels are dp, so these
/// transfer one for one.
abstract final class Dimens {
  /// Padding around the main screen's scrollable content.
  static const double mainPadding = 15;

  /// Side of the square icon action buttons.
  static const double imgButton = 40;

  /// Width of the Create button, and therefore of the row of action buttons
  /// beneath it.
  static const double createButton = 250;

  /// Font size of a displayed sequence.
  static const double outputText = 30;

  /// Font size of the coin digit, scaled down by a [FittedBox] when it cannot
  /// fit the coin area.
  static const double coinText = 160;

  /// Height of the coin area on a phone.
  static const double coinViewHeight = 280;

  /// Height of the coin area on a `sw600dp` device.
  static const double coinViewHeightTablet = 360;

  /// Gap between the two action buttons on the show sequence screen. Replaces
  /// the legacy 200dp side margins, which pushed them off a narrow phone.
  static const double showSequenceButtonGap = 48;
}
