import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Drives the toss of an object with [faces] equally likely faces: the face on
/// screen steps `0, 1, … , faces - 1, 0, …` on a decelerating tick, then
/// settles on a value decided up front.
///
/// Takes a plain `int` rather than a `TossKind` on purpose. Nothing here knows
/// what is being tossed, which is what lets a die reuse it unchanged — and what
/// lets a unit test prove that today, at `faces: 6`, before any die exists.
///
/// The legacy `CountDownTimer` captured a `findViewById` and outlived
/// `onDestroy`; this cancels its timer in [dispose] and refuses to notify
/// afterwards.
class TossController extends ChangeNotifier {
  TossController({required this.faces, Random? random})
    : assert(faces >= 2, 'A tossable object needs at least two faces'),
      _random = random ?? Random.secure();

  /// How many faces the object has, indexed `0` to `faces - 1`.
  final int faces;

  /// How many faces a single toss shows, the first one included. Drawn
  /// uniformly from this range, so no two tosses take the same time.
  static const int minTicks = 9;
  static const int maxTicks = 15;

  /// The toss decelerates: the gap between faces grows from [firstTick] to
  /// [lastTick] along an ease-in cubic, so most of it is a blur and only the
  /// last few faces are legible. A flat tick — what the legacy 200ms
  /// `CountDownTimer` did — reads as a flickering value rather than as an
  /// object coming to rest.
  static const Duration firstTick = Duration(milliseconds: 55);
  static const Duration lastTick = Duration(milliseconds: 320);

  final Random _random;
  final List<int> _history = <int>[];

  Timer? _timer;
  bool _disposed = false;

  /// Index of the face on screen, counting from the first of this toss.
  int _shown = 0;
  int _total = 0;
  int? _decided;
  int? _face;

  /// The face currently displayed, or null before the first toss.
  int? get face => _face;

  bool get isTossing => _timer != null;

  /// The settled results of this session, oldest first. In memory only: a run
  /// of coin flips is not something to write to disk.
  late final List<int> history = UnmodifiableListView(_history);

  /// How long the face on screen stays up, and therefore how long the view has
  /// to animate its arrival. It is the gap to the *next* face, so a view that
  /// takes exactly this long is still turning when the next one lands and the
  /// toss reads as one continuous motion.
  Duration get faceDuration =>
      _shown + 1 < _total ? _delayBefore(_shown + 1) : lastTick;

  /// Starts a toss. A no-op while one is already running.
  void toss() {
    if (isTossing || _disposed) return;

    _total = minTicks + _random.nextInt(maxTicks - minTicks + 1);
    // The outcome is decided up front; the animation only reveals it.
    _decided = _random.nextInt(faces);

    // Render the first face immediately rather than after a blank tick. There
    // is always a second one to schedule, because minTicks is well above 1 —
    // the settle-on-the-spot branch this used to carry was unreachable.
    assert(minTicks >= 2);
    _shown = 0;
    _face = 0;
    _scheduleNext();
    notifyListeners();
  }

  void _scheduleNext() {
    _timer = Timer(_delayBefore(_shown + 1), () {
      _shown++;
      if (_shown == _total - 1) {
        _settle();
      } else {
        _face = (_face! + 1) % faces;
        _scheduleNext();
      }
      notifyListeners();
    });
  }

  /// The gap before the face at [index], which is `1` for the first
  /// timer-driven face — index `0` is shown the moment [toss] is called.
  Duration _delayBefore(int index) {
    final span = _total - 2;
    final t = span <= 0 ? 1.0 : (index - 1) / span;
    // Ease-in cubic, written out rather than taken from `Curves` so this stays
    // a service with no Flutter animation import.
    final eased = t * t * t;
    final range = lastTick.inMicroseconds - firstTick.inMicroseconds;
    return Duration(
      microseconds: (firstTick.inMicroseconds + range * eased).round(),
    );
  }

  void _settle() {
    _timer?.cancel();
    _timer = null;
    // The last face is the outcome, not the next step of the cycle.
    _face = _decided;
    _history.add(_decided!);
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
