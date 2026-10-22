import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Vibración',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VibrationApp(),
    );
  }
}

class VibrationApp extends StatelessWidget {
  const VibrationApp({super.key});

  void _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Patrón de vibración que suena como un "buzz"
      // [espera, vibración, espera, vibración, ...]
      final pattern = [0, 100, 50, 100, 50, 100, 50, 100];
      Vibration.vibrate(pattern: pattern);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('App Vibración'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _vibrate,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(30),
            minimumSize: const Size(200, 200),
          ),
          child: const Text(
            'VIBRAR',
            style: TextStyle(fontSize: 30),
          ),
        ),
      ),
    );
  }
}
