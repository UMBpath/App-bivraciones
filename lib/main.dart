import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'foreground_service.dart';
import 'vibration_alerts.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  await inicializarNotificaciones();
  await _manejarMensajeFcm(message);
}

Future<void> _manejarMensajeFcm(RemoteMessage message) async {
  final letra = message.data['letra'] as String?;
  if (letra != null) {
    await reproducirAlertaLetra(letra);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  await inicializarNotificaciones();
  await _setupFirebaseMessaging();

  runApp(const MyApp());
}

Future<void> _setupFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen(_manejarMensajeFcm);
  FirebaseMessaging.onMessageOpenedApp.listen(_manejarMensajeFcm);
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
  bool _servicioActivo = false;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      inicializarServicioPrimerPlano();
      await pedirPermisosSegundoPlano();
      await _initializeApp();
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _channel?.unsubscribe();
    super.dispose();
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map) {
      return;
    }
    final tipo = data['tipo'];
    if (tipo == 'letra') {
      setState(() {
        _ultimaLetra = (data['letra'] as String?) ?? _ultimaLetra;
        _ultimoTimestamp = DateTime.tryParse('${data['timestamp'] ?? ''}');
        _estadoConexion = 'Servicio activo (pantalla apagada)';
        _servicioActivo = true;
      });
    } else if (tipo == 'estado') {
      setState(() {
        _estadoConexion = '${data['mensaje'] ?? _estadoConexion}';
      });
    }
  }

  Future<void> _initializeApp() async {
    setState(() {
      _estadoConexion = 'Iniciando...';
    });

    try {
      await _getFCMToken();
      await iniciarServicioPrimerPlano();
      final running = await FlutterForegroundTask.isRunningService;
      setState(() {
        _servicioActivo = running;
        _estadoConexion = running
            ? 'Servicio activo (pantalla apagada)'
            : 'FCM listo, conectando Supabase...';
      });
      if (!running) {
        _escucharVibracionesEnPantalla();
      }
    } catch (e) {
      setState(() {
        _estadoConexion = 'Error: $e';
      });
      _escucharVibracionesEnPantalla();
    }
  }

  Future<void> _getFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token;
      });
      if (token == null) {
        throw Exception('No se pudo obtener FCM Token');
      }
      await _saveFCMTokenToSupabase(token);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveFCMTokenToSupabase(String token) async {
    try {
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error guardando FCM Token: $e');
    }
  }

  void _escucharVibracionesEnPantalla() {
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
                  _estadoConexion = 'Conectado (app abierta)';
                });
                reproducirAlertaLetra(letra);
              }
            },
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              setState(() {
                _estadoConexion = 'Conectado (app abierta)';
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

  Future<void> _alternarServicio(bool activo) async {
    if (activo) {
      await pedirPermisosSegundoPlano();
      await iniciarServicioPrimerPlano();
      await _channel?.unsubscribe();
      _channel = null;
      setState(() {
        _servicioActivo = true;
        _estadoConexion = 'Servicio activo (pantalla apagada)';
      });
    } else {
      await detenerServicioPrimerPlano();
      setState(() {
        _servicioActivo = false;
      });
      _escucharVibracionesEnPantalla();
    }
  }

  bool get _conectado {
    return _estadoConexion.toLowerCase().contains('activo') ||
        _estadoConexion.toLowerCase().contains('conectado');
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _conectado
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _conectado ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _conectado ? Icons.wifi : Icons.wifi_off,
                      color: _conectado ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _estadoConexion,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _servicioActivo,
                title: const Text('Mantener activo con pantalla apagada'),
                subtitle: const Text(
                  'Debe quedar una notificación fija. No cierres la app desde recientes.',
                ),
                onChanged: _alternarServicio,
              ),
              const SizedBox(height: 8),
              Text(
                'Si apagas el celular por completo, ninguna app puede vibrar. '
                'Bloquéalo y deja la pantalla apagada con el interruptor activado.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                'Última letra:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
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
              ),
              const SizedBox(height: 32),
              if (_ultimoTimestamp != null)
                Text(
                  'Recibido: ${_ultimoTimestamp.toString().substring(0, 19)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              const SizedBox(height: 16),
              if (_fcmToken != null)
                Text(
                  'FCM Token: ${_fcmToken!.substring(0, 20)}...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


