import 'package:flutter/material.dart';

import '../../models/toss_kind.dart';
import 'coin_face.dart';
import 'die_face.dart';

/// Draws one face of whatever is being tossed.
///
/// This file is the seam. The switch is **exhaustive with no `default`**, the
/// same discipline `_ModeOptions` uses on the main screen, so a new
/// [TossFamily] does not compile until something exists to draw it — a family
/// cannot be half-added and silently fall through to a coin.
///
/// It keys off the *family* rather than off [TossKind] deliberately. Over kinds
/// it would be seven arms, six of them identical, and every new die would cost
/// a line here — exactly the boilerplate this seam was built to avoid. The
/// compile gate stays at the granularity that still earns it.
class TossFace extends StatelessWidget {
  const TossFace({required this.kind, required this.face, super.key});

  final TossKind kind;
  final int face;

  @override
  Widget build(BuildContext context) => switch (kind.family) {
    TossFamily.coin => CoinFace(face: face),
    TossFamily.die => DieFace(kind: kind, face: face),
  };
}
