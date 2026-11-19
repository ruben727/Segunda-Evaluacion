/// Resumen de un diseño creado por el usuario (para "Mis diseños" en el
/// perfil y la pestaña Conciertos): lo necesario para mostrar el
/// concierto, los colores por canción y compartir el código.
class MiDiseno {
  final String id;
  final String nombre;
  final String codigo;
  final DateTime createdAt;
  final String conciertoId;
  final String artista;
  final String? nombreTour;
  final DateTime fechaInicio;
  final String? estadioNombre;
  final String? estadioCiudad;

  /// Colores del diseño en orden de canción (#RRGGBB).
  final List<String> colores;

  const MiDiseno({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.createdAt,
    required this.conciertoId,
    required this.artista,
    this.nombreTour,
    required this.fechaInicio,
    this.estadioNombre,
    this.estadioCiudad,
    this.colores = const [],
  });

  factory MiDiseno.fromJson(Map<String, dynamic> json) {
    final concierto = json['concierto'] as Map<String, dynamic>? ?? {};
    final estadio = concierto['estadio'] as Map<String, dynamic>? ?? {};
    return MiDiseno(
      id: json['id'].toString(),
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      conciertoId: (concierto['id'] ?? '').toString(),
      artista: concierto['artista'] ?? '',
      nombreTour: concierto['nombre_tour'],
      fechaInicio: DateTime.tryParse(concierto['fecha_inicio'] ?? '') ?? DateTime.now(),
      estadioNombre: estadio['nombre'],
      estadioCiudad: estadio['ciudad'],
      colores: (json['colores'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
