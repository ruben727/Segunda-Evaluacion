// Práctica 12 – PER-03: milisegundos por operación medidos con Stopwatch.
// Usa el ApiService REAL de la app contra la API de producción (Vercel), igual que el teléfono.
// Sin TestWidgetsFlutterBinding, así que las peticiones HTTP son reales (no simuladas).
// Crea el usuario de prueba p12_movil_<ts>@test.com y sus incidencias; se borran al terminar la práctica.
// Uso: flutter test test/p12/p12_tiempos_test.dart --reporter expanded
import 'dart:convert';
import 'dart:io';

import 'package:concertx_movil/core/constants/api_constants.dart';
import 'package:concertx_movil/core/models/incidencia.dart';
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

String resumen(String op, List<int> us) {
  final ms = us.map((x) => x / 1000).toList()..sort();
  final prom = ms.reduce((a, b) => a + b) / ms.length;
  final p95 = ms[((ms.length - 1) * 0.95).round()];
  return 'P12|$op|n=${ms.length}|min=${ms.first.toStringAsFixed(2)}|prom=${prom.toStringAsFixed(2)}'
      '|p95=${p95.toStringAsFixed(2)}|max=${ms.last.toStringAsFixed(2)}';
}

Future<List<int>> medir(int n, Future<void> Function() op) async {
  final tiempos = <int>[];
  for (var i = 0; i < n; i++) {
    final sw = Stopwatch()..start();
    await op();
    sw.stop();
    tiempos.add(sw.elapsedMicroseconds);
  }
  return tiempos;
}

void main() {
  late ApiService api;
  final etiqueta = Platform.environment['P12_ETIQUETA'] ?? 'sin-etiqueta';

  setUpAll(() async {
    final correo = 'p12_movil_${DateTime.now().millisecondsSinceEpoch}@test.com';
    final r = await http.post(Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': 'P12 Movil', 'correo': correo, 'password': 'Segura123'}));
    expect(r.statusCode, 201, reason: r.body);
    api = ApiService(authService: AuthDePrueba(jsonDecode(r.body)['token'] as String));
    // ignore: avoid_print
    print('P12|inicio|$etiqueta|${DateTime.now().toIso8601String()}|usuario=$correo|api=${ApiConstants.baseUrl}');
  });

  test('OP1 consulta repetida: getConciertos ×20', () async {
    final t = await medir(20, () async => expect(await api.getConciertos(), isNotEmpty));
    // ignore: avoid_print
    print(resumen('OP1_getConciertos', t));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('OP2 escritura: crearIncidencia ×5', () async {
    final t = await medir(5, () async => expect((await api.crearIncidencia(tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja')).id, isNotEmpty));
    // ignore: avoid_print
    print(resumen('OP2_crearIncidencia', t));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('OP3 consulta repetida: getMisIncidencias ×20', () async {
    final t = await medir(20, () async => expect(await api.getMisIncidencias(), hasLength(5)));
    // ignore: avoid_print
    print(resumen('OP3_getMisIncidencias', t));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('OP4 búsqueda difusa: buscar("monte") ×20', () async {
    final t = await medir(20, () async => expect((await api.buscar('monte')).resultados, isNotEmpty));
    // ignore: avoid_print
    print(resumen('OP4_buscar', t));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('OP5 procesamiento: jsonDecode + Incidencia.fromJson de 10 000 elementos ×10', () async {
    final base = (await api.getMisIncidencias()).first;
    final item = {
      'id': base.id, 'tipo': base.tipo, 'equipo': base.equipo, 'prioridad': base.prioridad, 'estado': base.estado,
      'creado_por': base.creadoPor, 'creado_por_nombre': 'P12 Movil', 'agente_asignado': null,
      'fecha': '2026-11-12T00:00:00.000Z',
    };
    final texto = jsonEncode(List.generate(10000, (i) => {...item, 'id': i}));
    final t = await medir(10, () async {
      final lista = (jsonDecode(texto) as List).map((e) => Incidencia.fromJson(e as Map<String, dynamic>)).toList();
      expect(lista, hasLength(10000));
    });
    // ignore: avoid_print
    print('P12|OP5_tamaño_json|${texto.length} bytes');
    // ignore: avoid_print
    print(resumen('OP5_parse10000', t));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
