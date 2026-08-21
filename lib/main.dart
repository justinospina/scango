import 'package:flutter/material.dart';

void main() {
  runApp(const ScanGoApp());
}

class ScanGoApp extends StatelessWidget {
  const ScanGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScanGo',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar, size: 100, color: Colors.greenAccent),
              SizedBox(height: 20),
              Text(
                '¡Bienvenido a ScanGo!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Text('El radar está listo para buscar conexiones...'),
            ],
          ),
        ),
      ),
    );
  }
}