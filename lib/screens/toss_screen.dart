import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/toss_label.dart';
import '../models/app_section.dart';
import '../models/toss_kind.dart';
import '../services/toss_controller.dart';
import '../theme/breakpoints.dart';
import '../theme/dimens.dart';
import '../widgets/section_menu.dart';
import '../widgets/toss/die_selector.dart';
import '../widgets/toss/toss_tally.dart';
import '../widgets/toss/toss_view.dart';

/// Tosses one object and shows how it landed: the coin, or one of six dice.
///
/// Parameterised by [TossKind] rather than being a screen per object, so a new
/// one is an enum value and a face rather than a second screen. Within the die
/// family the picker on the screen moves between them; the section menu in the
/// app bar is what moves between families.
class TossScreen extends StatefulWidget {
  const TossScreen({this.kind = TossKind.coin, this.controller, super.key});

  /// What the screen opens on. The dice section can move off it from there,
  /// which is why the state below owns the current kind rather than reading
  /// this directly.
  final TossKind kind;

  /// Injectable so a widget test can make the toss deterministic. When null
  /// the screen owns and disposes its own controller.
  final TossController? controller;

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> {
  late TossKind _kind = widget.kind;
  late TossController _controller =
      widget.controller ?? TossController(faces: _kind.faces);
  late bool _ownsController = widget.controller == null;

  /// Switching die replaces the controller, because a [TossController] is built
  /// around a fixed face count.
  ///
  /// The session tally goes with it, which is right rather than unfortunate: a
  /// d20's counts are not a d6's, and there is no honest way to carry them over.
  void _selectKind(TossKind kind) {
    if (kind == _kind) return;
    setState(() {
      if (_ownsController) _controller.dispose();
      _kind = kind;
      _controller = TossController(faces: kind.faces);
      // The screen owns the replacement even when the first one was injected —
      // a test hands in one controller, not one per die.
      _ownsController = true;
    });
  }

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
        ? Dimens.tossMaxSizeTablet
        : Dimens.tossMaxSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleActivityRsgMain),
        actions: [SectionMenu(current: AppSection.forKind(_kind))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.mainPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Above the centred group rather than inside it, so choosing a
              // die does not move the die. Only the dice have siblings to pick
              // between; a one-option picker is not a picker.
              if (_kind.family == TossFamily.die) ...[
                DieSelector(kind: _kind, onChanged: _selectKind),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The object takes the room it is given, up to the §2.8
                    // cap and up to a little over half the height — the rest
                    // belongs to the caption under it.
                    final size = min(
                      maxDiameter,
                      min(constraints.maxHeight * 0.55, constraints.maxWidth),
                    );

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        // Centres the group when it fits and scrolls it when it
                        // does not, which is the case a d20 makes real: twenty
                        // tally entries and a picker do not fit a landscape
                        // phone at any object size, and the old fixed-height
                        // layout had nowhere to put the excess.
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) {
                            final face = _controller.face;

                            return Column(
                              // The object and its caption are centred as one
                              // group, rather than the object floating with the
                              // caption pinned far below it.
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: size,
                                  height: size,
                                  // Before the first toss the object is on
                                  // screen but dimmed, rather than absent.
                                  // "Tap the coin to flip" needs a coin to be
                                  // tappable at all.
                                  child: Opacity(
                                    opacity: face == null ? 0.45 : 1,
                                    child: TossView(
                                      kind: _kind,
                                      face: face ?? 0,
                                      faceDuration: _controller.faceDuration,
                                      onTap: _controller.isTossing
                                          ? null
                                          : _controller.toss,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // The tally keyed off the *history*, not off
                                // the face: a tally of nothing during the very
                                // first toss would read "0 × 0  1 × 0  0
                                // flips". The hint holds its place instead,
                                // hidden but still measured, so the object does
                                // not resize under the finger that just tapped
                                // it.
                                if (_controller.history.isEmpty)
                                  Opacity(
                                    opacity: _controller.isTossing ? 0 : 1,
                                    child: Text(
                                      _kind.hint(l10n),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                else
                                  // No separate readout of the value: the
                                  // object on screen is the value, three times
                                  // the size any caption would be.
                                  TossTally(
                                    kind: _kind,
                                    history: _controller.history,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
                child: Text(_kind.action(l10n)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
