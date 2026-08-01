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

  /// Font size of the value struck on a tossed object, scaled down by a
  /// [FittedBox] when it cannot fit.
  static const double tossText = 160;

  /// Largest a tossed object is drawn on a phone. The legacy `coin_view_height`
  /// was the fixed height of a coin *area*; it is a maximum diameter now, and
  /// it bounds a die as well as a coin.
  static const double tossMaxSize = 280;

  /// The same, on a `sw600dp` device.
  static const double tossMaxSizeTablet = 360;
}
