import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Conexión directa a tu proyecto de Supabase
  await Supabase.initialize(
    url: 'https://zlslfegiqpgdjxoexlta.supabase.co',
    anonKey: 'AQUÍ_PEGA_TU_LLAVE_sb_publishable...', // <-- Reemplaza con tu llave
  );

  runApp(const ScanGoApp());
}

class ScanGoApp extends StatelessWidget {
  const ScanGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanGo',
      theme: ThemeData.dark(), // Tema oscuro del radar
      home: const PantallaRadar(),
    );
  }
}

// Separamos la pantalla en su propio widget para mayor orden
class PantallaRadar extends StatelessWidget {
  const PantallaRadar({super.key});

  // Función para enviar el usuario de prueba a la base de datos
  Future<void> crearUsuarioPrueba(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('perfiles').insert({
        'id': 1,
        'nombre': 'Andrés',
        'edad': 25,
        'deseo_actual': 'bailar' 
      });
      
      // Muestra un mensaje verde de éxito en la pantalla
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Usuario de prueba insertado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      // Muestra un mensaje rojo si algo falla
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al insertar: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, color: Colors.greenAccent, size: 80),
            const SizedBox(height: 20),
            const Text(
              '¡Bienvenido a ScanGo!\nServidor Conectado',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 40),
            // Botón para probar la conexión y enviar el registro
            ElevatedButton.icon(
              onPressed: () => crearUsuarioPrueba(context),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Enviar Usuario de Prueba (REQ02)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}