import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Drives the toss of an object with [faces] equally likely faces: the face on
/// screen changes on a decelerating tick, each one drawn at random from the
/// faces other than the one it replaces, until it settles on a value decided up
/// front.
///
/// Takes a plain `int` rather than a `TossKind` on purpose. Nothing here knows
/// what is being tossed, which is what lets every die share it.
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
    // Starts from where the object lies, not from face 0: a die that snapped
    // back to a 1 before every roll would announce the toss before it began.
    _face ??= 0;
    _scheduleNext();
    notifyListeners();
  }

  void _scheduleNext() {
    _timer = Timer(_delayBefore(_shown + 1), () {
      _shown++;
      if (_shown == _total - 1) {
        _settle();
      } else {
        _face = _drawFace(
          exclude: {
            // Never the face already up, or the object would look stuck.
            _face!,
            // On the last turn before it settles, not the value it is about to
            // settle on either, or that final change would be invisible.
            // Skipped on a two-faced object, where excluding both leaves
            // nothing — and where there is no sequence to give away anyway.
            if (faces > 2 && _shown == _total - 2) _decided!,
          },
        );
        _scheduleNext();
      }
      notifyListeners();
    });
  }

  /// A face drawn uniformly from those not in [exclude].
  ///
  /// The faces between the start of a toss and its result are **drawn, not
  /// stepped**. `(face + 1) % faces` is invisible on a coin — it is exactly the
  /// legacy `0, 1, 0, 1 …` — but on a d20 it reads as a counter running up to
  /// an answer rather than as a die tumbling. At `faces: 2` there is only ever
  /// one legal choice, so that alternation is preserved by construction.
  int _drawFace({required Set<int> exclude}) {
    // Walks the allowed faces rather than re-drawing until one is legal, so the
    // draw is uniform and takes a bounded number of steps. `faces` is at most a
    // couple of dozen, so the walk costs nothing.
    var pick = _random.nextInt(faces - exclude.length);
    for (var face = 0; face < faces; face++) {
      if (exclude.contains(face)) continue;
      if (pick == 0) return face;
      pick--;
    }
    // Unreachable: `exclude` never holds every face — it has at most two
    // entries and this is only called when `faces` is at least two, with the
    // second entry added only above that.
    throw StateError('no face left to draw');
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
