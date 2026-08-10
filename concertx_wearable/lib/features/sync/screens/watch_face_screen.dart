import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/wear_theme.dart';
import '../services/ble_server_service.dart';
import '../services/sensor_simulator.dart';
import '../services/sync_bridge_service.dart';

/// Pantalla principal del reloj: círculo a pantalla completa que cambia
/// de color según la canción que el usuario esté reproduciendo en el
/// teléfono. Sin reloj, sin menús, sin navegación — solo título, nota
/// musical y los datos de salud que se envían al teléfono.
class WatchFaceScreen extends StatefulWidget {
  const WatchFaceScreen({super.key});

  @override
  State<WatchFaceScreen> createState() => _WatchFaceScreenState();
}

class _WatchFaceScreenState extends State<WatchFaceScreen> {
  final _bleServer = BleServerService();
  final _sensor = SensorSimulator();
  final _bridge = SyncBridgeService();

  bool _activo = false; // controla la generación de datos de salud
  int? _ritmoActual;
  int? _oxigenoActual;
  bool _vibracionActual = false;

  // Tercer dato mostrado en el reloj: calorías quemadas acumuladas durante
  // la sesión (estimadas a partir del ritmo cardiaco). Se acumula en
  // double para que suba de forma gradual y visible, y se redondea solo
  // al mostrarla.
  double _caloriasAcumuladas = 0;

  Color? _colorComando; // color mandado por el teléfono (canción activa)

  StreamSubscription? _sensorSub;
  Timer? _comandoTimer;

  @override
  void initState() {
    super.initState();

    _sensorSub = _sensor.stream.listen((lectura) {
      // BLE real (para hardware físico): best-effort, no bloquea nada si
      // el emulador no soporta modo periférico.
      _bleServer.enviarRitmo(lectura.ritmo);
      _bleServer.enviarOxigeno(lectura.oxigeno);
      _bleServer.enviarVibracion(lectura.vibracion);

      final colorMostrado = _colorComando != null
          ? _hexDe(_colorComando!)
          : '#0D1F3C';
      _bleServer.enviarColor(colorMostrado);

      // Puente HTTP (para que el teléfono vea el mismo dato aunque ambos
      // sean emuladores sin BLE real entre sí).
      _bridge.publicar(
        ritmo: lectura.ritmo,
        oxigeno: lectura.oxigeno,
        colorHex: colorMostrado,
        vibracion: lectura.vibracion,
      );

      // Estimación simple de calorías quemadas: más esfuerzo (vibración
      // activa, momento de "coro") quema más rápido que en reposo.
      _caloriasAcumuladas += lectura.vibracion ? 0.35 : 0.15;

      if (mounted) {
        setState(() {
          _ritmoActual = lectura.ritmo;
          _oxigenoActual = lectura.oxigeno;
          _vibracionActual = lectura.vibracion;
        });
      }
    });

    // El polling de comandos corre siempre (independiente del botón
    // Iniciar/Detener) para que el reloj refleje la canción que el
    // usuario está reproduciendo en el teléfono en cuanto pase algo.
    _comandoTimer = Timer.periodic(const Duration(seconds: 1), (_) => _consultarComando());
  }

  Future<void> _consultarComando() async {
    final comando = await _bridge.consultarComando();
    if (!mounted) return;

    final activo = comando != null && comando['activo'] == true;
    if (!activo) {
      if (_colorComando != null) setState(() => _colorComando = null);
      return;
    }

    final colorHex = comando['color_hex'] as String?;
    if (colorHex == null) return;
    setState(() => _colorComando = WearColors.fromHex(colorHex));
  }

  String _hexDe(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _alternar() async {
    if (_activo) {
      _sensor.detener();
      await _bleServer.detener();
      setState(() {
        _activo = false;
        _ritmoActual = null;
        _oxigenoActual = null;
        _vibracionActual = false;
        _caloriasAcumuladas = 0;
      });
    } else {
      // El simulador (y el puente HTTP) arrancan siempre; el servidor BLE
      // es best-effort porque muchos emuladores no soportan modo
      // periférico/advertising y no debe bloquear la demo.
      setState(() => _activo = true);
      _sensor.iniciar();
      unawaited(_bleServer.iniciar());
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _comandoTimer?.cancel();
    _sensor.dispose();
    _bleServer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorFondo = _colorComando ?? WearColors.darkNavy;

    // Se usa el tamaño real disponible (LayoutBuilder) en vez de un
    // valor fijo: el emulador/reloj real puede tener otras medidas, y
    // con un tamaño fijo el contenido no coincidía con el círculo real
    // (se veía amontonado o se cortaba). Además, todo se organiza en
    // una columna (en vez de posiciones absolutas) para que sea
    // imposible que dos elementos se encimen.
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final diametro = constraints.biggest.shortestSide;

          return Center(
            child: ClipOval(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: diametro,
                height: diametro,
                color: colorFondo,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anillo exterior sutil.
                    Container(
                      width: diametro * 0.84,
                      height: diametro * 0.84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: diametro * 0.09),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Título superior.
                          const Text(
                            'CONCERTX',
                            style: TextStyle(
                              fontFamily: poppinsFamily,
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          // Nota musical (más pequeña) + datos de salud,
                          // cada uno con su propio espacio (sin encimarse).
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note, color: Colors.white, size: 26),
                              const SizedBox(height: 10),
                              if (_activo && _ritmoActual != null) _buildDatosSalud(),
                            ],
                          ),
                          // Botón Iniciar/Detener + estado.
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _alternar,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                                  ),
                                  child: Text(
                                    _activo ? 'Detener' : 'Iniciar',
                                    style: const TextStyle(
                                      fontFamily: poppinsFamily,
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(width: 40, height: 1, color: Colors.white),
                              const SizedBox(height: 4),
                              Text(
                                _textoEstado(),
                                style: TextStyle(
                                  fontFamily: poppinsFamily,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatosSalud() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wrap (en vez de Row fijo) para que, si el reloj es más angosto,
        // los 3 datos pasen a una segunda línea en vez de desbordarse.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 2,
          children: [
            _buildDato(Icons.favorite, '$_ritmoActual BPM'),
            _buildDato(Icons.water_drop, '$_oxigenoActual%'),
            _buildDato(Icons.local_fire_department, '${_caloriasAcumuladas.round()} kcal'),
          ],
        ),
        if (_vibracionActual) ...[
          const SizedBox(height: 4),
          const Icon(Icons.vibration, color: Colors.white, size: 11),
        ],
      ],
    );
  }

  Widget _buildDato(IconData icono, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, color: Colors.white, size: 11),
        const SizedBox(width: 3),
        Text(texto, style: _estiloDato()),
      ],
    );
  }

  TextStyle _estiloDato() {
    return const TextStyle(
      fontFamily: poppinsFamily,
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
  }

  // Nunca muestra "error de bluetooth": en un emulador el BLE real casi
  // nunca conecta (no hay radio compartida entre dos AVDs) pero eso no
  // significa que algo esté roto — el puente HTTP sigue funcionando.
  String _textoEstado() {
    if (!_activo) return 'detenido';
    if (_colorComando != null) return 'reproduciendo';
    return 'transmitiendo salud';
  }
}
