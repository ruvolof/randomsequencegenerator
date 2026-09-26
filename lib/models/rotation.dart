import 'dart:math';

/// A point or direction in the die's space: x right, y up, z towards the
/// viewer.
///
/// Written out rather than taken from `vector_math`, whose vectors are mutable.
/// A mesh is built once and shared by every frame of every roll, and a single
/// `normal.normalize()` in a painter would silently corrupt it for the rest of
/// the session. These cannot be changed after they are made.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator -() => Vec3(-x, -y, -z);
  Vec3 operator *(double scale) => Vec3(x * scale, y * scale, z * scale);
  Vec3 operator /(double scale) => Vec3(x / scale, y / scale, z / scale);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  double get length => sqrt(dot(this));

  Vec3 get normalized => this / length;

  /// The angle between two directions, in radians.
  double angleTo(Vec3 other) =>
      acos((dot(other) / (length * other.length)).clamp(-1.0, 1.0));

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// An orientation in space, as a unit quaternion.
///
/// Written out for the reason [Vec3] is, and one more: `vector_math`'s
/// `Quaternion.rotate` conjugates on the opposite side from the textbook, which
/// is exactly the kind of convention that turns a die inside out without
/// failing a single type check. Here `a * b` means "b, then a", as it does for
/// matrices, and [apply] is the textbook `q v q*`.
class Rotation {
  const Rotation._(this.w, this.x, this.y, this.z);

  static const Rotation identity = Rotation._(1, 0, 0, 0);

  /// A turn of [angle] radians about [axis], anticlockwise seen from the tip of
  /// the axis.
  factory Rotation.axisAngle(Vec3 axis, double angle) {
    final unit = axis.normalized;
    final s = sin(angle / 2);
    return Rotation._(cos(angle / 2), unit.x * s, unit.y * s, unit.z * s);
  }

  /// The rotation that carries [right] onto x, [up] onto y and [forward] onto
  /// z. The three must be orthonormal and right-handed.
  ///
  /// That is a matrix whose rows are the three vectors, turned into a
  /// quaternion by the usual branch on the largest diagonal term, so that no
  /// orientation divides by something close to zero.
  factory Rotation.fromBasis({
    required Vec3 right,
    required Vec3 up,
    required Vec3 forward,
  }) {
    final m00 = right.x, m01 = right.y, m02 = right.z;
    final m10 = up.x, m11 = up.y, m12 = up.z;
    final m20 = forward.x, m21 = forward.y, m22 = forward.z;
    final trace = m00 + m11 + m22;

    if (trace > 0) {
      final s = 0.5 / sqrt(trace + 1);
      return Rotation._(
        0.25 / s,
        (m21 - m12) * s,
        (m02 - m20) * s,
        (m10 - m01) * s,
      );
    }
    if (m00 > m11 && m00 > m22) {
      final s = 2 * sqrt(1 + m00 - m11 - m22);
      return Rotation._(
        (m21 - m12) / s,
        0.25 * s,
        (m01 + m10) / s,
        (m02 + m20) / s,
      );
    }
    if (m11 > m22) {
      final s = 2 * sqrt(1 + m11 - m00 - m22);
      return Rotation._(
        (m02 - m20) / s,
        (m01 + m10) / s,
        0.25 * s,
        (m12 + m21) / s,
      );
    }
    final s = 2 * sqrt(1 + m22 - m00 - m11);
    return Rotation._(
      (m10 - m01) / s,
      (m02 + m20) / s,
      (m12 + m21) / s,
      0.25 * s,
    );
  }

  final double w;
  final double x;
  final double y;
  final double z;

  Vec3 get _axis => Vec3(x, y, z);

  /// [v], turned by this rotation.
  Vec3 apply(Vec3 v) {
    // q v q*, expanded: v + 2w(q × v) + 2 q × (q × v).
    final t = _axis.cross(v) * 2;
    return v + t * w + _axis.cross(t);
  }

  /// [other], then this.
  Rotation operator *(Rotation other) {
    final vector = other._axis * w + _axis * other.w + _axis.cross(other._axis);
    return Rotation._(
      w * other.w - _axis.dot(other._axis),
      vector.x,
      vector.y,
      vector.z,
    );
  }

  double _dot(Rotation other) =>
      w * other.w + x * other.x + y * other.y + z * other.z;

  /// The orientation a fraction [t] of the way from this one to [to], along
  /// the shorter way round.
  ///
  /// A [t] a little past one carries on along the same arc, which is what lets
  /// an overshooting curve swing a die past its resting face and back.
  Rotation slerp(Rotation to, double t) {
    var dot = _dot(to);
    // q and -q are the same orientation; taking the one on this side of the
    // sphere is what makes the path the short one.
    var target = to;
    if (dot < 0) {
      dot = -dot;
      target = Rotation._(-to.w, -to.x, -to.y, -to.z);
    }

    final double a;
    final double b;
    if (dot > 0.9995) {
      // Nearly the same orientation: sin θ is too small to divide by, and a
      // straight line between them is indistinguishable from the arc.
      a = 1 - t;
      b = t;
    } else {
      final theta = acos(dot);
      a = sin((1 - t) * theta) / sin(theta);
      b = sin(t * theta) / sin(theta);
    }

    final w = this.w * a + target.w * b;
    final x = this.x * a + target.x * b;
    final y = this.y * a + target.y * b;
    final z = this.z * a + target.z * b;
    final length = sqrt(w * w + x * x + y * y + z * z);
    return Rotation._(w / length, x / length, y / length, z / length);
  }

  /// How far apart two orientations are, as the angle of the single turn that
  /// takes one to the other.
  double angleTo(Rotation other) => 2 * acos(_dot(other).abs().clamp(0.0, 1.0));

  @override
  bool operator ==(Object other) =>
      other is Rotation &&
      other.w == w &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(w, x, y, z);

  @override
  String toString() => 'Rotation($w, $x, $y, $z)';
}
