import 'dart:async';
import 'dart:math';

/// Lectura simulada generada por el reloj: ritmo cardiaco, oxígeno en
/// sangre (SpO2) y vibración. Estos son los 3 datos de "salud" que se
/// envían al teléfono; el color de la pantalla NO sale de aquí — lo
/// controla el teléfono cuando el usuario reproduce una canción (ver
/// comando_poller.dart).
class LecturaSimulada {
  final int ritmo;
  final int oxigeno;
  final bool vibracion;

  const LecturaSimulada({
    required this.ritmo,
    required this.oxigeno,
    required this.vibracion,
  });
}

/// Genera datos falsos de sensores cada segundo, simulando "momentos de
/// coro" cada 30 segundos donde el BPM sube, el oxígeno baja un poco y
/// la vibración se activa.
class SensorSimulator {
  final _random = Random();

  Timer? _timer;
  int _segundos = 0;

  final _controller = StreamController<LecturaSimulada>.broadcast();
  Stream<LecturaSimulada> get stream => _controller.stream;

  void iniciar() {
    _segundos = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    _segundos++;
    final enCoro = _segundos % 30 < 6; // 6 segundos de "coro" cada 30s

    final bpm = enCoro
        ? 100 + _random.nextInt(41) // 100-140
        : 60 + _random.nextInt(61); // 60-120

    final oxigeno = enCoro
        ? 93 + _random.nextInt(6) // 93-98 (un poco más bajo con esfuerzo)
        : 96 + _random.nextInt(5); // 96-100

    _controller.add(LecturaSimulada(
      ritmo: bpm,
      oxigeno: oxigeno,
      vibracion: enCoro,
    ));
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
