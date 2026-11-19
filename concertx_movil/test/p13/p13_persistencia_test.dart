// Prácticas 13 y 14 – AUT-06: persistencia de la sesión en almacenamiento seguro.
// Operación seleccionada: el token JWT que AuthService guarda en flutter_secure_storage
// (Keystore en Android) al iniciar sesión o registrarse, y que se lee al abrir la app.
// El almacenamiento se simula con FlutterSecureStorage.setMockInitialValues (mismo API real).
import 'dart:convert';

import 'package:concertx_movil/core/providers/auth_provider.dart';
import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String jwt(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.firma';
}

int seg(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
const clave = 'concertx_token';
const almacen = FlutterSecureStorage();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final vigente = jwt({'id': 9, 'nombre': 'Ana López', 'correo': 'ana@test.com', 'tipo': 'agente', 'exp': seg(DateTime.now().add(const Duration(days: 7)))});
  final vencido = jwt({'id': 9, 'tipo': 'usuario', 'exp': seg(DateTime.now().subtract(const Duration(days: 8)))});
  const usuario = {'id': 9, 'nombre': 'Ana López', 'correo': 'ana@test.com', 'tipo': 'usuario'};

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('P-01 registro exitoso (201): el token queda guardado en el almacenamiento seguro', () async {
    final cliente = MockClient((_) async => http.Response(jsonEncode({'token': vigente, 'user': usuario}), 201));
    final auth = AuthProvider();
    final ok = await http.runWithClient(
        () => auth.register(nombre: 'Ana López', correo: 'ana@test.com', telefono: '5512345678', password: 'Segura123'), () => cliente);
    expect(ok, isTrue);
    expect(await almacen.read(key: clave), vigente);
    expect(await AuthService().isLoggedIn(), isTrue);
  });

  test('P-02 registro rechazado (409) o login fallido (401): no se guarda ningún token', () async {
    final auth = AuthProvider();
    await http.runWithClient(
        () => auth.register(nombre: 'Ana López', correo: 'ana@test.com', telefono: '5512345678', password: 'Segura123'),
        () => MockClient((_) async => http.Response('{"error":"Ya existe una cuenta con ese correo"}', 409)));
    await http.runWithClient(() => auth.login('ana@test.com', 'Mala1234'),
        () => MockClient((_) async => http.Response('{"error":"Correo o contraseña incorrectos"}', 401)));
    expect(await almacen.read(key: clave), isNull);
    expect(auth.errorMessage, MensajesAuth.credencialesIncorrectas);
  });

  test('P-03 al reabrir la app con un token vigente se restaura la sesión desde el almacenamiento', () async {
    FlutterSecureStorage.setMockInitialValues({clave: vigente});
    final auth = AuthProvider();
    await auth.cargarSesion();
    expect(auth.isLoggedIn, isTrue);
    expect(auth.currentUser!.id, '9');
    expect(auth.currentUser!.esAgente, isTrue);
  });

  test('P-04 token vencido guardado: se borra del almacenamiento y se avisa "sesión expirada"', () async {
    FlutterSecureStorage.setMockInitialValues({clave: vencido});
    final auth = AuthProvider();
    await auth.cargarSesion();
    expect(auth.isLoggedIn, isFalse);
    expect(await almacen.read(key: clave), isNull);
    expect(auth.tomarAvisoSesion(), MensajesAuth.sesionExpirada);
  });

  test('P-05 cerrar sesión elimina el token; otra apertura ya no tiene sesión', () async {
    FlutterSecureStorage.setMockInitialValues({clave: vigente});
    final auth = AuthProvider();
    await auth.cargarSesion();
    await auth.logout();
    expect(await almacen.read(key: clave), isNull);
    final reabierta = AuthProvider();
    await reabierta.cargarSesion();
    expect(reabierta.isLoggedIn, isFalse);
  });
}
