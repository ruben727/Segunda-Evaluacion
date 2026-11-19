// Práctica 11 — Caja blanca, Método M2 (procesamiento / cálculo):
//   ReproductorProvider.reproducir + cierre del Timer (cuenta regresiva)
//   lib/core/providers/reproductor_provider.dart:35-62
// Complementos analizados: repetir() (95-104, condición A||B||C) y
// _avisarDispositivos() (67-92, try/catch y guarda "cancionId != id").
//
// Se usa fake_async para controlar el reloj: no hay esperas reales.
import 'dart:async';

import 'package:concertx_movil/core/providers/reproductor_provider.dart';
import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/services/sync_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de ApiService: no toca la red; cuenta llamadas y puede fallar o
/// quedarse "colgado" hasta que la prueba lo libere.
class ApiFalsa extends ApiService {
  int comandos = 0;
  int detenciones = 0;
  bool fallar = false;
  final List<Completer<void>> bloqueos = [];

  @override
  Future<void> enviarComandoWearable({required String colorHex, required int duracionSeg, String? cancionTitulo}) async {
    comandos++;
    if (bloqueos.isNotEmpty) await bloqueos.removeAt(0).future;
    if (fallar) throw Exception('sin red');
  }

  @override
  Future<void> detenerComandoWearable() async {
    detenciones++;
  }
}

/// Doble de SyncService: registra lo que se le mandaría a la TV.
class SyncFalso extends SyncService {
  final List<String> cancionesEnviadas = [];
  final List<String?> artistas = [];

  @override
  Future<void> conectar() async {}

  @override
  void setArtistaActivo(String? artista) => artistas.add(artista);

  @override
  void enviarCancion(String titulo, String artista, int duracionSeg) => cancionesEnviadas.add(titulo);
}

void main() {
  late ApiFalsa api;
  late SyncFalso sync;
  late ReproductorProvider p;
  late int notificaciones;

  setUp(() {
    api = ApiFalsa();
    sync = SyncFalso();
    p = ReproductorProvider(apiService: api, syncService: sync);
    notificaciones = 0;
    p.addListener(() => notificaciones++);
  });

  void play(String id, int dur, {String artista = 'Evan Craft'}) {
    p.reproducir(cancionId: id, titulo: 'Canción $id', colorHex: '#EF4444', duracionSeg: dur, artista: artista);
  }

  group('M2 caminos independientes de reproducir()', () {
    test('WB-M2-P1 sin timer previo (D1=F): arranca, estado inicial y regresa sin tick', () {
      fakeAsync((async) {
        expect(p.reproduciendo, isFalse);
        play('1', 180);
        async.flushMicrotasks();
        expect(p.reproduciendo, isTrue);
        expect(p.segundosRestantes, 180);
        expect(p.tiempoRestanteFormateado, '03:00');
        expect(api.comandos, 1);
        expect(sync.cancionesEnviadas, ['Canción 1']);
        p.dispose();
      });
    });

    test('WB-M2-P2 con timer previo (D1=V): cancela el anterior, no se duplican ticks', () {
      fakeAsync((async) {
        play('1', 100);
        async.elapse(const Duration(seconds: 3));
        play('2', 10);
        async.elapse(const Duration(seconds: 1));
        // Si el timer viejo siguiera vivo bajaría 2 por segundo.
        expect(p.segundosRestantes, 9);
        expect(p.cancionId, '2');
        p.dispose();
      });
    });

    test('WB-M2-P3 duración 1: primer tick → D2=V → detener()', () {
      fakeAsync((async) {
        play('1', 1);
        async.elapse(const Duration(seconds: 1));
        expect(p.reproduciendo, isFalse);
        expect(p.cancionId, isNull);
        expect(p.segundosRestantes, 0);
        expect(api.detenciones, 1);
        expect(sync.artistas.last, isNull);
      });
    });

    test('WB-M2-P4 duración 2: tick con D2=F (notifica) y luego D2=V', () {
      fakeAsync((async) {
        play('1', 2);
        async.flushMicrotasks();
        final antes = notificaciones;
        async.elapse(const Duration(seconds: 1));
        expect(p.reproduciendo, isTrue);
        expect(p.segundosRestantes, 1);
        expect(notificaciones, antes + 1);
        async.elapse(const Duration(seconds: 1));
        expect(p.reproduciendo, isFalse);
        expect(api.detenciones, 1);
      });
    });
  });

  group('M2 valores límite de duracionSeg', () {
    test('WB-M2-L1 duración 0 (mín−1): no se detiene al instante, dura 1 tick', () {
      fakeAsync((async) {
        play('1', 0);
        expect(p.reproduciendo, isTrue, reason: 'reproducir() no valida duración 0');
        async.elapse(const Duration(seconds: 1));
        expect(p.reproduciendo, isFalse);
        expect(p.segundosRestantes, 0, reason: 'detener() deja 0, nunca negativo');
      });
    });
    test('WB-M2-L2 duración 1 (mín) dura exactamente 1 s', () {
      fakeAsync((async) {
        play('1', 1);
        async.elapse(const Duration(milliseconds: 999));
        expect(p.reproduciendo, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(p.reproduciendo, isFalse);
      });
    });
    test('WB-M2-L3 duración 3599 → formato "59:59"; 3600 → "60:00" (sin horas)', () {
      fakeAsync((async) {
        play('1', 3599);
        expect(p.tiempoRestanteFormateado, '59:59');
        play('2', 3600);
        expect(p.tiempoRestanteFormateado, '60:00');
        p.dispose();
      });
    });
  });

  group('M2 _avisarDispositivos: excepciones y carrera', () {
    test('WB-M2-X1 la API del reloj falla (sin red): no se propaga y la TV igual recibe la canción', () {
      fakeAsync((async) {
        api.fallar = true;
        play('1', 30);
        async.flushMicrotasks();
        expect(p.reproduciendo, isTrue);
        expect(sync.cancionesEnviadas, ['Canción 1']);
        p.dispose();
      });
    });

    test('WB-M2-X2 cambia la canción mientras la red responde: no se manda el aviso viejo (cancionId != id)', () {
      fakeAsync((async) {
        final lento = Completer<void>();
        api.bloqueos.add(lento);
        play('1', 30);
        async.flushMicrotasks();
        play('2', 30);
        async.flushMicrotasks();
        lento.complete();
        async.flushMicrotasks();
        expect(sync.cancionesEnviadas, ['Canción 2']);
        p.dispose();
      });
    });
  });

  group('M2 repetir(): cobertura de condiciones de A || B || C', () {
    test('WB-M2-C1 A=V (cancionId null) → no hace nada', () async {
      await p.repetir();
      expect(p.reproduciendo, isFalse);
      expect(api.comandos, 0);
    });
    test('WB-M2-C2 A=F, B=V (titulo null) → no hace nada', () async {
      p.cancionId = '1';
      p.colorActual = '#fff';
      await p.repetir();
      expect(p.reproduciendo, isFalse);
    });
    test('WB-M2-C3 A=F, B=F, C=V (color null) → no hace nada', () async {
      p.cancionId = '1';
      p.tituloActual = 'x';
      await p.repetir();
      expect(p.reproduciendo, isFalse);
    });
    test('WB-M2-C4 A=B=C=F → reinicia la cuenta desde la duración total', () {
      fakeAsync((async) {
        play('1', 10);
        async.elapse(const Duration(seconds: 4));
        expect(p.segundosRestantes, 6);
        p.repetir();
        expect(p.segundosRestantes, 10);
        expect(api.comandos, 2);
        p.dispose();
      });
    });
  });
}
