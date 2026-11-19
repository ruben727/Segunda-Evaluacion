// Sesión expirada: el token del backend dura 7 días. La app debe darse
// cuenta y pedir login, no mostrar "Token inválido o expirado" al crear un
// diseño u otra acción con sesión.
import 'dart:convert';

import 'package:concertx_movil/core/providers/auth_provider.dart';
import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// JWT de prueba (la firma no importa: la app no la verifica).
String jwt(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.firma';
}

int segundos(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = AuthService();

  test('SES-01 Un token cuyo exp ya pasó se considera vencido; uno vigente no', () {
    final ahora = DateTime.utc(2026, 11, 5, 12);
    final vencido = jwt({'id': 1, 'exp': segundos(ahora.subtract(const Duration(days: 1)))});
    final vigente = jwt({'id': 1, 'exp': segundos(ahora.add(const Duration(days: 6)))});

    expect(service.tokenVencido(vencido, ahora: ahora), isTrue);
    expect(service.tokenVencido(vigente, ahora: ahora), isFalse);
  });

  test('SES-02 Un token ilegible se trata como vencido', () {
    expect(service.tokenVencido('esto.no-es.un-jwt'), isTrue);
    expect(service.tokenVencido('abc'), isTrue);
  });

  test('SES-03 Al abrir la app con un token vencido no hay sesión y se avisa', () async {
    final vencido = jwt({'id': 1, 'tipo': 'usuario', 'exp': segundos(DateTime.now().subtract(const Duration(days: 8)))});
    FlutterSecureStorage.setMockInitialValues({'concertx_token': vencido});
    final auth = AuthProvider();

    await auth.cargarSesion();

    expect(auth.isLoggedIn, isFalse);
    expect(await service.getToken(), isNull); // se borró
    expect(auth.tomarAvisoSesion(), MensajesAuth.sesionExpirada);
    expect(auth.tomarAvisoSesion(), isNull); // solo una vez
  });

  test('SES-04 Un 401 del backend cierra la sesión una sola vez aunque fallen varias peticiones', () async {
    final vigente = jwt({'id': 1, 'tipo': 'usuario', 'exp': segundos(DateTime.now().add(const Duration(days: 3)))});
    FlutterSecureStorage.setMockInitialValues({'concertx_token': vigente});
    final auth = AuthProvider();
    await auth.cargarSesion();
    expect(auth.isLoggedIn, isTrue);

    var avisos = 0;
    auth.addListener(() => avisos++);
    await Future.wait([auth.sesionExpirada(), auth.sesionExpirada(), auth.sesionExpirada()]);

    expect(auth.isLoggedIn, isFalse);
    expect(auth.currentUser, isNull);
    expect(await service.getToken(), isNull);
    expect(avisos, 1);
  });
}
