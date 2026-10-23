import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'app_config.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

const Map<String, int> vibracionesPorLetra = {
  'A': 1,
  'B': 2,
  'C': 3,
  'D': 4,
};

Future<void> inicializarNotificaciones() async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(settings);

  final vibrationPattern = Int64List.fromList([0, 250, 500, 250]);
  final channel = AndroidNotificationChannel(
    vibracionesChannelId,
    vibracionesChannelName,
    description: 'Notificaciones de vibraciones',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: vibrationPattern,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

int cantidadVibraciones(String letra) {
  return vibracionesPorLetra[letra.toUpperCase()] ?? 0;
}

Int64List patronVibracion(int numVibraciones) {
  final pattern = <int>[0];
  for (var i = 0; i < numVibraciones; i++) {
    pattern.add(250);
    if (i < numVibraciones - 1) {
      pattern.add(500);
    }
  }
  return Int64List.fromList(pattern);
}

Future<void> reproducirAlertaLetra(String letra) async {
  final numVibraciones = cantidadVibraciones(letra);
  if (numVibraciones <= 0) {
    return;
  }

    if (await Vibration.hasVibrator()) {
    final pattern = List<int>.filled(numVibraciones * 2 + 1, 0);
    for (var i = 0; i < numVibraciones; i++) {
      pattern[i * 2 + 1] = 250;
      if (i < numVibraciones - 1) {
        pattern[i * 2 + 2] = 500;
      }
    }
    Vibration.vibrate(pattern: pattern);
  }

  final androidDetails = AndroidNotificationDetails(
    vibracionesChannelId,
    vibracionesChannelName,
    channelDescription: 'Notificaciones de vibraciones',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    fullScreenIntent: true,
    vibrationPattern: patronVibracion(numVibraciones),
    enableVibration: true,
    playSound: true,
    autoCancel: true,
    ticker: 'Respuesta $letra',
  );

  await notificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'Respuesta: $letra',
    '$numVibraciones vibración${numVibraciones > 1 ? 'es' : ''}',
    NotificationDetails(android: androidDetails),
  );
}
