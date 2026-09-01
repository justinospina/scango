import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

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

// ==================== PANTALLA PRINCIPAL ====================
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => PantallaPrincipalState();
}

class PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;
  double? _miLatitud;
  double? _miLongitud;
  Timer? _heartbeatTimer;
  bool _yaPreguntoDeseo = false;

  static bool deseoCompletado = false;

  @override
  void initState() {
    super.initState();
    deseoCompletado = false;
    _obtenerYGuardarGPS();

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _actualizarUltimaConexion();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preguntarDeseoDeHoy();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _preguntarDeseoDeHoy() {
    if (_yaPreguntoDeseo) return;
    _yaPreguntoDeseo = true;

    final deseoController = TextEditingController();

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('🌟 ¿Cuál es tu deseo de hoy?', style: TextStyle(color: Colors.greenAccent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Actualiza tu estado para que otros sepan qué buscas hacer el día de hoy.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 20),
                TextField(
                  controller: deseoController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Ej. Tomar un café...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.greenAccent), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  deseoCompletado = true;
                  Navigator.pop(context);
                },
                child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                onPressed: () async {
                  final nuevoDeseo = deseoController.text.trim();
                  if (nuevoDeseo.isEmpty) {
                    deseoCompletado = true;
                    Navigator.pop(context);
                    return;
                  }

                  try {
                    final miId = Supabase.instance.client.auth.currentUser?.id;
                    if (miId != null) {
                      await Supabase.instance.client.from('perfiles').update({'deseo_actual': nuevoDeseo}).eq('id', miId);
                    }
                    if (mounted) {
                      deseoCompletado = true;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Deseo actualizado'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                    }
                  } catch (e) {
                    if (mounted) {
                      deseoCompletado = true;
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Actualizar'),
              ),
            ],
          );
        });
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
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
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
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;

    final List<Widget> pantallas = [
      PantallaRadar(miLatitud: _miLatitud, miLongitud: _miLongitud),
      const PantallaSolicitudesYChats(),
      const PantallaMiPerfil(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_indiceActual == 0 ? 'Radar Global' : (_indiceActual == 1 ? 'Solicitudes y Chats' : 'Mi Perfil')),
        centerTitle: true,
        leading: Icon(_indiceActual == 0 ? Icons.radar : (_indiceActual == 1 ? Icons.chat_bubble : Icons.account_circle), color: Colors.greenAccent),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PantallaLogin()), (route) => false);
              }
            },
          )
        ],
      ),
      body: IndexedStack(
        index: _indiceActual,
        children: pantallas,
      ),
      bottomNavigationBar: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']),
        builder: (context, snapshotSolicitudes) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('mensajes').stream(primaryKey: ['id']),
            builder: (context, snapshotMensajes) {
              int notificacionesTotales = 0;

              if (miId != null) {
                int solicitudesPendientes = 0;
                int mensajesNoLeidos = 0;

                if (snapshotSolicitudes.hasData) {
                  final pendientes = snapshotSolicitudes.data!.where((s) => s['receptor_id'] == miId && s['estado'] == 'pendiente');
                  final pendientesUnicas = <String>{};
                  for (var p in pendientes) pendientesUnicas.add(p['emisor_id']);
                  solicitudesPendientes = pendientesUnicas.length;
                }

                if (snapshotMensajes.hasData && snapshotSolicitudes.hasData) {
                  final chatsActivosIds = snapshotSolicitudes.data!
                      .where((s) => (s['emisor_id'] == miId || s['receptor_id'] == miId) && s['estado'] == 'aceptada')
                      .map((s) => s['emisor_id'] == miId ? s['receptor_id'] : s['emisor_id'])
                      .toSet();

                  mensajesNoLeidos = snapshotMensajes.data!
                      .where((m) => m['receptor_id'] == miId && chatsActivosIds.contains(m['emisor_id']) && m['leido'] == false)
                      .length;
                }
                notificacionesTotales = solicitudesPendientes + mensajesNoLeidos;
              }

              return BottomNavigationBar(
                currentIndex: _indiceActual,
                selectedItemColor: Colors.greenAccent,
                unselectedItemColor: Colors.grey,
                backgroundColor: Colors.grey[900],
                onTap: (index) => setState(() => _indiceActual = index),
                items: [
                  const BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
                  BottomNavigationBarItem(
                    icon: Badge(
                      backgroundColor: Colors.red,
                      isLabelVisible: notificacionesTotales > 0,
                      label: Text('$notificacionesTotales', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      child: const Icon(Icons.chat_bubble),
                    ),
                    label: 'Solicitudes',
                  ),
                  const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mi Perfil'),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ==================== PANTALLA LOGIN ====================
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
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PantallaPrincipal()));
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
                        ElevatedButton.icon(onPressed: iniciarSesion, icon: const Icon(Icons.login), label: const Text('Iniciar Sesión'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50))),
                        const SizedBox(height: 10),
                        TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaRegistro())), style: TextButton.styleFrom(foregroundColor: Colors.greenAccent), child: const Text('Crear cuenta nueva'))
                      ],
                    )
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PANTALLA REGISTRO ====================
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

    if (email.isEmpty || password.isEmpty || nombre.isEmpty || edad.isEmpty || _generoDetectado == null || _fotoPerfil == null) return;
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
                ElevatedButton.icon(onPressed: procesarFoto, icon: const Icon(Icons.camera_alt), label: const Text('Tomar Foto para Análisis IA'), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white))
              else ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 10),
                if (_procesandoIA) const CircularProgressIndicator(),
              ],
              const SizedBox(height: 25),
              if (_generoDetectado != null && !_procesandoIA) ...[
                DropdownButtonFormField<String>(
                  value: _generoDetectado,
                  decoration: const InputDecoration(labelText: 'Confirma tu Género', border: OutlineInputBorder()),
                  items: ['MUJER', 'HOMBRE'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                  onChanged: (value) => setState(() => _generoDetectado = value!),
                ),
                const SizedBox(height: 15),
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
                    : ElevatedButton(onPressed: registrarYGuardar, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)), child: const Text('Completar Registro'))
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PANTALLA RADAR ====================
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
  final Set<String> _solicitudesAceptadasNotificadas = {};
  final Set<String> _exploradoresCercanosNotificados = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _dialogoMultiplesAbierto = false;

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

            if (widget.miLatitud != null && widget.miLongitud != null && nuevoPerfil['latitud'] != null && nuevoPerfil['longitud'] != null) {
              final distMetros = Geolocator.distanceBetween(widget.miLatitud!, widget.miLongitud!, (nuevoPerfil['latitud'] as num).toDouble(), (nuevoPerfil['longitud'] as num).toDouble());
              if (distMetros <= 5000) {
                final perfilId = nuevoPerfil['id'].toString();
                if (!_exploradoresCercanosNotificados.contains(perfilId)) {
                  _exploradoresCercanosNotificados.add(perfilId);
                  _mostrarNotificacionCercania(nuevoPerfil['nombre'] ?? 'Alguien', distMetros);
                }
              }
            }
          },
        ).subscribe();
  }

  void _mostrarNotificacionCercania(String nombre, double distMetros) {
    if (!PantallaPrincipalState.deseoCompletado) return;
    final distKm = (distMetros / 1000).toStringAsFixed(1);
    HapticFeedback.lightImpact();
    _audioPlayer.play(AssetSource('sonidos/notificacion.mp3')).catchError((_) {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📍 ¡$nombre acaba de conectarse! Está a $distKm km de ti.'), backgroundColor: Colors.blueAccent, duration: const Duration(seconds: 4)));
    }
  }

  void _escucharSolicitudesEntrantes() {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId == null) return;

    _solicitudesSubscription = Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']).listen((solicitudes) async {
      while (!PantallaPrincipalState.deseoCompletado) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      }

      final nuevasPendientes = <Map<String, dynamic>>[];

      for (var s in solicitudes) {
        final solicitudId = s['id'].toString();

        if (s['receptor_id'] == miId && s['estado'] == 'pendiente') {
          if (!_solicitudesNotificadas.contains(solicitudId)) {
            _solicitudesNotificadas.add(solicitudId);
            nuevasPendientes.add(s);
          }
        }

        if (s['emisor_id'] == miId && s['estado'] == 'aceptada') {
          if (!_solicitudesAceptadasNotificadas.contains(solicitudId)) {
            _solicitudesAceptadasNotificadas.add(solicitudId);
            final receptorData = await Supabase.instance.client.from('perfiles').select().eq('id', s['receptor_id']).maybeSingle();
            if (receptorData != null && mounted) {
              _mostrarAlertaSolicitudAceptada(context, receptorData);
            }
          }
        }
      }

      if (nuevasPendientes.isNotEmpty && mounted && !_dialogoMultiplesAbierto) {
        _mostrarAlertaMultiplesSolicitudes(context, nuevasPendientes);
      }
    });
  }

  void _mostrarAlertaMultiplesSolicitudes(BuildContext context, List<Map<String, dynamic>> pendientes) {
    _dialogoMultiplesAbierto = true;
    HapticFeedback.heavyImpact();
    _audioPlayer.play(AssetSource('sonidos/notificacion.mp3')).catchError((_) {});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('¡Nuevas Solicitudes!', style: TextStyle(color: Colors.greenAccent)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pendientes.length,
              itemBuilder: (context, index) {
                final s = pendientes[index];
                return FutureBuilder<Map<String, dynamic>?>(
                    future: Supabase.instance.client.from('perfiles').select().eq('id', s['emisor_id']).maybeSingle(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final emisor = snapshot.data!;
                      final fotoUrl = emisor['foto_url']?.toString();
                      final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

                      return Card(
                        color: Colors.grey[850],
                        child: ListTile(
                          leading: CircleAvatar(backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person) : null),
                          title: Text('${emisor['nombre']}'),
                          subtitle: const Text('Quiere conectar'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () async {
                                    await Supabase.instance.client.from('solicitudes').update({'estado': 'rechazada'}).eq('id', s['id']);
                                    if (pendientes.length == 1) Navigator.pop(context);
                                  }),
                              IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () async {
                                    await Supabase.instance.client.from('solicitudes').update({'estado': 'aceptada'}).eq('id', s['id']);
                                    if (pendientes.length == 1) Navigator.pop(context);
                                  }),
                            ],
                          ),
                        ),
                      );
                    });
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  _dialogoMultiplesAbierto = false;
                  Navigator.pop(context);
                },
                child: const Text('Cerrar'))
          ],
        );
      },
    ).then((_) => _dialogoMultiplesAbierto = false);
  }

  void _mostrarAlertaSolicitudAceptada(BuildContext context, Map<String, dynamic> receptor) {
    HapticFeedback.heavyImpact();
    _audioPlayer.play(AssetSource('sonidos/notificacion.mp3')).catchError((_) {});

    final fotoUrl = receptor['foto_url']?.toString();
    final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 45, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, size: 45, color: Colors.black) : null),
                      const SizedBox(height: 15),
                      Text('${receptor['nombre']} (${receptor['edad']} años)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text('Ha aceptado tu solicitud. ¡Ya pueden chatear!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: receptor['id'], receptorNombre: receptor['nombre'] ?? 'Explorador', receptorFoto: fotoUrl)));
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Abrir Chat Ahora'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
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

      final existentes = await supabase.from('solicitudes').select().or('and(emisor_id.eq.${usuarioActual.id},receptor_id.eq.$receptorId),and(emisor_id.eq.$receptorId,receptor_id.eq.${usuarioActual.id})');
      if (existentes.isNotEmpty && existentes.first['estado'] != 'rechazada') {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya existe una conexión con este usuario'), backgroundColor: Colors.orange));
        return;
      }

      await supabase.from('solicitudes').insert({'emisor_id': usuarioActual.id, 'receptor_id': receptorId, 'estado': 'pendiente'});

      HapticFeedback.mediumImpact();
      _audioPlayer.play(AssetSource('sonidos/envio.mp3')).catchError((_) {});
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Solicitud enviada exitosamente'), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarPerfilDetallado(BuildContext context, Map<String, dynamic> perfil, String distanciaTxt, bool esActivo, String estadoRelacion) {
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
                  Positioned(right: 0, bottom: 0, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: esActivo ? Colors.greenAccent : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 3))))
                ],
              ),
              const SizedBox(height: 16),
              Text('${perfil['nombre']}, ${perfil['edad']} años', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(distanciaTxt, style: const TextStyle(fontSize: 14, color: Colors.orangeAccent)),
              const SizedBox(height: 8),
              Text('Desea: ${perfil['deseo_actual']}', style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
              const SizedBox(height: 24),
              if (estadoRelacion == 'aceptada')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: perfil['id'], receptorNombre: perfil['nombre'], receptorFoto: fotoUrl)));
                  },
                  icon: const Icon(Icons.chat), label: const Text('Abrir Chat'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                )
              else if (estadoRelacion == 'ninguna')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    enviarSolicitud(context, perfil['id']);
                  },
                  icon: const Icon(Icons.send), label: const Text('Enviar Solicitud'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                )
              else
                const Text('Solicitud pendiente de respuesta', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold))
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamPerfiles = Supabase.instance.client.from('perfiles').stream(primaryKey: ['id']);
    final streamSolicitudes = Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: streamPerfiles,
      builder: (context, snapshotPerfiles) {
        if (!snapshotPerfiles.hasData) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: streamSolicitudes,
          builder: (context, snapshotSolicitudes) {
            if (!snapshotSolicitudes.hasData) return const Center(child: CircularProgressIndicator());
            
            final todosLosPerfiles = snapshotPerfiles.data!;
            final misSolicitudes = snapshotSolicitudes.data!.where((s) => s['emisor_id'] == miId || s['receptor_id'] == miId).toList();

            final miPerfil = todosLosPerfiles.firstWhere((p) => p['id'] == miId, orElse: () => {});
            final miGenero = miPerfil['genero'] ?? '';
            final miPreferencia = miPerfil['preferencia'] ?? 'AMBAS';

            final perfiles = todosLosPerfiles.where((p) {
              if (p['id'] == miId || p['ultima_conexion'] == null) return false;

              final ultimaConexion = DateTime.parse(p['ultima_conexion']);
              if (DateTime.now().toUtc().difference(ultimaConexion).inMinutes > 15) return false;

              final generoOtro = p['genero'] ?? '';
              final prefOtro = p['preferencia'] ?? 'AMBAS';

              bool yoLeGusto = (prefOtro == 'AMBAS' || prefOtro == miGenero);
              bool elMeGusta = (miPreferencia == 'AMBAS' || miPreferencia == generoOtro);

              return yoLeGusto && elMeGusta;
            }).toList();
            
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

            if (perfiles.isEmpty) return const Center(child: Text('No hay exploradores compatibles activos cerca.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)));
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: perfiles.length,
              itemBuilder: (context, index) {
                final perfil = perfiles[index];
                final otroId = perfil['id'];
                final fotoUrl = perfil['foto_url']?.toString();
                final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;

                String distanciaTxt = '📍 Ubicación desconocida';
                if (widget.miLatitud != null && widget.miLongitud != null && perfil['latitud'] != null && perfil['longitud'] != null) {
                  final distMetros = Geolocator.distanceBetween(widget.miLatitud!, widget.miLongitud!, (perfil['latitud'] as num).toDouble(), (perfil['longitud'] as num).toDouble());
                  distanciaTxt = '📍 A ${(distMetros / 1000).toStringAsFixed(1)} km';
                }

                String estadoRelacion = 'ninguna';
                try {
                  final relacionExistente = misSolicitudes.firstWhere((s) => (s['emisor_id'] == miId && s['receptor_id'] == otroId) || (s['emisor_id'] == otroId && s['receptor_id'] == miId));
                  estadoRelacion = relacionExistente['estado'];
                } catch (e) {}

                Widget botonAccion;
                if (estadoRelacion == 'aceptada') {
                  botonAccion = IconButton(icon: const Icon(Icons.chat, color: Colors.blueAccent), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: otroId, receptorNombre: perfil['nombre'], receptorFoto: fotoUrl))));
                } else if (estadoRelacion == 'pendiente') {
                  botonAccion = const Icon(Icons.access_time, color: Colors.orange);
                } else {
                  botonAccion = IconButton(icon: const Icon(Icons.send, color: Colors.greenAccent), onPressed: () => enviarSolicitud(context, otroId));
                }

                return Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ListTile(
                    onTap: () => _mostrarPerfilDetallado(context, perfil, distanciaTxt, true, estadoRelacion),
                    leading: Stack(
                      children: [
                        CircleAvatar(backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, color: Colors.black) : null),
                        Positioned(right: 0, bottom: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 2))))
                      ],
                    ),
                    title: Text('${perfil['nombre']} • ${perfil['edad']} años', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Desea: ${perfil['deseo_actual']}'), Text(distanciaTxt, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))]),
                    trailing: botonAccion,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ==================== PANTALLA MI PERFIL ====================
class PantallaMiPerfil extends StatefulWidget {
  const PantallaMiPerfil({super.key});
  @override
  State<PantallaMiPerfil> createState() => _PantallaMiPerfilState();
}

class _PantallaMiPerfilState extends State<PantallaMiPerfil> {
  final _nombreController = TextEditingController();
  final _edadController = TextEditingController();
  final _deseoController = TextEditingController();
  String? _genero;
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
            _genero = perfil['genero'] ?? 'HOMBRE';
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
      await Supabase.instance.client.from('perfiles').upsert({'id': miId, 'nombre': nombre, 'edad': int.parse(edad), 'deseo_actual': deseo, 'genero': _genero, 'preferencia': _preferencia});
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
            value: _genero,
            decoration: const InputDecoration(labelText: 'Mi Género', border: OutlineInputBorder()),
            items: ['MUJER', 'HOMBRE'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
            onChanged: (value) => setState(() => _genero = value),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _preferencia,
            decoration: const InputDecoration(labelText: 'Preferencia de búsqueda', border: OutlineInputBorder()),
            items: ['MUJER', 'HOMBRE', 'AMBAS'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
            onChanged: (value) => setState(() => _preferencia = value),
          ),
          const SizedBox(height: 30),
          _guardando ? const CircularProgressIndicator() : ElevatedButton.icon(onPressed: _guardarCambios, icon: const Icon(Icons.save), label: const Text('Guardar Cambios'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)))
        ],
      ),
    );
  }
}

// ==================== PANTALLA SOLICITUDES Y CHATS ====================
class PantallaSolicitudesYChats extends StatelessWidget {
  const PantallaSolicitudesYChats({super.key});

  void _mostrarPerfilRapidoLectura(BuildContext context, Map<String, dynamic> perfil) {
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
              CircleAvatar(radius: 50, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, size: 50, color: Colors.black) : null),
              const SizedBox(height: 16),
              Text('${perfil['nombre']}, ${perfil['edad']} años', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Desea: ${perfil['deseo_actual']}', style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                child: const Text('Cerrar'),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamSolicitudes = Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']);

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamSolicitudes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final solicitudesTotales = snapshot.data!;
          
          final pendientesUnicas = <String, Map<String, dynamic>>{};
          for (var s in solicitudesTotales.where((s) => s['receptor_id'] == miId && s['estado'] == 'pendiente')) {
            pendientesUnicas[s['emisor_id']] = s;
          }

          final chatsUnicos = <String, Map<String, dynamic>>{};
          for (var s in solicitudesTotales.where((s) => (s['emisor_id'] == miId || s['receptor_id'] == miId) && s['estado'] == 'aceptada')) {
            final otroId = s['emisor_id'] == miId ? s['receptor_id'] : s['emisor_id'];
            chatsUnicos[otroId] = s;
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client.from('perfiles').select(),
            builder: (context, perfilSnapshot) {
              if (!perfilSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final perfilesMap = {for (var p in perfilSnapshot.data!) p['id']: p};
              
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pendientesUnicas.isNotEmpty) ...[
                    const Text('Solicitudes Pendientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ...pendientesUnicas.values.map((s) {
                      final emisor = perfilesMap[s['emisor_id']] ?? {};
                      return Card(
                        color: Colors.grey[850],
                        child: ListTile(
                          title: Text(emisor['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white)),
                          subtitle: const Text('Quiere conectar contigo'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async => await Supabase.instance.client.from('solicitudes').update({'estado': 'aceptada'}).eq('id', s['id'])),
                              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () async => await Supabase.instance.client.from('solicitudes').update({'estado': 'rechazada'}).eq('id', s['id'])),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 30),
                  ],
                  
                  const Text('Chats Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ...chatsUnicos.values.map((s) {
                    final otroId = s['emisor_id'] == miId ? s['receptor_id'] : s['emisor_id'];
                    final otroPerfil = perfilesMap[otroId] ?? {};
                    final fotoUrl = otroPerfil['foto_url']?.toString();
                    
                    return Card(
                      color: Colors.grey[900],
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () => _mostrarPerfilRapidoLectura(context, otroPerfil),
                          child: CircleAvatar(backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null, child: fotoUrl == null ? const Icon(Icons.person) : null),
                        ),
                        title: GestureDetector(
                           onTap: () => _mostrarPerfilRapidoLectura(context, otroPerfil),
                           child: Text(otroPerfil['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        subtitle: const Text('Toca aquí para abrir el chat'),
                        trailing: const Icon(Icons.message, color: Colors.greenAccent),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: otroId, receptorNombre: otroPerfil['nombre'] ?? 'Explorador', receptorFoto: fotoUrl)));
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

// ==================== PANTALLA CHAT ====================
class PantallaChat extends StatefulWidget {
  final String receptorId;
  final String receptorNombre;
  final String? receptorFoto;

  const PantallaChat({super.key, required this.receptorId, required this.receptorNombre, this.receptorFoto});
  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  final ImagePicker _picker = ImagePicker();
  bool _subiendoMedia = false;

  Future<void> enviarMensaje({String? textoFijo}) async {
    final texto = textoFijo ?? _mensajeController.text.trim();
    if (texto.isEmpty) return;
    
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId == null) return;
    _mensajeController.clear();
    
    await Supabase.instance.client.from('mensajes').insert({'emisor_id': miId, 'receptor_id': widget.receptorId, 'contenido': texto});
    HapticFeedback.lightImpact();
    _audioPlayer.play(AssetSource('sonidos/envio.mp3')).catchError((_) {});
  }

  Future<void> _subirArchivoMultimedia(ImageSource origen, String tipo) async {
    try {
      final XFile? archivo = tipo == 'video' 
          ? await _picker.pickVideo(source: origen)
          : await _picker.pickImage(source: origen, imageQuality: 70);
          
      if (archivo == null) return;
      
      setState(() => _subiendoMedia = true);
      
      final miId = Supabase.instance.client.auth.currentUser!.id;
      final fileName = '${miId}_${DateTime.now().millisecondsSinceEpoch}.${tipo == 'video' ? 'mp4' : 'jpg'}';
      
      if (!kIsWeb) {
        await Supabase.instance.client.storage.from('chat-media').upload(fileName, File(archivo.path));
      } else {
        await Supabase.instance.client.storage.from('chat-media').uploadBinary(fileName, await archivo.readAsBytes());
      }
      
      final url = Supabase.instance.client.storage.from('chat-media').getPublicUrl(fileName);
      
      final prefijo = tipo == 'video' ? '[VID]' : '[IMG]';
      await enviarMensaje(textoFijo: '$prefijo$url');
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendoMedia = false);
    }
  }

  void _mostrarOpcionesMultimedia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.camera_alt, color: Colors.greenAccent), title: const Text('Tomar Foto'), onTap: () { Navigator.pop(context); _subirArchivoMultimedia(ImageSource.camera, 'imagen'); }),
          ListTile(leading: const Icon(Icons.image, color: Colors.greenAccent), title: const Text('Foto de Galería'), onTap: () { Navigator.pop(context); _subirArchivoMultimedia(ImageSource.gallery, 'imagen'); }),
          ListTile(leading: const Icon(Icons.videocam, color: Colors.greenAccent), title: const Text('Grabar Video'), onTap: () { Navigator.pop(context); _subirArchivoMultimedia(ImageSource.camera, 'video'); }),
        ],
      ),
    );
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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.receptorFoto != null ? NetworkImage(widget.receptorFoto!) : null,
              child: widget.receptorFoto == null ? const Icon(Icons.person, size: 20) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.receptorNombre, overflow: TextOverflow.ellipsis)),
          ],
        )
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: streamMensajes,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final mensajesAll = snapshot.data!;
                final mensajes = mensajesAll.where((m) => (m['emisor_id'] == miId && m['receptor_id'] == widget.receptorId) || (m['emisor_id'] == widget.receptorId && m['receptor_id'] == miId)).toList();

                final mensajesNoLeidos = mensajes.where((m) => m['receptor_id'] == miId && m['leido'] == false).toList();
                if (mensajesNoLeidos.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Supabase.instance.client.from('mensajes')
                      .update({'leido': true})
                      .eq('receptor_id', miId!)
                      .eq('emisor_id', widget.receptorId)
                      .eq('leido', false).then((_) {});
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = mensajes[index];
                    final esMio = mensaje['emisor_id'] == miId;
                    final textoOriginal = mensaje['contenido'] ?? '';
                    
                    final fecha = DateTime.parse(mensaje['created_at']).toLocal();
                    final horaStr = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
                    final leido = mensaje['leido'] ?? false;

                    Widget contenidoBurbuja;
                    if (textoOriginal.startsWith('[IMG]')) {
                      contenidoBurbuja = ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(textoOriginal.substring(5), width: 200, fit: BoxFit.cover));
                    } else if (textoOriginal.startsWith('[VID]')) {
                      contenidoBurbuja = ReproductorVideoWidget(url: textoOriginal.substring(5));
                    } else {
                      contenidoBurbuja = Text(textoOriginal, style: const TextStyle(color: Colors.white, fontSize: 16));
                    }

                    return Align(
                      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: esMio ? Colors.green[800] : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            contenidoBurbuja,
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(horaStr, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                if (esMio) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.done_all, size: 14, color: leido ? Colors.blueAccent : Colors.grey),
                                ]
                              ],
                            )
                          ],
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
                IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _mostrarOpcionesMultimedia),
                Expanded(child: TextField(controller: _mensajeController, decoration: const InputDecoration(hintText: 'Mensaje...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)))),
                _subiendoMedia
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(icon: const Icon(Icons.send, color: Colors.greenAccent), onPressed: () => enviarMensaje()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== REPRODUCTOR DE VIDEO CHAT ====================
class ReproductorVideoWidget extends StatefulWidget {
  final String url;
  const ReproductorVideoWidget({super.key, required this.url});

  @override
  State<ReproductorVideoWidget> createState() => _ReproductorVideoWidgetState();
}

class _ReproductorVideoWidgetState extends State<ReproductorVideoWidget> {
  late VideoPlayerController _controller;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _inicializado = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _inicializado
        ? SizedBox(
            width: 220,
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  IconButton(
                    icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 50, color: Colors.white70),
                    onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
                  )
                ],
              ),
            ),
          )
        : const SizedBox(width: 220, height: 150, child: Center(child: CircularProgressIndicator()));
  }
}