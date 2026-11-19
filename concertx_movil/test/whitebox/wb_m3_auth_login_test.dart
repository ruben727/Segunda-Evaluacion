// Práctica 11 — Caja blanca, Método M3 (comunicación):
//   AuthService.login (lib/core/services/auth_service.dart:50-61)
//   + AuthService._post (30-48), que hace la petición HTTP.
//
// El cliente HTTP se sustituye con http.runWithClient + MockClient (el
// http.post de nivel superior crea su Client() dentro de la zona), así que
// no se modifica el código de la app. El almacenamiento seguro se simula
// con FlutterSecureStorage.setMockInitialValues.
import 'dart:async';
import 'dart:convert';

import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const tokenFalso = 'eyJhbGciOiJIUzI1NiJ9.eyJpZCI6OTk5fQ.firma-de-prueba';
const usuarioJson = {'id': 999, 'nombre': 'Prueba WB', 'correo': 'prueba_wb_01@test.com', 'tipo': 'usuario'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthService service;
  late List<http.Request> peticiones;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = AuthService();
    peticiones = [];
  });

  /// Ejecuta login con un backend simulado que responde [handler].
  Future<({String token, dynamic user})> loginCon(Future<http.Response> Function(http.Request) handler) {
    return http.runWithClient(
      () => service.login('prueba_wb_01@test.com', 'Segura123'),
      () => MockClient((req) {
        peticiones.add(req);
        return handler(req);
      }),
    );
  }

  Matcher mensaje(String m) => throwsA(predicate((e) => e.toString() == 'Exception: $m', 'Exception("$m")'));

  group('M3 caminos independientes', () {
    test('WB-M3-P1 200 + JSON válido → devuelve token y usuario y guarda el token', () async {
      final r = await loginCon((_) async => http.Response(jsonEncode({'token': tokenFalso, 'user': usuarioJson}), 200));
      expect(r.token, tokenFalso);
      expect(r.user.correo, 'prueba_wb_01@test.com');
      expect(await service.getToken(), tokenFalso);
      // La petición sale como POST JSON a /auth/login con correo y password.
      expect(peticiones.single.method, 'POST');
      expect(peticiones.single.url.path, endsWith('/auth/login'));
      expect(peticiones.single.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(peticiones.single.body), {'correo': 'prueba_wb_01@test.com', 'password': 'Segura123'});
    });

    test('WB-M3-P2 200 con cuerpo que NO es objeto ([]) → data={} → TypeError sin traducir', () async {
      await expectLater(loginCon((_) async => http.Response('[]', 200)), throwsA(isA<TypeError>()));
      expect(await service.getToken(), isNull);
    });

    test('WB-M3-P3 401 → "Correo o contraseña incorrectos" y no guarda token', () async {
      await expectLater(
        loginCon((_) async => http.Response(jsonEncode({'error': 'Correo o contraseña incorrectos'}), 401)),
        mensaje(MensajesAuth.credencialesIncorrectas),
      );
      expect(await service.getToken(), isNull);
    });

    test('WB-M3-P4 500 → mensaje de "sin conexión" (no muestra el detalle del servidor)', () async {
      await expectLater(
        loginCon((_) async => http.Response(jsonEncode({'error': 'Error interno del servidor'}), 500)),
        mensaje(MensajesAuth.sinConexion),
      );
    });

    test('WB-M3-P5 timeout (servidor no responde en 20 s) → TimeoutException → "sin conexión"', () {
      fakeAsync((async) {
        Object? error;
        loginCon((_) => Completer<http.Response>().future).then((_) {}, onError: (Object e) {
          error = e;
        });
        async.elapse(const Duration(seconds: 19));
        expect(error, isNull, reason: 'a los 19 s todavía espera');
        async.elapse(const Duration(seconds: 2));
        expect(error.toString(), 'Exception: ${MensajesAuth.sinConexion}');
      });
    });

    test('WB-M3-P6 sin red (ClientException, lo que lanza IOClient ante SocketException) → "sin conexión"', () async {
      await expectLater(
        loginCon((_) async => throw http.ClientException('Failed host lookup: backend-three-xi-95.vercel.app')),
        mensaje(MensajesAuth.sinConexion),
      );
    });

    test('WB-M3-P7 JSON inválido (página HTML de 502 de un proxy) → FormatException → "sin conexión"', () async {
      await expectLater(
        loginCon((_) async => http.Response('<html><body>502 Bad Gateway</body></html>', 502)),
        mensaje(MensajesAuth.sinConexion),
      );
    });
  });

  group('M3 valores límite del código de estado (decisiones status!=200 y status>=500)', () {
    for (final caso in [
      (199, MensajesAuth.credencialesIncorrectas),
      (201, MensajesAuth.credencialesIncorrectas),
      (400, MensajesAuth.credencialesIncorrectas),
      (499, MensajesAuth.credencialesIncorrectas),
      (500, MensajesAuth.sinConexion),
      (503, MensajesAuth.sinConexion),
    ]) {
      test('WB-M3-L status ${caso.$1} → "${caso.$2}"', () async {
        await expectLater(loginCon((_) async => http.Response('{}', caso.$1)), mensaje(caso.$2));
      });
    }
  });
}
