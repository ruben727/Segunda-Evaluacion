import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/resultado_busqueda.dart';
import '../services/api_service.dart';

/// Estado del buscador difuso. Mientras el usuario escribe:
///  - espera [debounce] sin teclear antes de llamar a la API (no se hace
///    una petición por cada letra);
///  - si llegan respuestas fuera de orden, solo se aplica la de la última
///    consulta escrita.
class BusquedaProvider extends ChangeNotifier {
  final ApiService _api;
  final Duration debounce;

  BusquedaProvider({ApiService? apiService, this.debounce = const Duration(milliseconds: 300)})
      : _api = apiService ?? ApiService();

  static const mensajeError = 'No se pudo buscar. Revisa tu conexión e intenta de nuevo';

  String consulta = '';
  List<ResultadoBusqueda> resultados = [];
  String? sugerencia;

  /// Motor que respondió la última búsqueda ('elasticsearch' o 'postgres').
  String? motor;
  bool isLoading = false;
  String? errorMessage;

  /// true cuando ya hubo una respuesta para la consulta actual (para
  /// distinguir "sin resultados" de "todavía no se ha buscado").
  bool buscado = false;

  Timer? _timer;
  int _peticionActual = 0;

  /// Llamar en cada cambio del campo de texto.
  void escribir(String texto) {
    consulta = texto;
    _timer?.cancel();
    final limpio = texto.trim();
    if (limpio.isEmpty) {
      _peticionActual++; // invalida respuestas en vuelo
      resultados = [];
      sugerencia = null;
      errorMessage = null;
      isLoading = false;
      buscado = false;
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    _timer = Timer(debounce, () => buscarAhora(limpio));
  }

  /// Busca de inmediato (al pulsar "buscar" en el teclado o tocar la
  /// sugerencia "¿Quisiste decir…?").
  Future<void> buscarAhora(String texto) async {
    _timer?.cancel();
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    final id = ++_peticionActual;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final respuesta = await _api.buscar(limpio);
      if (id != _peticionActual) return; // llegó tarde: ya se escribió otra cosa
      resultados = respuesta.resultados;
      sugerencia = respuesta.sugerencia;
      motor = respuesta.motor;
    } catch (_) {
      if (id != _peticionActual) return;
      resultados = [];
      sugerencia = null;
      errorMessage = mensajeError;
    }
    buscado = true;
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
