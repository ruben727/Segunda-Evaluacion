import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

/// Controla la "reproducción" de canciones de un diseño: al iniciar una
/// canción, manda su color al reloj (vía backend) y lleva la cuenta
/// regresiva de su duración. Al terminar (o al detener manualmente), le
/// avisa al reloj para que vuelva a apagarse (negro). También le avisa a
/// Concertx TV (WebSocket) qué canción está sonando, para que la
/// tarjeta "Canción actual" se actualice sola.
class ReproductorProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SyncService _syncService;

  ReproductorProvider({ApiService? apiService, SyncService? syncService})
      : _apiService = apiService ?? ApiService(),
        _syncService = syncService ?? SyncService();

  String? cancionId;
  String? tituloActual;
  String? artistaActual;
  String? colorActual;
  int duracionTotal = 0;
  int segundosRestantes = 0;

  Timer? _timer;
  bool get reproduciendo => _timer != null;

  Future<void> reproducir({
    required String cancionId,
    required String titulo,
    required String colorHex,
    required int duracionSeg,
    String artista = '',
  }) async {
    _timer?.cancel();

    this.cancionId = cancionId;
    tituloActual = titulo;
    artistaActual = artista;
    colorActual = colorHex;
    duracionTotal = duracionSeg;
    segundosRestantes = duracionSeg;
    notifyListeners();

    await _apiService.enviarComandoWearable(
      colorHex: colorHex,
      duracionSeg: duracionSeg,
      cancionTitulo: titulo,
    );
    // Por si el socket compartido todavía no se había abierto (ej. se
    // reprodujo una canción sin haber pasado antes por Home): conectar()
    // no hace nada si ya está conectado.
    await _syncService.conectar();
    _syncService.enviarCancion(titulo, artista, duracionSeg);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      segundosRestantes--;
      if (segundosRestantes <= 0) {
        detener();
      } else {
        notifyListeners();
      }
    });
  }

  /// Repite la canción que está sonando ahora mismo desde el inicio.
  Future<void> repetir() async {
    if (cancionId == null || tituloActual == null || colorActual == null) return;
    await reproducir(
      cancionId: cancionId!,
      titulo: tituloActual!,
      colorHex: colorActual!,
      duracionSeg: duracionTotal,
      artista: artistaActual ?? '',
    );
  }

  /// Detiene la reproducción (botón "Quitar" o fin natural de la
  /// canción) y le avisa al reloj que vuelva a apagarse.
  Future<void> detener() async {
    _timer?.cancel();
    _timer = null;
    cancionId = null;
    tituloActual = null;
    artistaActual = null;
    colorActual = null;
    segundosRestantes = 0;
    notifyListeners();
    await _apiService.detenerComandoWearable();
  }

  String get tiempoRestanteFormateado {
    final m = (segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
