import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/concierto.dart';
import '../models/diseno.dart';
import '../models/incidencia.dart';
import '../models/mi_diseno.dart';
import '../models/mi_evento.dart';
import '../models/resultado_busqueda.dart';
import 'auth_service.dart';

/// Error de la API con el código HTTP, para que los providers decidan el
/// mensaje (p. ej. 403 → sin permisos) sin mostrar texto técnico.
class ApiException implements Exception {
  final int? statusCode;
  final String mensaje;

  const ApiException(this.statusCode, this.mensaje);

  bool get sinPermiso => statusCode == 403;
  bool get sesionInvalida => statusCode == 401;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP que avisa cuando el backend rechaza el token (401) en una
/// petición que sí lo llevaba: token vencido (dura 7 días) o inválido.
class _ClienteConSesion extends http.BaseClient {
  final http.Client _interno = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final respuesta = await _interno.send(request);
    if (respuesta.statusCode == 401 && request.headers.containsKey('Authorization')) {
      ApiService.onSesionExpirada?.call();
    }
    return respuesta;
  }
}

/// Cliente HTTP central para hablar con el backend Express.js.
class ApiService {
  /// Se llama cuando el backend responde 401 a una petición autenticada.
  /// La app lo conecta a [AuthProvider.sesionExpirada] (ver app.dart) para
  /// cerrar la sesión y mandar al login, en lugar de mostrar
  /// "Token inválido o expirado" en cada pantalla.
  static void Function()? onSesionExpirada;

  /// Compartido por todas las instancias de ApiService.
  static final http.Client _http = _ClienteConSesion();

  final AuthService _authService;

  ApiService({AuthService? authService}) : _authService = authService ?? AuthService();

  Future<Map<String, String>> _headers({bool conAuth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (conAuth) {
      final token = await _authService.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  Future<List<Concierto>> getConciertos() async {
    final res = await _http.get(_uri(ApiConstants.conciertos), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar los conciertos');
    }
    final lista = jsonDecode(res.body) as List<dynamic>;
    return lista.map((e) => Concierto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Concierto> getConciertoById(String id) async {
    final res = await _http.get(_uri(ApiConstants.concierto(id)), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('No se pudo cargar el concierto');
    }
    return Concierto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Diseno> createDiseno({
    required String conciertoId,
    required String nombre,
    required List<Map<String, dynamic>> configuraciones,
  }) async {
    final res = await _http.post(
      _uri(ApiConstants.disenos),
      headers: await _headers(conAuth: true),
      body: jsonEncode({
        'concierto_id': conciertoId,
        'nombre': nombre,
        'configuraciones': configuraciones,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(data['error'] ?? 'No se pudo crear el diseño');
    }
    return Diseno.fromJson(data['diseno'] as Map<String, dynamic>);
  }

  Future<Diseno> getDisenoPorCodigo(String codigo) async {
    final res = await _http.get(_uri(ApiConstants.disenoPorCodigo(codigo)), headers: await _headers());
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Código de evento no válido');
    }
    return Diseno.fromJson(data);
  }

  Future<void> joinEvento({
    required String codigo,
    required String zona,
    required String fila,
    required String asiento,
  }) async {
    final res = await _http.post(
      _uri(ApiConstants.unirseEvento),
      headers: await _headers(conAuth: true),
      body: jsonEncode({'codigo': codigo, 'zona': zona, 'fila': fila, 'asiento': asiento}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(data['error'] ?? 'No se pudo unir al evento');
    }
  }

  /// Cambia el nombre de un diseño propio (el backend responde 403 si no
  /// es del usuario autenticado).
  Future<void> updateDiseno({required String id, required String nombre}) async {
    final res = await _http.put(
      _uri(ApiConstants.disenoPorId(id)),
      headers: await _headers(conAuth: true),
      body: jsonEncode({'nombre': nombre}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'No se pudo actualizar el diseño');
    }
  }

  /// Elimina un diseño propio; su código deja de ser válido.
  Future<void> deleteDiseno(String id) async {
    final res = await _http.delete(_uri(ApiConstants.disenoPorId(id)), headers: await _headers(conAuth: true));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'No se pudo eliminar el diseño');
    }
  }

  /// Diseños creados por el usuario, para "Mis diseños" en el perfil.
  Future<List<MiDiseno>> getMisDisenos() async {
    final res = await _http.get(_uri(ApiConstants.misDisenos), headers: await _headers(conAuth: true));
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar tus diseños');
    }
    final lista = jsonDecode(res.body) as List<dynamic>;
    return lista.map((e) => MiDiseno.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Conciertos a los que el usuario se unió con un código, para la
  /// pestaña "Conciertos".
  Future<List<MiEvento>> getMisEventos() async {
    final res = await _http.get(_uri(ApiConstants.misEventos), headers: await _headers(conAuth: true));
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar tus conciertos');
    }
    final lista = jsonDecode(res.body) as List<dynamic>;
    return lista.map((e) => MiEvento.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _http.get(_uri(ApiConstants.perfil), headers: await _headers(conAuth: true));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'No se pudo cargar el perfil');
    }
    return data;
  }

  /// Consulta la última lectura simulada publicada por el reloj vía HTTP.
  /// Puente público (sin auth) usado cuando el teléfono y el reloj corren
  /// en emuladores separados y no pueden verse por BLE real. Devuelve
  /// `null` si el reloj todavía no ha publicado ningún dato.
  Future<Map<String, dynamic>?> getWearableSimulacion() async {
    final res = await _http.get(_uri(ApiConstants.wearableSimulacion));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<void> enviarDatoWearable({
    required int ritmo,
    required String efectoColor,
    required bool vibracion,
    String? disenoId,
  }) async {
    await _http.post(
      _uri(ApiConstants.wearableDatos),
      headers: await _headers(conAuth: true),
      body: jsonEncode({
        'ritmo': ritmo,
        'efecto_color': efectoColor,
        'vibracion': vibracion,
        'diseno_id': disenoId,
      }),
    );
  }

  /// Manda al reloj (vía backend) el color de la canción que se acaba de
  /// reproducir, para que su pantalla cambie de color. Puente público.
  Future<void> enviarComandoWearable({
    required String colorHex,
    required int duracionSeg,
    String? cancionTitulo,
  }) async {
    await _http.post(
      _uri(ApiConstants.wearableComando),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'color_hex': colorHex,
        'duracion_seg': duracionSeg,
        'cancion_titulo': cancionTitulo,
      }),
    );
  }

  /// Le dice al reloj que deje de mostrar el color de la canción (vuelve
  /// a negro/apagado).
  Future<void> detenerComandoWearable() async {
    await _http.post(_uri(ApiConstants.wearableComandoDetener), headers: {'Content-Type': 'application/json'});
  }

  // ---------------------------------------------------------------
  // Incidencias (Prácticas 7-10). Los permisos los decide el backend:
  // un usuario normal recibe 403 si pide todas o cambia el estado.
  // ---------------------------------------------------------------

  /// Hace la petición y devuelve el JSON decodificado; si el status no es
  /// el esperado lanza [ApiException] (el mensaje del backend ya viene
  /// redactado para el usuario, pero el provider puede sustituirlo).
  /// Tiempo máximo por intento (antes no había límite: la petición podía quedar pendiente para siempre).
  static const timeoutPeticion = Duration(seconds: 15);

  /// Espera progresiva entre reintentos de escrituras (exponential backoff): 1 s, 2 s y 4 s.
  static List<Duration> esperasReintento = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];

  /// Clave de idempotencia por escritura PENDIENTE (mismo contenido = misma operación). Se reutiliza en
  /// los reintentos automáticos y en el reintento manual del usuario, y se borra tras un éxito.
  static final Map<String, String> _clavesPendientes = {};

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Hace la petición y devuelve el JSON decodificado; si el status no es
  /// el esperado lanza [ApiException]. Con [reintentar], los errores transitorios
  /// (sin red, timeout o 5xx) se reintentan con [esperasReintento]; los 4xx nunca.
  Future<dynamic> _enviar(Future<http.Response> Function() peticion, int esperado, {bool reintentar = false}) async {
    var intento = 0;
    while (true) {
      try {
        return await _enviarUnaVez(peticion, esperado);
      } on ApiException catch (e) {
        final transitorio = e.statusCode == null || e.statusCode! >= 500;
        if (!reintentar || !transitorio || intento >= esperasReintento.length) rethrow;
        await Future<void>.delayed(esperasReintento[intento++]);
      }
    }
  }

  Future<dynamic> _enviarUnaVez(Future<http.Response> Function() peticion, int esperado) async {
    final http.Response res;
    try {
      res = await peticion().timeout(timeoutPeticion);
    } on TimeoutException {
      throw const ApiException(null, 'El servidor tardó demasiado en responder');
    } catch (_) {
      throw const ApiException(null, 'No se pudo conectar con el servidor');
    }
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (res.statusCode != esperado) {
      final mensaje = data is Map && data['error'] is String ? data['error'] as String : 'Ocurrió un error';
      throw ApiException(res.statusCode, mensaje);
    }
    return data;
  }

  Future<Incidencia> crearIncidencia({
    required String tipo,
    required String equipo,
    required String prioridad,
  }) async {
    final cuerpo = jsonEncode({'tipo': tipo, 'equipo': equipo, 'prioridad': prioridad});
    final clave = _clavesPendientes.putIfAbsent(cuerpo, _uuidV4);
    final headers = {...await _headers(conAuth: true), 'Idempotency-Key': clave};
    final data = await _enviar(() => _http.post(_uri(ApiConstants.incidencias), headers: headers, body: cuerpo), 201, reintentar: true);
    _clavesPendientes.remove(cuerpo);
    return Incidencia.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Incidencia>> getMisIncidencias() async {
    final data = await _enviar(
      () async => _http.get(_uri(ApiConstants.misIncidencias), headers: await _headers(conAuth: true)),
      200,
    );
    return (data as List<dynamic>).map((e) => Incidencia.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Todas las incidencias (solo agente/admin; el resto recibe 403).
  Future<List<Incidencia>> getTodasIncidencias() async {
    final data = await _enviar(
      () async => _http.get(_uri(ApiConstants.incidencias), headers: await _headers(conAuth: true)),
      200,
    );
    return (data as List<dynamic>).map((e) => Incidencia.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Agente>> getAgentes() async {
    final data = await _enviar(
      () async => _http.get(_uri(ApiConstants.agentesIncidencias), headers: await _headers(conAuth: true)),
      200,
    );
    return (data as List<dynamic>).map((e) => Agente.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Envía solo los campos indicados. Para quitar el agente asignado usa
  /// [quitarAgente] = true.
  Future<Incidencia> actualizarIncidencia(
    String id, {
    String? estado,
    String? agenteId,
    bool quitarAgente = false,
    String? prioridad,
  }) async {
    final body = <String, dynamic>{
      'estado': ?estado,
      'prioridad': ?prioridad,
      if (agenteId != null) 'agente_asignado': int.tryParse(agenteId) ?? agenteId,
      if (quitarAgente) 'agente_asignado': null,
    };
    final data = await _enviar(
      () async => _http.patch(
        _uri(ApiConstants.incidencia(id)),
        headers: await _headers(conAuth: true),
        body: jsonEncode(body),
      ),
      200,
    );
    return Incidencia.fromJson(data as Map<String, dynamic>);
  }

  /// Borra todo el historial de incidencias (solo admin). Devuelve cuántas
  /// se eliminaron.
  Future<int> limpiarIncidencias() async {
    final data = await _enviar(
      () async => _http.delete(_uri(ApiConstants.incidencias), headers: await _headers(conAuth: true)),
      200,
    );
    return (data is Map && data['eliminadas'] is int) ? data['eliminadas'] as int : 0;
  }

  /// Búsqueda difusa (tolera errores de escritura) sobre artistas, tours,
  /// estadios, ciudades y canciones. Endpoint público.
  Future<RespuestaBusqueda> buscar(String consulta, {int limite = 10}) async {
    final uri = _uri(ApiConstants.buscar).replace(queryParameters: {'q': consulta, 'limite': '$limite'});
    final data = await _enviar(() async => _http.get(uri, headers: await _headers()), 200);
    return RespuestaBusqueda.fromJson(data as Map<String, dynamic>);
  }
}
