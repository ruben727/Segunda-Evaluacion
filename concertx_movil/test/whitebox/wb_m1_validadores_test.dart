// Práctica 11 — Caja blanca, Método M1 (validación):
//   Validadores.passwordLongitud  (lib/core/utils/validadores.dart:25-30)
//   + estaVacio (línea 15), que aporta la condición compuesta A || B.
//
// Grafo (ver 02_movil/grafos/M1_passwordLongitud.mmd):
//   N1 A: valor == null        N2 B: valor.trim().isEmpty
//   N3 return 'Ingresa…'       N4 C: length < 8     N5 return 'Mínimo…'
//   N6 D: length > 64          N7 return 'Máximo…'  N8 return null   N9 fin
// V(G) = 12 aristas − 9 nodos + 2 = 5 = 4 predicados + 1 = 5 regiones.
import 'package:concertx_movil/core/utils/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vacio = 'Ingresa tu contraseña';
  const minimo = 'Mínimo 8 caracteres';
  const maximo = 'Máximo 64 caracteres';
  String rep(int n) => 'a' * n;

  group('M1 caminos independientes (cobertura de instrucciones y decisiones)', () {
    test('WB-M1-P1 null → A verdadera → "Ingresa tu contraseña"', () {
      expect(Validadores.passwordLongitud(null), vacio);
    });
    test('WB-M1-P2 "   " → A falsa, B verdadera → "Ingresa tu contraseña"', () {
      expect(Validadores.passwordLongitud('   '), vacio);
    });
    test('WB-M1-P3 7 caracteres → C verdadera → "Mínimo 8"', () {
      expect(Validadores.passwordLongitud(rep(7)), minimo);
    });
    test('WB-M1-P4 65 caracteres → D verdadera → "Máximo 64"', () {
      expect(Validadores.passwordLongitud(rep(65)), maximo);
    });
    test('WB-M1-P5 8 caracteres → C y D falsas → null (válida)', () {
      expect(Validadores.passwordLongitud(rep(8)), isNull);
    });
  });

  group('M1 cobertura de condiciones de A || B (cada una V y F por separado)', () {
    test('WB-M1-C1 A=V (B no se evalúa: cortocircuito)', () {
      expect(Validadores.estaVacio(null), isTrue);
    });
    test('WB-M1-C2 A=F, B=V', () {
      expect(Validadores.estaVacio(''), isTrue);
      expect(Validadores.estaVacio(' \t\n'), isTrue);
    });
    test('WB-M1-C3 A=F, B=F', () {
      expect(Validadores.estaVacio(' x '), isFalse);
    });
  });

  group('M1 valores límite (mín−1, mín, máx, máx+1)', () {
    test('WB-M1-L1 longitud 7 (mín−1) → Mínimo', () => expect(Validadores.passwordLongitud(rep(7)), minimo));
    test('WB-M1-L2 longitud 8 (mín) → válida', () => expect(Validadores.passwordLongitud(rep(8)), isNull));
    test('WB-M1-L3 longitud 64 (máx) → válida', () => expect(Validadores.passwordLongitud(rep(64)), isNull));
    test('WB-M1-L4 longitud 65 (máx+1) → Máximo', () => expect(Validadores.passwordLongitud(rep(65)), maximo));
    test('WB-M1-L5 8 espacios: longitud válida pero solo espacios → rechazada por B', () {
      expect(Validadores.passwordLongitud(' ' * 8), vacio);
    });
    test('WB-M1-L6 espacios internos cuentan (no se hace trim): " abcdef " = 8 → válida', () {
      expect(Validadores.passwordLongitud(' abcdef '), isNull);
    });
  });

  group('M1 método llamador passwordRegistro (decisión extra: mayúscula y número)', () {
    test('WB-M1-R1 longitud inválida se propaga sin evaluar el regex', () {
      expect(Validadores.passwordRegistro('Ab1'), minimo);
    });
    test('WB-M1-R2 sin mayúscula → error', () {
      expect(Validadores.passwordRegistro('abcdefg1'), 'Debe incluir una mayúscula y un número');
    });
    test('WB-M1-R3 sin número → error', () {
      expect(Validadores.passwordRegistro('Abcdefgh'), 'Debe incluir una mayúscula y un número');
    });
    test('WB-M1-R4 mayúscula y número, longitud 8 → válida', () {
      expect(Validadores.passwordRegistro('Abcdefg1'), isNull);
    });
  });

  group('Valores límite de otros validadores del mismo archivo', () {
    const errTel = 'El teléfono debe tener entre 10 y 13 dígitos';
    test('WB-M1-T1 teléfono 9 dígitos (mín−1) → error', () => expect(Validadores.telefono('551234567'), errTel));
    test('WB-M1-T2 teléfono 10 dígitos (mín) → válido', () => expect(Validadores.telefono('5512345678'), isNull));
    test('WB-M1-T3 teléfono 13 dígitos (máx) → válido', () => expect(Validadores.telefono('+52 1 55 1234 5678'), isNull));
    test('WB-M1-T4 teléfono 14 dígitos (máx+1) → error', () => expect(Validadores.telefono('12345678901234'), errTel));
    test('WB-M1-T5 teléfono null → error (no lanza excepción)', () => expect(Validadores.telefono(null), errTel));

    const errNom = 'Ingresa tu nombre completo';
    test('WB-M1-N1 nombre 2 caracteres (mín−1) → error', () => expect(Validadores.nombre('Al'), errNom));
    test('WB-M1-N2 nombre 3 caracteres (mín) → válido', () => expect(Validadores.nombre('Ana'), isNull));
    test('WB-M1-N3 nombre "  Al  " (trim=2) → error', () => expect(Validadores.nombre('  Al  '), errNom));

    test('WB-M1-E1 correo válido con espacios alrededor → válido (se hace trim)', () {
      expect(Validadores.email('  prueba_wb_01@test.com '), isNull);
    });
    test('WB-M1-E2 dominio de 1 letra en TLD → inválido', () {
      expect(Validadores.email('a@b.c'), 'Correo inválido');
    });
  });
}
