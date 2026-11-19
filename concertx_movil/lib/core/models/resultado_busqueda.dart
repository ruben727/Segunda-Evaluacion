/// Un resultado del buscador difuso (GET /api/buscar).
class ResultadoBusqueda {
  /// 'concierto' o 'cancion'.
  final String tipo;
  final String id;
  final String conciertoId;

  /// Campo que coincidió: artista, tour, estadio, ciudad o cancion.
  final String campo;

  /// Texto con el que coincidió la búsqueda (p. ej. "Estadio Azteca").
  final String texto;
  final String titulo;
  final String subtitulo;

  /// Parecido con lo escrito, de 0 a 1 (1 = coincidencia literal).
  final double puntaje;

  const ResultadoBusqueda({
    required this.tipo,
    required this.id,
    required this.conciertoId,
    required this.campo,
    required this.texto,
    required this.titulo,
    required this.subtitulo,
    required this.puntaje,
  });

  bool get esCancion => tipo == 'cancion';

  factory ResultadoBusqueda.fromJson(Map<String, dynamic> json) => ResultadoBusqueda(
        tipo: json['tipo'] ?? 'concierto',
        id: json['id'].toString(),
        conciertoId: json['concierto_id'].toString(),
        campo: json['campo'] ?? '',
        texto: json['texto'] ?? '',
        titulo: json['titulo'] ?? '',
        subtitulo: json['subtitulo'] ?? '',
        puntaje: (json['puntaje'] as num?)?.toDouble() ?? 0,
      );
}

/// Respuesta completa: resultados + corrección sugerida.
class RespuestaBusqueda {
  final String consulta;
  final List<ResultadoBusqueda> resultados;

  /// "¿Quisiste decir …?" cuando lo escrito no coincide literalmente.
  final String? sugerencia;

  /// Motor que respondió: 'elasticsearch' o 'postgres' (respaldo).
  final String? motor;

  const RespuestaBusqueda({required this.consulta, required this.resultados, this.sugerencia, this.motor});

  factory RespuestaBusqueda.fromJson(Map<String, dynamic> json) => RespuestaBusqueda(
        consulta: json['consulta'] ?? '',
        resultados: ((json['resultados'] as List<dynamic>?) ?? [])
            .map((e) => ResultadoBusqueda.fromJson(e as Map<String, dynamic>))
            .toList(),
        sugerencia: json['sugerencia'] as String?,
        motor: json['motor'] as String?,
      );
}
