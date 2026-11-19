// Buscador difuso — pruebas de caja negra del provider y la pantalla
// (BUS-01 a BUS-06). La similitud real la calcula PostgreSQL (pg_trgm);
// aquí se prueba cómo la app pide y muestra los resultados.
import 'dart:async';

import 'package:concertx_movil/core/models/resultado_busqueda.dart';
import 'package:concertx_movil/core/providers/busqueda_provider.dart';
import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/features/search/screens/buscar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ResultadoBusqueda _res(String titulo, {String campo = 'artista'}) => ResultadoBusqueda(
      tipo: 'concierto',
      id: '2',
      conciertoId: '2',
      campo: campo,
      texto: titulo,
      titulo: titulo,
      subtitulo: 'Mañana Será Bonito Tour · Foro Sol',
      puntaje: 0.5,
    );

class ApiBusquedaFalsa extends ApiService {
  final consultas = <String>[];
  final pendientes = <String, Completer<RespuestaBusqueda>>{};
  bool manual = false; // true: la prueba decide cuándo responde cada consulta
  bool fallar = false;

  @override
  Future<RespuestaBusqueda> buscar(String consulta, {int limite = 10}) {
    consultas.add(consulta);
    if (fallar) return Future.error(const ApiException(500, 'syntax error at or near "SELECT"'));
    if (manual) return (pendientes[consulta] = Completer<RespuestaBusqueda>()).future;
    return Future.value(RespuestaBusqueda(
      consulta: consulta,
      resultados: consulta == 'zzzz' ? [] : [_res('Karol G')],
      sugerencia: consulta == 'karl g' ? 'Karol G' : null,
      motor: 'elasticsearch',
    ));
  }
}

void main() {
  test('BUS-01 Escribir rápido hace UNA sola petición con el texto final (debounce)', () async {
    final api = ApiBusquedaFalsa();
    final p = BusquedaProvider(apiService: api, debounce: const Duration(milliseconds: 50));

    for (final t in ['k', 'ka', 'kar', 'karl', 'karl g']) {
      p.escribir(t);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(api.consultas, ['karl g']);
    expect(p.resultados.single.titulo, 'Karol G');
    expect(p.sugerencia, 'Karol G');
  });

  test('BUS-02 Una respuesta vieja que llega tarde no reemplaza a la más nueva', () async {
    final api = ApiBusquedaFalsa()..manual = true;
    final p = BusquedaProvider(apiService: api);

    final vieja = p.buscarAhora('bad');
    final nueva = p.buscarAhora('karol');
    api.pendientes['karol']!.complete(RespuestaBusqueda(consulta: 'karol', resultados: [_res('Karol G')]));
    await nueva;
    api.pendientes['bad']!.complete(RespuestaBusqueda(consulta: 'bad', resultados: [_res('Bad Bunny')]));
    await vieja;

    expect(p.resultados.single.titulo, 'Karol G');
  });

  test('BUS-03 Borrar el texto limpia resultados y no llama a la API', () async {
    final api = ApiBusquedaFalsa();
    final p = BusquedaProvider(apiService: api);
    await p.buscarAhora('karol');

    p.escribir('   ');

    expect(p.resultados, isEmpty);
    expect(p.buscado, isFalse);
    expect(api.consultas, ['karol']);
  });

  test('BUS-04 Un error del servidor muestra un mensaje genérico sin texto técnico', () async {
    final p = BusquedaProvider(apiService: ApiBusquedaFalsa()..fallar = true);
    await p.buscarAhora('karol');

    expect(p.errorMessage, BusquedaProvider.mensajeError);
    expect(p.errorMessage, isNot(contains('SELECT')));
    expect(p.isLoading, isFalse);
  });

  testWidgets('BUS-05 Con errores de escritura muestra "¿Quisiste decir…?" y el resultado parecido', (tester) async {
    final api = ApiBusquedaFalsa();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => BusquedaProvider(apiService: api, debounce: const Duration(milliseconds: 10)),
      child: const MaterialApp(home: BuscarScreen()),
    ));

    await tester.enterText(find.byKey(const Key('campo_buscar')), 'karl g');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.byKey(const Key('quisiste_decir')), findsOneWidget);
    expect(find.text('Karol G'), findsOneWidget);
    expect(find.textContaining('Buscando con'), findsNothing);

    // Tocar la sugerencia busca con el texto corregido.
    await tester.tap(find.byKey(const Key('quisiste_decir')));
    await tester.pump();
    expect(api.consultas.last, 'Karol G');
  });

  testWidgets('BUS-06 Sin nada parecido se avisa que no hubo resultados', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => BusquedaProvider(apiService: ApiBusquedaFalsa(), debounce: const Duration(milliseconds: 10)),
      child: const MaterialApp(home: BuscarScreen()),
    ));

    await tester.enterText(find.byKey(const Key('campo_buscar')), 'zzzz');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.textContaining('No encontramos nada parecido'), findsOneWidget);
  });
}
