import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/die_mesh.dart';
import '../../models/rotation.dart';
import '../../models/toss_kind.dart';
import 'coin_face.dart';
import 'die_3d.dart';

/// The tossed object in motion: a coin flips, a die tumbles.
///
/// Knows nothing about randomness — it is handed a face and how long that face
/// has before the next one, and moves. That split is what lets the outcome
/// stay in a pure-Dart controller a unit test can drive with `fake_async`,
/// while the part that has to run at 60fps stays in the widget layer.
///
/// The switch below is the toss seam. It is **exhaustive with no `default`**,
/// the same discipline `_ModeOptions` uses on the main screen, so a new
/// [TossFamily] does not compile until something exists to draw and move it.
/// It keys off the *family* rather than off [TossKind] deliberately: every die
/// is drawn by one mesh painter, and a new die costs a row in [DieMesh], not an
/// arm here.
class TossView extends StatelessWidget {
  const TossView({
    required this.kind,
    required this.face,
    required this.faceDuration,
    this.settling = false,
    this.onTap,
    super.key,
  });

  final TossKind kind;
  final int face;

  /// How long this face has before the next one arrives. The motion towards it
  /// takes exactly this long, so the object is still moving when the next face
  /// lands and the toss reads as one continuous motion rather than as a
  /// sequence of separate turns.
  final Duration faceDuration;

  /// Whether [face] is where the toss ends. A die eases into its last face and
  /// overshoots a little, rather than stopping dead at full speed.
  final bool settling;

  /// Tapping the object itself tosses it. Null while a toss is running, which
  /// is also what disables the button below.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Outside the motion, so the tap target stays the whole square however
      // far through a turn the object happens to be.
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: switch (kind.family) {
        TossFamily.coin => _Flip(face: face, faceDuration: faceDuration),
        TossFamily.die => _Roll(
          // A new die is a new solid: start it at rest rather than tumbling
          // from the orientation of the old one.
          key: ValueKey(kind),
          kind: kind,
          face: face,
          faceDuration: faceDuration,
          settling: settling,
        ),
      },
    );
  }
}

/// The coin: one half-turn about the horizontal axis every time [face]
/// changes.
class _Flip extends StatefulWidget {
  const _Flip({required this.face, required this.faceDuration});

  final int face;
  final Duration faceDuration;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.faceDuration,
  );

  /// The two faces of the turn in progress: the one rotating away and the one
  /// arriving. Equal while nothing is moving.
  late int _outgoing = widget.face;
  late int _incoming = widget.face;

  @override
  void didUpdateWidget(_Flip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.face != oldWidget.face) {
      _outgoing = oldWidget.face;
      _incoming = widget.face;
      _turn.duration = widget.faceDuration;
      _turn.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) {
        final t = _turn.value;
        // The coin is edge-on at the halfway point, which is exactly where the
        // face swaps. The second half restarts from -90° rather than
        // continuing past +90°, so the arriving face is always seen from the
        // front and never needs un-mirroring.
        final angle = t < 0.5 ? pi * t : pi * t - pi;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            // A little perspective, or the turn is an affine squash rather
            // than something rotating in space.
            ..setEntry(3, 2, 0.0012)
            ..rotateX(angle),
          child: CoinFace(face: t < 0.5 ? _outgoing : _incoming),
        );
      },
    );
  }
}

/// A die: every time [face] changes it turns, the short way round, to the
/// orientation in which that face is the one you read.
///
/// That is the whole roll. The controller's faces are drawn at random, so each
/// turn is about a new axis, and they come faster at the start and slower at
/// the end, so the die tumbles, slows, and settles — with no physics, and with
/// no change to `TossController`.
class _Roll extends StatefulWidget {
  const _Roll({
    required this.kind,
    required this.face,
    required this.faceDuration,
    required this.settling,
    super.key,
  });

  final TossKind kind;
  final int face;
  final Duration faceDuration;
  final bool settling;

  @override
  State<_Roll> createState() => _RollState();
}

class _RollState extends State<_Roll> with SingleTickerProviderStateMixin {
  late final DieMesh _mesh = DieMesh.of(widget.kind);

  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.faceDuration,
    // At rest until the first face change.
    value: 1,
  );

  late Rotation _from = _mesh.restingOrientation(widget.face);
  late Rotation _to = _from;
  Curve _curve = Curves.linear;

  /// Where the die is right now, which is not necessarily where the last turn
  /// was going: the next face can arrive before a turn completes.
  Rotation get _current => _from.slerp(_to, _curve.transform(_turn.value));

  @override
  void didUpdateWidget(_Roll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.face != oldWidget.face) {
      // From wherever it is, not from where it was headed, or an unfinished
      // turn would jump.
      _from = _current;
      _to = _mesh.restingOrientation(widget.face);
      // Mid-roll the turns run at an even speed, so one flows into the next.
      // The last one decelerates and overshoots, which is what makes it read
      // as the die coming to rest rather than being stopped.
      _curve = widget.settling ? Curves.easeOutBack : Curves.linear;
      _turn.duration = widget.faceDuration;
      _turn.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) =>
          Die3D(kind: widget.kind, face: widget.face, orientation: _current),
    );
  }
}
