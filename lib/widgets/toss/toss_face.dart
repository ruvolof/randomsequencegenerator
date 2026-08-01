import 'package:flutter/material.dart';

import '../../models/toss_kind.dart';
import 'coin_face.dart';

/// Draws one face of whatever is being tossed.
///
/// This file is the seam. The switch is **exhaustive with no `default`**, the
/// same discipline `_ModeOptions` uses on the main screen, so adding
/// `TossKind.d6` does not compile until a `DieFace` exists to draw it — the
/// die cannot be half-added and silently fall through to a coin.
class TossFace extends StatelessWidget {
  const TossFace({required this.kind, required this.face, super.key});

  final TossKind kind;
  final int face;

  @override
  Widget build(BuildContext context) => switch (kind) {
    TossKind.coin => CoinFace(face: face),
  };
}
