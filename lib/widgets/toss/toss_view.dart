import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/toss_kind.dart';
import 'toss_face.dart';

/// The tossed object in motion: one half-turn about the horizontal axis every
/// time [face] changes.
///
/// Knows nothing about randomness — it is handed a face and how long that face
/// has before the next one, and turns. That split is what lets the outcome
/// stay in a pure-Dart controller a unit test can drive with `fake_async`,
/// while the part that has to run at 60fps stays in the widget layer.
class TossView extends StatefulWidget {
  const TossView({
    required this.kind,
    required this.face,
    required this.faceDuration,
    this.onTap,
    super.key,
  });

  final TossKind kind;
  final int face;

  /// How long this face has before the next one arrives. The half-turn takes
  /// exactly this long, so the object is still moving when the next face
  /// lands and the toss reads as one continuous motion rather than as a
  /// sequence of separate flips.
  final Duration faceDuration;

  /// Tapping the object itself tosses it. Null while a toss is running, which
  /// is also what disables the button below.
  final VoidCallback? onTap;

  @override
  State<TossView> createState() => _TossViewState();
}

class _TossViewState extends State<TossView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.faceDuration,
  );

  /// The two faces of the turn in progress: the one rotating away and the one
  /// arriving. Equal while nothing is moving.
  late int _outgoing = widget.face;
  late int _incoming = widget.face;

  @override
  void didUpdateWidget(TossView oldWidget) {
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
    return GestureDetector(
      // Outside the Transform, so the tap target stays the whole square
      // however far through a turn the object happens to be.
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final t = _turn.value;
          // The object is edge-on at the halfway point, which is exactly where
          // the face swaps. The second half restarts from -90° rather than
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
            child: TossFace(
              kind: widget.kind,
              face: t < 0.5 ? _outgoing : _incoming,
            ),
          );
        },
      ),
    );
  }
}
