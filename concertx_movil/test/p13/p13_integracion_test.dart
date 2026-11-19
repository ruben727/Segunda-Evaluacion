// Prácticas 13 y 14 – AUT-04 y AUT-05: pruebas de integración entre componentes reales de la app
// (pantalla → Provider → Service → cliente HTTP). Solo se reemplaza la red por un servidor simulado
// (MockClient de package:http) para que el CI no dependa de Vercel ni cree datos en producción.
import 'dart:async';
import 'dart:convert';

import 'package:concertx_movil/core/providers/auth_provider.dart';
import 'package:concertx_movil/core/providers/concierto_provider.dart';
import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Servidor simulado: cada prueba define cómo responde.
Future<http.Response> Function(http.Request) servidor = (_) async => http.Response('[]', 200);
final cliente = MockClient((req) => servidor(req));
final peticiones = <http.Request>[];

String jwt(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.firma';
}

final tokenValido = jwt({'id': 9, 'tipo': 'usuario', 'exp': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000});
const usuarioJson = {'id': 9, 'nombre': 'Ana López', 'correo': 'ana@test.com', 'telefono': '5512345678', 'tipo': 'usuario'};
const conciertoJson = {
  'id': 3,
  'artista': 'Banda Prueba',
  'nombre_tour': 'Tour P13',
  'fecha_inicio': '2026-12-01T02:00:00Z',
  'estadio': {'id': 1, 'nombre': 'Estadio Azteca', 'ciudad': 'CDMX'},
};

/// Ejecuta [cuerpo] con el cliente HTTP simulado (AuthService usa http.post de nivel superior).
Future<T> conServidor<T>(Future<T> Function() cuerpo) => http.runWithClient(cuerpo, () => cliente);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiService comparte un cliente estático: se crea una vez dentro de runWithClient para que use el simulado.
  setUpAll(() async {
    await initializeDateFormatting('es_MX'); // igual que main.dart
    // El widget de inicio (home_widget) es un plugin nativo: en la VM de pruebas se simula su canal.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (_) async => true);
    await conServidor(() => ApiService(authService: AuthService()).getConciertos());
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    peticiones.clear();
    ApiService.onSesionExpirada = null;
  });

  group('AUT-04 App ↔ servicio de autenticación (POST /auth/login)', () {
    test('I-01 la app envía las credenciales y con 200 inicia la sesión con el usuario recibido', () async {
      servidor = (req) async {
        peticiones.add(req);
        return http.Response(jsonEncode({'token': tokenValido, 'user': usuarioJson}), 200);
      };
      final auth = AuthProvider();
      final ok = await conServidor(() => auth.login('ana@test.com', 'Segura123'));

      expect(ok, isTrue);
      expect(peticiones.single.method, 'POST');
      expect(peticiones.single.url.path, endsWith('/auth/login'));
      expect(peticiones.single.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(peticiones.single.body), {'correo': 'ana@test.com', 'password': 'Segura123'});
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser!.nombre, 'Ana López');
      expect(auth.errorMessage, isNull);
    });

    test('I-02 la API devuelve 401 / 500: la app muestra el mensaje genérico adecuado (sin texto del backend)', () async {
      final auth = AuthProvider();
      servidor = (_) async => http.Response(jsonEncode({'error': 'Usuario ana@test.com no existe'}), 401);
      expect(await conServidor(() => auth.login('ana@test.com', 'Segura123')), isFalse);
      expect(auth.errorMessage, MensajesAuth.credencialesIncorrectas);

      servidor = (_) async => http.Response('<html>502 Bad Gateway</html>', 502);
      expect(await conServidor(() => auth.login('ana@test.com', 'Segura123')), isFalse);
      expect(auth.errorMessage, MensajesAuth.sinConexion);
      expect(auth.isLoggedIn, isFalse);
    });

    test('I-03 el servidor no responde: tras el timeout (20 s) la app muestra "sin conexión" y no se queda cargando', () {
      fakeAsync((async) {
        servidor = (_) => Completer<http.Response>().future; // nunca responde
        final auth = AuthProvider();
        bool? resultado;
        conServidor(() => auth.login('ana@test.com', 'Segura123')).then((v) => resultado = v);
        async.elapse(const Duration(seconds: 21));
        expect(resultado, isFalse);
        expect(auth.isLoading, isFalse);
        expect(auth.errorMessage, MensajesAuth.sinConexion);
      });
    });
  });

  group('AUT-05 App ↔ API de conciertos e incidencias', () {
    test('I-04 GET /conciertos con 200: el provider recibe y convierte la lista', () async {
      servidor = (req) async {
        peticiones.add(req);
        return http.Response(jsonEncode([conciertoJson]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      };
      final p = ConciertoProvider();
      await conServidor(p.fetchConciertos);
      expect(peticiones.single.url.path, endsWith('/conciertos'));
      expect(p.errorMessage, isNull);
      expect(p.conciertos.single.artista, 'Banda Prueba');
      expect(p.conciertos.single.estadio!.nombre, 'Estadio Azteca');
    });

    test('I-05 [riesgo P12] el servidor de conciertos no responde: la app muestra un mensaje en ≤ 15 s', () {
      fakeAsync((async) {
        servidor = (_) => Completer<http.Response>().future; // servidor colgado
        final p = ConciertoProvider();
        conServidor(p.fetchConciertos);
        async.elapse(const Duration(seconds: 16));
        expect(p.isLoading, isFalse, reason: 'getConciertos debe tener timeout como el resto de ApiService');
        expect(p.errorMessage, 'El servidor tardó demasiado en responder');
      });
    });

    test('I-06 POST /incidencias: envía token e Idempotency-Key y con 201 devuelve la incidencia creada', () async {
      FlutterSecureStorage.setMockInitialValues({'concertx_token': tokenValido});
      servidor = (req) async {
        peticiones.add(req);
        return http.Response(
            jsonEncode({'id': 21, 'tipo': 'Otro', 'equipo': 'Teléfono', 'prioridad': 'Alta', 'estado': 'Pendiente', 'creado_por': 9, 'fecha': '2026-11-18T00:00:00Z'}),
            201);
      };
      final inc = await conServidor(() => ApiService().crearIncidencia(tipo: 'Otro', equipo: 'Teléfono', prioridad: 'Alta'));
      final req = peticiones.single;
      expect(req.headers['Authorization'], 'Bearer $tokenValido');
      expect(req.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(jsonDecode(req.body), {'tipo': 'Otro', 'equipo': 'Teléfono', 'prioridad': 'Alta'});
      expect(inc.id, '21');
      expect(inc.prioridad, 'Alta');
    });

    test('I-07 403 en una petición autenticada: ApiException.sinPermiso y la sesión NO se cierra', () async {
      FlutterSecureStorage.setMockInitialValues({'concertx_token': tokenValido});
      var cierres = 0;
      ApiService.onSesionExpirada = () => cierres++;
      servidor = (_) async => http.Response(jsonEncode({'error': 'No tienes permisos para esta acción'}), 403);
      await expectLater(
        conServidor(() => ApiService().getTodasIncidencias()),
        throwsA(isA<ApiException>().having((e) => e.sinPermiso, 'sinPermiso', isTrue)),
      );
      expect(cierres, 0);
    });
  });
}
