import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

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
          : const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;
  double? _miLatitud;
  double? _miLongitud;
  Timer? _heartbeatTimer;
  bool _estaDisponible = true;
  
  @override
  void initState() {
    super.initState();
    _obtenerYGuardarGPS();
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _actualizarUltimaConexion();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _cambiarDisponibilidad(bool valor) async {
    setState(() => _estaDisponible = valor);
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId != null) {
      await Supabase.instance.client.from('perfiles').update({'disponible': valor}).eq('id', miId);
    }
  }

  Future<void> _actualizarUltimaConexion() async {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId != null) {
      await Supabase.instance.client.from('perfiles').update({
        'ultima_conexion': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', miId);
    }
  }

  Future<void> _obtenerYGuardarGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Activa el GPS de tu dispositivo'), backgroundColor: Colors.orange));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Permiso de ubicación denegado'), backgroundColor: Colors.red));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Permisos de ubicación bloqueados'), backgroundColor: Colors.red));
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      if (mounted) {
        setState(() {
          _miLatitud = position.latitude;
          _miLongitud = position.longitude;
        });
      }

      final miId = Supabase.instance.client.auth.currentUser?.id;
      if (miId != null) {
        await Supabase.instance.client.from('perfiles').update({
          'latitud': position.latitude,
          'longitud': position.longitude,
          'ultima_conexion': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', miId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📍 Ubicación y estado actualizados'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error GPS: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      PantallaRadar(miLatitud: _miLatitud, miLongitud: _miLongitud),
      const PantallaMiPerfil(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_indiceActual == 0 ? 'Radar' : 'Mi Perfil', style: const TextStyle(fontSize: 18)),
        centerTitle: false,
        leading: Icon(_indiceActual == 0 ? Icons.radar : Icons.account_circle, color: Colors.greenAccent),
        actions: [
          Row(
            children: [
              Text(_estaDisponible ? 'Disponible' : 'Ocupado', style: TextStyle(color: _estaDisponible ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _estaDisponible,
                activeColor: Colors.greenAccent,
                inactiveThumbColor: Colors.redAccent,
                onChanged: _cambiarDisponibilidad,
              ),
            ],
          ),
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
      body: IndexedStack(
        index: _indiceActual,
        children: pantallas,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.grey[900],
        onTap: (index) => setState(() => _indiceActual = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mi Perfil'),
        ],
      ),
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
      await Supabase.instance.client.auth.signInWithPassword(email: emailLimpio, password: passwordLimpio);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PantallaPrincipal()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciales incorrectas'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
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
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder())),
              const SizedBox(height: 25),
              _procesando
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: iniciarSesion,
                          icon: const Icon(Icons.login),
                          label: const Text('Iniciar Sesión'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaRegistro())),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos y toma tu foto'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _procesando = true);

    try {
      final supabase = Supabase.instance.client;
      final respuesta = await supabase.auth.signUp(email: email, password: password);
      final usuarioNuevo = respuesta.user;
      if (usuarioNuevo == null) throw Exception('Error al generar sesión');

      final fileName = '${usuarioNuevo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (!kIsWeb) {
        await supabase.storage.from('fotos-perfil').upload(fileName, File(_fotoPerfil!.path));
      } else {
        await supabase.storage.from('fotos-perfil').uploadBinary(fileName, await _fotoPerfil!.readAsBytes());
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
        'ultima_conexion': DateTime.now().toUtc().toIso8601String(),
        'disponible': true,
      });

      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PantallaPrincipal()), (route) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
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
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Tu Nombre', border: OutlineInputBorder())),
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
                if (_procesandoIA) const CircularProgressIndicator()
                else Text('IA Detectó: $_generoDetectado', style: const TextStyle(fontSize: 20, color: Colors.greenAccent)),
              ],
              const SizedBox(height: 25),
              if (_generoDetectado != null && !_procesandoIA) ...[
                TextField(controller: _edadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ingresa tu Edad', border: OutlineInputBorder())),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _preferencia,
                  decoration: const InputDecoration(labelText: 'Preferencia', border: OutlineInputBorder()),
                  items: ['MUJER', 'HOMBRE', 'AMBAS'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                  onChanged: (value) => setState(() => _preferencia = value!),
                ),
                const SizedBox(height: 30),
                _procesando
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: registrarYGuardar,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
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

class PantallaRadar extends StatefulWidget {
  final double? miLatitud;
  final double? miLongitud;
  const PantallaRadar({super.key, this.miLatitud, this.miLongitud});

  @override
  State<PantallaRadar> createState() => _PantallaRadarState();
}

class _PantallaRadarState extends State<PantallaRadar> {
  StreamSubscription? _solicitudesSubscription;
  RealtimeChannel? _perfilesChannel;
  final Set<String> _solicitudesNotificadas = {};
  final Set<String> _exploradoresCercanosNotificados = {};
  final AudioPlayer _audioPlayer = AudioPlayer(); 

  @override
  void initState() {
    super.initState();
    _escucharSolicitudesEntrantes();
    _escucharExploradoresCercanos();
  }

  void _escucharExploradoresCercanos() {
    _perfilesChannel = Supabase.instance.client
        .channel('public:perfiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'perfiles',
          callback: (payload) {
            final nuevoPerfil = payload.newRecord;
            final miId = Supabase.instance.client.auth.currentUser?.id;
            
            if (miId == null || nuevoPerfil['id'] == miId) return;

            if (widget.miLatitud != null && widget.miLongitud != null && 
                nuevoPerfil['latitud'] != null && nuevoPerfil['longitud'] != null) {
              
              final distMetros = Geolocator.distanceBetween(
                widget.miLatitud!, widget.miLongitud!,
                (nuevoPerfil['latitud'] as num).toDouble(),
                (nuevoPerfil['longitud'] as num).toDouble()
              );

              if (distMetros <= 5000 && nuevoPerfil['disponible'] != false) {
                final perfilId = nuevoPerfil['id'].toString();
                if (!_exploradoresCercanosNotificados.contains(perfilId)) {
                  _exploradoresCercanosNotificados.add(perfilId);
                  _mostrarNotificacionCercania(nuevoPerfil['nombre'] ?? 'Alguien', distMetros);
                }
              }
            }
          },
        )
        .subscribe();
  }

  void _mostrarNotificacionCercania(String nombre, double distMetros) {
    final distKm = (distMetros / 1000).toStringAsFixed(1);
    HapticFeedback.lightImpact();
    _audioPlayer.play(AssetSource('sonidos/notificacion.mp3')).catchError((_) {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 ¡$nombre acaba de conectarse! Está a $distKm km de ti.'),
          backgroundColor: Colors.blueAccent,
          duration: const Duration(seconds: 4),
        )
      );
    }
  }

  void _escucharSolicitudesEntrantes() {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId == null) return;

    _solicitudesSubscription = Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']).listen((solicitudes) async {
      for (var s in solicitudes) {
        if (s['receptor_id'] == miId && s['estado'] == 'pendiente') {
          final solicitudId = s['id'].toString();
          if (!_solicitudesNotificadas.contains(solicitudId)) {
            _solicitudesNotificadas.add(solicitudId);
            final emisorData = await Supabase.instance.client.from('perfiles').select().eq('id', s['emisor_id']).maybeSingle();
            if (emisorData != null && mounted) _mostrarAlertaSolicitud(context, solicitudId, emisorData);
          }
        }
      }
    });
  }

  void _mostrarAlertaSolicitud(BuildContext context, String solicitudId, Map<String, dynamic> emisor) {
    HapticFeedback.heavyImpact();
    _audioPlayer.play(AssetSource('sonidos/notificacion.mp3')).catchError((_) {});

    final fotoUrl = emisor['foto_url']?.toString();
    final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('¡Nueva solicitud!', style: TextStyle(color: Colors.greenAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 45, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, size: 45, color: Colors.black) : null),
              const SizedBox(height: 15),
              Text('${emisor['nombre']} (${emisor['edad']} años)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Quiere conectar contigo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Supabase.instance.client.from('solicitudes').update({'estado': 'rechazada'}).eq('id', solicitudId);
              },
              child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(context);
                await Supabase.instance.client.from('solicitudes').update({'estado': 'aceptada'}).eq('id', solicitudId);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _solicitudesSubscription?.cancel();
    _perfilesChannel?.unsubscribe();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> enviarSolicitud(BuildContext context, String receptorId) async {
    try {
      final supabase = Supabase.instance.client;
      final usuarioActual = supabase.auth.currentUser;
      if (usuarioActual == null) return;
      await supabase.from('solicitudes').insert({'emisor_id': usuarioActual.id, 'receptor_id': receptorId, 'estado': 'pendiente'});
      
      HapticFeedback.mediumImpact();
      _audioPlayer.play(AssetSource('sonidos/envio.mp3')).catchError((_) {});

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Solicitud enviada exitosamente'), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarPerfilDetallado(BuildContext context, Map<String, dynamic> perfil, String distanciaTxt, bool esActivo) {
    final fotoUrl = perfil['foto_url']?.toString();
    final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  CircleAvatar(radius: 50, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, size: 50, color: Colors.black) : null),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: esActivo ? Colors.greenAccent : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 3)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text('${perfil['nombre']}, ${perfil['edad']} años', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(distanciaTxt, style: const TextStyle(fontSize: 14, color: Colors.orangeAccent)),
              const SizedBox(height: 8),
              Text('Desea: ${perfil['deseo_actual']}', style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  enviarSolicitud(context, perfil['id']);
                },
                icon: const Icon(Icons.send),
                label: const Text('Enviar Solicitud'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: streamPerfiles,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Filtramos a nosotros mismos y a los usuarios con disponible = false
        final perfiles = snapshot.data!.where((p) => p['id'] != miId && p['disponible'] != false).toList();
        
        if (widget.miLatitud != null && widget.miLongitud != null) {
          perfiles.sort((a, b) {
            final latA = (a['latitud'] as num?)?.toDouble();
            final lonA = (a['longitud'] as num?)?.toDouble();
            final latB = (b['latitud'] as num?)?.toDouble();
            final lonB = (b['longitud'] as num?)?.toDouble();
            if (latA == null || lonA == null) return 1;
            if (latB == null || lonB == null) return -1;

            final distA = Geolocator.distanceBetween(widget.miLatitud!, widget.miLongitud!, latA, lonA);
            final distB = Geolocator.distanceBetween(widget.miLatitud!, widget.miLongitud!, latB, lonB);
            return distA.compareTo(distB);
          });
        }

        if (perfiles.isEmpty) {
          return const Center(child: Text('No hay exploradores cerca de ti aún.', style: TextStyle(fontSize: 18, color: Colors.grey)));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: perfiles.length,
          itemBuilder: (context, index) {
            final perfil = perfiles[index];
            final fotoUrl = perfil['foto_url']?.toString();
            final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

            bool esActivo = false;
            if (perfil['ultima_conexion'] != null) {
              final ultimaConexion = DateTime.parse(perfil['ultima_conexion']);
              esActivo = DateTime.now().toUtc().difference(ultimaConexion).inMinutes <= 15;
            }

            String distanciaTxt = '📍 Ubicación desconocida';
            if (widget.miLatitud != null && widget.miLongitud != null && perfil['latitud'] != null && perfil['longitud'] != null) {
              final distanciaMetros = Geolocator.distanceBetween(
                widget.miLatitud!, widget.miLongitud!, 
                (perfil['latitud'] as num).toDouble(), (perfil['longitud'] as num).toDouble()
              );
              final distanciaKm = (distanciaMetros / 1000).toStringAsFixed(1);
              distanciaTxt = '📍 A $distanciaKm km de distancia';
            }

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 15),
              child: ListTile(
                onTap: () => _mostrarPerfilDetallado(context, perfil, distanciaTxt, esActivo),
                leading: Stack(
                  children: [
                    CircleAvatar(backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, color: Colors.black) : null),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(color: esActivo ? Colors.greenAccent : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 2)),
                      ),
                    )
                  ],
                ),
                title: Text('${perfil['nombre']} • ${perfil['edad']} años', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desea: ${perfil['deseo_actual']}'),
                    Text(distanciaTxt, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ],
                ),
                trailing: IconButton(icon: const Icon(Icons.send, color: Colors.greenAccent), onPressed: () => enviarSolicitud(context, perfil['id'])),
              ),
            );
          },
        );
      },
    );
  }
}

class PantallaMiPerfil extends StatefulWidget {
  const PantallaMiPerfil({super.key});

  @override
  State<PantallaMiPerfil> createState() => _PantallaMiPerfilState();
}

class _PantallaMiPerfilState extends State<PantallaMiPerfil> {
  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  final _deseoController = TextEditingController();
  String? _preferencia;
  String? _fotoUrl;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarMiPerfil();
  }

  Future<void> _cargarMiPerfil() async {
    try {
      final miId = Supabase.instance.client.auth.currentUser?.id;
      if (miId == null) return;
      final perfil = await Supabase.instance.client.from('perfiles').select().eq('id', miId).maybeSingle();
      if (mounted) {
        if (perfil != null) {
          setState(() {
            _nombreController.text = perfil['nombre'] ?? '';
            _edadController.text = perfil['edad']?.toString() ?? '';
            _deseoController.text = perfil['deseo_actual'] ?? '';
            _preferencia = perfil['preferencia'] ?? 'AMBAS';
            _fotoUrl = perfil['foto_url'];
          });
        }
        setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar perfil: $e')));
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarCambios() async {
    final nombre = _nombreController.text.trim();
    final edad = _edadController.text.trim();
    final deseo = _deseoController.text.trim();

    if (nombre.isEmpty || edad.isEmpty || deseo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos')));
      return;
    }
    setState(() => _guardando = true);

    try {
      final miId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('perfiles').upsert({
        'id': miId,
        'nombre': nombre,
        'edad': int.parse(edad),
        'deseo_actual': deseo,
        'preferencia': _preferencia,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil guardado con éxito'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final tieneFoto = _fotoUrl != null && _fotoUrl!.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(radius: 60, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(_fotoUrl!) : null, child: !tieneFoto ? const Icon(Icons.person, size: 60, color: Colors.black) : null),
          const SizedBox(height: 25),
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Tu Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _edadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Edad', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _deseoController, decoration: const InputDecoration(labelText: '¿Qué deseas actualmente?', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _preferencia,
            decoration: const InputDecoration(labelText: 'Preferencia de búsqueda', border: OutlineInputBorder()),
            items: ['MUJER', 'HOMBRE', 'AMBAS'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
            onChanged: (value) => setState(() => _preferencia = value),
          ),
          const SizedBox(height: 30),
          _guardando
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(onPressed: _guardarCambios, icon: const Icon(Icons.save), label: const Text('Guardar Cambios'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)))
        ],
      ),
    );
  }
}

class PantallaSolicitudes extends StatelessWidget {
  const PantallaSolicitudes({super.key});

  Future<void> actualizarEstado(String solicitudId, String nuevoEstado) async {
    await Supabase.instance.client.from('solicitudes').update({'estado': nuevoEstado}).eq('id', solicitudId);
  }

  Future<void> _eliminarChat(BuildContext context, String solicitudId, String otroId, String miId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Eliminar chat?', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Esto borrará el historial de mensajes permanentemente para ambos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ],
      )
    );

    if (confirmar == true) {
      await Supabase.instance.client.from('solicitudes').delete().eq('id', solicitudId);
      await Supabase.instance.client.from('mensajes').delete().or('and(emisor_id.eq.$miId,receptor_id.eq.$otroId),and(emisor_id.eq.$otroId,receptor_id.eq.$miId)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamSolicitudes = Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes y Chats')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamSolicitudes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final solicitudes = snapshot.data!;
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client.from('perfiles').select(),
            builder: (context, perfilSnapshot) {
              if (!perfilSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final perfilesMap = {for (var p in perfilSnapshot.data!) p['id']: p};
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Solicitudes Pendientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
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
                            IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => actualizarEstado(s['id'], 'aceptada')),
                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => actualizarEstado(s['id'], 'rechazada')),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                  const Text('Chats Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ...solicitudes.where((s) => (s['emisor_id'] == miId || s['receptor_id'] == miId) && s['estado'] == 'aceptada').map((s) {
                    final otroId = s['emisor_id'] == miId ? s['receptor_id'] : s['emisor_id'];
                    final otroPerfil = perfilesMap[otroId] ?? {};
                    final fotoUrl = otroPerfil['foto_url']?.toString();
                    return Card(
                      color: Colors.grey[900],
                      child: ListTile(
                        leading: CircleAvatar(backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null, child: fotoUrl == null ? const Icon(Icons.person) : null),
                        title: Text(otroPerfil['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white)),
                        subtitle: const Text('Toca para abrir el chat'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          onPressed: () => _eliminarChat(context, s['id'].toString(), otroId, miId!),
                        ),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: otroId, receptorNombre: otroPerfil['nombre'] ?? 'Explorador')));
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
  final AudioPlayer _audioPlayer = AudioPlayer(); 

  Future<void> enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty) return;
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId == null) return;
    _mensajeController.clear();
    
    await Supabase.instance.client.from('mensajes').insert({'emisor_id': miId, 'receptor_id': widget.receptorId, 'contenido': texto});
    
    HapticFeedback.lightImpact();
    _audioPlayer.play(AssetSource('sonidos/envio.mp3')).catchError((_) {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Mensaje enviado'), backgroundColor: Colors.black87, duration: Duration(milliseconds: 800))
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamMensajes = Supabase.instance.client.from('mensajes').stream(primaryKey: ['id']).order('created_at', ascending: true);

    return Scaffold(
      appBar: AppBar(title: Text('Chat con ${widget.receptorNombre}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: streamMensajes,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final mensajes = snapshot.data!.where((m) => (m['emisor_id'] == miId && m['receptor_id'] == widget.receptorId) || (m['emisor_id'] == widget.receptorId && m['receptor_id'] == miId)).toList();

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
                        decoration: BoxDecoration(color: esMio ? Colors.green[800] : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                        child: Text(mensaje['contenido'] ?? '', style: const TextStyle(color: Colors.white)),
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
                Expanded(child: TextField(controller: _mensajeController, decoration: const InputDecoration(hintText: 'Mensaje...', border: OutlineInputBorder()))),
                IconButton(icon: const Icon(Icons.send, color: Colors.greenAccent), onPressed: enviarMensaje),
              ],
            ),
          ),
        ],
      ),
    );
  }
}