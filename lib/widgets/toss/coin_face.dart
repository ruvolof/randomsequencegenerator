import 'package:flutter/material.dart';

import '../../theme/dimens.dart';

/// One face of the coin: a struck disc with its value on it.
///
/// Drawn rather than bundled as an image. It costs nothing in the APK, it is
/// sharp at any diameter with no density buckets, and — the reason that
/// decided it — every colour comes from the [ColorScheme], so the coin follows
/// the theme the way D1 asks the whole widget layer to. A PNG would freeze the
/// palette at the moment it was exported.
///
/// Fills whatever square its parent gives it.
class CoinFace extends StatelessWidget {
  const CoinFace({required this.face, super.key});

  /// The digit struck on this side. `0` and `1` rather than heads and tails:
  /// legacy parity, and the right pair for a binary sequence generator whose
  /// launcher icon is `100101`.
  final int face;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Every measurement below is a fraction of the diameter, so the coin
        // looks the same at 120dp in landscape and at 360dp on a tablet.
        final diameter = constraints.biggest.shortestSide;

        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Lit from the upper left, so the disc reads as struck metal
            // rather than as a flat circle. Both stops are surface roles: on
            // #333333 the ramp is all that separates the coin from the page.
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.5),
              radius: 0.95,
              colors: [
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerLowest,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: diameter * 0.08,
                offset: Offset(0, diameter * 0.035),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The milled rim, inset so it reads as part of the coin rather
              // than as a border around a circle.
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.86,
                  heightFactor: 0.86,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.55),
                        width: diameter * 0.012,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 0.5,
                  child: FittedBox(
                    child: Text(
                      '$face',
                      style: TextStyle(
                        // Scaled down by the FittedBox to whatever the coin
                        // actually is; the legacy code fed this number
                        // straight to an sp setter and clipped the glyph.
                        fontSize: Dimens.coinText,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
