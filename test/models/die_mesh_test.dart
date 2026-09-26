import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/die_mesh.dart';
import 'package:random_sequence_generator/models/toss_kind.dart';

void main() {
  for (final kind in TossKind.dice) {
    group('DieMesh.of($kind)', () {
      final mesh = DieMesh.of(kind);

      test('has one face per face of the die', () {
        expect(mesh.faces, hasLength(kind.faces));
      });

      test('is a closed solid: V - E + F = 2', () {
        final edges = <String>{};
        for (final face in mesh.faces) {
          final c = face.corners;
          for (var i = 0; i < c.length; i++) {
            final a = c[i], b = c[(i + 1) % c.length];
            edges.add(a < b ? '$a-$b' : '$b-$a');
          }
        }
        expect(mesh.vertices.length - edges.length + mesh.faces.length, 2);
      });

      test('every face is flat, and every corner of it is on the hull', () {
        // The d10's kites are only flat for one ring height; this is the test
        // that holds the formula to it.
        for (final face in mesh.faces) {
          for (final c in face.corners) {
            expect(
              (mesh.vertices[c] - face.centre).dot(face.normal),
              closeTo(0, 1e-9),
            );
          }
        }
      });

      test('every face is wound anticlockwise from outside', () {
        // The painter drops faces by their normal; a face wound the wrong way
        // round would vanish exactly when it turned towards the viewer.
        for (final face in mesh.faces) {
          final p = [for (final c in face.corners) mesh.vertices[c]];
          final winding = (p[1] - p[0]).cross(p[2] - p[0]);
          expect(winding.dot(face.normal), greaterThan(0));
          expect(face.centre.dot(face.normal), greaterThan(0));
        }
      });

      test('the value sits inside its face, the right way up', () {
        for (final face in mesh.faces) {
          expect(face.up.dot(face.normal), closeTo(0, 1e-9));
          expect(face.up.length, closeTo(1, 1e-9));
          expect(face.inradius, greaterThan(0));
        }
      });

      if (kind != TossKind.d4) {
        test('opposite faces sum to one more than the face count', () {
          for (var i = 0; i < kind.faces; i++) {
            final opposite = mesh.opposite(i)!;
            expect(
              mesh.faces[i].normal.dot(mesh.faces[opposite].normal),
              closeTo(-1, 1e-9),
            );
            expect(kind.valueOf(i) + kind.valueOf(opposite), kind.faces + 1);
          }
        });
      }

      test('at rest, the face you read is the one turned most towards you', () {
        // The guarantee the lean has to keep: tip a d20 too far and the value
        // on screen is a neighbour's.
        for (var i = 0; i < kind.faces; i++) {
          final rest = mesh.restingOrientation(i);
          final facing = [
            for (final face in mesh.faces) rest.apply(face.normal).z,
          ];
          final best = facing.indexOf(facing.reduce(max));
          expect(best, i, reason: 'resting on face $i');
        }
      });

      test('at rest, the result is square to the viewer and upright', () {
        // Looked at from straight above, so the face turned to the viewer is
        // the face on top. A lean put a d6's top face above its result, and the
        // top face is the one everybody reads.
        for (var i = 0; i < kind.faces; i++) {
          final rest = mesh.restingOrientation(i);
          final normal = rest.apply(mesh.faces[i].normal);
          final up = rest.apply(mesh.faces[i].up);
          expect(normal.z, closeTo(1, 1e-9), reason: 'resting on face $i');
          expect(up.y, closeTo(1, 1e-9), reason: 'resting on face $i');
        }
      });

      test('at rest, the result is fully legible', () {
        for (var i = 0; i < kind.faces; i++) {
          final z = mesh.restingOrientation(i).apply(mesh.faces[i].normal).z;
          expect(DieMesh.legibility(z), 1, reason: 'resting on face $i');
        }
      });
    });
  }

  group('DieMesh.legibility', () {
    test('full square on, gone edge-on, fading between', () {
      expect(DieMesh.legibility(1), 1);
      expect(DieMesh.legibility(0.5), 1);
      expect(DieMesh.legibility(0.35), inExclusiveRange(0, 1));
      expect(DieMesh.legibility(0.1), 0);
      expect(DieMesh.legibility(-1), 0);
    });

    test("a d20's neighbours keep their numbers at rest", () {
      // The faces around the result are context, not competition, once the
      // result is square on top: they stay readable.
      final mesh = DieMesh.of(TossKind.d20);
      final rest = mesh.restingOrientation(0);
      final legible = [
        for (final face in mesh.faces)
          DieMesh.legibility(rest.apply(face.normal).z),
      ].where((l) => l > 0);
      expect(legible.length, greaterThan(1));
    });
  });

  test('the coin has no mesh', () {
    expect(() => DieMesh.of(TossKind.coin), throwsArgumentError);
  });
}
