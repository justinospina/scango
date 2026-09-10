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
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_auth/local_auth.dart';

bool _mayorDeEdadConfirmado = false;

// ==================== LIBRERÍA DE DATOS ====================
class ColombiaData {
  static const List<String> categorias = [
    '💘 Ligar: Interés romántico o sexual hacia otra persona sin precio.',
    '💃 Dama de Compañía: Mujer dispuesta en complacer a un hombre sexualmente, asistir a reuniones, viajes, cenas y eventos por un precio.',
    '🕺 Hombre de Compañía: Hombre dispuesto en complacer a mujeres sexualmente, asistir a reuniones, viajes, cenas y eventos por un precio.',
    '👩‍❤️‍👩 Mujer Lesbiana: Mujer dispuesta a complacer mujeres sexualmente, asistir a reuniones, viajes, cenas y eventos por un precio.',
    '👨‍❤️‍👨 Hombre Gay: Hombre dispuesto a complacer hombres sexualmente, asistir a reuniones, viajes, cenas y eventos por un precio.'
  ];

  static const Map<String, List<String>> ubicaciones = {
    'Amazonas': ['Leticia', 'Puerto Nariño'],
    'Antioquia': ['Medellín', 'Bello', 'Itagüí', 'Envigado', 'Apartadó', 'Rionegro', 'Turbo', 'Caucasia'],
    'Arauca': ['Arauca', 'Arauquita', 'Saravena', 'Tame'],
    'Atlántico': ['Barranquilla', 'Soledad', 'Malambo', 'Sabanalarga', 'Baranoa'],
    'Bogotá D.C.': ['Bogotá'],
    'Bolívar': ['Cartagena', 'Magangué', 'Turbaco', 'Arjona', 'El Carmen de Bolívar'],
    'Boyacá': ['Tunja', 'Duitama', 'Sogamoso', 'Chiquinquirá', 'Paipa'],
    'Caldas': ['Manizales', 'La Dorada', 'Chinchiná', 'Villamaría', 'Riosucio'],
    'Cundinamarca': ['Soacha', 'Chía', 'Zipaquirá', 'Facatativá', 'Fusagasugá', 'Girardot', 'Mosquera'],
    'Risaralda': ['Pereira', 'Dosquebradas', 'Santa Rosa de Cabal', 'La Virginia'],
    'Santander': ['Bucaramanga', 'Floridablanca', 'Barrancabermeja', 'Girón', 'Piedecuesta', 'San Gil'],
    'Tolima': ['Ibagué', 'Espinal', 'Melgar', 'Chaparral', 'Honda'],
    'Valle del Cauca': ['Cali', 'Buenaventura', 'Palmira', 'Tuluá', 'Jamundí', 'Cartago', 'Buga', 'Yumbo'],
  };
}

Widget _construirTextoCategoria(String textoCompleto) {
  final partes = textoCompleto.split(':');
  if (partes.length > 1) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          text: '${partes[0]}:',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          children: [
            TextSpan(
              text: partes[1],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  return Text(textoCompleto, style: const TextStyle(fontSize: 14));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zlslfegiqpgdjxoexlta.supabase.co',
    anonKey: 'sb_publishable_iVJD8SvV1jtbM-hMVGAsGQ_XTT60Cdk', 
  );
  runApp(const ScanGoApp());
}

void _verificarEdadGlobal(BuildContext context) {
  if (_mayorDeEdadConfirmado) return;
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('⚠️ Verificación de Edad', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Para ingresar y utilizar ScanGo debes ser mayor de edad (+18 años). ¿Confirmas que eres mayor de edad?'),
        actions: [
          TextButton(
            onPressed: () {
              if (Platform.isAndroid || Platform.isIOS) {
                SystemNavigator.pop();
              } else {
                Navigator.of(ctx).pop();
                showDialog(context: ctx, barrierDismissible: false, builder: (_) => const Scaffold(body: Center(child: Text('Acceso Denegado. Solo para mayores de 18 años.', style: TextStyle(fontSize: 20, color: Colors.red)))));
              }
            },
            child: const Text('No, salir', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () {
              _mayorDeEdadConfirmado = true;
              Navigator.of(ctx).pop();
            },
            child: const Text('Sí, soy mayor de 18 años'),
          ),
        ],
      ),
    );
  });
}

class ScanGoApp extends StatefulWidget {
  const ScanGoApp({super.key});

  @override
  State<ScanGoApp> createState() => _ScanGoAppState();
}

class _ScanGoAppState extends State<ScanGoApp> with WidgetsBindingObserver {
  bool _autenticado = false;
  bool _autenticando = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _solicitarBiometria();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_autenticando) {
      if (Supabase.instance.client.auth.currentSession != null) {
        setState(() => _autenticado = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_autenticado && !_autenticando && Supabase.instance.client.auth.currentSession != null) {
        _solicitarBiometria();
      }
    }
  }

  Future<void> _solicitarBiometria() async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    if (_autenticando) return;

    if (kIsWeb) {
      setState(() => _autenticado = true);
      return;
    }

    setState(() => _autenticando = true);
    
    try {
      final soportaBiometria = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!soportaBiometria) {
        setState(() => _autenticado = true); 
        return;
      }

      final exitoso = await _auth.authenticate(
        localizedReason: 'Desbloquea ScanGo para continuar',
      );

      if (exitoso) {
        final miId = Supabase.instance.client.auth.currentUser?.id;
        if (miId != null) {
          await Supabase.instance.client.from('perfiles').update({'verificado_biometria': true}).eq('id', miId);
        }
      }

      if (mounted) setState(() => _autenticado = exitoso);
    } catch (e) {
      if (mounted) setState(() => _autenticado = true);
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanGo',
      theme: ThemeData.dark(),
      home: Supabase.instance.client.auth.currentSession == null
          ? const PantallaMuro(esInvitado: true)
          : (_autenticado 
              ? const PantallaPrincipal() 
              : PantallaBloqueo(onReintentar: _solicitarBiometria)),
    );
  }
}

class PantallaBloqueo extends StatelessWidget {
  final VoidCallback onReintentar;
  const PantallaBloqueo({super.key, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 20),
            const Text('ScanGo Bloqueado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Verifica tu identidad para acceder.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Desbloquear'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent, 
                foregroundColor: Colors.black,
                minimumSize: const Size(200, 50),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==================== WIDGET CENTRAL DE PERFIL CON MATCH ====================
class ModalPerfilDetalle extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final String distanciaTxt;
  final Map<String, dynamic>? relacionExistenteInit;
  final String miId;

  const ModalPerfilDetalle({
    super.key,
    required this.perfil,
    required this.distanciaTxt,
    this.relacionExistenteInit,
    required this.miId,
  });

  @override
  State<ModalPerfilDetalle> createState() => _ModalPerfilDetalleState();
}

class _ModalPerfilDetalleState extends State<ModalPerfilDetalle> {
  Map<String, dynamic>? _relacion;

  @override
  void initState() {
    super.initState();
    _relacion = widget.relacionExistenteInit;
  }

  Future<void> _alternarLike() async {
    final otroId = widget.perfil['id'];
    try {
      if (_relacion == null) {
        final res = await Supabase.instance.client.from('solicitudes').insert({
          'emisor_id': widget.miId,
          'receptor_id': otroId,
          'estado': 'pendiente',
          'emisor_like': true
        }).select().single();
        setState(() => _relacion = res);
      } else {
        final soyEmisor = _relacion!['emisor_id'] == widget.miId;
        final campo = soyEmisor ? 'emisor_like' : 'receptor_like';
        final yoDiLike = _relacion![campo] == true;
        final nuevoValor = !yoDiLike;
        
        await Supabase.instance.client.from('solicitudes').update({campo: nuevoValor}).eq('id', _relacion!['id']);
        setState(() => _relacion![campo] = nuevoValor);
      }
    } catch (e) {
      debugPrint("Error dando like: $e");
    }
  }

  Future<void> _actualizarEstadoSolicitud(String nuevoEstado) async {
    try {
      await Supabase.instance.client.from('solicitudes').update({'estado': nuevoEstado}).eq('id', _relacion!['id']);
      if (nuevoEstado == 'aceptada') {
        setState(() => _relacion!['estado'] = nuevoEstado);
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error actualizando solicitud: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = widget.perfil['foto_url']?.toString();
    final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;
    final esVerificado = widget.perfil['verificado_biometria'] == true;
    
    String estadoRelacion = _relacion?['estado'] ?? 'ninguna';
    bool soyEmisor = _relacion?['emisor_id'] == widget.miId;
    bool yoDiLike = _relacion != null ? (soyEmisor ? _relacion!['emisor_like'] == true : _relacion!['receptor_like'] == true) : false;
    bool elDioLike = _relacion != null ? (soyEmisor ? _relacion!['receptor_like'] == true : _relacion!['emisor_like'] == true) : false;
    bool matchMutuo = yoDiLike && elDioLike;

    return Container(
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(radius: 50, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, size: 50, color: Colors.black) : null),
              Positioned(
                bottom: -5, right: -5,
                child: GestureDetector(
                  onTap: _alternarLike,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 2)),
                    child: Icon(yoDiLike ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 24),
                  )
                )
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${widget.perfil['nombre']}, ${widget.perfil['edad']} años', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              if (esVerificado) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.blueAccent, size: 22)),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.distanciaTxt, style: const TextStyle(fontSize: 14, color: Colors.orangeAccent)),
          const SizedBox(height: 8),
          Text('Desea: ${widget.perfil['deseo_actual'] ?? ''}', style: const TextStyle(fontSize: 16, color: Colors.greenAccent), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (matchMutuo) 
            const Text('💖 ¡Personas que se gustan!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          if (elDioLike && !yoDiLike)
            const Text('¡A esta persona le gustas!', style: TextStyle(color: Colors.orangeAccent, fontSize: 14)),
          const SizedBox(height: 24),

          if (estadoRelacion == 'aceptada') 
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: widget.perfil['id'], receptorNombre: widget.perfil['nombre'], receptorFoto: fotoUrl, solicitudId: _relacion!['id'].toString())));
              },
              icon: const Icon(Icons.chat), label: const Text('Abrir Chat'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            )
          else if (estadoRelacion == 'ninguna')
            ElevatedButton.icon(
              onPressed: () async {
                 try {
                   final res = await Supabase.instance.client.from('solicitudes').insert({'emisor_id': widget.miId, 'receptor_id': widget.perfil['id'], 'estado': 'pendiente', 'emisor_like': yoDiLike}).select().single();
                   setState(() => _relacion = res);
                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Solicitud enviada exitosamente'), backgroundColor: Colors.green));
                 } catch(e) {}
              },
              icon: const Icon(Icons.send), label: const Text('Enviar Solicitud'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
            )
          else if (estadoRelacion == 'pendiente' && !soyEmisor)
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    onPressed: () => _actualizarEstadoSolicitud('rechazada'),
                    icon: const Icon(Icons.close), label: const Text('Rechazar')
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _actualizarEstadoSolicitud('aceptada'),
                    icon: const Icon(Icons.check), label: const Text('Aceptar')
                  ),
                ],
              )
          else 
            const Text('Solicitud pendiente de respuesta', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
}

// ==================== RESTO DE LA APLICACIÓN ====================

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
  StreamSubscription<Position>? _positionStream;
  bool _yaPreguntoDeseo = false;
  bool _estaDisponible = true;
  
  static bool deseoCompletado = false;

  @override
  void initState() {
    super.initState();
    deseoCompletado = false;
    _cargarDisponibilidad();
    _iniciarRastreoGPS();
    
    _verificarEdadGlobal(context);
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _actualizarUltimaConexion();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mayorDeEdadConfirmado) _preguntarDeseoDeHoy();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _cargarDisponibilidad() async {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId != null) {
      final data = await Supabase.instance.client.from('perfiles').select('disponible').eq('id', miId).maybeSingle();
      if (data != null && mounted) {
        setState(() => _estaDisponible = data['disponible'] ?? true);
      }
    }
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
      }
    );
  }

  Future<void> _actualizarUltimaConexion() async {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId != null) {
      await Supabase.instance.client.from('perfiles').update({
        'ultima_conexion': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', miId);
    }
  }

  Future<void> _iniciarRastreoGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final posInicial = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _miLatitud = posInicial.latitude;
          _miLongitud = posInicial.longitude;
        });
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
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
      });
    } catch (e) {
      debugPrint("Error GPS: $e");
    }
  }

  void _actualizarBadgeDelIcono(int contador) {
    if (!kIsWeb) {
      FlutterAppBadger.isAppBadgeSupported().then((soportado) {
        if (soportado) {
          if (contador > 0) {
            FlutterAppBadger.updateBadgeCount(contador);
          } else {
            FlutterAppBadger.removeBadge();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;

    final List<Widget> pantallas = [
      PantallaRadar(miLatitud: _miLatitud, miLongitud: _miLongitud),
      const PantallaMuro(esInvitado: false),
      const PantallaSolicitudesYChats(),
      const PantallaMiPerfil(),
    ];

    String getTitulo() {
      switch (_indiceActual) {
        case 0: return 'Radar';
        case 1: return 'Muro de Exploradores';
        case 2: return 'Chats';
        case 3: return 'Mi Perfil';
        default: return 'ScanGo';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(getTitulo()),
        centerTitle: false,
        actions: [
          Row(
            children: [
              Text(_estaDisponible ? 'Disponible' : 'Ocupado', style: TextStyle(color: _estaDisponible ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _estaDisponible,
                activeColor: Colors.greenAccent,
                inactiveThumbColor: Colors.redAccent,
                onChanged: (val) async {
                  setState(() => _estaDisponible = val);
                  if (miId != null) {
                    await Supabase.instance.client.from('perfiles').update({'disponible': val}).eq('id', miId);
                  }
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!kIsWeb) FlutterAppBadger.removeBadge();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PantallaMuro(esInvitado: true)), (route) => false);
              }
            },
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: IndexedStack(
            index: _indiceActual,
            children: pantallas,
          ),
        ),
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
                      .where((m) => m['receptor_id'] == miId && chatsActivosIds.contains(m['emisor_id']) && (m['leido'] == null || m['leido'] == false))
                      .length;
                }
                notificacionesTotales = solicitudesPendientes + mensajesNoLeidos;
                
                _actualizarBadgeDelIcono(notificacionesTotales);
              }

              return BottomNavigationBar(
                currentIndex: _indiceActual,
                selectedItemColor: Colors.greenAccent,
                unselectedItemColor: Colors.grey,
                backgroundColor: Colors.grey[900],
                type: BottomNavigationBarType.fixed,
                onTap: (index) => setState(() => _indiceActual = index),
                items: [
                  const BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
                  const BottomNavigationBarItem(icon: Icon(Icons.view_day), label: 'Muro'),
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
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PantallaPrincipal()), (route) => false);
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
                          ),
                        ],
                      )
              ],
            ),
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
  final _deseoController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoPerfil;
  bool _procesando = false;
  bool _procesandoIA = false;
  String? _generoDetectado;
  String _preferencia = 'AMBAS';
  bool _aceptaPoliticas = false;

  void _mostrarPoliticas() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Política de Tratamiento de Datos', style: TextStyle(color: Colors.greenAccent)),
        content: const SingleChildScrollView(
          child: Text(
            'En cumplimiento de la Ley 1581 de 2012 (Habeas Data):\n\n'
            '1. Datos Recopilados: ScanGo almacena tu ubicación GPS en tiempo real, fotografías biométricas temporales, edad y contenido de chats.\n\n'
            '2. Finalidad: Tu ubicación y preferencias cruzadas se usan exclusivamente para el "Radar" de proximidad y el Muro social. No vendemos ni cedemos tus datos a terceros.\n\n'
            '3. Control y Eliminación: Tienes total autonomía para ocultarte del Radar (botón Disponible/Ocupado) y para eliminar vínculos o el historial completo de mensajes.\n\n'
            '4. Consentimiento: Al registrarte, autorizas a ScanGo a tratar tus datos bajo estrictos parámetros de seguridad y confidencialidad.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: Colors.greenAccent)))
        ],
      ),
    );
  }

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
    final deseo = _deseoController.text.trim();

    if (!_aceptaPoliticas) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes aceptar la política de tratamiento de datos para continuar'), backgroundColor: Colors.orange));
      return;
    }

    if (email.isEmpty || password.isEmpty || nombre.isEmpty || edad.isEmpty || deseo.isEmpty || _generoDetectado == null || _fotoPerfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos requeridos'), backgroundColor: Colors.redAccent));
      return;
    }
    
    setState(() => _procesando = true);

    try {
      final supabase = Supabase.instance.client;
      final respuesta = await supabase.auth.signUp(email: email, password: password);
      final usuarioNuevo = respuesta.user;
      if (usuarioNuevo == null) throw Exception('Error al generar sesión');

      final fileName = '${usuarioNuevo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await _fotoPerfil!.readAsBytes();
      
      await supabase.storage.from('fotos-perfil').uploadBinary(fileName, fileBytes);
      final fotoUrl = supabase.storage.from('fotos-perfil').getPublicUrl(fileName);

      await supabase.from('perfiles').upsert({
        'id': usuarioNuevo.id, 
        'nombre': nombre,
        'edad': int.parse(edad),
        'deseo_actual': deseo, 
        'genero': _generoDetectado,
        'preferencia': _preferencia,
        'foto_url': fotoUrl,
        'ultima_conexion': DateTime.now().toUtc().toIso8601String(),
        'disponible': true,
        'verificado_biometria': false, 
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
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
                  DropdownButtonFormField<String>(
                    value: _generoDetectado,
                    decoration: const InputDecoration(labelText: 'Confirma tu Género', border: OutlineInputBorder()),
                    items: ['MUJER', 'HOMBRE'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                    onChanged: (value) => setState(() => _generoDetectado = value!),
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: _edadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ingresa tu Edad', border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  TextField(controller: _deseoController, decoration: const InputDecoration(labelText: '¿Qué buscas en ScanGo?', border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _preferencia,
                    decoration: const InputDecoration(labelText: 'Preferencia', border: OutlineInputBorder()),
                    items: ['MUJER', 'HOMBRE', 'AMBAS'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                    onChanged: (value) => setState(() => _preferencia = value!),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Checkbox(
                        value: _aceptaPoliticas,
                        activeColor: Colors.greenAccent,
                        checkColor: Colors.black,
                        onChanged: (val) => setState(() => _aceptaPoliticas = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _mostrarPoliticas,
                          child: const Text('Acepto la Política de Tratamiento de Datos Personales', style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline, fontSize: 13)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  _procesando
                      ? const CircularProgressIndicator()
                      : ElevatedButton(onPressed: registrarYGuardar, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)), child: const Text('Completar Registro'))
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaMuro extends StatefulWidget {
  final bool esInvitado;
  const PantallaMuro({super.key, this.esInvitado = false});

  @override
  State<PantallaMuro> createState() => _PantallaMuroState();
}

class _PantallaMuroState extends State<PantallaMuro> {
  final ImagePicker _picker = ImagePicker();
  
  String? _filtroCategoria;
  String? _filtroDepartamento;
  String? _filtroCiudad;

  int _paginaActual = 0;
  final int _limitePagina = 10;
  bool _cargandoMuro = false;
  bool _hayMas = true;
  List<Map<String, dynamic>> _publicaciones = [];
  Map<String, dynamic> _perfilesMap = {};

  @override
  void initState() {
    super.initState();
    _verificarEdadGlobal(context);
    _cargarPublicaciones();
  }

  Future<void> _cargarPublicaciones() async {
    setState(() => _cargandoMuro = true);
    try {
      var query = Supabase.instance.client.from('publicaciones').select();

      if (_filtroCategoria != null) query = query.eq('categoria', _filtroCategoria!);
      if (_filtroDepartamento != null) query = query.eq('departamento', _filtroDepartamento!);
      if (_filtroCiudad != null) query = query.eq('ciudad', _filtroCiudad!);

      final from = _paginaActual * _limitePagina;
      final to = from + _limitePagina - 1;

      final data = await query.order('created_at', ascending: false).range(from, to);

      final userIds = data.map((p) => p['usuario_id']).toSet().toList();
      if (userIds.isNotEmpty) {
        final perfilesData = await Supabase.instance.client.from('perfiles').select().inFilter('id', userIds);
        _perfilesMap = {for (var p in perfilesData) p['id']: p};
      } else {
        _perfilesMap = {};
      }

      if (mounted) {
        setState(() {
          _publicaciones = List<Map<String, dynamic>>.from(data);
          _hayMas = data.length == _limitePagina;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando muro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargandoMuro = false);
    }
  }

  Widget _construirBuscadorDinamico({
    required String label,
    required Iterable<String> opciones,
    required Function(String) onSelected,
    required VoidCallback onCleared,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return opciones;
        return opciones.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                controller.clear();
                onCleared();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _eliminarPublicacion(String pubId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Eliminar publicación?', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Esta acción borrará la publicación del muro de todos los exploradores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await Supabase.instance.client.from('publicaciones').delete().eq('id', pubId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicación eliminada'), backgroundColor: Colors.green));
        _cargarPublicaciones(); 
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _abrirCrearPublicacion() async {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    if (miId == null) return;

    final txtController = TextEditingController();
    final whatsappController = TextEditingController();
    XFile? mediaFile;
    String? mediaTipo;
    bool procesando = false;
    
    String categoriaSel = ColombiaData.categorias.first;
    String? depSel;
    String? ciuSel;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            Future<void> publicar() async {
              final texto = txtController.text.trim();
              if ((texto.isEmpty && mediaFile == null) || depSel == null || ciuSel == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega contenido, departamento y ciudad para publicar')));
                return;
              }
              
              setStateModal(() => procesando = true);
              
              String? urlFinal;
              try {
                if (mediaFile != null) {
                  final fileName = '${miId}_${DateTime.now().millisecondsSinceEpoch}.${mediaTipo == 'vid' ? 'mp4' : 'jpg'}';
                  if (!kIsWeb) {
                    await Supabase.instance.client.storage.from('chat-media').upload(fileName, File(mediaFile!.path));
                  } else {
                    await Supabase.instance.client.storage.from('chat-media').uploadBinary(fileName, await mediaFile!.readAsBytes());
                  }
                  urlFinal = Supabase.instance.client.storage.from('chat-media').getPublicUrl(fileName);
                }

                await Supabase.instance.client.from('publicaciones').insert({
                  'usuario_id': miId,
                  'texto': texto,
                  'media_url': urlFinal,
                  'tipo': mediaTipo,
                  'whatsapp': whatsappController.text.trim(),
                  'categoria': categoriaSel,
                  'departamento': depSel,
                  'ciudad': ciuSel,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Publicado con éxito'), backgroundColor: Colors.green));
                  setState(() => _paginaActual = 0);
                  _cargarPublicaciones();
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                setStateModal(() => procesando = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nueva Publicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: categoriaSel,
                      decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                      items: ColombiaData.categorias.map((c) => DropdownMenuItem(value: c, child: _construirTextoCategoria(c))).toList(),
                      onChanged: (val) => setStateModal(() => categoriaSel = val!),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _construirBuscadorDinamico(
                            label: 'Departamento',
                            opciones: ColombiaData.ubicaciones.keys,
                            onSelected: (val) => setStateModal(() { depSel = val; ciuSel = null; }),
                            onCleared: () => setStateModal(() { depSel = null; ciuSel = null; }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _construirBuscadorDinamico(
                            label: 'Ciudad',
                            opciones: depSel == null ? [] : ColombiaData.ubicaciones[depSel]!,
                            onSelected: (val) => setStateModal(() => ciuSel = val),
                            onCleared: () => setStateModal(() => ciuSel = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: txtController,
                      maxLines: 2,
                      decoration: InputDecoration(hintText: '¿Qué quieres compartir?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Tu WhatsApp (Opcional)', 
                        prefixIcon: const Icon(Icons.phone, color: Colors.greenAccent),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (mediaFile != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(mediaTipo == 'vid' ? Icons.videocam : Icons.image, color: Colors.greenAccent),
                            const SizedBox(width: 10),
                            Expanded(child: Text(mediaFile!.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setStateModal(() { mediaFile = null; mediaTipo = null; }))
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(icon: const Icon(Icons.camera_alt), color: Colors.blueAccent, onPressed: () async {
                          final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (f != null) setStateModal(() { mediaFile = f; mediaTipo = 'img'; });
                        }),
                        IconButton(icon: const Icon(Icons.image), color: Colors.blueAccent, onPressed: () async {
                          final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (f != null) setStateModal(() { mediaFile = f; mediaTipo = 'img'; });
                        }),
                        IconButton(icon: const Icon(Icons.videocam), color: Colors.blueAccent, onPressed: () async {
                          final f = await _picker.pickVideo(source: ImageSource.camera);
                          if (f != null) setStateModal(() { mediaFile = f; mediaTipo = 'vid'; });
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    procesando
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: publicar,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                          child: const Text('Publicar Ahora'),
                        ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: widget.esInvitado 
          ? AppBar(
              title: const Text('ScanGo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)), 
              backgroundColor: Colors.grey[900],
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaLogin())),
                  icon: const Icon(Icons.login, color: Colors.greenAccent),
                  label: const Text('Ingresar', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                )
              ],
            ) 
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[850],
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Filtrar Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                      value: _filtroCategoria,
                      items: ['Todas', ...ColombiaData.categorias].map((c) => DropdownMenuItem(value: c, child: _construirTextoCategoria(c))).toList(),
                      onChanged: (val) {
                        setState(() { _filtroCategoria = val == 'Todas' ? null : val; _paginaActual = 0; });
                        _cargarPublicaciones();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _construirBuscadorDinamico(
                            label: 'Filtrar Depto',
                            opciones: ColombiaData.ubicaciones.keys,
                            onSelected: (val) {
                              setState(() { _filtroDepartamento = val; _filtroCiudad = null; _paginaActual = 0; });
                              _cargarPublicaciones();
                            },
                            onCleared: () {
                              setState(() { _filtroDepartamento = null; _filtroCiudad = null; _paginaActual = 0; });
                              _cargarPublicaciones();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _construirBuscadorDinamico(
                            label: 'Filtrar Ciudad',
                            opciones: _filtroDepartamento == null ? [] : ColombiaData.ubicaciones[_filtroDepartamento]!,
                            onSelected: (val) {
                              setState(() { _filtroCiudad = val; _paginaActual = 0; });
                              _cargarPublicaciones();
                            },
                            onCleared: () {
                              setState(() { _filtroCiudad = null; _paginaActual = 0; });
                              _cargarPublicaciones();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: _cargandoMuro 
                  ? const Center(child: CircularProgressIndicator())
                  : _publicaciones.isEmpty
                      ? const Center(child: Text('No hay publicaciones con estos filtros.', style: TextStyle(color: Colors.grey)))
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _publicaciones.length,
                                itemBuilder: (context, index) {
                                  final pub = _publicaciones[index];
                                  final autor = _perfilesMap[pub['usuario_id']] ?? {};
                                  final fotoAutor = autor['foto_url']?.toString();
                                  final tieneFotoAutor = fotoAutor != null && fotoAutor.trim().isNotEmpty;
                                  final esVerificado = autor['verificado_biometria'] == true;
                                  
                                  DateTime fecha = DateTime.now();
                                  if (pub['created_at'] != null) {
                                    fecha = DateTime.tryParse(pub['created_at'].toString())?.toLocal() ?? DateTime.now();
                                  }
                                  final fechaStr = '${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
                                  
                                  final whatsapp = pub['whatsapp']?.toString();
                                  final esMio = !widget.esInvitado && miId != null && pub['usuario_id'] == miId;

                                  return Card(
                                    color: Colors.grey[900],
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(backgroundImage: tieneFotoAutor ? NetworkImage(fotoAutor) : null, child: !tieneFotoAutor ? const Icon(Icons.person) : null),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(autor['nombre'] ?? 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                                        if (esVerificado) ...[
                                                          const SizedBox(width: 4),
                                                          const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                                                        ],
                                                      ],
                                                    ),
                                                    Text('${pub['ciudad'] ?? 'Sin Ciudad'}, ${pub['departamento'] ?? ''}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                                    if (pub['categoria'] != null)
                                                      Text('${pub['categoria']}'.split(':')[0], style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                                                    Text(fechaStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              if (esMio)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                  onPressed: () => _eliminarPublicacion(pub['id'].toString()),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (pub['texto'] != null && pub['texto'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: Text(pub['texto'], style: const TextStyle(fontSize: 15)),
                                            ),
                                          if (pub['media_url'] != null)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: pub['tipo'] == 'vid'
                                                  ? ReproductorVideoWidget(url: pub['media_url'])
                                                  : ConstrainedBox(
                                                      constraints: const BoxConstraints(maxHeight: 250),
                                                      child: Image.network(
                                                        pub['media_url'], 
                                                        width: double.infinity, 
                                                        fit: BoxFit.cover, 
                                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50, color: Colors.grey)
                                                      ),
                                                    ),
                                            ),
                                          if (whatsapp != null && whatsapp.trim().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 16),
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  final numeroLimpio = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
                                                  final url = Uri.parse('https://wa.me/$numeroLimpio');
                                                  if (await canLaunchUrl(url)) {
                                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                                  } else {
                                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
                                                  }
                                                },
                                                icon: const Icon(Icons.chat, color: Colors.white),
                                                label: const Text('Contactar por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF25D366),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(double.infinity, 45),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.grey[900],
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _paginaActual > 0 ? () {
                                      setState(() => _paginaActual--);
                                      _cargarPublicaciones();
                                    } : null,
                                    icon: const Icon(Icons.arrow_back_ios, size: 14),
                                    label: const Text('Anterior'),
                                  ),
                                  Text('Página ${_paginaActual + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                  ElevatedButton.icon(
                                    onPressed: _hayMas ? () {
                                      setState(() => _paginaActual++);
                                      _cargarPublicaciones();
                                    } : null,
                                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                    label: const Text('Siguiente'),
                                    iconAlignment: IconAlignment.end,
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.esInvitado 
          ? null 
          : FloatingActionButton(
              onPressed: _abrirCrearPublicacion,
              backgroundColor: Colors.greenAccent,
              child: const Icon(Icons.add, color: Colors.black),
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
  final Set<String> _solicitudesAceptadasNotificadas = {}; 
  final Set<String> _exploradoresCercanosNotificados = {};
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  bool _dialogoMultiplesAbierto = false;
  bool _esPrimeraCargaSolicitudes = true; 
  
  RangeValues _rangoEdad = const RangeValues(18, 99);
  double _distanciaMaximaKm = 15.0; 

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

            if (nuevoPerfil['disponible'] == false) return;

            if (widget.miLatitud != null && widget.miLongitud != null && nuevoPerfil['latitud'] != null && nuevoPerfil['longitud'] != null) {
              final distMetros = Geolocator.distanceBetween(widget.miLatitud!, widget.miLongitud!, (nuevoPerfil['latitud'] as num).toDouble(), (nuevoPerfil['longitud'] as num).toDouble());
              if (distMetros <= _distanciaMaximaKm * 1000) {
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
            if (!_esPrimeraCargaSolicitudes) nuevasPendientes.add(s);
          }
        }

        if (s['emisor_id'] == miId && s['estado'] == 'aceptada') {
          if (!_solicitudesAceptadasNotificadas.contains(solicitudId)) {
            _solicitudesAceptadasNotificadas.add(solicitudId);
            if (!_esPrimeraCargaSolicitudes) {
              final receptorData = await Supabase.instance.client.from('perfiles').select().eq('id', s['receptor_id']).maybeSingle();
              if (receptorData != null && mounted) {
                _mostrarAlertaSolicitudAceptada(context, receptorData);
              }
            }
          }
        }
      }

      if (nuevasPendientes.isNotEmpty && mounted && !_dialogoMultiplesAbierto) {
        _mostrarAlertaMultiplesSolicitudes(context, nuevasPendientes);
      }

      _esPrimeraCargaSolicitudes = false; 
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
                              }
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                await Supabase.instance.client.from('solicitudes').update({'estado': 'aceptada'}).eq('id', s['id']);
                                if (pendientes.length == 1) Navigator.pop(context);
                              }
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _dialogoMultiplesAbierto = false;
                Navigator.pop(context);
              }, 
              child: const Text('Cerrar')
            )
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
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: receptor['id'], receptorNombre: receptor['nombre'] ?? 'Explorador', receptorFoto: fotoUrl, solicitudId: '')));
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

  @override
  Widget build(BuildContext context) {
    final miId = Supabase.instance.client.auth.currentUser?.id;
    final streamPerfiles = Supabase.instance.client.from('perfiles').stream(primaryKey: ['id']);
    final streamSolicitudes = Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[850],
          child: Column(
            children: [
              Text('Filtrar por edad: ${_rangoEdad.start.round()} a ${_rangoEdad.end.round()} años', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              RangeSlider(
                values: _rangoEdad,
                min: 18,
                max: 99,
                divisions: 81,
                activeColor: Colors.greenAccent,
                labels: RangeLabels('${_rangoEdad.start.round()}', '${_rangoEdad.end.round()}'),
                onChanged: (RangeValues values) {
                  setState(() => _rangoEdad = values);
                },
              ),
              const SizedBox(height: 5),
              Text('Distancia máxima: ${_distanciaMaximaKm.round()} km', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Slider(
                value: _distanciaMaximaKm,
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: Colors.greenAccent,
                label: '${_distanciaMaximaKm.round()} km',
                onChanged: (val) => setState(() => _distanciaMaximaKm = val),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
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
                    
                    if (p['disponible'] == false) return false;

                    final int edadOtro = p['edad'] ?? 18;
                    if (edadOtro < _rangoEdad.start.round() || edadOtro > _rangoEdad.end.round()) return false;

                    if (widget.miLatitud != null && widget.miLongitud != null && p['latitud'] != null && p['longitud'] != null) {
                      final distMetros = Geolocator.distanceBetween(
                        widget.miLatitud!, widget.miLongitud!, 
                        (p['latitud'] as num).toDouble(), (p['longitud'] as num).toDouble()
                      );
                      if (distMetros > _distanciaMaximaKm * 1000) return false;
                    } else {
                      return false; 
                    }

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

                  if (perfiles.isEmpty) return const Center(child: Text('No hay exploradores en este rango cerca.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)));
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: perfiles.length,
                    itemBuilder: (context, index) {
                      final perfil = perfiles[index];
                      final otroId = perfil['id'];
                      final fotoUrl = perfil['foto_url']?.toString();
                      final tieneFoto = fotoUrl != null && fotoUrl.trim().isNotEmpty;
                      final esVerificado = perfil['verificado_biometria'] == true;

                      String distanciaTxt = '📍 Ubicación desconocida';
                      if (widget.miLatitud != null && widget.miLongitud != null && perfil['latitud'] != null && perfil['longitud'] != null) {
                        final distMetros = Geolocator.distanceBetween(widget.miLatitud!, widget.miLongitud!, (perfil['latitud'] as num).toDouble(), (perfil['longitud'] as num).toDouble());
                        distanciaTxt = '📍 A ${(distMetros / 1000).toStringAsFixed(1)} km';
                      }

                      Map<String, dynamic>? relacionExitente;
                      try {
                        relacionExitente = misSolicitudes.firstWhere((s) => (s['emisor_id'] == miId && s['receptor_id'] == otroId) || (s['emisor_id'] == otroId && s['receptor_id'] == miId));
                      } catch (e) {}

                      String estadoRelacion = relacionExitente?['estado'] ?? 'ninguna';
                      Widget botonAccion;
                      if (estadoRelacion == 'aceptada') {
                        botonAccion = IconButton(icon: const Icon(Icons.chat, color: Colors.blueAccent), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: otroId, receptorNombre: perfil['nombre'], receptorFoto: fotoUrl, solicitudId: relacionExitente!['id'].toString()))));
                      } else if (estadoRelacion == 'pendiente') {
                        botonAccion = const Icon(Icons.access_time, color: Colors.orange);
                      } else {
                        botonAccion = IconButton(
                          icon: const Icon(Icons.send, color: Colors.greenAccent), 
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.from('solicitudes').insert({'emisor_id': miId, 'receptor_id': otroId, 'estado': 'pendiente'});
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Solicitud enviada exitosamente'), backgroundColor: Colors.green));
                            } catch(e) {}
                          }
                        );
                      }

                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 15),
                        child: ListTile(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) => ModalPerfilDetalle(perfil: perfil, distanciaTxt: distanciaTxt, relacionExistenteInit: relacionExitente, miId: miId!)
                            );
                          },
                          leading: Stack(
                            children: [
                              CircleAvatar(backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null, child: !tieneFoto ? const Icon(Icons.person, color: Colors.black) : null),
                              Positioned(right: 0, bottom: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 2))))
                            ],
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${perfil['nombre']} • ${perfil['edad']} años', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              if (esVerificado) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                              ],
                            ],
                          ),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${perfil['deseo_actual']}', overflow: TextOverflow.ellipsis), 
                            Text(distanciaTxt, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))
                          ]),
                          trailing: botonAccion,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
  String? _genero;
  String? _preferencia;
  String? _fotoUrl;
  bool _esVerificado = false;
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
            _esVerificado = perfil['verificado_biometria'] == true;
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

  Future<void> _cambiarFotoPerfil() async {
    final ImagePicker picker = ImagePicker();
    final XFile? nuevaFoto = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (nuevaFoto == null) return;

    setState(() => _guardando = true);
    try {
      final miId = Supabase.instance.client.auth.currentUser!.id;
      final fileName = '${miId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      if (!kIsWeb) {
        await Supabase.instance.client.storage.from('fotos-perfil').upload(fileName, File(nuevaFoto.path));
      } else {
        await Supabase.instance.client.storage.from('fotos-perfil').uploadBinary(fileName, await nuevaFoto.readAsBytes());
      }
      
      final nuevaUrl = Supabase.instance.client.storage.from('fotos-perfil').getPublicUrl(fileName);

      await Supabase.instance.client.from('perfiles').update({'foto_url': nuevaUrl}).eq('id', miId);

      setState(() => _fotoUrl = nuevaUrl);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Foto actualizada'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
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
          GestureDetector(
            onTap: _cambiarFotoPerfil,
            child: Stack(
              children: [
                CircleAvatar(radius: 60, backgroundColor: Colors.greenAccent, backgroundImage: tieneFoto ? NetworkImage(_fotoUrl!) : null, child: !tieneFoto ? const Icon(Icons.person, size: 60, color: Colors.black) : null),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.edit, size: 20, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
          if (_esVerificado) ...[
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                SizedBox(width: 5),
                Text('Usuario Verificado', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))
              ],
            )
          ],
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

class PantallaSolicitudesYChats extends StatelessWidget {
  const PantallaSolicitudesYChats({super.key});

  Future<void> _eliminarVinculoYCreados(BuildContext context, String solicitudId, String otroId, String miId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Eliminar conexión?', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Esto borrará el vínculo y el historial de mensajes permanentemente para ambos usuarios.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
    final streamMensajes = Supabase.instance.client.from('mensajes').stream(primaryKey: ['id']);

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: streamSolicitudes,
        builder: (context, snapshotSolicitudes) {
          if (!snapshotSolicitudes.hasData) return const Center(child: CircularProgressIndicator());
          
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: streamMensajes,
            builder: (context, snapshotMensajes) {
              if (!snapshotMensajes.hasData) return const Center(child: CircularProgressIndicator());

              final solicitudesTotales = snapshotSolicitudes.data!;
              final mensajesTotales = snapshotMensajes.data!;
              
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
                          final esVerificado = emisor['verificado_biometria'] == true;
                          return Card(
                            color: Colors.grey[850],
                            child: ListTile(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => ModalPerfilDetalle(perfil: emisor, distanciaTxt: 'Pendiente', relacionExistenteInit: s, miId: miId!)
                                );
                              },
                              title: Row(
                                children: [
                                  Text(emisor['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white)),
                                  if (esVerificado) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Colors.blueAccent, size: 16)),
                                ],
                              ),
                              subtitle: const Text('Toque para ver perfil', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
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
                        final esVerificado = otroPerfil['verificado_biometria'] == true;
                        
                        final bool yoDiLike = (s['emisor_id'] == miId) ? (s['emisor_like'] == true) : (s['receptor_like'] == true);
                        final bool elDioLike = (s['emisor_id'] == miId) ? (s['receptor_like'] == true) : (s['emisor_like'] == true);
                        final bool matchMutuo = yoDiLike && elDioLike;

                        final mensajesSinLeer = mensajesTotales.where((m) => m['receptor_id'] == miId && m['emisor_id'] == otroId && (m['leido'] == null || m['leido'] == false)).length;

                        return Card(
                          color: Colors.grey[900],
                          child: ListTile(
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      builder: (_) => ModalPerfilDetalle(perfil: otroPerfil, distanciaTxt: 'Chat Abierto', relacionExistenteInit: s, miId: miId!)
                                    );
                                  },
                                  child: CircleAvatar(backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null, child: fotoUrl == null ? const Icon(Icons.person) : null),
                                ),
                                if (mensajesSinLeer > 0)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.grey[900]!, width: 2)),
                                      child: Text('$mensajesSinLeer', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  )
                              ],
                            ),
                            title: GestureDetector(
                               onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (_) => ModalPerfilDetalle(perfil: otroPerfil, distanciaTxt: 'Chat Abierto', relacionExistenteInit: s, miId: miId!)
                                  );
                               },
                               child: Row(
                                 children: [
                                   Text(otroPerfil['nombre'] ?? 'Explorador', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                   if (esVerificado) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Colors.blueAccent, size: 16)),
                                 ],
                               ),
                            ),
                            subtitle: matchMutuo 
                                ? const Text('💖 ¡Personas que se gustan!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                                : const Text('Toca aquí para abrir el chat'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                              onPressed: () => _eliminarVinculoYCreados(context, s['id'].toString(), otroId, miId!),
                            ),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaChat(receptorId: otroId, receptorNombre: otroPerfil['nombre'] ?? 'Explorador', receptorFoto: fotoUrl, solicitudId: s['id'].toString())));
                            },
                          ),
                        );
                      }),
                    ],
                  );
                },
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
  final String? receptorFoto;
  final String solicitudId;

  const PantallaChat({super.key, required this.receptorId, required this.receptorNombre, this.receptorFoto, required this.solicitudId});
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
      final fileBytes = await archivo.readAsBytes();
      
      await Supabase.instance.client.storage.from('chat-media').uploadBinary(fileName, fileBytes);
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
        ),
        actions: [
          if (widget.solicitudId.isNotEmpty)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('solicitudes').stream(primaryKey: ['id']).eq('id', widget.solicitudId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                final sol = snapshot.data!.first;
                
                final bool soyEmisor = sol['emisor_id'] == miId;
                final bool yoDiLike = soyEmisor ? (sol['emisor_like'] == true) : (sol['receptor_like'] == true);
                final bool elDioLike = soyEmisor ? (sol['receptor_like'] == true) : (sol['emisor_like'] == true);
                final bool match = yoDiLike && elDioLike;

                return Row(
                  children: [
                    if (match)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Text('💖 ¡Personas que se gustan!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    IconButton(
                      icon: Icon(yoDiLike ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent),
                      onPressed: () async {
                        final campo = soyEmisor ? 'emisor_like' : 'receptor_like';
                        await Supabase.instance.client.from('solicitudes').update({campo: !yoDiLike}).eq('id', widget.solicitudId);
                      }
                    ),
                  ],
                );
              }
            )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: streamMensajes,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final mensajesAll = snapshot.data!;
                    final mensajes = mensajesAll.where((m) => (m['emisor_id'] == miId && m['receptor_id'] == widget.receptorId) || (m['emisor_id'] == widget.receptorId && m['receptor_id'] == miId)).toList();

                    final mensajesNoLeidos = mensajes.where((m) => m['receptor_id'] == miId && m['leido'] == false).toList();
                    if (mensajesNoLeidos.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Supabase.instance.client.from('mensajes').update({'leido': true}).eq('receptor_id', miId!).eq('emisor_id', widget.receptorId).eq('leido', false).then((_) {}).catchError((_) {});
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
                        
                        DateTime fecha = DateTime.now();
                        if (mensaje['created_at'] != null) {
                          fecha = DateTime.tryParse(mensaje['created_at'].toString())?.toLocal() ?? DateTime.now();
                        }
                        final horaStr = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
                        final leido = mensaje['leido'] ?? false;

                        Widget contenidoBurbuja;
                        if (textoOriginal.startsWith('[IMG]') && textoOriginal.length > 5) {
                          contenidoBurbuja = ClipRRect(
                            borderRadius: BorderRadius.circular(8), 
                            child: Image.network(
                              textoOriginal.substring(5), 
                              width: 200, 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 200, height: 100, color: Colors.grey[850],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey, size: 30),
                                    SizedBox(height: 5),
                                    Text('Bloqueado', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              ),
                            )
                          );
                        } else if (textoOriginal.startsWith('[VID]') && textoOriginal.length > 5) {
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
        ),
      ),
    );
  }
}

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
      }).catchError((_) {});
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