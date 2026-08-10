import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/concierto.dart';
import '../models/diseno.dart';
import '../models/mi_diseno.dart';
import '../models/mi_evento.dart';
import 'auth_service.dart';

/// Cliente HTTP central para hablar con el backend Express.js.
class ApiService {
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
    final res = await http.get(_uri(ApiConstants.conciertos), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar los conciertos');
    }
    final lista = jsonDecode(res.body) as List<dynamic>;
    return lista.map((e) => Concierto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Concierto> getConciertoById(String id) async {
    final res = await http.get(_uri(ApiConstants.concierto(id)), headers: await _headers());
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
    final res = await http.post(
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
    final res = await http.get(_uri(ApiConstants.disenoPorCodigo(codigo)), headers: await _headers());
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
    final res = await http.post(
      _uri(ApiConstants.unirseEvento),
      headers: await _headers(conAuth: true),
      body: jsonEncode({'codigo': codigo, 'zona': zona, 'fila': fila, 'asiento': asiento}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(data['error'] ?? 'No se pudo unir al evento');
    }
  }

  /// Diseños creados por el usuario, para "Mis diseños" en el perfil.
  Future<List<MiDiseno>> getMisDisenos() async {
    final res = await http.get(_uri(ApiConstants.misDisenos), headers: await _headers(conAuth: true));
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar tus diseños');
    }
    final lista = jsonDecode(res.body) as List<dynamic>;
    return lista.map((e) => MiDiseno.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Conciertos a los que el usuario se unió con un código, para la
  /// pestaña "Conciertos".
  Future<List<MiEvento>> getMisEventos() async {
    final res = await http.get(_uri(ApiConstants.misEventos), headers: await _headers(conAuth: true));
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar tus conciertos');
    }
    final lista = jsonDecode(res.body) as List<dynamic>;
    return lista.map((e) => MiEvento.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(_uri(ApiConstants.perfil), headers: await _headers(conAuth: true));
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
    final res = await http.get(_uri(ApiConstants.wearableSimulacion));
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
    await http.post(
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
    await http.post(
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
    await http.post(_uri(ApiConstants.wearableComandoDetener), headers: {'Content-Type': 'application/json'});
  }
}
