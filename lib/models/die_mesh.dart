import 'dart:math';

import 'rotation.dart';
import 'toss_kind.dart';

/// One face of a [DieMesh]: which corners bound it, where it faces, and how
/// its value is written on it.
class MeshFace {
  const MeshFace({
    required this.corners,
    required this.centre,
    required this.normal,
    required this.up,
    required this.inradius,
  });

  /// Indices into [DieMesh.vertices], anticlockwise seen from outside the die.
  final List<int> corners;

  /// Where the value is centred: the average of the corners.
  final Vec3 centre;

  /// Unit length, pointing out of the die.
  final Vec3 normal;

  /// Unit length, in the plane of the face: the way the top of the value
  /// points.
  final Vec3 up;

  /// The distance from [centre] to the nearest edge — the room there is to
  /// write the value in.
  final double inradius;

  /// Unit length, in the plane of the face: the way the value reads.
  Vec3 get right => up.cross(normal);
}

/// A die as a solid: its corners, its faces, and the orientation in which each
/// face is the one you read.
///
/// **`faces[i]` is the face `TossController` calls `i`**, the same indexing the
/// rest of the toss uses, and what is written on it is still
/// [TossKind.valueOf]. The mesh decides only *where* each face is, and it
/// places them the way real dice are made: opposite faces sum to one more than
/// the face count, so face `i` is opposite face `faces - 1 - i`. The d4, which
/// has no opposite faces, is the exception.
///
/// Built by finding the convex hull of a handful of corners rather than from
/// hand-typed face tables. That makes the d10 honest — if its kites were not
/// flat, the hull would split them into triangles and the face count test
/// would fail — and it means no face can be wound the wrong way round by a
/// typo.
///
/// Pure Dart. Nothing here knows about pixels.
class DieMesh {
  DieMesh._({
    required this.kind,
    required this.vertices,
    required this.faces,
    required this.contentSize,
  });

  /// The die this is the shape of.
  final TossKind kind;

  /// The corners, scaled so the farthest is at distance one from the centre.
  final List<Vec3> vertices;

  /// In `TossController` order: `faces[i]` shows [TossKind.valueOf] `(i)`.
  final List<MeshFace> faces;

  /// Half the side of the square the value is drawn in, as a fraction of the
  /// face's [MeshFace.inradius].
  final double contentSize;

  static final Map<TossKind, DieMesh> _cache = {};

  /// The mesh of [kind], built once and shared.
  static DieMesh of(TossKind kind) => _cache[kind] ??= _build(kind);

  /// The face opposite [face], or null on a die that has none.
  int? opposite(int face) {
    if (kind == TossKind.d4) return null;
    return faces.length - 1 - face;
  }

  /// The orientation in which [face] is the result: square to the viewer and
  /// the right way up.
  ///
  /// **The viewer looks straight down on the die**, so the face turned to the
  /// viewer and the face on top are one and the same — which is how dice are
  /// read. An earlier version leaned the die to show it off as a solid, and a
  /// leaned d6 put a second, brighter face on top of the result, where
  /// everybody's eye went. A d6 or a d4 at rest is one face from above, as it
  /// is on a table; the others still show the ring of faces around their top.
  Rotation restingOrientation(int face) {
    final geometry = faces[face];
    return Rotation.fromBasis(
      right: geometry.right,
      up: geometry.up,
      forward: geometry.normal,
    );
  }

  /// How legible the value on a face should be, from `1` down to `0`, when the
  /// face's normal points [facing] of the way at the viewer — `1` square on,
  /// `0` edge-on.
  ///
  /// Only faces seen nearly edge-on fade: a numeral squashed into a sliver is
  /// noise, not information. Every other face keeps its value, as on a real
  /// die. With the result square to the viewer and on top, the numbers around
  /// it are context and not competition — an earlier version faded them all
  /// out at rest, and a die with one number on it stopped looking like a die.
  static double legibility(double facing) =>
      ((facing - 0.2) / 0.3).clamp(0.0, 1.0);

  static DieMesh _build(TossKind kind) {
    final (points, size) = switch (kind) {
      TossKind.d4 => (_tetrahedron, 0.62),
      TossKind.d6 => (_cube, 0.82),
      TossKind.d8 => (_octahedron, 0.70),
      TossKind.d10 => (_trapezohedron(), 0.62),
      TossKind.d12 => (_dodecahedron, 0.66),
      TossKind.d20 => (_icosahedron, 0.72),
      // Not a die. The switch is exhaustive so the coin cannot quietly acquire
      // a mesh.
      TossKind.coin => throw ArgumentError.value(kind, 'kind', 'not a die'),
    };

    final radius = points.map((p) => p.length).reduce(max);
    final vertices = List<Vec3>.unmodifiable([
      for (final p in points) p / radius,
    ]);
    final hull = _hull(vertices);
    assert(
      hull.length == kind.faces,
      '$kind hull has ${hull.length} faces, not ${kind.faces}',
    );

    return DieMesh._(
      kind: kind,
      vertices: vertices,
      faces: List.unmodifiable(
        _numbered([for (final c in hull) _face(kind, vertices, c)]),
      ),
      contentSize: size,
    );
  }

  /// Every face of the convex hull of [vertices], as corner lists wound
  /// anticlockwise from outside. The solids are centred on the origin.
  ///
  /// A face is any plane through three corners with every other corner behind
  /// it; all the corners on it are the face. Twenty corners is 1140 triples,
  /// done once per die per launch.
  static List<List<int>> _hull(List<Vec3> vertices) {
    const epsilon = 1e-6;
    final seen = <String>{};
    final faces = <List<int>>[];
    final n = vertices.length;

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        for (var k = j + 1; k < n; k++) {
          var normal = (vertices[j] - vertices[i]).cross(
            vertices[k] - vertices[i],
          );
          if (normal.length < epsilon) continue;
          normal = normal.normalized;
          // Outwards: the origin is inside every one of these solids.
          if (normal.dot(vertices[i]) < 0) normal = -normal;
          final offset = normal.dot(vertices[i]);

          final on = <int>[];
          var supporting = true;
          for (var v = 0; v < n; v++) {
            final d = normal.dot(vertices[v]) - offset;
            if (d > epsilon) {
              supporting = false;
              break;
            }
            if (d > -epsilon) on.add(v);
          }
          if (!supporting || !seen.add(on.join(','))) continue;

          faces.add(_wound(vertices, on, normal));
        }
      }
    }
    return faces;
  }

  /// [corners], sorted anticlockwise about [normal] as seen from its tip.
  static List<int> _wound(List<Vec3> vertices, List<int> corners, Vec3 normal) {
    final centre = _average(vertices, corners);
    final a = (vertices[corners.first] - centre).normalized;
    final b = normal.cross(a);
    double angle(int v) {
      final d = vertices[v] - centre;
      return atan2(d.dot(b), d.dot(a));
    }

    return [...corners]..sort((p, q) => angle(p).compareTo(angle(q)));
  }

  static Vec3 _average(List<Vec3> vertices, List<int> corners) =>
      corners.fold(Vec3.zero, (sum, v) => sum + vertices[v]) /
      corners.length.toDouble();

  static MeshFace _face(TossKind kind, List<Vec3> vertices, List<int> corners) {
    final points = [for (final c in corners) vertices[c]];
    final centre = _average(vertices, corners);
    final normal = (points[1] - points[0]).cross(points[2] - points[0]);

    // Which way is up for the value. Towards a corner on a triangle or a
    // pentagon, which puts a point at the top as the old flat silhouettes had
    // it; towards an edge on the d6, so the pips line up with its sides; and
    // along the kite on the d10, towards the long point, as a real d10 is
    // printed.
    final Vec3 towards = switch (kind) {
      TossKind.d6 => (points[0] + points[1]) / 2,
      TossKind.d10 => points.reduce(
        (p, q) => (p - centre).length >= (q - centre).length ? p : q,
      ),
      TossKind.d4 ||
      TossKind.d8 ||
      TossKind.d12 ||
      TossKind.d20 => points.first,
      TossKind.coin => throw ArgumentError.value(kind, 'kind', 'not a die'),
    };

    var inradius = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final edge = (points[(i + 1) % points.length] - a).normalized;
      final d = centre - a;
      inradius = min(inradius, (d - edge * d.dot(edge)).length);
    }

    return MeshFace(
      corners: List.unmodifiable(corners),
      centre: centre,
      normal: normal.normalized,
      up: (towards - centre).normalized,
      inradius: inradius,
    );
  }

  /// [faces], ordered so that faces `i` and `n - 1 - i` are opposite each
  /// other wherever the die has opposite faces.
  ///
  /// The starting order is by height and then by bearing, only so that it is
  /// the same on every launch; no face is meant to be anywhere in particular.
  static List<MeshFace> _numbered(List<MeshFace> faces) {
    double bearing(MeshFace f) => atan2(f.normal.y, f.normal.x);
    final sorted = [...faces]
      ..sort((a, b) {
        final dz = b.normal.z - a.normal.z;
        // Heights within rounding of each other are one height.
        if (dz.abs() > 1e-6) return dz.sign.toInt();
        return bearing(a).compareTo(bearing(b));
      });

    final n = faces.length;
    final ordered = List<MeshFace?>.filled(n, null);
    final placed = <MeshFace>{};
    var next = 0;
    for (final face in sorted) {
      if (placed.contains(face)) continue;
      final opposite = sorted.where(
        (other) => other.normal.dot(face.normal) < -1 + 1e-6,
      );
      if (opposite.isEmpty) {
        // The d4: no opposite faces, so no pairing to honour.
        ordered[next++] = face;
        placed.add(face);
        continue;
      }
      ordered[next] = face;
      ordered[n - 1 - next] = opposite.single;
      placed
        ..add(face)
        ..add(opposite.single);
      next++;
    }
    return ordered.cast<MeshFace>();
  }

  static const double _phi = 1.618033988749895;

  static const List<Vec3> _tetrahedron = [
    Vec3(1, 1, 1),
    Vec3(1, -1, -1),
    Vec3(-1, 1, -1),
    Vec3(-1, -1, 1),
  ];

  static final List<Vec3> _cube = List.unmodifiable([
    for (final x in [-1.0, 1.0])
      for (final y in [-1.0, 1.0])
        for (final z in [-1.0, 1.0]) Vec3(x, y, z),
  ]);

  static const List<Vec3> _octahedron = [
    Vec3(1, 0, 0),
    Vec3(-1, 0, 0),
    Vec3(0, 1, 0),
    Vec3(0, -1, 0),
    Vec3(0, 0, 1),
    Vec3(0, 0, -1),
  ];

  static final List<Vec3> _icosahedron = List.unmodifiable([
    for (final a in [-1.0, 1.0])
      for (final b in [-_phi, _phi]) ...[
        Vec3(0, a, b),
        Vec3(a, b, 0),
        Vec3(b, 0, a),
      ],
  ]);

  static final List<Vec3> _dodecahedron = List.unmodifiable([
    ..._cube,
    for (final a in [-1 / _phi, 1 / _phi])
      for (final b in [-_phi, _phi]) ...[
        Vec3(0, a, b),
        Vec3(a, b, 0),
        Vec3(b, 0, a),
      ],
  ]);

  /// The d10: two points and two staggered rings of five.
  ///
  /// Each kite runs from a point, over two neighbouring corners of the near
  /// ring, to the corner of the far ring between them. For those four to be
  /// flat the rings must sit at `h (1 - cos 36°) / (1 + cos 36°)` either side
  /// of the middle, where `h` is the height of the points: in the half-plane
  /// through the far corner, the point, the midpoint of the near pair and the
  /// far corner then lie on one line.
  static List<Vec3> _trapezohedron() {
    const h = 1.0;
    final c = cos(pi / 5);
    final ring = h * (1 - c) / (1 + c);
    return [
      const Vec3(0, 0, h),
      const Vec3(0, 0, -h),
      for (var i = 0; i < 5; i++) ...[
        Vec3(cos(2 * pi * i / 5), sin(2 * pi * i / 5), ring),
        Vec3(cos(2 * pi * i / 5 + pi / 5), sin(2 * pi * i / 5 + pi / 5), -ring),
      ],
    ];
  }
}
