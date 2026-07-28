import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/coin_flip_controller.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../theme/dimens.dart';

/// The coin flip screen.
class CoinScreen extends StatefulWidget {
  const CoinScreen({this.controller, super.key});

  /// Injectable so a widget test can make the flip deterministic. When null the
  /// screen owns and disposes its own controller.
  final CoinFlipController? controller;

  @override
  State<CoinScreen> createState() => _CoinScreenState();
}

class _CoinScreenState extends State<CoinScreen> {
  late final CoinFlipController _controller =
      widget.controller ?? CoinFlipController();
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
    final height = Breakpoints.isTablet(context)
        ? Dimens.coinViewHeightTablet
        : Dimens.coinViewHeight;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleActivityLaunchCoin)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final face = _controller.face;
          return Column(
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: Center(
                  child: face == null
                      ? Text(
                          l10n.clickOnFlip,
                          style: const TextStyle(
                            fontSize: Dimens.outputText,
                            color: AppTheme.foreground,
                          ),
                        )
                      // Renders giant but can never overflow: the legacy code
                      // fed a px dimension to a sp setter and clipped at
                      // roughly 480sp.
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$face',
                            style: const TextStyle(
                              fontSize: Dimens.coinText,
                              height: 1,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: Dimens.createButton,
                  child: ElevatedButton(
                    // Disabled mid-flip, so a second tap cannot restart it.
                    onPressed: _controller.isFlipping ? null : _controller.flip,
                    child: Text(l10n.flip),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
