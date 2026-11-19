// Widget de pantalla de inicio "Próximo concierto" (WID-01 a WID-05).
// La parte nativa (Kotlin) se prueba en el teléfono; aquí se prueba la
// lógica que decide QUÉ se muestra y a dónde lleva el toque.
import 'package:concertx_movil/core/models/concierto.dart';
import 'package:concertx_movil/core/services/widget_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Concierto c(String id, String artista, DateTime fecha, {String? estadio}) => Concierto(
      id: id,
      artista: artista,
      nombreTour: '$artista Tour',
      fechaInicio: fecha,
      estadio: estadio == null ? null : Estadio(id: '1', nombre: estadio),
    );

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  final ahora = DateTime(2026, 11, 6, 12);

  test('WID-01 Elige el concierto más cercano que todavía no pasa', () {
    final lista = [
      c('3', 'Evan Craft', DateTime(2026, 12, 5, 20)),
      c('1', 'Bad Bunny', DateTime(2025, 7, 12, 20)), // ya pasó
      c('6', 'Monte Santo', DateTime(2026, 11, 7, 20)),
      c('7', 'Alex Zurdo', DateTime(2026, 11, 21, 20)),
    ];
    expect(WidgetService.elegirProximo(lista, ahora: ahora)?.artista, 'Monte Santo');
  });

  test('WID-02 Un concierto que empezó hace menos de 4 h sigue contando (en curso)', () {
    final lista = [
      c('6', 'Monte Santo', ahora.subtract(const Duration(hours: 2))),
      c('7', 'Alex Zurdo', DateTime(2026, 11, 21, 20)),
    ];
    expect(WidgetService.elegirProximo(lista, ahora: ahora)?.id, '6');
  });

  test('WID-03 Sin conciertos futuros no se elige ninguno', () {
    final lista = [c('1', 'Bad Bunny', DateTime(2025, 7, 12, 20))];
    expect(WidgetService.elegirProximo(lista, ahora: ahora), isNull);
    expect(WidgetService.elegirProximo([], ahora: ahora), isNull);
  });

  test('WID-04 El detalle muestra día, fecha, hora y estadio en español', () {
    final texto = WidgetService.detalle(c('6', 'Monte Santo', DateTime(2026, 11, 7, 20), estadio: 'Estadio Azteca'));
    expect(texto, startsWith('Sáb'));
    expect(texto, contains('7 nov'));
    expect(texto, contains('20:00'));
    expect(texto, endsWith('Estadio Azteca'));
  });

  test('WID-05 Tocar el widget lleva al detalle del concierto; enlaces raros se ignoran', () {
    expect(WidgetService.rutaDesdeUri(Uri.parse('concertx://concierto/6')), '/conciertos/6');
    expect(WidgetService.rutaDesdeUri(Uri.parse('concertx://inicio')), isNull);
    expect(WidgetService.rutaDesdeUri(Uri.parse('concertx://concierto/abc')), isNull);
    expect(WidgetService.rutaDesdeUri(Uri.parse('https://evil.com/concierto/6')), isNull);
    expect(WidgetService.rutaDesdeUri(null), isNull);
  });
}
