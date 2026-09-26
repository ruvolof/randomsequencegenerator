import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/rotation.dart';

const double _tolerance = 1e-9;

Matcher closeToVec(Vec3 expected) => predicate<Vec3>(
  (v) => (v - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

void main() {
  const x = Vec3(1, 0, 0);
  const y = Vec3(0, 1, 0);
  const z = Vec3(0, 0, 1);

  group('Rotation', () {
    test('a quarter turn about z carries x onto y — anticlockwise', () {
      final quarter = Rotation.axisAngle(z, pi / 2);

      expect(quarter.apply(x), closeToVec(y));
      expect(quarter.apply(y), closeToVec(-x));
      expect(quarter.apply(z), closeToVec(z));
    });

    test('a * b is b first, then a', () {
      // The convention everything else leans on. The two orders give different
      // answers here, so a flipped product cannot pass.
      final a = Rotation.axisAngle(z, pi / 2);
      final b = Rotation.axisAngle(x, pi / 2);

      expect((a * b).apply(y), closeToVec(a.apply(b.apply(y))));
      expect((a * b).apply(y), isNot(closeToVec(b.apply(a.apply(y)))));
    });

    test('fromBasis carries each vector of the basis onto its axis', () {
      // An arbitrary right-handed basis, well away from the identity so every
      // branch of the matrix conversion is not the trace-positive one.
      final forward = const Vec3(-0.3, -0.5, -0.8).normalized;
      final up = const Vec3(0, 1, 0).cross(forward).cross(forward).normalized;
      final right = up.cross(forward);
      final rotation = Rotation.fromBasis(
        right: right,
        up: up,
        forward: forward,
      );

      expect(rotation.apply(right), closeToVec(x));
      expect(rotation.apply(up), closeToVec(y));
      expect(rotation.apply(forward), closeToVec(z));
    });

    test('fromBasis survives every branch of the conversion', () {
      // Half-turns about each axis zero the trace, forcing each of the three
      // largest-diagonal branches in turn.
      for (final (right, up, forward) in [
        (x, -y, -z),
        (-x, y, -z),
        (-x, -y, z),
      ]) {
        final rotation = Rotation.fromBasis(
          right: right,
          up: up,
          forward: forward,
        );
        expect(rotation.apply(right), closeToVec(x));
        expect(rotation.apply(up), closeToVec(y));
        expect(rotation.apply(forward), closeToVec(z));
      }
    });

    test('slerp runs from one end to the other at an even rate', () {
      final to = Rotation.axisAngle(const Vec3(1, 1, 0), 2);

      expect(Rotation.identity.slerp(to, 0).angleTo(Rotation.identity), 0);
      expect(Rotation.identity.slerp(to, 1).angleTo(to), closeTo(0, 1e-7));
      expect(
        Rotation.identity.slerp(to, 0.25).angleTo(Rotation.identity),
        closeTo(0.5, 1e-9),
      );
    });

    test('slerp takes the short way round', () {
      // 300° one way is 60° the other. A die spinning the long way between
      // two nearby faces would read as a glitch.
      final to = Rotation.axisAngle(z, 300 * pi / 180);
      final halfway = Rotation.identity.slerp(to, 0.5);

      expect(
        halfway.apply(x),
        closeToVec(Rotation.axisAngle(z, -pi / 6).apply(x)),
      );
      // And evenly along it. The midpoint is right by symmetry even with the
      // arc measured wrongly; a quarter of the way is not.
      expect(
        Rotation.identity.slerp(to, 0.25).angleTo(Rotation.identity),
        closeTo(pi / 12, 1e-9),
      );
    });

    test('slerp past one carries on along the arc', () {
      // What lets easeOutBack swing a die past its face and back.
      final to = Rotation.axisAngle(z, 1);

      expect(
        Rotation.identity.slerp(to, 1.1).angleTo(Rotation.identity),
        closeTo(1.1, 1e-9),
      );
    });
  });
}
