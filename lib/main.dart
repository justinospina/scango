import 'dart:io';
import 'package:flutter/foundation.dart';
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
          : const PantallaRadar(),
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

  Future<void> iniciarSesion() async {
    final emailLimpio = _emailController.text.trim();
    final passwordLimpio = _passwordController.text.trim();

    if (emailLimpio.isEmpty || passwordLimpio.isEmpty) return;
    setState(() => _procesando = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailLimpio,
        password: passwordLimpio,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaRadar()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas'), backgroundColor: Colors.red),
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
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PantallaRegistro()),
                            );
                          },
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

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoPerfil;
  bool _procesando = false;
  bool _procesandoIA = false;
  String? _generoDetectado;
  String _preferencia = 'AMBAS';

  Future<void> procesarFoto() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera, maxWidth: 600);
    if (foto == null) return;
    setState(() { _fotoPerfil = foto; _procesandoIA = true; });
    await Future.delayed(const Duration(seconds: 2));
    setState(() { _procesandoIA = false; _generoDetectado = 'HOMBRE'; });
  }

  Future<void> registrarYGuardar() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final nombre = _nombreController.text.trim();
    final edad = _edadController.text.trim();

    if (email.isEmpty || password.isEmpty || nombre.isEmpty || edad.isEmpty || _generoDetectado == null || _fotoPerfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos y toma tu foto'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      final supabase = Supabase.instance.client;
      
      final respuesta = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final usuarioNuevo = respuesta.user;
      if (usuarioNuevo == null) throw Exception('Error al generar la sesión en Supabase');

      final fileName = '${usuarioNuevo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (!kIsWeb) {
        final file = File(_fotoPerfil!.path);
        await supabase.storage.from('fotos-perfil').upload(fileName, file);
      } else {
        final bytes = await _fotoPerfil!.readAsBytes();
        await supabase.storage.from('fotos-perfil').uploadBinary(fileName, bytes);
      }

      final fotoUrl = supabase.storage.from('fotos-perfil').getPublicUrl(fileName);

      await supabase.from('perfiles').upsert({
        'id': usuarioNuevo.id, 
        'nombre': nombre,
        'edad': int.parse(edad),
        'deseo_actual': 'conocer',
        'genero': _generoDetectado,
        'preferencia': _preferencia,
        'foto_url': fotoUrl,
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaRadar()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    _nombreController.dispose();
    _edadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea tu Cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const SizedBox(height: 15),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Tu Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              if (_fotoPerfil == null)
                ElevatedButton.icon(
                  onPressed: procesarFoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar Foto para Análisis IA'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                )
              else ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 10),
                if (_procesandoIA)
                  const CircularProgressIndicator()
                else
                  Text('IA Detectó: $_generoDetectado', style: const TextStyle(fontSize: 20, color: Colors.greenAccent)),
              ],
              const SizedBox(height: 25),
              if (_generoDetectado != null && !_procesandoIA) ...[
                TextField(
                  controller: _edadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ingresa tu Edad', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _preferencia,
                  decoration: const InputDecoration(labelText: 'Preferencia', border: OutlineInputBorder()),
                  items: ['MUJER', 'HOMBRE', 'AMBAS']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (value) => setState(() => _preferencia = value!),
                ),
                const SizedBox(height: 30),
                _procesando
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: registrarYGuardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent, 
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50)
                        ),
                        child: const Text('Completar Registro'),
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
          const SnackBar(content: Text('Solicitud enviada con éxito'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar solicitud: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarPerfilDetallado(BuildContext context, Map<String, dynamic> perfil) {
    final fotoUrl = perfil['foto_url']?.toString();
    final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.greenAccent,
                backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null,
                child: !tieneFoto ? const Icon(Icons.person, size: 50, color: Colors.black) : null,
              ),
              const SizedBox(height: 16),
              Text(
                '${perfil['nombre']}, ${perfil['edad']} años',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Género: ${perfil['genero'] ?? 'No especificado'}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Desea: ${perfil['deseo_actual']}',
                style: const TextStyle(fontSize: 16, color: Colors.greenAccent),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  enviarSolicitud(context, perfil['id']);
                },
                icon: const Icon(Icons.send),
                label: const Text('Enviar Solicitud de Conexión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        );
      },
    );
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
          // Botón para ver la bandeja de solicitudes y chats activos
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaSolicitudes()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PantallaLogin()),
                  (route) => false,
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
              final fotoUrl = perfil['foto_url']?.toString();
              final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  onTap: () => _mostrarPerfilDetallado(context, perfil),
                  leading: CircleAvatar(
                    backgroundColor: Colors.greenAccent,
                    backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null,
                    child: !tieneFoto ? const Icon(Icons.person, color: Colors.black) : null,
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

class PantallaSolicitudes extends StatelessWidget {
  const PantallaSolicitudes({super.key});

  Future<void> actualizarEstado(String solicitudId, String nuevoEstado) async {
    await Supabase.instance.client
        .from('solicitudes')
        .update({'estado': nuevoEstado})
        .eq('id', solicitudId);
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamSolicitudes = Supabase.instance.client
        .from('solicitudes')
        .stream(primaryKey: ['id']);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes y Chats')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamSolicitudes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filtramos solicitudes donde somos el receptor (pendientes) o donde ya fueron aceptadas
          final solicitudes = snapshot.data!;
          
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client.from('perfiles').select(),
            builder: (context, perfilSnapshot) {
              if (!perfilSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final perfilesMap = {for (var p in perfilSnapshot.data!) p['id']: p};

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Solicitudes Recibidas (Pendientes)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  const SizedBox(height: 10),
                  ...solicitudes.where((s) => s['receptor_id'] == miId && s['estado'] == 'pendiente').map((s) {
                    final emisor = perfilesMap[s['emisor_id']] ?? {};
                    return Card(
                      color: Colors.grey[850],
                      child: ListTile(
                        title: Text(emisor['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white)),
                        subtitle: const Text('Quiere conectar contigo'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => actualizarEstado(s['id'], 'aceptada'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => actualizarEstado(s['id'], 'rechazada'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                  const Text('Chats Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  const SizedBox(height: 10),
                  ...solicitudes.where((s) => (s['emisor_id'] == miId || s['receptor_id'] == miId) && s['estado'] == 'aceptada').map((s) {
                    final otroId = s['emisor_id'] == miId ? s['receptor_id'] : s['emisor_id'];
                    final otroPerfil = perfilesMap[otroId] ?? {};
                    final fotoUrl = otroPerfil['foto_url']?.toString();
                    final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

                    return Card(
                      color: Colors.grey[900],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null,
                          child: !tieneFoto ? const Icon(Icons.person) : null,
                        ),
                        title: Text(otroPerfil['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white)),
                        subtitle: const Text('Toca para abrir el chat instantáneo'),
                        trailing: const Icon(Icons.message, color: Colors.greenAccent),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PantallaChat(
                                receptorId: otroId,
                                receptorNombre: otroPerfil['nombre'] ?? 'Explorador',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PantallaChat extends StatefulWidget {
  final String receptorId;
  final String receptorNombre;

  const PantallaChat({super.key, required this.receptorId, required this.receptorNombre});

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty) return;

    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId == null) return;

    _mensajeController.clear();

    try {
      await Supabase.instance.client.from('mensajes').insert({
        'emisor_id': miId,
        'receptor_id': widget.receptorId,
        'contenido': texto,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamMensajes = Supabase.instance.client
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);

    return Scaffold(
      appBar: AppBar(title: Text('Chat con ${widget.receptorNombre}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: streamMensajes,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final mensajes = snapshot.data!.where((m) =>
                    (m['emisor_id'] == miId && m['receptor_id'] == widget.receptorId) ||
                    (m['emisor_id'] == widget.receptorId && m['receptor_id'] == miId)).toList();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = mensajes[index];
                    final esMio = mensaje['emisor_id'] == miId;

                    return Align(
                      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: esMio ? Colors.green[800] : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mensaje['contenido'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: enviarMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}