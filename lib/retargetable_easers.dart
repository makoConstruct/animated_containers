// EaseInOut animations that can be smoothly retargeted partway through with no sudden velocity changes. Unlike most Simulation animations, this one reaches its target utterly reliably on the frame of `duration`.

// It works by just remembering the initial velocity and the initial location, instead of sort of simulating, frame by frame, a little thing moving along. It's more accurate and doesn't need to be updated every frame, it is just called at paint.

//translated from https://github.com/makoConstruct/interruptable_easer/blob/master/src/lib.rs by claude sonnet
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// this is supposedly dangerous "returns an arbitrary value", but we have no choice. https://github.com/flutter/flutter/issues/157648

double sq(double a) {
  return a * a;
}

double clampUnit(double v) => max(0, min(1, v));

double anti(double v) => 1 - v;

double linearAccelerationEaseInOutWithInitialVelocity(
    double t, double initialVelocity) {
  return t *
      (t * ((initialVelocity - 2) * t + (3 - 2 * initialVelocity)) +
          initialVelocity);
}

double velocityOfLinearAccelerationEaseInOutWithInitialVelocity(
    double t, double initialVelocity) {
  return t * ((3 * initialVelocity - 6) * t + (6 - 4 * initialVelocity)) +
      initialVelocity;
}

double constantAccelerationEaseInOutWithInitialVelocity(
    double t, double initialVelocity) {
  if (t >= 1) {
    return 1;
  }
  double sqrtPart = sqrt(2 * sq(initialVelocity) - 4 * initialVelocity + 4);
  double m =
      (2 - initialVelocity + (initialVelocity < 2 ? sqrtPart : -sqrtPart)) / 2;
  double ax = -initialVelocity / (2 * m);
  double ay = initialVelocity * ax / 2;
  double h = (ax + 1) / 2;
  if (t < h) {
    return m * sq(t - ax) + ay;
  } else {
    return -m * sq(t - 1) + 1;
  }
}

double velocityOfConstantAccelerationEaseInOutWithInitialVelocity(
    double t, double initialVelocity) {
  if (t >= 1) {
    return 0;
  }
  double sqrtPart = sqrt(2 * sq(initialVelocity) - 4 * initialVelocity + 4);
  double m =
      (2 - initialVelocity + (initialVelocity < 2 ? sqrtPart : -sqrtPart)) / 2;
  double ax = -initialVelocity / (2 * m);
  double h = (ax + 1) / 2;
  if (t < h) {
    return 2 * m * (t - ax);
  } else {
    return 2 * m * (1 - t);
  }
}

double ease(
  double startValue,
  double endValue,
  double startTime,
  double endTime,
  double currentTime,
  double initialVelocity,
) {
  if (startTime == double.negativeInfinity) {
    return endValue;
  }
  if (startValue == endValue) {
    return startValue;
  }
  double normalizedTime = (currentTime - startTime) / (endTime - startTime);
  double normalizedVelocity =
      initialVelocity / (endValue - startValue) * (endTime - startTime);
  double normalizedOutput = normalizedVelocity > 2
      ? linearAccelerationEaseInOutWithInitialVelocity(
          normalizedTime, normalizedVelocity)
      : constantAccelerationEaseInOutWithInitialVelocity(
          normalizedTime, normalizedVelocity);
  return startValue + normalizedOutput * (endValue - startValue);
}

Offset easeOffset(
  Offset startValue,
  Offset endValue,
  double startTime,
  double endTime,
  double currentTime,
  Offset initialVelocity,
) {
  return Offset(
    ease(startValue.dx, endValue.dx, startTime, endTime, currentTime,
        initialVelocity.dx),
    ease(startValue.dy, endValue.dy, startTime, endTime, currentTime,
        initialVelocity.dy),
  );
}

(Offset, Offset) easeValVelOffset(
  Offset startValue,
  Offset endValue,
  double startTime,
  double endTime,
  double currentTime,
  Offset initialVelocity,
) {
  final (dx, ddx) = easeValVel(startValue.dx, endValue.dx, startTime, endTime,
      currentTime, initialVelocity.dx);
  final (dy, ddy) = easeValVel(startValue.dy, endValue.dy, startTime, endTime,
      currentTime, initialVelocity.dy);
  return (
    Offset(dx, dy),
    Offset(ddx, ddy),
  );
}

double velEase(
  double startValue,
  double endValue,
  double startTime,
  double endTime,
  double currentTime,
  double initialVelocity,
) {
  if (startTime == double.negativeInfinity) {
    return 0.0;
  }
  if (startValue == endValue) {
    return 0.0;
  }
  double normalizedTime = (currentTime - startTime) / (endTime - startTime);
  double normalizedVelocity =
      initialVelocity / (endValue - startValue) * (endTime - startTime);
  double normalizedOutput = normalizedVelocity > 2
      ? velocityOfLinearAccelerationEaseInOutWithInitialVelocity(
          normalizedTime, normalizedVelocity)
      : velocityOfConstantAccelerationEaseInOutWithInitialVelocity(
          normalizedTime, normalizedVelocity);
  return normalizedOutput * (endValue - startValue) / (endTime - startTime);
}

(double, double) easeValVel(
  double startValue,
  double endValue,
  double startTime,
  double endTime,
  double currentTime,
  double initialVelocity,
) {
  if (startTime == double.negativeInfinity || startValue == endValue) {
    return (endValue, 0.0);
  }
  double normalizedTime = (currentTime - startTime) / (endTime - startTime);
  double normalizedVelocity =
      initialVelocity / (endValue - startValue) * (endTime - startTime);

  late double normalizedPOut, normalizedVelOut;
  if (normalizedVelocity > 2) {
    normalizedPOut = linearAccelerationEaseInOutWithInitialVelocity(
        normalizedTime, normalizedVelocity);
    normalizedVelOut = velocityOfLinearAccelerationEaseInOutWithInitialVelocity(
        normalizedTime, normalizedVelocity);
  } else {
    normalizedPOut = constantAccelerationEaseInOutWithInitialVelocity(
        normalizedTime, normalizedVelocity);
    normalizedVelOut =
        velocityOfConstantAccelerationEaseInOutWithInitialVelocity(
            normalizedTime, normalizedVelocity);
  }
  return (
    startValue + normalizedPOut * (endValue - startValue),
    normalizedVelOut * (endValue - startValue) / (endTime - startTime),
  );
}

Duration maxDuration(Duration a, Duration b) {
  return a.compareTo(b) > 0 ? a : b;
}

const double _midpoint = 0.1;
double defaultPulserFunction(double v) =>
    v < _midpoint ? v / _midpoint : 1 - (v - _midpoint) / (1 - _midpoint);

/// pulses to 1 and sags to 0. Is fairly graceful when interrupted, allowing pulses to overlap. T is a fold over the pulse
class PulserFold<T> {
  double duration;
  T zero;
  List<(double, T)> pulseStarts = [];

  /// pulseTime is the amount of time that's passed since this pulse started. For pulses in the future, it will be negative. For pulses in the past, it will be large. You usually want to get the pulse progress as clampUnit(pulseTime/duration)
  T Function(T accumulator, double pulseTime, T pulseValue) folder;
  PulserFold({this.duration = 200, required this.folder, required this.zero});
  void pulse(T v, {required double time}) {
    pulseStarts.add((time, v));
  }

  T v({required double time}) {
    T r = zero;
    for (var s in pulseStarts) {
      double tp = time - s.$1;
      if (tp > 0 && tp < duration) {
        r = folder(r, tp, s.$2);
      }
    }
    return r;
  }
}

class Pulser extends PulserFold<double> {
  double Function(double) pulseFunction;
  Pulser({super.duration = 200, this.pulseFunction = defaultPulserFunction})
      : super(
            folder: (a, t, _) => pulseFunction(clampUnit(t / duration)),
            zero: 0);
  void pulseThat({required double time}) {
    // this pulser doesn't pay attention to the pulse value, only the time
    super.pulse(0, time: time);
  }
}

class BumpPulse extends PulserFold<Offset> {
  BumpPulse({super.duration})
      : super(
            folder: (Offset acc, double bt, Offset b) =>
                acc + b * defaultPulserFunction(clampUnit(bt / duration)),
            zero: Offset.zero);
}

/// A simulation that can be interrupted and reoriented with no discontinuities in velocity. Used in DynamicEaseInOutAnimationController, and SmoothV2
class DynamicEaseInOutSimulation extends Simulation {
  double startValue;
  double endValue;
  double startVelocity;
  double duration;

  DynamicEaseInOutSimulation(double v, {required this.duration})
      : startValue = v,
        endValue = v,
        startVelocity = 0.0,
        super();

  /// use this when you want the first targetting to reach its destination instantly regardless of transitionDuration
  DynamicEaseInOutSimulation.unset({required this.duration})
      : startValue = double.nan,
        endValue = double.nan,
        startVelocity = double.nan,
        super();

  void target(double v, {required double time}) {
    if (v != endValue) {
      if (startValue.isNaN) {
        startValue = endValue = v;
        startVelocity = 0;
      } else {
        startValue = x(time);
        startVelocity = dx(time);
        endValue = v;
      }
    }
  }

  @override
  double x(double time) {
    if (startValue.isNaN) return endValue;
    if (startValue == endValue) return startValue;
    double normalizedTime = time / duration;
    double normalizedVelocity =
        startVelocity / (endValue - startValue) * duration;
    double normalizedOutput = normalizedVelocity > 2
        ? linearAccelerationEaseInOutWithInitialVelocity(
            normalizedTime, normalizedVelocity)
        : constantAccelerationEaseInOutWithInitialVelocity(
            normalizedTime, normalizedVelocity);
    return startValue + normalizedOutput * (endValue - startValue);
  }

  @override
  double dx(double time) {
    if (startValue.isNaN) return 0.0;
    if (startValue == endValue) return 0.0;
    double normalizedTime = time / duration;
    double normalizedVelocity =
        startVelocity / (endValue - startValue) * duration;
    double normalizedOutput = normalizedVelocity > 2
        ? velocityOfLinearAccelerationEaseInOutWithInitialVelocity(
            normalizedTime, normalizedVelocity)
        : velocityOfConstantAccelerationEaseInOutWithInitialVelocity(
            normalizedTime, normalizedVelocity);
    return normalizedOutput * (endValue - startValue) / duration;
  }

  @override
  bool isDone(double time) => time >= duration;

  // For backward compatibility
}

/// An animation controller that uses DynamicEaseInOut to allow smooth retargeting of animations.
/// When the target value changes, the animation smoothly reorients without any discontinuities in velocity.
class DynamicEaseInOutAnimationController extends Animation<double>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  final DynamicEaseInOutSimulation _simulation;
  late final Ticker _ticker;
  double _value;
  Duration duration;
  Duration lastElapsedDuration = const Duration(milliseconds: 0);
  double get targetValue => _simulation.endValue;

  DynamicEaseInOutAnimationController(
    this._value, {
    required this.duration,
    required TickerProvider vsync,
  }) : _simulation = DynamicEaseInOutSimulation(
          _value,
          duration: duration.inMicroseconds.toDouble(),
        ) {
    _ticker = vsync.createTicker(_tick);
  }

  @override
  double get value => _value;

  @override
  AnimationStatus get status {
    if (_value == targetValue) return AnimationStatus.completed;
    return AnimationStatus.forward;
  }

  void _tick(Duration elapsed) {
    if (elapsed > duration) {
      _value = targetValue;
      _ticker.stop();
      notifyListeners();
      notifyStatusListeners(AnimationStatus.completed);
      return;
    }
    lastElapsedDuration = elapsed;
    _value = _simulation.x(elapsed.inMicroseconds.toDouble());
    notifyListeners();
  }

  void target(double v) {
    if (_value != v) {
      _simulation.target(v,
          time: lastElapsedDuration.inMicroseconds.toDouble());
      lastElapsedDuration = const Duration(milliseconds: 0);
      if (!_ticker.isActive) {
        notifyStatusListeners(AnimationStatus.forward);
      }
      _ticker.stop();
      _ticker.start();
    }
  }
}

class SmoothOffset extends Animation<Offset>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  final DynamicEaseInOutSimulation xSimulation;
  final DynamicEaseInOutSimulation ySimulation;
  late final Ticker _ticker;
  Offset _value;
  Duration duration;
  Duration lastElapsedDuration;

  SmoothOffset({
    required Offset value,
    required this.duration,
    required TickerProvider vsync,
  })  : _value = value,
        xSimulation = DynamicEaseInOutSimulation(
          value.dx,
          duration: duration.inMicroseconds.toDouble(),
        ),
        ySimulation = DynamicEaseInOutSimulation(
          value.dy,
          duration: duration.inMicroseconds.toDouble(),
        ),
        lastElapsedDuration = duration {
    _ticker = vsync.createTicker(_tick);
  }

  Offset get targetValue => Offset(xSimulation.endValue, ySimulation.endValue);

  @override
  Offset get value => _value;

  @override
  AnimationStatus get status {
    if (lastElapsedDuration >= duration) return AnimationStatus.completed;
    return AnimationStatus.forward;
  }

  void _tick(Duration elapsed) {
    if (elapsed > duration) {
      _value = targetValue;
      _ticker.stop();
      notifyListeners();
      notifyStatusListeners(AnimationStatus.completed);
      return;
    }
    lastElapsedDuration = elapsed;
    _value = Offset(
      xSimulation.x(elapsed.inMicroseconds.toDouble()),
      ySimulation.x(elapsed.inMicroseconds.toDouble()),
    );
    notifyListeners();
  }

  void target(Offset target) {
    if (_value.dx != target.dx || _value.dy != target.dy) {
      xSimulation.target(target.dx,
          time: lastElapsedDuration.inMicroseconds.toDouble());
      ySimulation.target(target.dy,
          time: lastElapsedDuration.inMicroseconds.toDouble());
      lastElapsedDuration = const Duration(milliseconds: 0);
      bool tickingWasActive = _ticker.isActive;
      _ticker.stop();
      _ticker.start();
      if (!tickingWasActive) {
        notifyStatusListeners(AnimationStatus.forward);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _ticker.dispose();
  }
}
