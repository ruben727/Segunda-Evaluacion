// Prácticas 13 y 14 – AUT-01, AUT-02, AUT-03: pruebas unitarias de la lógica de negocio.
// Componente crítico: inicio de sesión / registro (Validadores y lectura del token JWT).
// No usan red ni plugins: son funciones puras.
import 'dart:convert';

import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/services/auth_service.dart';
import 'package:concertx_movil/core/utils/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.firma';
}

int seg(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

void main() {
  final auth = AuthService();

  group('AUT-01 Validación de formularios de login/registro', () {
    test('U-01 entrada válida: correo, contraseña, nombre y teléfono correctos no devuelven error', () {
      expect(Validadores.email('ana.lopez@test.com'), isNull);
      expect(Validadores.email('  ana@test.mx  '), isNull); // se recorta antes de validar
      expect(Validadores.passwordRegistro('Segura123'), isNull);
      expect(Validadores.nombre('Ana López'), isNull);
      expect(Validadores.telefono('55 1234 5678'), isNull);
    });

    test('U-02 entrada vacía o nula: cada campo pide el dato', () {
      for (final v in [null, '', '    ']) {
        expect(Validadores.email(v), 'Ingresa tu correo');
        expect(Validadores.passwordLongitud(v), 'Ingresa tu contraseña');
        expect(Validadores.nombre(v), 'Ingresa tu nombre completo');
        expect(Validadores.telefono(v), 'El teléfono debe tener entre 10 y 13 dígitos');
      }
    });

    test('U-03 valores fuera de rango: límites −1 y +1 se rechazan; los límites exactos se aceptan', () {
      expect(Validadores.passwordLongitud('Abcde12'), 'Mínimo 8 caracteres'); // 7
      expect(Validadores.passwordLongitud('A1${'a' * 63}'), 'Máximo 64 caracteres'); // 65
      expect(Validadores.passwordLongitud('Abcdef12'), isNull); // 8
      expect(Validadores.passwordLongitud('A1${'a' * 62}'), isNull); // 64
      expect(Validadores.telefono('551234567'), isNotNull); // 9 dígitos
      expect(Validadores.telefono('12345678901234'), isNotNull); // 14 dígitos
      expect(Validadores.telefono('1234567890123'), isNull); // 13 dígitos
      expect(Validadores.nombre('Al'), 'Ingresa tu nombre completo'); // 2 caracteres
    });
  });

  group('AUT-02 Reglas de negocio con resultado esperado', () {
    test('U-04 resultado esperado: el registro exige mayúscula y número (misma regla que el backend)', () {
      expect(Validadores.passwordRegistro('abcdefgh1'), 'Debe incluir una mayúscula y un número');
      expect(Validadores.passwordRegistro('ABCDEFGHI'), 'Debe incluir una mayúscula y un número');
      expect(Validadores.passwordRegistro('Abcdefgh1'), isNull);
      expect(Validadores.email('sin-arroba.com'), 'Correo inválido');
      expect(Validadores.email('ana@test'), 'Correo inválido');
    });

    test('U-05 resultado esperado: vencimiento del token con margen de 1 minuto', () {
      final ahora = DateTime.utc(2026, 11, 18, 12);
      expect(auth.tokenVencido(jwt({'id': 1, 'exp': seg(ahora.add(const Duration(days: 6)))}), ahora: ahora), isFalse);
      expect(auth.tokenVencido(jwt({'id': 1, 'exp': seg(ahora.subtract(const Duration(seconds: 1)))}), ahora: ahora), isTrue);
      // Vence dentro de 30 s: ya se trata como vencido por el margen de reloj.
      expect(auth.tokenVencido(jwt({'id': 1, 'exp': seg(ahora.add(const Duration(seconds: 30)))}), ahora: ahora), isTrue);
      expect(auth.tokenVencido(jwt({'id': 1}), ahora: ahora), isFalse); // sin exp: no caduca
    });
  });

  group('AUT-03 Manejo de excepciones', () {
    test('U-06 token corrupto: decodePayload no lanza excepción, devuelve null y se considera vencido', () {
      for (final t in ['abc', 'a.b', 'a.%%%.c', 'x.${base64Url.encode(utf8.encode('no-json'))}.y', '']) {
        expect(() => auth.decodePayload(t), returnsNormally);
        expect(auth.decodePayload(t), isNull);
        expect(auth.tokenVencido(t), isTrue);
      }
    });

    test('U-07 ApiException clasifica el código HTTP y su texto es apto para el usuario', () {
      const e403 = ApiException(403, 'No tienes permisos para esta acción');
      const e401 = ApiException(401, 'Token inválido');
      const sinRed = ApiException(null, 'No se pudo conectar con el servidor');
      expect(e403.sinPermiso, isTrue);
      expect(e403.sesionInvalida, isFalse);
      expect(e401.sesionInvalida, isTrue);
      expect(sinRed.statusCode, isNull);
      expect(sinRed.toString(), 'No se pudo conectar con el servidor'); // sin "Exception:" ni detalles técnicos
      expect(() => throw e403, throwsA(isA<ApiException>()));
    });
  });
}
