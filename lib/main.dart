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
      home: const PantallaOnboarding(),
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

  Future<void> procesarFoto() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() {
      _fotoPerfil = foto;
      _procesandoIA = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _procesandoIA = false;
      _generoDetectado = 'HOMBRE'; 
    });
  }

  // Se movió la función dentro de la clase para acceder al context y las variables
  Future<void> guardarPerfil() async {
    if (_edadController.text.isEmpty) return;
    
    final supabase = Supabase.instance.client;
    await supabase.from('perfiles').insert({
      'id': DateTime.now().millisecondsSinceEpoch, 
      'nombre': 'Nuevo Explorador',
      'edad': int.parse(_edadController.text),
      'deseo_actual': 'conocer' 
    });

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PantallaRadar()),
      );
    }
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

// Clase faltante añadida para el StreamBuilder del Radar
class PantallaRadar extends StatelessWidget {
  const PantallaRadar({super.key});

  @override
  Widget build(BuildContext context) {
    final streamPerfiles = Supabase.instance.client.from('perfiles').stream(primaryKey: ['id']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Activo'),
        centerTitle: true,
        leading: const Icon(Icons.radar, color: Colors.greenAccent),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamPerfiles,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final perfiles = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: perfiles.length,
            itemBuilder: (context, index) {
              final perfil = perfiles[index];
              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.greenAccent,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  title: Text('${perfil['nombre']} • ${perfil['edad']} años', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('Desea: ${perfil['deseo_actual']}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}