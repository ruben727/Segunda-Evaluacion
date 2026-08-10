/// Resumen de un diseño creado por el usuario (para "Mis diseños" en el
/// perfil): solo lo necesario para mostrar y compartir el código.
class MiDiseno {
  final String id;
  final String nombre;
  final String codigo;
  final DateTime createdAt;
  final String conciertoId;
  final String artista;
  final String? nombreTour;
  final DateTime fechaInicio;

  const MiDiseno({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.createdAt,
    required this.conciertoId,
    required this.artista,
    this.nombreTour,
    required this.fechaInicio,
  });

  factory MiDiseno.fromJson(Map<String, dynamic> json) {
    final concierto = json['concierto'] as Map<String, dynamic>? ?? {};
    return MiDiseno(
      id: json['id'].toString(),
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      conciertoId: (concierto['id'] ?? '').toString(),
      artista: concierto['artista'] ?? '',
      nombreTour: concierto['nombre_tour'],
      fechaInicio: DateTime.tryParse(concierto['fecha_inicio'] ?? '') ?? DateTime.now(),
    );
  }
}
