import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/die_mesh.dart';
import '../../models/rotation.dart';
import '../../models/toss_kind.dart';
import '../../theme/dimens.dart';

/// A die drawn as a solid, turned to [orientation].
///
/// Drawn rather than bundled for the reasons [CoinFace] gives — no APK cost,
/// sharp at any size, every colour a [ColorScheme] role — and drawn in plain
/// Dart rather than by a 3D engine because every die is a convex solid of at
/// most twenty faces. On a convex solid the faces turned away from the viewer
/// are exactly the hidden ones, so dropping them is the whole of hidden-surface
/// removal: no depth buffer, no GPU pipeline, and nothing a widget test cannot
/// render.
///
/// [face] is what the die is showing, which is what a screen reader announces.
/// [orientation] is where it is in its tumble; the two agree once it comes to
/// rest.
///
/// Fills whatever square its parent gives it.
class Die3D extends StatefulWidget {
  const Die3D({
    required this.kind,
    required this.face,
    required this.orientation,
    super.key,
  });

  final TossKind kind;

  /// The face index, counted from `0` as `TossController` counts them.
  final int face;

  final Rotation orientation;

  @override
  State<Die3D> createState() => _Die3DState();
}

class _Die3DState extends State<Die3D> {
  /// One laid-out numeral per face, built when the die or the theme changes
  /// and never once per frame: laying out text is the one expensive thing
  /// here, and a roll repaints sixty times a second.
  Map<int, TextPainter> _numerals = const {};
  TossKind? _numeralsKind;
  TextStyle? _numeralsStyle;

  void _ensureNumerals(TextStyle style) {
    if (_numeralsKind == widget.kind && _numeralsStyle == style) return;
    _disposeNumerals();
    _numeralsKind = widget.kind;
    _numeralsStyle = style;
    _numerals = {
      // The one die everybody pictures with pips rather than numbers.
      if (widget.kind != TossKind.d6)
        for (var face = 0; face < widget.kind.faces; face++)
          face: TextPainter(
            text: TextSpan(text: '${widget.kind.valueOf(face)}', style: style),
            textDirection: TextDirection.ltr,
          )..layout(),
    };
  }

  void _disposeNumerals() {
    for (final painter in _numerals.values) {
      painter.dispose();
    }
  }

  @override
  void dispose() {
    _disposeNumerals();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _ensureNumerals(
      DefaultTextStyle.of(context).style.merge(
        TextStyle(
          // Scaled down by the painter to whatever the face actually is, as
          // the coin's digit is by its FittedBox.
          fontSize: Dimens.tossText,
          height: 1,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );

    return Semantics(
      // The painted numeral is invisible to a screen reader, where the Text
      // the flat die used to wear was not. The value is a glyph, like the
      // picker's D20, and reads the same in every locale.
      container: true,
      label: '${widget.kind.valueOf(widget.face)}',
      child: CustomPaint(
        size: Size.infinite,
        painter: DieMeshPainter(
          mesh: DieMesh.of(widget.kind),
          orientation: widget.orientation,
          numerals: _numerals,
          // Lit from the upper left, off the surface ramp: on #333333 that
          // ramp is all that separates the die from the page.
          fillFrom: scheme.surfaceContainerHighest,
          fillTo: scheme.surfaceContainerLowest,
          ink: scheme.onSurface,
          rim: scheme.primary.withValues(alpha: 0.55),
          shadow: Colors.black.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Projects a [DieMesh] and paints it: shadow, shaded faces, edges, and the
/// value on every face that can be seen.
///
/// Public, and its colours are plain fields, so a test can read them back and
/// prove they came from the [ColorScheme].
class DieMeshPainter extends CustomPainter {
  const DieMeshPainter({
    required this.mesh,
    required this.orientation,
    required this.numerals,
    required this.fillFrom,
    required this.fillTo,
    required this.ink,
    required this.rim,
    required this.shadow,
  });

  final DieMesh mesh;
  final Rotation orientation;

  /// Laid out, keyed by face index. Empty on the d6, which wears pips.
  final Map<int, TextPainter> numerals;

  /// The fill of a face turned full to the light, and of one turned away.
  final Color fillFrom;
  final Color fillTo;

  /// The numerals, the pips, and the glint on the faces the light hits.
  final Color ink;

  /// The edges.
  final Color rim;
  final Color shadow;

  /// How far the eye is from the centre of the die, in die radii. Far enough
  /// that the perspective is mild — a die on a table, not a fisheye.
  static const double _eye = 5;

  /// From the upper left, as the flat die's gradient was lit, but mostly from
  /// the viewer: the result faces the viewer, and it should be the brightest
  /// face showing.
  static final Vec3 _light = const Vec3(-0.35, 0.25, 1).normalized;

  /// Where the grid of the d6's pips sits, as fractions of the content box's
  /// half-side, and which cells of it each value fills.
  static const List<double> _pipStops = [-0.68, 0, 0.68];
  static const Map<int, List<(int, int)>> _pipLayout = {
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
    final centre = size.center(Offset.zero);
    // A vertex at radius one never projects further out than about 1.02 radii
    // at this eye distance, so this keeps every orientation inside the square.
    final scale = side / 2 * 0.92;

    Offset project(Vec3 p) {
      final s = _eye / (_eye - p.z) * scale;
      // y is up in the die's space and down on the canvas.
      return centre + Offset(p.x * s, -p.y * s);
    }

    final turned = [for (final v in mesh.vertices) orientation.apply(v)];
    final eye = const Vec3(0, 0, _eye);

    final visible = <int>[];
    for (var i = 0; i < mesh.faces.length; i++) {
      final face = mesh.faces[i];
      final normal = orientation.apply(face.normal);
      // Seen from the eye rather than from infinitely far away, so a face at
      // the rim of a perspective view is kept or dropped correctly.
      final corner = turned[face.corners.first];
      if (normal.dot(eye - corner) > 0) visible.add(i);
    }

    Path outline(MeshFace face) => Path()
      ..addPolygon([for (final c in face.corners) project(turned[c])], true);

    // The visible faces are the silhouette, and the silhouette is the shadow:
    // the same offset and blur the coin and the flat die used.
    final silhouette = Path();
    for (final i in visible) {
      silhouette.addPath(outline(mesh.faces[i]), Offset.zero);
    }
    canvas.drawPath(
      silhouette.shift(Offset(0, side * 0.035)),
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.04),
    );

    final edges = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.008
      ..strokeJoin = StrokeJoin.round
      ..color = rim;

    for (final i in visible) {
      final face = mesh.faces[i];
      final normal = orientation.apply(face.normal);
      final path = outline(face);

      final lambert = max(0.0, normal.dot(_light));
      // The surface ramp is only #262626 to #404040, too narrow on its own for
      // one face to read as turned from the next. Faces turned from the light
      // take on some of the shadow, and faces turned to it a faint glint.
      final base = Color.lerp(fillTo, fillFrom, lambert)!;
      final shaded = Color.alphaBlend(
        shadow.withValues(alpha: shadow.a * (1 - lambert)),
        base,
      );
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(shaded, ink, 0.12 * pow(lambert, 3))!,
      );
      canvas.drawPath(path, edges);

      final opacity = DieMesh.legibility(normal.z);
      if (opacity > 0) {
        _paintValue(canvas, i, face, project, opacity, path.getBounds());
      }
    }
  }

  /// Writes the value of face [index] into the face's plane.
  ///
  /// The face's own two axes are projected, and the canvas is sheared onto
  /// them: that affine map is exact at the centre of the face and off by a
  /// fraction of a pixel at its edge at this eye distance, which is
  /// perspective nobody can see on a numeral.
  void _paintValue(
    Canvas canvas,
    int index,
    MeshFace face,
    Offset Function(Vec3) project,
    double opacity,
    Rect bounds,
  ) {
    final origin = orientation.apply(face.centre);
    final o = project(origin);
    final x = project(origin + orientation.apply(face.right) * face.inradius);
    final y = project(origin - orientation.apply(face.up) * face.inradius);

    if (opacity < 1) {
      // Only a value that is fading needs a layer to fade it through: at rest
      // there are none, and mid-roll one or two.
      canvas.saveLayer(
        bounds,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    } else {
      canvas.save();
    }
    // One unit in each direction is the face's inradius, so a content box of
    // half-side [DieMesh.contentSize] fits inside every face alike.
    canvas.transform(
      Float64List.fromList([
        x.dx - o.dx, x.dy - o.dy, 0, 0, //
        y.dx - o.dx, y.dy - o.dy, 0, 0,
        0, 0, 1, 0,
        o.dx, o.dy, 0, 1,
      ]),
    );

    final box = mesh.contentSize;
    final numeral = numerals[index];
    if (numeral == null) {
      final paint = Paint()..color = ink;
      final count = mesh.kind.valueOf(index);
      for (final (column, row) in _pipLayout[count] ?? const <(int, int)>[]) {
        canvas.drawCircle(
          Offset(_pipStops[column] * box, _pipStops[row] * box),
          box * 0.24,
          paint,
        );
      }
    } else {
      _paintNumeral(canvas, numeral, mesh.kind.valueOf(index), box);
    }
    canvas.restore();
  }

  /// [numeral], centred on the origin and fitted into a square of half-side
  /// [box].
  void _paintNumeral(
    Canvas canvas,
    TextPainter numeral,
    int value,
    double box,
  ) {
    // Once a die has both, a 6 and a 9 are the same glyph turned over; real
    // dice underline them, and so does this.
    final underlined = mesh.kind.faces >= 9 && (value == 6 || value == 9);
    final width = numeral.width;
    final glyph = numeral.height;
    final bar = glyph * 0.08;
    final gap = glyph * 0.04;
    final height = underlined ? glyph + gap + bar : glyph;

    // Fitted into the box, with a little more room across than down: a face
    // is wider than it is tall where a two-digit value sits, and a "20" held
    // to the height of a "7" would read as the smaller number.
    canvas.scale(min(2.4 * box / width, 2 * box / height));
    final top = -height / 2;
    numeral.paint(canvas, Offset(-width / 2, top));
    if (underlined) {
      canvas.drawRect(
        Rect.fromLTWH(-width * 0.3, top + glyph + gap, width * 0.6, bar),
        Paint()..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(DieMeshPainter old) =>
      old.mesh != mesh ||
      old.orientation != orientation ||
      old.numerals != numerals ||
      old.fillFrom != fillFrom ||
      old.fillTo != fillTo ||
      old.ink != ink ||
      old.rim != rim ||
      old.shadow != shadow;
}
