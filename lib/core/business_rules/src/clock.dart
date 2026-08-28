/// Monotonic source of time. Tests inject a fixed clock; production uses
/// [SystemClock]. Injected so every rule is deterministic and testable.
abstract class Clock {
  DateTime now();
}

class SystemClock extends Clock {
  @override
  DateTime now() => DateTime.now();
}

class FixedClock extends Clock {
  final DateTime fixed;
  FixedClock(this.fixed);
  @override
  DateTime now() => fixed;
}
