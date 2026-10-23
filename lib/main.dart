import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.initCommunicationPort();

  runApp(const MyApp());
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

class _VibrationAppState extends State<VibrationApp> with WidgetsBindingObserver {
  String _ultimaLetra = 'Ninguna';
  String _estadoConexion = 'Conectando...';
  DateTime? _ultimoTimestamp;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Supabase.initialize(
      url: 'https://ftaiunqdviyzatvioppu.supabase.co',
      anonKey: 'sb_publishable_GEf8hplzR0Rkb3kCPfJUlg_hJFTKeTK',
    );

    await _initializeNotifications();
    _escucharVibraciones();

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  void _onReceiveTaskData(Object data) {
    // Data received from TaskHandler
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _startForegroundService();
    } else if (state == AppLifecycleState.resumed) {
      _stopForegroundService();
    }
  }

  Future<void> _startForegroundService() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'SmowlCM Vibraciones',
      notificationText: 'Escuchando vibraciones...',
      callback: startCallback,
    );
  }

  Future<void> _stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'vibraciones_channel',
      'Vibraciones SmowlCM',
      description: 'Notificaciones de vibraciones',
      importance: Importance.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 500, 250]),
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
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

      final androidDetails = AndroidNotificationDetails(
        'vibraciones_channel',
        'Vibraciones SmowlCM',
        channelDescription: 'Notificaciones de vibraciones',
        importance: Importance.high,
        priority: Priority.high,
        vibrationPattern: _generarPatronVibracion(numVibraciones),
        enableVibration: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(''),
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
    pattern.add(0);
    for (int i = 0; i < numVibraciones; i++) {
      pattern.add(250);
      if (i < numVibraciones - 1) {
        pattern.add(500);
      }
    }
    return Int64List.fromList(pattern);
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('SmowlCM Vibraciones'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(VibrationTaskHandler());
}

class VibrationTaskHandler extends TaskHandler {
  RealtimeChannel? _channel;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await Supabase.initialize(
      url: 'https://ftaiunqdviyzatvioppu.supabase.co',
      anonKey: 'sb_publishable_GEf8hplzR0Rkb3kCPfJUlg_hJFTKeTK',
    );

    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin!.initialize(initializationSettings);

    _escucharVibraciones();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Evento periódico
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _channel?.unsubscribe();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
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

            if (letra != null) {
              _vibrarSegunLetra(letra);
            }
          },
        )
        .subscribe();
  }

  void _vibrarSegunLetra(String letra) async {
    final vibraciones = {'A': 1, 'B': 2, 'C': 3, 'D': 4};
    final numVibraciones = vibraciones[letra.toUpperCase()] ?? 0;

    if (numVibraciones > 0 && _notificationsPlugin != null) {
      final androidDetails = AndroidNotificationDetails(
        'vibraciones_channel',
        'Vibraciones SmowlCM',
        channelDescription: 'Notificaciones de vibraciones',
        importance: Importance.high,
        priority: Priority.high,
        vibrationPattern: _generarPatronVibracion(numVibraciones),
        enableVibration: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(''),
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin!.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Respuesta: $letra',
        '$numVibraciones vibración${numVibraciones > 1 ? 'es' : ''}',
        notificationDetails,
      );
    }
  }

  Int64List _generarPatronVibracion(int numVibraciones) {
    final pattern = <int>[];
    pattern.add(0);
    for (int i = 0; i < numVibraciones; i++) {
      pattern.add(250);
      if (i < numVibraciones - 1) {
        pattern.add(500);
      }
    }
    return Int64List.fromList(pattern);
  }
}
