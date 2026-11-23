import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/brow_exercise_logic.dart';

void addSamples(BrowExerciseLogic logic, BrowSample sample, DateTime start) {
  for (var i = 0; i < BrowExerciseLogic.samplesPerCalibration; i++) {
    logic.add(sample, start.add(Duration(milliseconds: i * 200)));
  }
}

void main() {
  test(
    'short calibration waits for seven stable samples and ignores one outlier',
    () {
      final logic = BrowExerciseLogic();
      final start = DateTime(2026);
      logic.beginNeutral();
      for (var i = 0; i < BrowExerciseLogic.samplesPerCalibration - 1; i++) {
        logic.add(
          const BrowSample(0.20, 0.21),
          start.add(Duration(milliseconds: i * 150)),
        );
      }
      expect(logic.phase, BrowPhase.neutral);
      logic.add(
        const BrowSample(0.50, 0.50),
        start.add(const Duration(milliseconds: 900)),
      );
      expect(logic.phase, BrowPhase.readyForMax);
      expect(logic.neutral!.blue, closeTo(0.20, 0.0001));
      expect(logic.neutral!.orange, closeTo(0.21, 0.0001));

      logic.beginMaximum();
      for (var i = 0; i < BrowExerciseLogic.samplesPerCalibration - 1; i++) {
        logic.add(
          const BrowSample(0.30, 0.24),
          start.add(Duration(milliseconds: 1200 + i * 150)),
        );
      }
      expect(logic.phase, BrowPhase.maximum);
      logic.add(
        const BrowSample(0.60, 0.60),
        start.add(const Duration(milliseconds: 2100)),
      );
      expect(logic.phase, BrowPhase.ready);
      expect(logic.maximum!.blue, closeTo(0.30, 0.0001));
      expect(logic.maximum!.orange, closeTo(0.24, 0.0001));
    },
  );

  test('smile calibrates sides separately and counts only a full cycle', () {
    final logic = BrowExerciseLogic(smile: true);
    final start = DateTime(2026);
    void frame(double blue, double orange, int ms) => logic.add(
      BrowSample(blue, orange),
      start.add(Duration(milliseconds: ms)),
    );

    logic.beginNeutral();
    addSamples(logic, const BrowSample(0.30, 0.32), start);
    logic.beginMaximum();
    addSamples(logic, const BrowSample(0.42, 0.36), start);
    expect(logic.phase, BrowPhase.ready);
    expect(logic.maximum!.blue, closeTo(0.42, 0.0001));
    expect(logic.maximum!.orange, closeTo(0.36, 0.0001));
    logic.beginTracking();

    frame(0.30, 0.32, 0);
    frame(0.30, 0.32, 300);
    frame(0.42, 0.32, 400); // One corner cannot complete the smile.
    frame(0.42, 0.32, 800);
    expect(logic.repetitions, 0);
    frame(0.30, 0.32, 900);
    frame(0.30, 0.32, 1200);
    frame(0.42, 0.36, 1300);
    frame(0.42, 0.36, 1450); // Too short.
    frame(0.30, 0.32, 1550);
    expect(logic.repetitions, 0);
    frame(0.42, 0.36, 1800);
    frame(0.42, 0.36, 2200);
    expect(logic.repetitions, 1); // The held peak completes the repetition.
    frame(0.30, 0.32, 2300);
    frame(0.30, 0.32, 2600);
    expect(logic.repetitions, 1);
    logic.faceLost();
    frame(0.42, 0.36, 2700);
    frame(0.42, 0.36, 3100);
    expect(logic.repetitions, 1);
  });

  test('wink alternates eyes and rejects both-eye closures', () {
    final logic = BrowExerciseLogic(wink: true);
    final start = DateTime(2026);
    BrowSample eyes(double blue, double orange) =>
        BrowSample.fromGaps(blue, orange, frown: true);
    void frame(double blue, double orange, int ms) =>
        logic.add(eyes(blue, orange), start.add(Duration(milliseconds: ms)));

    logic.beginNeutral();
    addSamples(logic, eyes(0.20, 0.24), start);
    logic.beginMaximum();
    addSamples(logic, eyes(0.04, 0.08), start);
    expect(logic.phase, BrowPhase.ready);
    expect(logic.goalRepetitions, 20);
    logic.beginTracking();

    frame(0.20, 0.24, 0);
    frame(0.20, 0.24, 300);
    frame(0.04, 0.08, 400); // Ordinary blink closes both eyes.
    frame(0.20, 0.24, 700);
    expect(logic.repetitions, 0);

    frame(0.04, 0.24, 900);
    frame(0.04, 0.24, 1100);
    frame(0.04, 0.08, 1200); // The peak was valid before the other eye closed.
    frame(0.20, 0.24, 1300);
    frame(0.20, 0.24, 1600);
    expect(logic.repetitions, 1);

    frame(0.04, 0.24, 1700);
    frame(0.04, 0.24, 1900);
    frame(0.20, 0.24, 2000);
    frame(0.20, 0.24, 2200);
    expect(logic.repetitions, 1);

    frame(0.20, 0.24, 2500);
    frame(0.20, 0.24, 2800);
    frame(0.04, 0.24, 2900); // Same eye cannot count twice in a row.
    frame(0.04, 0.24, 3100);
    frame(0.20, 0.24, 3200);
    frame(0.20, 0.24, 3400);
    expect(logic.repetitions, 1);

    frame(0.20, 0.08, 3500);
    frame(0.20, 0.08, 3700);
    frame(0.20, 0.24, 3800);
    frame(0.20, 0.24, 4000);
    expect(logic.repetitions, 2);
  });

  test('squint needs both eyes, a hold, and a full reopening', () {
    final logic = BrowExerciseLogic(squint: true);
    final start = DateTime(2026);
    void frame(double blue, double orange, int ms) => logic.add(
      BrowSample(blue, orange),
      start.add(Duration(milliseconds: ms)),
    );

    logic.beginNeutral();
    addSamples(logic, const BrowSample(-0.02, 0.01), start);
    logic.beginMaximum();
    addSamples(logic, const BrowSample(0.04, 0.03), start);
    expect(logic.phase, BrowPhase.ready);
    logic.beginTracking();

    frame(-0.02, 0.01, 0);
    frame(-0.02, 0.01, 300);
    frame(0.04, 0.03, 400);
    frame(-0.02, 0.01, 520); // A short peak resembles a blink.
    frame(-0.02, 0.01, 800);
    expect(logic.repetitions, 0);

    frame(0.04, 0.01, 900); // One eye cannot complete the movement.
    frame(0.04, 0.01, 1300);
    frame(-0.02, 0.01, 1400);
    expect(logic.repetitions, 0);

    frame(0.04, 0.03, 1500);
    frame(0.04, 0.03, 1900);
    expect(logic.repetitions, 1);
    frame(-0.02, 0.01, 2000);
    frame(-0.02, 0.01, 2300);
    expect(logic.repetitions, 1);
    frame(-0.02, 0.01, 2600);
    expect(logic.repetitions, 1);
  });

  test('squint tracks the lower eyelids and rejects wide and shut eyes', () {
    final logic = BrowExerciseLogic(squint: true);
    final start = DateTime(2026);
    const open = BrowSample(
      -0.02,
      0.01,
      blueAperture: 0.20,
      orangeAperture: 0.21,
    );
    const widened = BrowSample(
      0.04,
      0.06,
      blueAperture: 0.32,
      orangeAperture: 0.31,
    );
    const squint = BrowSample(
      -0.02,
      0.01,
      blueAperture: 0.12,
      orangeAperture: 0.13,
    );
    const shut = BrowSample(
      0.02,
      0.03,
      blueAperture: 0.005,
      orangeAperture: 0.005,
    );
    void frame(BrowSample sample, int ms) =>
        logic.add(sample, start.add(Duration(milliseconds: ms)));

    logic.beginNeutral();
    addSamples(logic, open, start);
    logic.beginMaximum();
    addSamples(logic, widened, start);
    expect(logic.phase, BrowPhase.readyForMax);
    logic.beginMaximum();
    addSamples(logic, shut, start);
    expect(logic.phase, BrowPhase.readyForMax);
    logic.beginMaximum();
    addSamples(logic, squint, start);
    expect(logic.phase, BrowPhase.ready);
    logic.beginTracking();

    frame(open, 0);
    frame(open, 300);
    frame(widened, 400);
    frame(widened, 750);
    frame(shut, 850);
    frame(shut, 1200);
    expect(logic.repetitions, 0);
    frame(squint, 1300);
    frame(squint, 1650);
    expect(logic.repetitions, 1);
  });

  test('calibrates each brow separately and counts a full cycle', () {
    final logic = BrowExerciseLogic();
    final start = DateTime(2026);
    logic.beginNeutral();
    addSamples(logic, const BrowSample(0.20, 0.20), start);
    expect(logic.phase, BrowPhase.readyForMax);
    logic.beginMaximum();
    addSamples(logic, const BrowSample(0.30, 0.22), start);
    expect(logic.phase, BrowPhase.ready);
    expect(logic.maximum!.blue, closeTo(0.30, 0.0001));
    expect(logic.maximum!.orange, closeTo(0.22, 0.0001));

    logic.beginTracking();
    logic.add(const BrowSample(0.20, 0.20), start);
    logic.add(
      const BrowSample(0.20, 0.20),
      start.add(const Duration(milliseconds: 300)),
    );
    logic.add(
      const BrowSample(0.30, 0.20),
      start.add(const Duration(milliseconds: 500)),
    );
    logic.add(
      const BrowSample(0.30, 0.22),
      start.add(const Duration(milliseconds: 600)),
    );
    expect(logic.repetitions, 0);
    logic.add(
      const BrowSample(0.30, 0.22),
      start.add(const Duration(milliseconds: 900)),
    );
    expect(logic.repetitions, 1);
    logic.add(
      const BrowSample(0.30, 0.22),
      start.add(const Duration(milliseconds: 1200)),
    );
    logic.add(
      const BrowSample(0.30, 0.22),
      start.add(const Duration(milliseconds: 1600)),
    );
    expect(logic.repetitions, 1); // Must release before another count.
  });

  test('rejects unmeasurable maximum instead of counting noise', () {
    final logic = BrowExerciseLogic();
    final start = DateTime(2026);
    logic.beginNeutral();
    addSamples(logic, const BrowSample(0.20, 0.20), start);
    logic.beginMaximum();
    addSamples(logic, const BrowSample(0.30, 0.203), start);
    expect(logic.phase, BrowPhase.readyForMax);
    expect(logic.error, contains('оранжевой'));
  });

  test('two stray peaks cannot calibrate a relaxed face as maximum', () {
    final logic = BrowExerciseLogic();
    final start = DateTime(2026);
    const relaxed = BrowSample(0.20, 0.20);
    const raised = BrowSample(0.30, 0.24);
    logic.beginNeutral();
    addSamples(logic, relaxed, start);
    logic.beginMaximum();
    for (var i = 0; i < 7; i++) {
      logic.add(
        i >= 5 ? raised : relaxed,
        start.add(Duration(milliseconds: i * 150)),
      );
    }
    expect(logic.phase, BrowPhase.maximum);
    expect(logic.maximum, isNull);
    addSamples(logic, raised, start.add(const Duration(milliseconds: 1050)));
    expect(logic.phase, BrowPhase.ready);
    expect(logic.maximum!.blue, raised.blue);
  });

  test('a long frame gap or an invalid frame breaks a brow hold', () {
    final logic = BrowExerciseLogic();
    final start = DateTime(2026);
    const relaxed = BrowSample(0.20, 0.20);
    const raised = BrowSample(0.30, 0.24);
    void frame(BrowSample sample, int ms) =>
        logic.add(sample, start.add(Duration(milliseconds: ms)));
    logic.beginNeutral();
    addSamples(logic, relaxed, start);
    logic.beginMaximum();
    addSamples(logic, raised, start);
    logic.beginTracking();

    frame(relaxed, 0);
    frame(relaxed, 300);
    frame(raised, 400);
    frame(raised, 1250);
    expect(logic.repetitions, 0);

    frame(relaxed, 1400);
    frame(relaxed, 1700);
    frame(raised, 1800);
    frame(const BrowSample(double.nan, 0.24), 1900);
    frame(raised, 2100);
    expect(logic.repetitions, 0);
  });

  test('an opposite expression cannot rearm a smile', () {
    final logic = BrowExerciseLogic(smile: true);
    final start = DateTime(2026);
    const relaxed = BrowSample(0.30, 0.30);
    const smile = BrowSample(0.40, 0.40);
    const opposite = BrowSample(0.22, 0.22);
    void frame(BrowSample sample, int ms) =>
        logic.add(sample, start.add(Duration(milliseconds: ms)));
    logic.beginNeutral();
    addSamples(logic, relaxed, start);
    logic.beginMaximum();
    addSamples(logic, smile, start);
    logic.beginTracking();

    frame(relaxed, 0);
    frame(relaxed, 300);
    frame(smile, 400);
    frame(smile, 700);
    frame(opposite, 800);
    frame(opposite, 1100);
    frame(smile, 1200);
    frame(smile, 1500);
    expect(logic.repetitions, 1);

    frame(relaxed, 1600);
    frame(relaxed, 1900);
    frame(smile, 2000);
    frame(smile, 2300);
    expect(logic.repetitions, 2);
  });

  test('pausing winks preserves the count and the alternating side', () {
    final logic = BrowExerciseLogic(wink: true);
    final start = DateTime(2026);
    const open = BrowSample(-0.20, -0.20);
    const closed = BrowSample(-0.05, -0.05);
    const blueWink = BrowSample(-0.05, -0.20);
    const orangeWink = BrowSample(-0.20, -0.05);
    void frame(BrowSample sample, int ms) =>
        logic.add(sample, start.add(Duration(milliseconds: ms)));
    logic.beginNeutral();
    addSamples(logic, open, start);
    logic.beginMaximum();
    addSamples(logic, closed, start);
    logic.beginTracking();

    frame(open, 0);
    frame(open, 300);
    frame(blueWink, 400);
    frame(blueWink, 600);
    expect(logic.repetitions, 1);
    logic.pause();
    logic.beginTracking();
    expect(logic.repetitions, 1);
    frame(open, 800);
    frame(open, 1100);
    frame(blueWink, 1200);
    frame(blueWink, 1400);
    expect(logic.repetitions, 1);
    frame(orangeWink, 1500);
    frame(orangeWink, 1700);
    expect(logic.repetitions, 2);
  });

  test('losing face disarms a partial repetition', () {
    final logic = BrowExerciseLogic();
    final start = DateTime(2026);
    logic.beginNeutral();
    addSamples(logic, const BrowSample(0.20, 0.20), start);
    logic.beginMaximum();
    addSamples(logic, const BrowSample(0.30, 0.22), start);
    logic.beginTracking();
    logic.add(const BrowSample(0.20, 0.20), start);
    logic.add(
      const BrowSample(0.20, 0.20),
      start.add(const Duration(milliseconds: 300)),
    );
    logic.faceLost();
    logic.add(
      const BrowSample(0.30, 0.22),
      start.add(const Duration(milliseconds: 600)),
    );
    logic.add(
      const BrowSample(0.30, 0.22),
      start.add(const Duration(milliseconds: 900)),
    );
    expect(logic.repetitions, 0);
  });

  test('frown counts relaxed to lowered brows with separate ranges', () {
    final logic = BrowExerciseLogic();
    final start = DateTime(2026);
    logic.beginNeutral();
    addSamples(logic, BrowSample.fromGaps(0.20, 0.20, frown: true), start);
    logic.beginMaximum();
    addSamples(logic, BrowSample.fromGaps(0.12, 0.17, frown: true), start);
    expect(logic.phase, BrowPhase.ready);

    logic.beginTracking();
    logic.add(BrowSample.fromGaps(0.20, 0.20, frown: true), start);
    logic.add(
      BrowSample.fromGaps(0.20, 0.20, frown: true),
      start.add(const Duration(milliseconds: 300)),
    );
    logic.add(
      BrowSample.fromGaps(0.12, 0.20, frown: true),
      start.add(const Duration(milliseconds: 500)),
    );
    expect(logic.repetitions, 0);
    logic.add(
      BrowSample.fromGaps(0.12, 0.17, frown: true),
      start.add(const Duration(milliseconds: 600)),
    );
    logic.add(
      BrowSample.fromGaps(0.12, 0.17, frown: true),
      start.add(const Duration(milliseconds: 900)),
    );
    expect(logic.repetitions, 1);
  });

  test('eye closure needs soft, squeeze signal and held strong peak', () {
    final logic = BrowExerciseLogic(softThenStrong: true);
    final start = DateTime(2026);
    BrowSample eyes(double blue, double orange, {double squeeze = 0.05}) =>
        BrowSample.fromGaps(
          blue,
          orange,
          frown: true,
          blueSqueeze: squeeze,
          orangeSqueeze: squeeze,
        );
    void frame(
      double blue,
      double orange,
      int milliseconds, {
      double squeeze = 0.05,
    }) => logic.add(
      eyes(blue, orange, squeeze: squeeze),
      start.add(Duration(milliseconds: milliseconds)),
    );

    logic.beginNeutral();
    addSamples(logic, eyes(0.20, 0.24), start);
    logic.beginMaximum();
    addSamples(logic, eyes(0.04, 0.08, squeeze: 0.35), start);
    expect(logic.phase, BrowPhase.ready);
    expect(logic.maximum!.blue, closeTo(-0.04, 0.0001));
    expect(logic.maximum!.orange, closeTo(-0.08, 0.0001));
    logic.beginTracking();
    expect(logic.eyeCloseStep, EyeCloseStep.open);

    frame(0.20, 0.24, 0);
    frame(0.20, 0.24, 300);
    frame(0.04, 0.08, 600, squeeze: 0.35); // No soft hold.
    frame(0.04, 0.08, 1000, squeeze: 0.35);
    frame(0.20, 0.24, 1300);
    frame(0.20, 0.24, 1600);
    expect(logic.repetitions, 0);

    frame(0.12, 0.24, 1900); // One eye alone cannot complete the soft hold.
    frame(0.12, 0.24, 2200);
    frame(0.04, 0.08, 2500, squeeze: 0.35);
    frame(0.04, 0.08, 2900, squeeze: 0.35);
    frame(0.20, 0.24, 3200);
    frame(0.20, 0.24, 3500);
    expect(logic.repetitions, 0);
    expect(logic.eyeCloseStep, EyeCloseStep.gentle);

    frame(0.12, 0.16, 3800); // Half-closed is not gentle closure.
    frame(0.12, 0.16, 4100);
    frame(0.04, 0.08, 4400); // Lids fully closed without a squeeze.
    expect(logic.repetitions, 0);
    frame(0.04, 0.08, 4700); // Gentle closure held long enough.
    expect(logic.eyeCloseStep, EyeCloseStep.strong);
    expect(logic.squeezeProgress, 0);
    frame(0.04, 0.08, 4800, squeeze: 0.35);
    frame(0.04, 0.08, 5300, squeeze: 0.35);
    expect(logic.repetitions, 1); // Count at the held maximum.
    expect(logic.squeezeProgress, 1);
    expect(logic.eyeCloseStep, EyeCloseStep.reopen);
    frame(0.20, 0.24, 5400);
    frame(0.20, 0.24, 5700);
    expect(logic.repetitions, 1);
    frame(0.20, 0.24, 6000);
    expect(logic.repetitions, 1);
  });

  test('blink counts both eyes closing and reopening once', () {
    final logic = BrowExerciseLogic(blink: true);
    final start = DateTime(2026);
    BrowSample eyes(double blue, double orange) =>
        BrowSample.fromGaps(blue, orange, frown: true);
    void frame(double blue, double orange, int milliseconds) => logic.add(
      eyes(blue, orange),
      start.add(Duration(milliseconds: milliseconds)),
    );

    logic.beginNeutral();
    addSamples(logic, eyes(0.20, 0.24), start);
    logic.beginMaximum();
    addSamples(logic, eyes(0.04, 0.08), start);
    expect(logic.phase, BrowPhase.ready);
    logic.beginTracking();

    frame(0.04, 0.08, 0); // Closure before open calibration does not count.
    frame(0.20, 0.24, 120);
    frame(0.20, 0.24, 420);
    frame(0.04, 0.24, 540); // One eye alone does not count.
    frame(0.20, 0.24, 660);
    expect(logic.repetitions, 0);

    frame(0.04, 0.08, 780);
    expect(logic.repetitions, 1);
    frame(0.20, 0.24, 900);
    expect(logic.repetitions, 1);
    frame(0.20, 0.24, 1140);
    expect(logic.repetitions, 1);
    frame(0.20, 0.24, 1260);
    expect(logic.repetitions, 1);

    frame(0.20, 0.24, 1560);
    frame(0.04, 0.08, 1680);
    logic.faceLost();
    frame(0.20, 0.24, 1800);
    frame(0.20, 0.24, 2100);
    expect(logic.repetitions, 2);
  });

  test('a confirmed reopening immediately prepares the next blink', () {
    final logic = BrowExerciseLogic(blink: true);
    final start = DateTime(2026);
    const open = BrowSample(-0.20, -0.20);
    const closed = BrowSample(-0.05, -0.05);
    void frame(BrowSample sample, int ms) =>
        logic.add(sample, start.add(Duration(milliseconds: ms)));
    logic.beginNeutral();
    addSamples(logic, open, start);
    logic.beginMaximum();
    addSamples(logic, closed, start);
    logic.beginTracking();

    frame(open, 0);
    frame(open, 300);
    frame(closed, 420);
    frame(closed, 540);
    expect(logic.repetitions, 1);
    frame(open, 660);
    frame(open, 900);
    frame(closed, 1020);
    expect(logic.repetitions, 2);
  });
}
