/// Un concierto al que el usuario se unió con un código (para la
/// pestaña "Conciertos" — lista de eventos propios, no búsqueda global).
class MiEvento {
  final String zona;
  final String fila;
  final String asiento;
  final DateTime fechaUnion;
  final String disenoId;
  final String codigo;
  final String conciertoId;
  final String artista;
  final String? nombreTour;
  final DateTime fechaInicio;
  final String? estadioNombre;
  final String? estadioCiudad;

  const MiEvento({
    required this.zona,
    required this.fila,
    required this.asiento,
    required this.fechaUnion,
    required this.disenoId,
    required this.codigo,
    required this.conciertoId,
    required this.artista,
    this.nombreTour,
    required this.fechaInicio,
    this.estadioNombre,
    this.estadioCiudad,
  });

  factory MiEvento.fromJson(Map<String, dynamic> json) {
    final diseno = json['diseno'] as Map<String, dynamic>? ?? {};
    final concierto = json['concierto'] as Map<String, dynamic>? ?? {};
    final estadio = concierto['estadio'] as Map<String, dynamic>? ?? {};
    return MiEvento(
      zona: json['zona'] ?? '',
      fila: json['fila'] ?? '',
      asiento: json['asiento'] ?? '',
      fechaUnion: DateTime.tryParse(json['fecha_union'] ?? '') ?? DateTime.now(),
      disenoId: (diseno['id'] ?? '').toString(),
      codigo: diseno['codigo'] ?? '',
      conciertoId: (concierto['id'] ?? '').toString(),
      artista: concierto['artista'] ?? '',
      nombreTour: concierto['nombre_tour'],
      fechaInicio: DateTime.tryParse(concierto['fecha_inicio'] ?? '') ?? DateTime.now(),
      estadioNombre: estadio['nombre'],
      estadioCiudad: estadio['ciudad'],
    );
  }
}
