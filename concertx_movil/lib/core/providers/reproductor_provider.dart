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

  /// Empieza la canción DE INMEDIATO (estado, cuenta regresiva y UI) y
  /// avisa al reloj y a la TV en segundo plano. Antes se esperaba a la red
  /// (POST a Vercel + WebSocket a la TV) antes de arrancar, lo que hacía
  /// que la canción y las opciones de pantalla completa/lámpara tardaran
  /// varios segundos, o no aparecieran si la red fallaba.
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

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      segundosRestantes--;
      if (segundosRestantes <= 0) {
        detener();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();

    unawaited(_avisarDispositivos(cancionId, titulo, colorHex, duracionSeg, artista));
  }

  /// Avisos de red de [reproducir]. Si fallan, la canción sigue sonando en
  /// el teléfono; si mientras tanto se cambió de canción, no se manda el
  /// aviso viejo a la TV.
  Future<void> _avisarDispositivos(
    String id,
    String titulo,
    String colorHex,
    int duracionSeg,
    String artista,
  ) async {
    try {
      await _apiService.enviarComandoWearable(
        colorHex: colorHex,
        duracionSeg: duracionSeg,
        cancionTitulo: titulo,
      );
    } catch (_) {
      // Sin red o backend caído: el reloj no cambia, pero el teléfono sí.
    }
    // Por si el socket compartido todavía no se había abierto (ej. se
    // reprodujo una canción sin haber pasado antes por Home): conectar()
    // no hace nada si ya está conectado.
    await _syncService.conectar();
    if (cancionId != id) return; // ya suena otra canción
    // Marca qué artista está sonando: la TV solo se actualiza cuando es
    // el diseño de SyncService.artistaAutorizadoTV (ver sync_service.dart).
    _syncService.setArtistaActivo(artista);
    _syncService.enviarCancion(titulo, artista, duracionSeg);
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
    // Sin canción activa, ningún dato del reloj debe seguir llegándole a
    // la TV hasta que se reproduzca de nuevo el diseño autorizado.
    _syncService.setArtistaActivo(null);
    notifyListeners();
    // Avisar al reloj en segundo plano: la UI ya se actualizó.
    unawaited(_apiService.detenerComandoWearable().catchError((_) {}));
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
