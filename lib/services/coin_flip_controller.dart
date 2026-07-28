import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Drives the coin animation: the displayed digit alternates `0, 1, 0, 1, …`
/// on a fixed tick, then settles on a value decided up front.
///
/// The legacy `CountDownTimer` captured a `findViewById` and outlived
/// `onDestroy`; this cancels its timer in [dispose] and refuses to notify
/// afterwards.
class CoinFlipController extends ChangeNotifier {
  CoinFlipController({Random? random}) : _random = random ?? Random.secure();

  static const int minFlips = 10;
  static const int maxFlips = 30;
  static const Duration tick = Duration(milliseconds: 200);

  final Random _random;

  Timer? _timer;
  bool _disposed = false;
  int _remainingTicks = 0;
  int? _decided;
  int? _face;

  /// The digit currently displayed, or null before the first flip.
  int? get face => _face;

  bool get isFlipping => _timer != null;

  /// Starts a flip. A no-op while one is already running.
  void flip() {
    if (isFlipping || _disposed) return;

    final flipCount = minFlips + _random.nextInt(maxFlips - minFlips + 1);
    // The outcome is decided up front; the animation only reveals it.
    _decided = _random.nextInt(2);
    _remainingTicks = flipCount;

    // Render the first face immediately rather than after a blank 200ms.
    _face = 0;
    _remainingTicks--;

    if (_remainingTicks == 0) {
      _settle();
      notifyListeners();
      return;
    }

    _timer = Timer.periodic(tick, (_) {
      _face = _face == 0 ? 1 : 0;
      _remainingTicks--;
      if (_remainingTicks == 0) _settle();
      notifyListeners();
    });
    notifyListeners();
  }

  void _settle() {
    _timer?.cancel();
    _timer = null;
    _face = _decided;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
