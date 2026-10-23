import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'vibration_alerts.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(VibrationTaskHandler());
}

class VibrationTaskHandler extends TaskHandler {
  RealtimeChannel? _channel;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await inicializarNotificaciones();

    if (!Supabase.instance.isInitialized) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
    }

    _escucharVibraciones();
    FlutterForegroundTask.sendDataToMain({
      'tipo': 'estado',
      'mensaje': 'Servicio activo (pantalla apagada)',
    });
  }

  void _escucharVibraciones() {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('vibraciones_foreground')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'vibraciones',
          callback: (payload) async {
            final data = payload.newRecord;
            final letra = data['letra'] as String?;
            final timestamp = data['timestamp'] as String?;
            if (letra == null) {
              return;
            }

            await reproducirAlertaLetra(letra);
            FlutterForegroundTask.updateService(
              notificationTitle: 'SmowlCM activo',
              notificationText: 'Última letra: $letra',
            );
            FlutterForegroundTask.sendDataToMain({
              'tipo': 'letra',
              'letra': letra,
              'timestamp': timestamp ?? DateTime.now().toIso8601String(),
            });
          },
        )
        .subscribe((status, error) {
          final conectado = status == RealtimeSubscribeStatus.subscribed;
          FlutterForegroundTask.sendDataToMain({
            'tipo': 'estado',
            'mensaje': conectado
                ? 'Servicio activo (pantalla apagada)'
                : 'Reconectando servicio...${error != null ? ': $error' : ''}',
          });
        });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_channel == null) {
      _escucharVibraciones();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

Future<void> pedirPermisosSegundoPlano() async {
  final notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (Platform.isAndroid) {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}

void inicializarServicioPrimerPlano() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: servicioChannelId,
      channelName: 'Servicio SmowlCM',
      channelDescription:
          'Mantiene las vibraciones activas con la pantalla apagada',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(30000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> iniciarServicioPrimerPlano() async {
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.restartService();
    return;
  }

  await FlutterForegroundTask.startService(
    serviceId: 256,
    notificationTitle: 'SmowlCM activo',
    notificationText: 'Funciona con la pantalla apagada. No cierres esta notificación.',
    notificationButtons: const [
      NotificationButton(id: 'btn_stop', text: 'Detener'),
    ],
    callback: startForegroundCallback,
  );
}

Future<void> detenerServicioPrimerPlano() {
  return FlutterForegroundTask.stopService();
}
