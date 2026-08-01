import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/toss_label.dart';
import '../models/toss_kind.dart';
import '../services/toss_controller.dart';
import '../theme/breakpoints.dart';
import '../theme/dimens.dart';
import '../widgets/toss/toss_tally.dart';
import '../widgets/toss/toss_view.dart';

/// Tosses one object and shows how it landed. The coin, today.
///
/// Parameterised by [TossKind] rather than being the coin screen, so a die is
/// a new enum value and a new face rather than a second screen. The picker
/// that would choose between them is deliberately absent while there is only
/// one kind: a one-option picker is not a picker.
class TossScreen extends StatefulWidget {
  const TossScreen({this.kind = TossKind.coin, this.controller, super.key});

  final TossKind kind;

  /// Injectable so a widget test can make the toss deterministic. When null
  /// the screen owns and disposes its own controller.
  final TossController? controller;

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> {
  late final TossController _controller =
      widget.controller ?? TossController(faces: widget.kind.faces);
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    // Cancels the timer. The legacy CountDownTimer captured a findViewById and
    // outlived onDestroy.
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // The legacy 280/360 were the *height of the coin area*, in a column that
    // did not scroll — which overflowed a landscape phone. They are a maximum
    // diameter now: the object takes the room it is given, up to a size past
    // which a coin stops reading as one.
    final maxDiameter = Breakpoints.isTablet(context)
        ? Dimens.coinViewHeightTablet
        : Dimens.coinViewHeight;

    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.title(l10n))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.mainPadding),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final face = _controller.face;

              return SizedBox(
                // The body's width constraint is loose, so without this the
                // Column takes the width of its widest child — the caption —
                // and centres the coin inside *that* rather than on screen.
                width: double.infinity,
                child: Column(
                  // The object and its caption are centred as one group,
                  // rather than the object floating in an Expanded with the
                  // caption pinned far below it.
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxDiameter,
                          maxHeight: maxDiameter,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          // Before the first toss the object is on screen but
                          // dimmed, rather than absent. "Tap the coin to flip"
                          // needs a coin to be tappable at all.
                          child: Opacity(
                            opacity: face == null ? 0.45 : 1,
                            child: TossView(
                              kind: widget.kind,
                              face: face ?? 0,
                              faceDuration: _controller.faceDuration,
                              onTap: _controller.isTossing
                                  ? null
                                  : _controller.toss,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // The tally keyed off the *history*, not off the face: a
                    // tally of nothing during the very first toss would read
                    // "0 × 0  1 × 0  0 flips". The hint holds its place instead,
                    // hidden but still measured, so the coin does not resize
                    // under the finger that just tapped it.
                    if (_controller.history.isEmpty)
                      Opacity(
                        opacity: _controller.isTossing ? 0 : 1,
                        child: Text(
                          l10n.clickOnFlip,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      // No separate readout of the value: the object on screen
                      // is the value, three times the size any caption would be.
                      TossTally(
                        faces: widget.kind.faces,
                        history: _controller.history,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      // The same pinned footer the main screen and Show Sequences use, at the
      // same 250dp: the primary action of every screen in the app is now in
      // the same place, under the thumb.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.mainPadding),
          // heightFactor keeps the bar exactly as tall as the button. Without
          // it Center fills the whole Scaffold and leaves the body no height.
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              width: Dimens.createButton,
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) => ElevatedButton(
                  // Disabled mid-toss, so a second tap cannot restart it.
                  onPressed: _controller.isTossing ? null : _controller.toss,
                  child: child,
                ),
                child: Text(widget.kind.action(l10n)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
