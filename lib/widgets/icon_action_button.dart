import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// One of the small square icon buttons the legacy app used for copy, save and
/// share.
///
/// [label] is both the tooltip and the accessibility label — the legacy
/// `ImageButton`s had neither.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Dimens.imgButton,
      height: Dimens.imgButton,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 24,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: Dimens.imgButton,
          height: Dimens.imgButton,
        ),
        tooltip: label,
      ),
    );
  }
}
