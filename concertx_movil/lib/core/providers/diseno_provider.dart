import 'package:flutter/foundation.dart';
import '../models/configuracion_luz.dart';
import '../models/diseno.dart';
import '../models/mi_diseno.dart';
import '../models/mi_evento.dart';
import '../services/api_service.dart';

class DisenoProvider extends ChangeNotifier {
  final ApiService _apiService;

  DisenoProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  bool isLoading = false;
  String? errorMessage;
  Diseno? ultimoDisenoCreado;
  Diseno? disenoUnido;

  List<MiDiseno> misDisenos = [];
  List<MiEvento> misEventos = [];
  bool isLoadingMisDisenos = false;
  bool isLoadingMisEventos = false;

  Future<bool> crearDiseno({
    required String conciertoId,
    required String nombre,
    required List<ConfiguracionLuz> configuraciones,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      ultimoDisenoCreado = await _apiService.createDiseno(
        conciertoId: conciertoId,
        nombre: nombre,
        configuraciones: configuraciones.map((c) => c.toJson()).toList(),
      );
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> unirseConCodigo({
    required String codigo,
    required String zona,
    required String fila,
    required String asiento,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      disenoUnido = await _apiService.getDisenoPorCodigo(codigo);
      await _apiService.joinEvento(codigo: codigo, zona: zona, fila: fila, asiento: asiento);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> validarCodigo(String codigo) async {
    try {
      disenoUnido = await _apiService.getDisenoPorCodigo(codigo);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchMisDisenos() async {
    isLoadingMisDisenos = true;
    notifyListeners();
    try {
      misDisenos = await _apiService.getMisDisenos();
    } catch (_) {
      // Se mantiene la última lista conocida si falla.
    } finally {
      isLoadingMisDisenos = false;
      notifyListeners();
    }
  }

  Future<void> fetchMisEventos() async {
    isLoadingMisEventos = true;
    notifyListeners();
    try {
      misEventos = await _apiService.getMisEventos();
    } catch (_) {
      // Se mantiene la última lista conocida si falla.
    } finally {
      isLoadingMisEventos = false;
      notifyListeners();
    }
  }
}
