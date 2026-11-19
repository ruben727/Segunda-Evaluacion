import 'package:flutter/foundation.dart';
import '../models/incidencia.dart';
import '../services/api_service.dart';

/// Estado del sistema de incidencias (Prácticas 7 y 8).
///
/// - Usuario: reporta incidencias y ve solo las suyas ([misIncidencias]).
/// - Agente/admin: ve todas ([todas]), cambia estado y asigna agente.
/// - Admin: además puede limpiar el historial de pruebas.
///
/// Los métodos que escriben devuelven `null` si salió bien o el mensaje a
/// mostrar. Los mensajes son genéricos: nunca se muestra texto técnico.
class IncidenciaProvider extends ChangeNotifier {
  final ApiService _api;

  IncidenciaProvider({ApiService? apiService}) : _api = apiService ?? ApiService();

  static const mensajeSinPermiso = 'No tienes permisos para esta acción';
  static const mensajeErrorGenerico = 'No se pudo completar la operación. Intenta de nuevo';
  static const mensajeSesion = 'Tu sesión expiró. Inicia sesión de nuevo';

  List<Incidencia> misIncidencias = [];
  List<Incidencia> todas = [];
  List<Agente> agentes = [];
  bool isLoading = false;
  bool isGuardando = false;
  String? errorMessage;

  Map<String, int> get conteoMias => OpcionesIncidencia.contarPorEstado(misIncidencias);
  Map<String, int> get conteoTodas => OpcionesIncidencia.contarPorEstado(todas);

  /// Traduce cualquier error a un mensaje apto para el usuario.
  static String mensajePara(Object error) {
    if (error is ApiException) {
      if (error.sinPermiso) return mensajeSinPermiso;
      if (error.sesionInvalida) return mensajeSesion;
      // 400/404/409 del backend de incidencias ya vienen redactados para
      // el usuario (p. ej. "Selecciona tipo"); 5xx y red, genérico.
      final status = error.statusCode;
      if (status != null && status >= 400 && status < 500) return error.mensaje;
    }
    return mensajeErrorGenerico;
  }

  /// Valida que las tres opciones estén elegidas y guarda. Devuelve `null`
  /// si se guardó o el mensaje de error.
  Future<String?> reportar({String? tipo, String? equipo, String? prioridad}) async {
    final errorValidacion = OpcionesIncidencia.validarSeleccion(
      tipo: tipo,
      equipo: equipo,
      prioridad: prioridad,
    );
    if (errorValidacion != null) return errorValidacion;

    isGuardando = true;
    notifyListeners();
    try {
      final nueva = await _api.crearIncidencia(tipo: tipo!, equipo: equipo!, prioridad: prioridad!);
      misIncidencias = [nueva, ...misIncidencias];
      return null;
    } catch (e) {
      return mensajePara(e);
    } finally {
      isGuardando = false;
      notifyListeners();
    }
  }

  Future<void> cargarMias() async {
    await _cargar(() async => misIncidencias = await _api.getMisIncidencias());
  }

  /// Carga todas las incidencias y la lista de agentes (agente/admin).
  Future<void> cargarTodas() async {
    await _cargar(() async {
      final resultados = await Future.wait([_api.getTodasIncidencias(), _api.getAgentes()]);
      todas = resultados[0] as List<Incidencia>;
      agentes = resultados[1] as List<Agente>;
    });
  }

  Future<void> _cargar(Future<void> Function() accion) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await accion();
    } catch (e) {
      errorMessage = mensajePara(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> cambiarEstado(String id, String estado) {
    if (!OpcionesIncidencia.estados.contains(estado)) {
      return Future.value('Estado no válido');
    }
    return _actualizar(id, () => _api.actualizarIncidencia(id, estado: estado));
  }

  /// [agenteId] = null quita la asignación.
  Future<String?> asignarAgente(String id, String? agenteId) {
    return _actualizar(
      id,
      () => agenteId == null
          ? _api.actualizarIncidencia(id, quitarAgente: true)
          : _api.actualizarIncidencia(id, agenteId: agenteId),
    );
  }

  /// El dueño puede cambiar la prioridad de su incidencia mientras siga
  /// pendiente (el backend lo valida).
  Future<String?> cambiarPrioridad(String id, String prioridad) {
    if (!OpcionesIncidencia.prioridades.contains(prioridad)) {
      return Future.value('Prioridad no válida');
    }
    return _actualizar(id, () => _api.actualizarIncidencia(id, prioridad: prioridad));
  }

  Future<String?> _actualizar(String id, Future<Incidencia> Function() peticion) async {
    try {
      final actualizada = await peticion();
      todas = [for (final i in todas) i.id == id ? actualizada : i];
      misIncidencias = [for (final i in misIncidencias) i.id == id ? actualizada : i];
      notifyListeners();
      return null;
    } catch (e) {
      return mensajePara(e);
    }
  }

  /// Borra todo el historial (solo admin; el backend responde 403 al resto).
  Future<String?> limpiarHistorial() async {
    try {
      await _api.limpiarIncidencias();
      todas = [];
      misIncidencias = [];
      notifyListeners();
      return null;
    } catch (e) {
      return mensajePara(e);
    }
  }

  /// Al cerrar sesión, para que el siguiente usuario no vea datos ajenos.
  void limpiarEstadoLocal() {
    misIncidencias = [];
    todas = [];
    agentes = [];
    errorMessage = null;
    notifyListeners();
  }
}
