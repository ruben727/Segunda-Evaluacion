// Práctica 11 — Caja blanca de apoyo: ApiService (lib/core/services/api_service.dart)
// Comprueba dinámicamente el hallazgo estático SA-02 y las ramas de
// _enviar (247-265) y _ClienteConSesion.send (33-39).
//
// ApiService usa un cliente estático (_http) que se crea la primera vez que
// se usa. Esa primera llamada se hace dentro de http.runWithClient, así el
// cliente interno queda apuntando a [ClienteConmutable] durante todo el
// archivo y cada prueba solo cambia [ClienteConmutable.handler]. No se
// modifica el código de la app.
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

const incidenciaJson = {
  'id': 1, 'tipo': 'Otro', 'equipo': 'Otro', 'prioridad': 'Baja', 'estado': 'Pendiente',
  'creado_por': 999, 'fecha': '2026-11-11T00:00:00Z', 'actualizado_en': '2026-11-11T00:00:00Z',
};

void main() {
  late ApiService api;
  late int sesionesExpiradas;

  setUpAll(() async {
    await http.runWithClient(() => ApiService(authService: AuthFalso()).getConciertos(), () => cliente);
  });

  setUp(() {
    api = ApiService(authService: AuthFalso());
    sesionesExpiradas = 0;
    ApiService.onSesionExpirada = () => sesionesExpiradas++;
  });

  Future<Object?> errorDe(Future<Object?> f) async {
    try {
      await f;
      return null;
    } catch (e) {
      return e;
    }
  }

  test('WB-API-01 (SA-02) GET por código con 502 HTML: FormatException en bruto, sin mensaje para el usuario', () async {
    handler = (_) async => http.Response('<html>502 Bad Gateway</html>', 502);
    final e = await errorDe(api.getDisenoPorCodigo('ABC123'));
    expect(e, isA<FormatException>(), reason: 'jsonDecode se ejecuta antes de revisar statusCode (línea 108)');
  });

  test('WB-API-02 _enviar: fallo de red → ApiException(null, "No se pudo conectar con el servidor")', () async {
    handler = (_) async => throw http.ClientException('Connection refused');
    final e = await errorDe(api.crearIncidencia(tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja'));
    expect(e, isA<ApiException>());
    expect((e as ApiException).statusCode, isNull);
    expect(e.mensaje, 'No se pudo conectar con el servidor');
  });

  test('WB-API-03 401 en petición con Authorization → onSesionExpirada() y ApiException.sesionInvalida', () async {
    handler = (req) async {
      expect(req.headers['Authorization'], 'Bearer token-de-prueba');
      return http.Response(jsonEncode({'error': 'Token inválido o expirado'}), 401);
    };
    final e = await errorDe(api.getMisIncidencias()) as ApiException;
    expect(e.sesionInvalida, isTrue);
    expect(sesionesExpiradas, 1);
  });

  test('WB-API-04 401 en petición pública (sin Authorization) → NO cierra la sesión', () async {
    handler = (_) async => http.Response('{"error":"x"}', 401);
    await errorDe(api.getConciertos());
    expect(sesionesExpiradas, 0);
  });

  test('WB-API-05 403 → ApiException.sinPermiso con el mensaje del backend', () async {
    handler = (_) async => http.Response(jsonEncode({'error': 'No tienes permisos para esta acción'}), 403);
    final e = await errorDe(api.getTodasIncidencias()) as ApiException;
    expect(e.sinPermiso, isTrue);
    expect(e.mensaje, 'No tienes permisos para esta acción');
  });

  test('WB-API-06 500 con cuerpo no-JSON → ApiException(500, "Ocurrió un error")', () async {
    handler = (_) async => http.Response('Internal Server Error', 500);
    final e = await errorDe(api.getAgentes()) as ApiException;
    expect(e.statusCode, 500);
    expect(e.mensaje, 'Ocurrió un error');
  });

  test('WB-API-07 201 esperado y recibido → Incidencia parseada', () async {
    handler = (_) async => http.Response(jsonEncode(incidenciaJson), 201);
    final inc = await api.crearIncidencia(tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja');
    expect(inc.id, '1');
  });

  test('WB-API-08 (SA-02) servidor que nunca responde: tras 5 min simulados la petición sigue pendiente (no hay timeout)', () {
    fakeAsync((async) {
      handler = (_) => Completer<http.Response>().future;
      var terminada = false;
      api.getConciertos().then((_) => terminada = true, onError: (_) => terminada = true);
      async.elapse(const Duration(minutes: 5));
      expect(terminada, isFalse, reason: 'ApiService no aplica .timeout(); AuthService sí (20 s)');
    });
  });
}
