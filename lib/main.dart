import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://ftaiunqdviyzatvioppu.supabase.co',
    anonKey: 'sb_publishable_GEf8hplzR0Rkb3kCPfJUlg_hJFTKeTK',
  );

  await _initializeNotifications();
  await _setupFirebaseMessaging();

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

  final vibrationPattern = Int64List.fromList([0, 250, 500, 250]);
  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vibraciones_channel',
    'Vibraciones SmowlCM',
    description: 'Notificaciones de vibraciones',
    importance: Importance.high,
    enableVibration: true,
    vibrationPattern: vibrationPattern,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Permiso de notificaciones concedido');
  } else {
    print('Permiso de notificaciones denegado');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Mensaje recibido en foreground: ${message.notification?.title}');
    _handleMessage(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Mensaje abierto desde background: ${message.notification?.title}');
    _handleMessage(message);
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Mensaje recibido en background: ${message.notification?.title}');
  _handleMessage(message);
}

void _handleMessage(RemoteMessage message) {
  final data = message.data;
  final letra = data['letra'] as String?;

  if (letra != null) {
    _vibrarSegunLetra(letra);
  }
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
  String? _fcmToken;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _estadoConexion = 'Iniciando Firebase...';
    });

    try {
      await _getFCMToken();
      setState(() {
        _estadoConexion = 'FCM listo, conectando Supabase...';
      });
      _escucharVibraciones();
    } catch (e) {
      setState(() {
        _estadoConexion = 'Error: $e';
      });
    }
  }

  Future<void> _getFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token;
      });
      print('FCM Token: $token');
      if (token == null) {
        throw Exception('No se pudo obtener FCM Token');
      }

      // Guardar token en Supabase
      await _saveFCMTokenToSupabase(token);
    } catch (e) {
      print('Error obteniendo FCM Token: $e');
      rethrow;
    }
  }

  Future<void> _saveFCMTokenToSupabase(String token) async {
    try {
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('FCM Token guardado en Supabase');
    } catch (e) {
      print('Error guardando FCM Token: $e');
      // No lanzar error, es solo guardar el token
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _escucharVibraciones() {
    try {
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
                  _estadoConexion = 'Conectado (Supabase)';
                });
                _vibrarSegunLetra(letra);
              }
            },
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              setState(() {
                _estadoConexion = 'Conectado (Supabase)';
              });
            } else if (error != null) {
              setState(() {
                _estadoConexion = 'Error Supabase: $error';
              });
            }
          });
    } catch (e) {
      setState(() {
        _estadoConexion = 'Error al conectar: $e';
      });
    }
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
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _estadoConexion == 'Conectado' || _estadoConexion == 'FCM Token obtenido'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _estadoConexion == 'Conectado' || _estadoConexion == 'FCM Token obtenido'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _estadoConexion == 'Conectado' || _estadoConexion == 'FCM Token obtenido'
                        ? Icons.wifi
                        : Icons.wifi_off,
                    color: _estadoConexion == 'Conectado' || _estadoConexion == 'FCM Token obtenido'
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
            const SizedBox(height: 16),
            if (_fcmToken != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'FCM Token: ${_fcmToken!.substring(0, 20)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
