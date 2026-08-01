import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/toss_kind.dart';
import '../../theme/dimens.dart';

/// One face of a die: its silhouette with the rolled value on it.
///
/// Drawn rather than bundled, for the reasons [CoinFace] gives — no APK cost,
/// sharp at any size, and every colour a [ColorScheme] role, so a die follows
/// the theme instead of freezing a palette at export time. It is struck from
/// the same set as the coin on purpose: the same gradient, the same drop
/// shadow, the same inset rim.
///
/// **The shape is the die's silhouette, not its face.** The faces of a d4, a d8
/// and a d20 are all triangles and would be indistinguishable; people recognise
/// dice by their outline, so that is what [DieShape] tabulates.
///
/// Fills whatever square its parent gives it.
class DieFace extends StatelessWidget {
  const DieFace({required this.kind, required this.face, super.key});

  final TossKind kind;

  /// The face index, counted from `0` as `TossController` counts them. What is
  /// printed is [TossKind.valueOf], which is where the die's numbering from one
  /// lives.
  final int face;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = DieShape.of(kind);
    final value = kind.valueOf(face);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Every measurement below is a fraction of the side, so a die looks the
        // same at 120dp in landscape and at 360dp on a tablet.
        final side = constraints.biggest.shortestSide;

        return CustomPaint(
          painter: DieBody(
            shape: shape,
            // Lit from the upper left, off the surface ramp: on #333333 that
            // ramp is all that separates the die from the page.
            fillFrom: scheme.surfaceContainerHighest,
            fillTo: scheme.surfaceContainerLowest,
            rim: scheme.primary.withValues(alpha: 0.55),
            shadow: Colors.black.withValues(alpha: 0.45),
          ),
          child: Transform.translate(
            // A point-up triangle or pentagon carries its visual mass below the
            // circumcentre, so a value centred in the *square* reads high.
            offset: Offset(0, side * shape.contentOffset),
            child: Center(
              child: FractionallySizedBox(
                // How much room the value gets, which is not the same in a
                // triangle as in a hexagon.
                widthFactor: shape.contentFactor,
                heightFactor: shape.contentFactor,
                child: kind == TossKind.d6
                    // The one die everybody pictures with pips rather than a
                    // number.
                    ? CustomPaint(
                        painter: _Pips(count: value, color: scheme.onSurface),
                      )
                    : FittedBox(
                        child: Text(
                          '$value',
                          style: TextStyle(
                            // Scaled down by the FittedBox to whatever the die
                            // actually is, as the coin's digit is.
                            fontSize: Dimens.tossText,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The outline of one die, and how much of the square its value may occupy.
///
/// A table rather than six widgets: adding a d100 is a row here plus a line in
/// [TossKind], which is the promise the toss seam was built to keep.
class DieShape {
  const DieShape({
    required this.sides,
    required this.rotation,
    required this.contentFactor,
    this.contentOffset = 0,
  });

  /// A regular polygon with this many vertices, or `0` for the d10, whose kite
  /// is not regular and is written out in [vertices].
  final int sides;

  /// Angle of the first vertex. Zero points right; `-pi / 2` points up.
  final double rotation;

  /// Side of the centred square the value is drawn in, as a fraction of the
  /// die. A triangle's inscribed area is far smaller than a hexagon's.
  final double contentFactor;

  /// How far below centre that square sits, as a fraction of the die.
  final double contentOffset;

  static DieShape of(TossKind kind) => switch (kind) {
    // Pointing up, the way a d4 comes to rest.
    TossKind.d4 => const DieShape(
      sides: 3,
      rotation: -pi / 2,
      contentFactor: 0.30,
      contentOffset: 0.05,
    ),
    // Edges horizontal: the rounded square everybody pictures. The pip grid is
    // the widest content of any die, so its box sits tightest against the rim —
    // measured, not guessed: at 0.68 the outer pips cross it.
    TossKind.d6 => const DieShape(
      sides: 4,
      rotation: pi / 4,
      contentFactor: 0.58,
    ),
    // The same square on its point — a d8's silhouette.
    TossKind.d8 => const DieShape(
      sides: 4,
      rotation: -pi / 2,
      contentFactor: 0.42,
    ),
    TossKind.d10 => const DieShape(
      sides: 0,
      rotation: 0,
      contentFactor: 0.40,
      contentOffset: -0.04,
    ),
    TossKind.d12 => const DieShape(
      sides: 5,
      rotation: -pi / 2,
      contentFactor: 0.48,
      contentOffset: 0.03,
    ),
    // Flat top and bottom: an icosahedron seen face on.
    TossKind.d20 => const DieShape(sides: 6, rotation: 0, contentFactor: 0.52),
    // Not a die. The switch is exhaustive so this file cannot quietly acquire
    // a shape for something the coin painter draws.
    TossKind.coin => throw ArgumentError.value(kind, 'kind', 'not a die'),
  };

  /// The corners of the outline, on a circle of [radius] about [centre].
  List<Offset> vertices(Offset centre, double radius) {
    if (sides == 0) {
      // The d10's kite: a tall apex, shoulders above the middle, a long taper
      // to the bottom point. Not a regular polygon, so it is written out.
      return [
        centre + Offset(0, -radius),
        centre + Offset(radius * 0.62, -radius * 0.18),
        centre + Offset(0, radius),
        centre + Offset(-radius * 0.62, -radius * 0.18),
      ];
    }
    return [
      for (var i = 0; i < sides; i++)
        centre +
            Offset(
              radius * cos(rotation + i * 2 * pi / sides),
              radius * sin(rotation + i * 2 * pi / sides),
            ),
    ];
  }
}

/// The silhouette: shadow, gradient body, inset rim.
///
/// Public, and its colours are plain fields, so a test can read them back and
/// prove they came from the [ColorScheme] — the guarantee [CoinFace] gets for
/// free from being built out of inspectable [BoxDecoration]s.
class DieBody extends CustomPainter {
  const DieBody({
    required this.shape,
    required this.fillFrom,
    required this.fillTo,
    required this.rim,
    required this.shadow,
  });

  final DieShape shape;
  final Color fillFrom;
  final Color fillTo;
  final Color rim;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = side / 2;
    final corner = side * 0.07;

    final body = _rounded(shape.vertices(centre, radius), corner);

    // The same offset and blur CoinFace's BoxShadow uses — a MaskFilter sigma
    // is half a blur radius.
    canvas.save();
    canvas.translate(0, side * 0.035);
    canvas.drawPath(
      body,
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.04),
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.95,
          colors: [fillFrom, fillTo],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );

    // Inset so it reads as part of the die rather than as a border around it.
    canvas.drawPath(
      _rounded(shape.vertices(centre, radius * 0.86), corner * 0.86),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.012
        ..color = rim,
    );
  }

  /// The polygon through [points] with its corners filleted.
  ///
  /// A quadratic through each vertex rather than a true arc: at this radius the
  /// difference is invisible, and it costs no trigonometry per corner. The
  /// radius is clamped to half the shorter adjacent edge so a sharp apex — the
  /// d4's, the d10's — cannot swallow the edges either side of it.
  static Path _rounded(List<Offset> points, double radius) {
    final path = Path();
    final n = points.length;

    for (var i = 0; i < n; i++) {
      final current = points[i];
      final toPrevious = points[(i - 1 + n) % n] - current;
      final toNext = points[(i + 1) % n] - current;
      final r = min(radius, min(toPrevious.distance, toNext.distance) / 2);

      final start = current + toPrevious / toPrevious.distance * r;
      final end = current + toNext / toNext.distance * r;

      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
    }

    return path..close();
  }

  @override
  bool shouldRepaint(DieBody old) =>
      old.shape != shape ||
      old.fillFrom != fillFrom ||
      old.fillTo != fillTo ||
      old.rim != rim ||
      old.shadow != shadow;
}

/// The d6's pips, on the usual three-by-three grid.
class _Pips extends CustomPainter {
  const _Pips({required this.count, required this.color});

  final int count;
  final Color color;

  /// Where the three grid stops sit inside the content box. Inset rather than
  /// flush, so an outer pip stays inside the rounded square rather than sitting
  /// on its edge.
  static const List<double> _stops = [0.17, 0.5, 0.83];

  /// Which cells of the grid are filled, as (column, row) in `0..2`.
  static const Map<int, List<(int, int)>> _layout = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (0, 1), (0, 2), (2, 0), (2, 1), (2, 2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final paint = Paint()..color = color;

    for (final (column, row) in _layout[count] ?? const <(int, int)>[]) {
      canvas.drawCircle(
        Offset(size.width * _stops[column], size.height * _stops[row]),
        side * 0.13,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Pips old) => old.count != count || old.color != color;
}
