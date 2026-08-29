import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://zlslfegiqpgdjxoexlta.supabase.co',
    anonKey: 'AQUÍ_PEGA_TU_LLAVE_sb_publishable...', 
  );

  runApp(const ScanGoApp());
}

class ScanGoApp extends StatelessWidget {
  const ScanGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanGo',
      theme: ThemeData.dark(),
      home: const PantallaOnboarding(), // Cambiamos el inicio al Onboarding
    );
  }
}

class PantallaOnboarding extends StatefulWidget {
  const PantallaOnboarding({super.key});

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoPerfil;
  bool _procesandoIA = false;
  String? _generoDetectado;
  
  final TextEditingController _edadController = TextEditingController();
  String _preferencia = 'AMBAS';

  // Función 1: Capturar foto y simular IA
  Future<void> procesarFoto() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() {
      _fotoPerfil = foto;
      _procesandoIA = true;
    });

    // Simulamos el retraso de una API de Visión Artificial (ej. Google Vision)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _procesandoIA = false;
      _generoDetectado = 'HOMBRE'; // Aquí vendrá la respuesta real de la IA
    });
  }

  // Función 2: Guardar en Supabase y avanzar
  Future<void> guardarPerfil() async {
    if (_edadController.text.isEmpty) return;
    
    // Aquí enviaremos los datos reales a tu tabla 'perfiles'
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado con éxito'), backgroundColor: Colors.green),
    );
    // Luego navega a PantallaRadar()...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea tu Perfil ScanGo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_fotoPerfil == null)
                ElevatedButton.icon(
                  onPressed: procesarFoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar Foto para Análisis IA'),
                )
              else ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 10),
                if (_procesandoIA)
                  const CircularProgressIndicator()
                else
                  Text('IA Detectó: $_generoDetectado', style: const TextStyle(fontSize: 20)),
              ],
              
              const SizedBox(height: 30),
              
              // Solo mostrar el resto si la IA ya terminó
              if (_generoDetectado != null && !_procesandoIA) ...[
                TextField(
                  controller: _edadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ingresa tu Edad', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _preferencia,
                  decoration: const InputDecoration(labelText: 'Preferencia', border: OutlineInputBorder()),
                  items: ['MUJER', 'HOMBRE', 'AMBAS']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (value) => setState(() => _preferencia = value!),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: guardarPerfil,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  child: const Text('Continuar al Radar'),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}