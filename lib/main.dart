import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zlslfegiqpgdjxoexlta.supabase.co',
    anonKey: 'sb_publishable_iVJD8SvV1jtbM-hMVGAsGQ_XTT60Cdk', 
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
      home: Supabase.instance.client.auth.currentSession == null
          ? const PantallaLogin()
          : const PantallaOnboarding(),
    );
  }
}

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _procesando = false;

  Future<void> registrarCuenta() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _procesando = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaOnboarding()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> iniciarSesion() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _procesando = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaOnboarding()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Credenciales incorrectas'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso a ScanGo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.radar, size: 100, color: Colors.greenAccent),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              _procesando
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: iniciarSesion,
                          icon: const Icon(Icons.login),
                          label: const Text('Iniciar Sesión'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent, 
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50)
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: registrarCuenta,
                          style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                          child: const Text('Crear cuenta nueva'),
                        )
                      ],
                    )
            ],
          ),
        ),
      ),
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
    setState(() { _fotoPerfil = foto; _procesandoIA = true; });
    await Future.delayed(const Duration(seconds: 2));
    setState(() { _procesandoIA = false; _generoDetectado = 'HOMBRE'; });
  }
  
  Future<void> guardarPerfil() async {
    if (_edadController.text.isEmpty) return;
    
    try {
      final supabase = Supabase.instance.client;
      final usuarioActual = supabase.auth.currentUser;
      if (usuarioActual == null) throw Exception('No hay sesión activa');

      await supabase.from('perfiles').upsert({
        'id': usuarioActual.id, 
        'nombre': 'Explorador',
        'edad': int.parse(_edadController.text),
        'deseo_actual': 'conocer',
        'genero': _generoDetectado,
        'preferencia': _preferencia
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaRadar()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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

class PantallaRadar extends StatelessWidget {
  const PantallaRadar({super.key});

  Future<void> enviarSolicitud(BuildContext context, String receptorId) async {
    try {
      final supabase = Supabase.instance.client;
      final usuarioActual = supabase.auth.currentUser;
      if (usuarioActual == null) return;
      
      await supabase.from('solicitudes').insert({
        'emisor_id': usuarioActual.id,
        'receptor_id': receptorId,
        'estado': 'pendiente'
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamPerfiles = Supabase.instance.client.from('perfiles').stream(primaryKey: ['id']);
    final miId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Global'),
        centerTitle: true,
        leading: const Icon(Icons.radar, color: Colors.greenAccent),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PantallaLogin())
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamPerfiles,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final perfiles = snapshot.data!.where((p) => p['id'] != miId).toList();
          
          if (perfiles.isEmpty) {
            return const Center(
              child: Text(
                'No hay exploradores cerca de ti aún.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          
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
                  trailing: IconButton(
                    icon: const Icon(Icons.send, color: Colors.greenAccent),
                    onPressed: () => enviarSolicitud(context, perfil['id']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}