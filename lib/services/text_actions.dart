import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_localizations.dart';

/// The copy and share actions, shared by the three screens that offer them.
abstract final class TextActions {
  /// Copies [text] to the clipboard and confirms with a SnackBar, matching the
  /// legacy toast.
  static Future<void> copyToClipboard(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).copiedToCb;
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  /// Opens the system share sheet, the equivalent of the legacy
  /// `ACTION_SEND` chooser.
  static Future<void> shareText(BuildContext context, String text) async {
    // Harmless on Android; on iPad it anchors the popover, which saves work in
    // the iOS session.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}
