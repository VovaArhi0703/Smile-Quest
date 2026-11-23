import 'dart:math' as math;

enum BrowPhase { idle, neutral, readyForMax, maximum, ready, tracking, done }

enum EyeCloseStep { open, gentle, strong, reopen }

class BrowSample {
  const BrowSample(
    this.blue,
    this.orange, {
    this.blueSqueeze,
    this.orangeSqueeze,
    this.blueAperture,
    this.orangeAperture,
  });
  BrowSample.fromGaps(
    double blueGap,
    double orangeGap, {
    bool frown = false,
    this.blueSqueeze,
    this.orangeSqueeze,
    this.blueAperture,
    this.orangeAperture,
  }) : blue = frown ? -blueGap : blueGap,
       orange = frown ? -orangeGap : orangeGap;
  final double blue;
  final double orange;
  final double? blueSqueeze;
  final double? orangeSqueeze;
  final double? blueAperture;
  final double? orangeAperture;
}

/// Calibrates both sides separately and counts one full release/lift cycle.
class BrowExerciseLogic {
  BrowExerciseLogic({
    this.softThenStrong = false,
    this.blink = false,
    this.squint = false,
    this.wink = false,
    this.smile = false,
  }) : assert(!softThenStrong || !blink),
       assert(!squint || (!softThenStrong && !blink)),
       assert(!wink || (!softThenStrong && !blink && !squint)),
       assert(!smile || (!softThenStrong && !blink && !squint && !wink));

  final bool softThenStrong;
  final bool blink;
  final bool squint;
  final bool wink;
  final bool smile;
  static const samplesPerCalibration = 7;
  static const targetRepetitions = 10;
  int get goalRepetitions => wink ? 20 : targetRepetitions;
  static const releaseThreshold = 0.35;
  static const liftThreshold = 0.75;
  static const releaseHold = Duration(milliseconds: 250);
  static const liftHold = Duration(milliseconds: 250);
  static const _maxSampleGap = Duration(milliseconds: 750);

  BrowPhase phase = BrowPhase.idle;
  String? error;
  int repetitions = 0;
  BrowSample? current;
  BrowSample? neutral;
  BrowSample? maximum;
  BrowSample? _neutralNoise;
  BrowSample? _squeezeNeutral;
  BrowSample? _squeezeMaximum;
  final List<BrowSample> _samples = [];
  DateTime? _lastSampleAt;
  DateTime? _releaseSince;
  DateTime? _liftSince;
  bool _armed = false;
  bool _softReached = false;
  bool _strongReached = false;
  DateTime? _softSince;
  DateTime? _strongSince;
  bool? _nextWinkBlue;
  bool? _winkSideBlue;

  int get calibrationProgress => _samples.length;
  double get blueProgress =>
      _progress(current?.blue, neutral?.blue, maximum?.blue);
  double get orangeProgress =>
      _progress(current?.orange, neutral?.orange, maximum?.orange);
  double get squeezeProgress => math.min(
    _progress(
      current?.blueSqueeze,
      _squeezeNeutral?.blue,
      _squeezeMaximum?.blue,
    ),
    _progress(
      current?.orangeSqueeze,
      _squeezeNeutral?.orange,
      _squeezeMaximum?.orange,
    ),
  );
  EyeCloseStep get eyeCloseStep {
    if (_strongReached) return EyeCloseStep.reopen;
    if (!_armed) return EyeCloseStep.open;
    if (!_softReached) return EyeCloseStep.gentle;
    return EyeCloseStep.strong;
  }

  void beginNeutral() {
    phase = BrowPhase.neutral;
    error = null;
    repetitions = 0;
    neutral = null;
    maximum = null;
    _neutralNoise = null;
    _squeezeNeutral = null;
    _squeezeMaximum = null;
    _samples.clear();
    _lastSampleAt = null;
    _nextWinkBlue = null;
    _resetCycle();
  }

  void beginMaximum() {
    if (phase != BrowPhase.readyForMax) return;
    phase = BrowPhase.maximum;
    error = null;
    _samples.clear();
    _lastSampleAt = null;
  }

  void beginTracking() {
    if (phase != BrowPhase.ready && phase != BrowPhase.done) return;
    if (phase == BrowPhase.done) {
      repetitions = 0;
      _nextWinkBlue = null;
    }
    phase = BrowPhase.tracking;
    error = null;
    _lastSampleAt = null;
    _resetCycle();
  }

  void pause() {
    if (phase == BrowPhase.tracking) phase = BrowPhase.ready;
    _resetCycle();
  }

  void faceLost() {
    current = null;
    _lastSampleAt = null;
    if (phase == BrowPhase.neutral || phase == BrowPhase.maximum) {
      _samples.clear();
    }
    _resetCycle();
  }

  void add(BrowSample sample, DateTime now) {
    if (!sample.blue.isFinite ||
        !sample.orange.isFinite ||
        (squint && !_validAperturePair(sample)) ||
        (softThenStrong &&
            (sample.blueSqueeze?.isFinite != true ||
                sample.orangeSqueeze?.isFinite != true))) {
      faceLost();
      return;
    }
    final previous = _lastSampleAt;
    if (previous != null) {
      if (!now.isAfter(previous)) return;
      if (now.difference(previous) > _maxSampleGap) faceLost();
    }
    _lastSampleAt = now;
    // The reported center and vertical aperture share the same eye axis.
    // Subtract half the aperture to recover the lower lid's position.
    final observed =
        squint && sample.blueAperture != null
            ? BrowSample(
              sample.blue - sample.blueAperture! / 2,
              sample.orange - sample.orangeAperture! / 2,
              blueAperture: sample.blueAperture,
              orangeAperture: sample.orangeAperture,
            )
            : sample;
    current = observed;
    if (phase == BrowPhase.neutral || phase == BrowPhase.maximum) {
      _samples.add(observed);
      if (_samples.length < samplesPerCalibration) return;
      final blueSamples = _samples.map((e) => e.blue).toList()..sort();
      final orangeSamples = _samples.map((e) => e.orange).toList()..sort();
      if (!_stableCalibration(blueSamples, neutral?.blue) ||
          !_stableCalibration(orangeSamples, neutral?.orange)) {
        _samples.removeAt(0);
        return;
      }
      final haveApertures =
          squint && _samples.every((sample) => sample.blueAperture != null);
      final measured = BrowSample(
        _median(blueSamples),
        _median(orangeSamples),
        blueAperture:
            haveApertures
                ? _median(
                  _samples.map((sample) => sample.blueAperture!).toList(),
                )
                : null,
        orangeAperture:
            haveApertures
                ? _median(
                  _samples.map((sample) => sample.orangeAperture!).toList(),
                )
                : null,
      );
      if (phase == BrowPhase.neutral) {
        neutral = measured;
        _neutralNoise = BrowSample(
          _median(_samples.map((e) => (e.blue - neutral!.blue).abs()).toList()),
          _median(
            _samples.map((e) => (e.orange - neutral!.orange).abs()).toList(),
          ),
        );
        if (softThenStrong) {
          _squeezeNeutral = BrowSample(
            _median(_samples.map((e) => e.blueSqueeze!).toList()),
            _median(_samples.map((e) => e.orangeSqueeze!).toList()),
          );
        }
        phase = BrowPhase.readyForMax;
      } else {
        final candidate = measured;
        final blueRange = candidate.blue - neutral!.blue;
        final orangeRange = candidate.orange - neutral!.orange;
        final blueMinimum = math.max(0.008, 3 * _neutralNoise!.blue);
        final orangeMinimum = math.max(0.008, 3 * _neutralNoise!.orange);
        if (softThenStrong) {
          _squeezeMaximum = BrowSample(
            _median(_samples.map((e) => e.blueSqueeze!).toList()),
            _median(_samples.map((e) => e.orangeSqueeze!).toList()),
          );
        }
        final squeezeMeasurable =
            !softThenStrong ||
            (_squeezeMaximum!.blue - _squeezeNeutral!.blue >= 0.02 &&
                _squeezeMaximum!.orange - _squeezeNeutral!.orange >= 0.02);
        final squintMeasured = !squint || _calibratedSquintAperture(candidate);
        if (blueRange < blueMinimum ||
            orangeRange < orangeMinimum ||
            !squeezeMeasurable ||
            !squintMeasured) {
          phase = BrowPhase.readyForMax;
          error =
              !squeezeMeasurable
                  ? 'Не удалось отличить сильное зажмуривание от обычного закрытия глаз. Повторите калибровку, крепко зажмурив оба глаза.'
                  : !squintMeasured
                  ? 'Подтяните нижние веки, слегка сузив глаза. Оставьте веки разомкнутыми и повторите калибровку.'
                  : smile
                  ? blueRange < blueMinimum && orangeRange < orangeMinimum
                      ? 'Не удалось отличить улыбку от шума. Повторите калибровку.'
                      : blueRange < blueMinimum
                      ? 'Синий уголок рта почти не сдвинулся. Повторите калибровку.'
                      : 'Оранжевый уголок рта почти не сдвинулся. Повторите калибровку.'
                  : squint
                  ? blueRange < blueMinimum && orangeRange < orangeMinimum
                      ? 'Прищур обоих глаз не удалось надёжно отличить от шума. Повторите калибровку.'
                      : blueRange < blueMinimum
                      ? 'Прищур синего глаза не удалось надёжно отличить от шума. Повторите калибровку.'
                      : 'Прищур оранжевого глаза не удалось надёжно отличить от шума. Повторите калибровку.'
                  : (softThenStrong || blink || wink)
                  ? blueRange < blueMinimum && orangeRange < orangeMinimum
                      ? 'Закрытие обоих глаз не удалось надёжно отличить от шума. Повторите калибровку.'
                      : blueRange < blueMinimum
                      ? 'Закрытие синего глаза не удалось надёжно отличить от шума. Повторите калибровку.'
                      : 'Закрытие оранжевого глаза не удалось надёжно отличить от шума. Повторите калибровку.'
                  : blueRange < blueMinimum && orangeRange < orangeMinimum
                  ? 'Движение обеих бровей не удалось надёжно отличить от шума. Повторите калибровку.'
                  : blueRange < blueMinimum
                  ? 'Движение синей брови не удалось надёжно отличить от шума. Повторите калибровку.'
                  : 'Движение оранжевой брови не удалось надёжно отличить от шума. Повторите калибровку.';
          maximum = null;
        } else {
          maximum = candidate;
          error = null;
          phase = BrowPhase.ready;
        }
      }
      _samples.clear();
      return;
    }

    if (phase != BrowPhase.tracking) return;
    final blue = blueProgress;
    final orange = orangeProgress;
    if (softThenStrong) {
      final squeezeBlue = _progress(
        sample.blueSqueeze,
        _squeezeNeutral?.blue,
        _squeezeMaximum?.blue,
      );
      final squeezeOrange = _progress(
        sample.orangeSqueeze,
        _squeezeNeutral?.orange,
        _squeezeMaximum?.orange,
      );
      _addEyeCycle(blue, orange, squeezeBlue, squeezeOrange, now);
      return;
    }
    if (blink) {
      _addBlinkCycle(blue, orange, now);
      return;
    }
    if (squint) {
      _addSquintCycle(blue, orange, now);
      return;
    }
    if (smile) {
      _addSquintCycle(blue, orange, now);
      return;
    }
    if (wink) {
      _addWinkCycle(blue, orange, now);
      return;
    }
    if (_atNeutral(releaseThreshold)) {
      _releaseSince ??= now;
      _liftSince = null;
      if (now.difference(_releaseSince!) >= releaseHold) _armed = true;
    } else if (blue >= liftThreshold && orange >= liftThreshold) {
      _releaseSince = null;
      if (!_armed) return;
      _liftSince ??= now;
      if (now.difference(_liftSince!) >= liftHold) {
        repetitions++;
        _resetCycle();
        if (repetitions >= targetRepetitions) phase = BrowPhase.done;
      }
    } else {
      _releaseSince = null;
      _liftSince = null;
    }
  }

  void _addEyeCycle(
    double blue,
    double orange,
    double squeezeBlue,
    double squeezeOrange,
    DateTime now,
  ) {
    final open = blue <= 0.25 && orange <= 0.25;
    // Gentle closure still closes the eyelids fully. Distinguish it from a
    // forceful squeeze with the separately calibrated under-eye signal.
    final soft =
        blue >= 0.70 &&
        orange >= 0.70 &&
        squeezeBlue <= 0.45 &&
        squeezeOrange <= 0.45;
    final strong =
        blue >= 0.80 &&
        orange >= 0.80 &&
        squeezeBlue >= 0.65 &&
        squeezeOrange >= 0.65;

    if (_strongReached) {
      if (open) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >=
            const Duration(milliseconds: 250)) {
          _rearmFromOpen();
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    if (!_armed) {
      if (open) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >=
            const Duration(milliseconds: 250)) {
          _armed = true;
          _releaseSince = null;
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    if (!_softReached) {
      if (soft) {
        _softSince ??= now;
        if (now.difference(_softSince!) >= const Duration(milliseconds: 250)) {
          _softReached = true;
        }
      } else {
        _softSince = null;
        if (strong) _armed = false;
      }
      return;
    }

    if (strong) {
      _strongSince ??= now;
      if (now.difference(_strongSince!) >= const Duration(milliseconds: 400)) {
        _strongReached = true;
        _releaseSince = null;
        _countPeak();
      }
    } else if (open) {
      _resetCycle();
    } else {
      _strongSince = null;
    }
  }

  void _addBlinkCycle(double blue, double orange, DateTime now) {
    final open = blue <= 0.30 && orange <= 0.30;
    final closed = blue >= 0.70 && orange >= 0.70;

    if (_strongReached) {
      if (open) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >=
            const Duration(milliseconds: 180)) {
          _rearmFromOpen();
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    if (!_armed) {
      if (open) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >=
            const Duration(milliseconds: 250)) {
          _armed = true;
          _releaseSince = null;
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    if (closed) {
      _strongReached = true;
      _countPeak();
    }
  }

  void _addSquintCycle(double blue, double orange, DateTime now) {
    final open =
        _atNeutral(0.30) && (!squint || _atSquintAperture(active: false));
    final narrowed =
        blue >= 0.65 &&
        orange >= 0.65 &&
        (!squint || _atSquintAperture(active: true));

    if (_strongReached) {
      if (open) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >= releaseHold) {
          _rearmFromOpen();
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    if (!_armed) {
      if (open) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >= releaseHold) {
          _armed = true;
          _releaseSince = null;
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    if (narrowed) {
      _liftSince ??= now;
      if (now.difference(_liftSince!) >= const Duration(milliseconds: 300)) {
        _strongReached = true;
        _releaseSince = null;
        _countPeak();
      }
    } else {
      _liftSince = null;
    }
  }

  void _addWinkCycle(double blue, double orange, DateTime now) {
    final bothOpen = blue <= 0.30 && orange <= 0.30;
    final blueOnly = blue >= 0.70 && orange <= 0.30;
    final orangeOnly = orange >= 0.70 && blue <= 0.30;

    if (_strongReached) {
      if (bothOpen) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >=
            const Duration(milliseconds: 180)) {
          _rearmFromOpen();
        }
      } else {
        _releaseSince = null;
        final otherEyeStayedOpen =
            _winkSideBlue == true ? orange <= 0.40 : blue <= 0.40;
        if (!otherEyeStayedOpen) _resetCycle();
      }
      return;
    }

    if (!_armed) {
      if (bothOpen) {
        _releaseSince ??= now;
        if (now.difference(_releaseSince!) >= releaseHold) {
          _armed = true;
          _releaseSince = null;
        }
      } else {
        _releaseSince = null;
      }
      return;
    }

    final side =
        blueOnly
            ? true
            : orangeOnly
            ? false
            : null;
    if (side == null || (_nextWinkBlue != null && side != _nextWinkBlue)) {
      _winkSideBlue = null;
      _liftSince = null;
      return;
    }
    if (_winkSideBlue != side) {
      _winkSideBlue = side;
      _liftSince = now;
      return;
    }
    if (now.difference(_liftSince!) >= const Duration(milliseconds: 150)) {
      _strongReached = true;
      _releaseSince = null;
      _nextWinkBlue = !side;
      _countPeak();
    }
  }

  void _countPeak() {
    repetitions++;
    if (repetitions >= goalRepetitions) phase = BrowPhase.done;
  }

  static bool _validAperturePair(BrowSample sample) {
    final blue = sample.blueAperture;
    final orange = sample.orangeAperture;
    return (blue == null && orange == null) ||
        (blue != null &&
            blue.isFinite &&
            blue >= 0 &&
            orange != null &&
            orange.isFinite &&
            orange >= 0);
  }

  bool _calibratedSquintAperture(BrowSample target) {
    final base = neutral!;
    if (base.blueAperture == null || target.blueAperture == null) return true;
    bool narrowed(double open, double peak) =>
        peak >= _minimumAperture(open) &&
        open - peak >= math.max(0.005, open * 0.07);
    return narrowed(base.blueAperture!, target.blueAperture!) &&
        narrowed(base.orangeAperture!, target.orangeAperture!);
  }

  bool _atSquintAperture({required bool active}) {
    final base = neutral!;
    final target = maximum!;
    if (base.blueAperture == null || target.blueAperture == null) return true;
    bool matches(double open, double peak, double? observed) {
      if (observed == null) return false;
      final travel = open - peak;
      if (!active)
        return (observed - open).abs() <= math.max(0.006, travel * 0.4);
      return observed >= _minimumAperture(open) &&
          observed <= open - travel * 0.5;
    }

    return matches(
          base.blueAperture!,
          target.blueAperture!,
          current!.blueAperture,
        ) &&
        matches(
          base.orangeAperture!,
          target.orangeAperture!,
          current!.orangeAperture,
        );
  }

  static double _minimumAperture(double baseline) =>
      math.max(0.015, baseline * 0.15);

  bool _atNeutral(double upperThreshold) {
    final sample = current!;
    final low = neutral!;
    final high = maximum!;
    final blue = _fraction(sample.blue, low.blue, high.blue);
    final orange = _fraction(sample.orange, low.orange, high.orange);
    return blue >= -0.50 &&
        blue <= upperThreshold &&
        orange >= -0.50 &&
        orange <= upperThreshold;
  }

  void _rearmFromOpen() {
    _resetCycle();
    _armed = true;
  }

  void _resetCycle() {
    _releaseSince = null;
    _liftSince = null;
    _armed = false;
    _softReached = false;
    _strongReached = false;
    _softSince = null;
    _strongSince = null;
    _winkSideBlue = null;
  }

  static double _progress(double? value, double? base, double? peak) {
    if (value == null || base == null || peak == null || peak <= base) return 0;
    return _fraction(value, base, peak).clamp(0.0, 1.0);
  }

  static double _fraction(double value, double base, double peak) =>
      (value - base) / (peak - base);

  static bool _stableCalibration(List<double> sorted, double? base) {
    // Both calibration phases tolerate one stray sample at each end. The
    // remaining samples must describe a single held position.
    final middle = sorted[sorted.length ~/ 2];
    final travel = base == null ? 0.0 : (middle - base).abs();
    return sorted[sorted.length - 2] - sorted[1] <=
        math.max(0.012, travel * 0.3);
  }

  static double _median(List<double> values) {
    values.sort();
    return values[values.length ~/ 2];
  }
}
