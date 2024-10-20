import 'dart:async';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class VolumeController {
  Timer? _timer;
  final Duration _interval = Duration(seconds: 1); // Interval pengecekan

  void startMonitoring() {
    _setMaxVolume(); // Pastikan volume maksimal diatur pada awal

    _timer = Timer.periodic(_interval, (timer) async {
      try {
        var volume = await FlutterVolumeController
            .getVolume();

        double currentVolume = _ensureDouble(volume);

        if (currentVolume < 1.0) {
          await _setMaxVolume(); // Atur volume ke maksimal jika kurang dari 1.0
        }
      } catch (e) {
        print('Error getting volume: $e');
      }
    });
  }

  double _ensureDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else {
      throw Exception('Unexpected volume type: ${value.runtimeType}');
    }
  }

  void stopMonitoring() {
    _timer?.cancel(); // Hentikan timer
  }

  Future<void> _setMaxVolume() async {
    try {
      await FlutterVolumeController.setVolume(1.0); // Atur volume ke maksimal
      print('Volume set to max');
    } catch (e) {
      print('Error setting volume: $e'); // Penanganan kesalahan
    }
  }
}
