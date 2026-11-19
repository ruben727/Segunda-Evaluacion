// Práctica 12 – Fase 5: tiempos de detección y duplicados con el ApiService REAL de la app
// contra el backend LOCAL con fallos forzados (middleware temporal p12_fallos.js).
//   flutter test test/p12/p12_resiliencia_test.dart --dart-define=API_URL=http://localhost:3000/api
//   (sin servidor:  --dart-define=API_URL=http://localhost:3999/api  y P12_SOLO=sin_servidor)
// Variables: P12_FALLO_ARCHIVO = archivo de control que lee el middleware; P12_ETIQUETA = antes|despues.
// Solo IMPRIME lo observado (no afirma), para comparar antes y después con el mismo arnés.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:concertx_movil/core/constants/api_constants.dart';
import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class AuthDePrueba extends AuthService {
  AuthDePrueba(this.token);
  final String token;
  @override
  Future<String?> getToken() async => token;
}

final control = File(Platform.environment['P12_FALLO_ARCHIVO'] ?? 'p12_fallo.txt');
final etiqueta = Platform.environment['P12_ETIQUETA'] ?? 'sin-etiqueta';
const limite = Duration(seconds: 60); // tope de observación para "sin respuesta"
void fallo(String linea) => control.writeAsStringSync(linea);
// ignore: avoid_print
void reporte(String s) => print('P12RES|$etiqueta|$s');

/// Ejecuta [op] y devuelve (ms, resultado o error); corta la observación a los 60 s.
Future<(double, String)> cronometrar(Future<Object?> Function() op) async {
  final sw = Stopwatch()..start();
  String r;
  try {
    final v = await op().timeout(limite);
    r = 'OK ${v.runtimeType}';
  } on TimeoutException {
    r = 'SIN RESPUESTA tras ${limite.inSeconds} s (la app seguiría esperando)';
  } on ApiException catch (e) {
    r = 'ApiException(status=${e.statusCode}, "${e.mensaje}", sesionInvalida=${e.sesionInvalida}, sinPermiso=${e.sinPermiso})';
  } catch (e) {
    r = '${e.runtimeType}: ${e.toString().split('\n').first}';
  }
  return (sw.elapsedMicroseconds / 1000, r);
}

void main() {
  late ApiService api;
  var sesionesExpiradas = 0;
  final soloSinServidor = Platform.environment['P12_SOLO'] == 'sin_servidor';

  setUpAll(() async {
    if (soloSinServidor) {
      api = ApiService(authService: AuthDePrueba('token-irrelevante'));
      return;
    }
    fallo('ninguno');
    final correo = 'p12_res_${DateTime.now().millisecondsSinceEpoch}@test.com';
    final r = await http.post(Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': 'P12 Res', 'correo': correo, 'password': 'Segura123'}));
    api = ApiService(authService: AuthDePrueba(jsonDecode(r.body)['token'] as String));
    ApiService.onSesionExpirada = () => sesionesExpiradas++;
    reporte('inicio ${DateTime.now().toIso8601String()} usuario=$correo api=${ApiConstants.baseUrl}');
  });
  tearDownAll(() => soloSinServidor ? null : fallo('ninguno'));

  Future<int> filas() async {
    fallo('ninguno');
    return (await api.getMisIncidencias()).length;
  }

  Future<Object?> escribir() => api.crearIncidencia(tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja');

  test('RES-01/02 servidor inaccesible (sin conexión): consulta y escritura', () async {
    if (!soloSinServidor) return;
    final c = await cronometrar(() => api.getConciertos());
    reporte('RES-01 consulta sin conexión: ${c.$1.toStringAsFixed(1)} ms → ${c.$2}');
    final e = await cronometrar(escribir);
    reporte('RES-02 escritura sin conexión: ${e.$1.toStringAsFixed(1)} ms → ${e.$2}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('RES-03 servidor sin respuesta (cuelga)', () async {
    if (soloSinServidor) return;
    fallo('cuelga /api/incidencias');
    final r = await cronometrar(() => api.getMisIncidencias());
    reporte('RES-03 consulta con servidor colgado: ${r.$1.toStringAsFixed(1)} ms → ${r.$2}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('RES-04 respuesta 500', () async {
    if (soloSinServidor) return;
    fallo('500 /api/incidencias');
    final r = await cronometrar(() => api.getMisIncidencias());
    final w = await cronometrar(escribir);
    reporte('RES-04 consulta 500: ${r.$1.toStringAsFixed(1)} ms → ${r.$2}');
    reporte('RES-04 escritura 500: ${w.$1.toStringAsFixed(1)} ms → ${w.$2}; filas tras el 500: ${await filas()}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('RES-05 respuestas 403 y 401', () async {
    if (soloSinServidor) return;
    fallo('403 /api/incidencias');
    final p = await cronometrar(() => api.getMisIncidencias());
    reporte('RES-05 403: ${p.$1.toStringAsFixed(1)} ms → ${p.$2}; onSesionExpirada llamado ${sesionesExpiradas} veces');
    fallo('401 /api/incidencias');
    final a = await cronometrar(() => api.getMisIncidencias());
    reporte('RES-05 401: ${a.$1.toStringAsFixed(1)} ms → ${a.$2}; onSesionExpirada llamado ${sesionesExpiradas} veces');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('RES-07 el servidor procesa la escritura pero la respuesta no llega; el usuario reintenta', () async {
    if (soloSinServidor) return;
    final antes = await filas();
    fallo('corta /api/incidencias');
    final w = await cronometrar(escribir);
    final trasCorte = await filas();
    reporte('RES-07 escritura con respuesta perdida: ${w.$1.toStringAsFixed(1)} ms → ${w.$2}; filas $antes → $trasCorte');
    final reintento = await cronometrar(escribir); // el usuario pulsa "Intenta de nuevo"
    reporte('RES-07 reintento manual: ${reintento.$1.toStringAsFixed(1)} ms → ${reintento.$2}; filas finales ${await filas()} (esperado ${antes + 1})');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('RES-08 respuesta tardía (8 s): dos envíos de la misma operación', () async {
    if (soloSinServidor) return;
    final antes = await filas();
    fallo('lento:8000 /api/incidencias');
    final sw = Stopwatch()..start();
    final r = await Future.wait([cronometrar(escribir), cronometrar(escribir)]);
    sw.stop();
    reporte('RES-08 dos envíos con respuesta tardía: ${r.map((x) => '${x.$1.toStringAsFixed(1)} ms → ${x.$2}').join(' | ')}; filas $antes → ${await filas()} en ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
