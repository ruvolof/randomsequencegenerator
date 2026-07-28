import 'package:flutter/widgets.dart';

/// The single breakpoint the legacy app had: Android's `sw600dp` resource
/// qualifier, which selects on the shortest side so it does not flip when a
/// phone rotates.
abstract final class Breakpoints {
  static const double tabletShortestSide = 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletShortestSide;
}
