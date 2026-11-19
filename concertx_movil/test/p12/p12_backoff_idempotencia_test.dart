// Práctica 12 – pruebas unitarias del reintento con exponential backoff, del timeout y de la
// Idempotency-Key de ApiService (cliente HTTP simulado; tiempo controlado con fake_async).
import 'dart:async';
import 'dart:convert';

import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class AuthFalso extends AuthService {
  @override
  Future<String?> getToken() async => 'token-de-prueba';
}

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final cliente = MockClient((req) => handler(req));
const inc = {'id': 1, 'tipo': 'Otro', 'equipo': 'Otro', 'prioridad': 'Baja', 'estado': 'Pendiente', 'creado_por': 9, 'fecha': '2026-11-12T00:00:00Z'};

void main() {
  late ApiService api;
  late List<(Duration, String?)> llamadas;

  setUpAll(() async => http.runWithClient(() => ApiService(authService: AuthFalso()).getConciertos(), () => cliente));
  setUp(() {
    api = ApiService(authService: AuthFalso());
    llamadas = [];
  });

  test('P12-BO-01 escritura con fallos de red: 1 + 3 reintentos a 1 s, 2 s y 4 s con la MISMA Idempotency-Key; éxito al 4.º', () {
    fakeAsync((async) {
      final reloj = Stopwatch()..start();
      var n = 0;
      handler = (req) async {
        llamadas.add((async.elapsed, req.headers['Idempotency-Key']));
        if (++n < 4) throw http.ClientException('sin red');
        return http.Response(jsonEncode(inc), 201);
      };
      Object? resultado;
      api.crearIncidencia(tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja').then((v) => resultado = v);
      async.elapse(const Duration(seconds: 8));
      expect(resultado, isNotNull);
      expect(llamadas.map((x) => x.$1.inSeconds).toList(), [0, 1, 3, 7]); // esperas acumuladas 1, 2, 4 s
      expect(llamadas.map((x) => x.$2).toSet(), hasLength(1));
      expect(llamadas.first.$2, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      reloj.stop();
    });
  });

  test('P12-BO-02 4xx NO se reintenta (error definitivo)', () {
    fakeAsync((async) {
      handler = (req) async {
        llamadas.add((async.elapsed, null));
        return http.Response('{"error":"Selecciona tipo"}', 400);
      };
      Object? error;
      api.crearIncidencia(tipo: 'Otro', equipo: 'Otro', prioridad: 'Media').then((_) {}, onError: (Object e) {
        error = e;
      });
      async.elapse(const Duration(seconds: 10));
      expect((error as ApiException).statusCode, 400);
      expect(llamadas, hasLength(1), reason: 'un 400 no se reintenta');
    });
  });

  test('P12-BO-03 si se agotan los reintentos, el reintento MANUAL reutiliza la clave; tras el éxito se usa una nueva', () {
    fakeAsync((async) {
      final claves = <String?>[];
      var falla = true;
      handler = (req) async {
        claves.add(req.headers['Idempotency-Key']);
        if (falla) return http.Response('{"error":"x"}', 503);
        return http.Response(jsonEncode(inc), 201);
      };
      Object? error;
      api.crearIncidencia(tipo: 'Otro', equipo: 'Teléfono', prioridad: 'Alta').then((_) {}, onError: (Object e) {
        error = e;
      });
      async.elapse(const Duration(seconds: 8));
      expect(claves, hasLength(4), reason: '1 intento + 3 reintentos');
      expect((error as ApiException).statusCode, 503);
      falla = false; // el usuario pulsa "Intenta de nuevo" con el mismo formulario
      Object? ok;
      api.crearIncidencia(tipo: 'Otro', equipo: 'Teléfono', prioridad: 'Alta').then((v) => ok = v);
      async.flushMicrotasks();
      expect(ok, isNotNull);
      expect(claves.toSet(), hasLength(1), reason: 'reintentos automáticos y manual: misma clave');
      api.crearIncidencia(tipo: 'Otro', equipo: 'Teléfono', prioridad: 'Alta');
      async.flushMicrotasks();
      expect(claves.last, isNot(claves.first), reason: 'tras un éxito, una nueva operación usa clave nueva');
    });
  });

  test('P12-TO-01 consulta con servidor que no responde: ApiException a los 15 s (antes quedaba pendiente)', () {
    fakeAsync((async) {
      handler = (_) => Completer<http.Response>().future;
      Object? error;
      api.getMisIncidencias().catchError((Object e) { error = e; return <Never>[]; });
      async.elapse(const Duration(seconds: 14));
      expect(error, isNull);
      async.elapse(const Duration(seconds: 2));
      expect((error as ApiException).mensaje, 'El servidor tardó demasiado en responder');
    });
  });
}
