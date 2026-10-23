import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ftaiunqdviyzatvioppu.supabase.co',
    anonKey: 'sb_publishable_GEf8hplzR0Rkb3kCPfJUlg_hJFTKeTK',
  );

  await _initializeNotifications();

  runApp(const MyApp());
}

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await notificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmowlCM Vibraciones',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VibrationApp(),
    );
  }
}

class VibrationApp extends StatefulWidget {
  const VibrationApp({super.key});

  @override
  State<VibrationApp> createState() => _VibrationAppState();
}

class _VibrationAppState extends State<VibrationApp> {
  String _ultimaLetra = 'Ninguna';
  String _estadoConexion = 'Conectando...';
  DateTime? _ultimoTimestamp;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _escucharVibraciones();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _escucharVibraciones() {
    _channel = Supabase.instance.client
        .channel('vibraciones_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'vibraciones',
          callback: (payload) {
            final data = payload.newRecord;
            final letra = data['letra'] as String?;
            final timestamp = data['timestamp'] as String?;

            if (letra != null) {
              setState(() {
                _ultimaLetra = letra;
                _ultimoTimestamp = DateTime.tryParse(timestamp ?? '');
                _estadoConexion = 'Conectado';
              });
              _vibrarSegunLetra(letra);
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            setState(() {
              _estadoConexion = 'Conectado';
            });
          } else if (error != null) {
            setState(() {
              _estadoConexion = 'Error: $error';
            });
          }
        });
  }

  void _vibrarSegunLetra(String letra) async {
    final vibraciones = {'A': 1, 'B': 2, 'C': 3, 'D': 4};
    final numVibraciones = vibraciones[letra.toUpperCase()] ?? 0;

    if (numVibraciones > 0) {
      // Vibración directa (funciona con pantalla encendida)
      if (await Vibration.hasVibrator() ?? false) {
        final pattern = List<int>.filled(numVibraciones * 2 + 1, 0);
        for (int i = 0; i < numVibraciones; i++) {
          pattern[i * 2 + 1] = 250;
          if (i < numVibraciones - 1) {
            pattern[i * 2 + 2] = 500;
          }
        }
        Vibration.vibrate(pattern: pattern);
      }

      // Notificación con vibración (funciona con pantalla apagada)
      final androidDetails = AndroidNotificationDetails(
        'vibraciones_channel',
        'Vibraciones SmowlCM',
        channelDescription: 'Notificaciones de vibraciones',
        importance: Importance.high,
        priority: Priority.high,
        vibrationPattern: _generarPatronVibracion(numVibraciones),
        enableVibration: true,
        autoCancel: true,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Respuesta: $letra',
        '$numVibraciones vibración${numVibraciones > 1 ? 'es' : ''}',
        notificationDetails,
      );
    }
  }

  Int64List _generarPatronVibracion(int numVibraciones) {
    final pattern = <int>[];
    pattern.add(0); // tiempo de espera inicial
    for (int i = 0; i < numVibraciones; i++) {
      pattern.add(250); // duración de vibración
      if (i < numVibraciones - 1) {
        pattern.add(500); // silencio entre vibraciones
      }
    }
    return Int64List.fromList(pattern);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('SmowlCM Vibraciones'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Estado de conexión
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _estadoConexion == 'Conectado'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _estadoConexion == 'Conectado'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _estadoConexion == 'Conectado'
                        ? Icons.wifi
                        : Icons.wifi_off,
                    color: _estadoConexion == 'Conectado'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _estadoConexion,
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Última letra recibida
            Text(
              'Última letra:',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: Text(
                _ultimaLetra,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Timestamp
            if (_ultimoTimestamp != null)
              Text(
                'Recibido: ${_ultimoTimestamp.toString().substring(0, 19)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
