import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class SensorInput {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  const SensorInput({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });

  double get shakeLevel => (magnitude - 9.81).abs();

  Map<String, dynamic> toMap() {
    return {
      'x': double.parse(x.toStringAsFixed(3)),
      'y': double.parse(y.toStringAsFixed(3)),
      'z': double.parse(z.toStringAsFixed(3)),
      'magnitude': double.parse(magnitude.toStringAsFixed(3)),
      'shake_level': double.parse(shakeLevel.toStringAsFixed(3)),
    };
  }
}

class SensorInputService {
  SensorInputService._();

  static SensorInputService? _instance;
  static SensorInputService get instance => _instance ??= SensorInputService._();

  Stream<SensorInput> accelerometerInputStream() {
    return accelerometerEventStream().map((event) {
      final magnitude = sqrt(
        (event.x * event.x) +
            (event.y * event.y) +
            (event.z * event.z),
      );

      return SensorInput(
        x: event.x,
        y: event.y,
        z: event.z,
        magnitude: magnitude,
        timestamp: DateTime.now(),
      );
    });
  }
}
