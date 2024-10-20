import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm_app/screens/edit.dart';
import 'package:alarm_app/screens/ring.dart';
import 'package:alarm_app/screens/tile.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class VolumeController {
  Timer? _timer;
  final Duration _interval = Duration(seconds: 1); // Interval pengecekan

  void startMonitoring() {
    print('Starting volume monitoring...');
    _setMaxVolume(); // Pastikan volume maksimal diatur pada awal

    _timer = Timer.periodic(_interval, (timer) async {
      try {
        var volume = await FlutterVolumeController
            .getVolume(); // Dapatkan volume saat ini

        // Pastikan volume adalah double
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
    print('Stopping volume monitoring...');
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

class ExampleAlarmHomeScreen extends StatefulWidget {
  const ExampleAlarmHomeScreen({super.key});

  @override
  State<ExampleAlarmHomeScreen> createState() => _ExampleAlarmHomeScreenState();
}

class _ExampleAlarmHomeScreenState extends State<ExampleAlarmHomeScreen> {
  late List<AlarmSettings> alarms;
  static StreamSubscription<AlarmSettings>? subscription;
  final VolumeController _volumeController = VolumeController();

  @override
  void initState() {
    super.initState();
    if (Alarm.android) {
      checkAndroidNotificationPermission();
      checkAndroidScheduleExactAlarmPermission();
    }
    loadAlarms();
    subscription ??= Alarm.ringStream.stream.listen((alarmSettings) {
      print('Alarm ringing...');
      navigateToRingScreen(alarmSettings);
      _volumeController
          .startMonitoring(); // Start monitoring volume when alarm rings
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    _volumeController.stopMonitoring(); // Stop monitoring volume
    super.dispose();
  }

  void loadAlarms() {
    setState(() {
      alarms = Alarm.getAlarms();
      alarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);
    });
  }

  Future<void> navigateToRingScreen(AlarmSettings alarmSettings) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            ExampleAlarmRingScreen(alarmSettings: alarmSettings),
      ),
    );
    loadAlarms();
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: ExampleAlarmEditScreen(alarmSettings: settings),
        );
      },
    );

    if (res != null && res == true) loadAlarms();
  }

  Future<void> checkAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      alarmPrint('Requesting notification permission...');
      final res = await Permission.notification.request();
      alarmPrint(
        'Notification permission ${res.isGranted ? '' : 'not '}granted',
      );
    }
  }

  Future<void> checkAndroidExternalStoragePermission() async {
    final status = await Permission.storage.status;
    if (status.isDenied) {
      alarmPrint('Requesting external storage permission...');
      final res = await Permission.storage.request();
      alarmPrint(
        'External storage permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  Future<void> checkAndroidScheduleExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    alarmPrint('Schedule exact alarm permission: $status.');
    if (status.isDenied) {
      alarmPrint('Requesting schedule exact alarm permission...');
      final res = await Permission.scheduleExactAlarm.request();
      alarmPrint(
        'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALARM DAMAI'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: alarms.isNotEmpty
            ? ListView.separated(
                itemCount: alarms.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ExampleAlarmTile(
                    key: Key(alarms[index].id.toString()),
                    title: TimeOfDay(
                      hour: alarms[index].dateTime.hour,
                      minute: alarms[index].dateTime.minute,
                    ).format(context),
                    onPressed: () => navigateToAlarmScreen(alarms[index]),
                    onDismissed: () {
                      Alarm.stop(alarms[index].id).then((_) => loadAlarms());
                    },
                  );
                },
              )
            : Center(
                child: Text(
                  'Tidak ada Alarm',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 25.0),
        child: FloatingActionButton(
          onPressed: () => navigateToAlarmScreen(null),
          child: const Icon(Icons.alarm_add_rounded, size: 33),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
