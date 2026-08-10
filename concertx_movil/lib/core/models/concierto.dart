import 'cancion.dart';

class Estadio {
  final String id;
  final String nombre;
  final String? direccion;
  final String? ciudad;

  const Estadio({required this.id, required this.nombre, this.direccion, this.ciudad});

  factory Estadio.fromJson(Map<String, dynamic> json) {
    return Estadio(
      id: json['id'].toString(),
      nombre: json['nombre'] ?? '',
      direccion: json['direccion'],
      ciudad: json['ciudad'],
    );
  }
}

class Concierto {
  final String id;
  final String artista;
  final String? nombreTour;
  final DateTime fechaInicio;
  final String? imagenUrl;
  final String? descripcion;
  final int asistentesRegistrados;
  final Estadio? estadio;
  final List<Cancion> canciones;

  const Concierto({
    required this.id,
    required this.artista,
    this.nombreTour,
    required this.fechaInicio,
    this.imagenUrl,
    this.descripcion,
    this.asistentesRegistrados = 0,
    this.estadio,
    this.canciones = const [],
  });

  bool get esHoy {
    final ahora = DateTime.now();
    return fechaInicio.year == ahora.year &&
        fechaInicio.month == ahora.month &&
        fechaInicio.day == ahora.day;
  }

  factory Concierto.fromJson(Map<String, dynamic> json) {
    return Concierto(
      id: json['id'].toString(),
      artista: json['artista'] ?? '',
      nombreTour: json['nombre_tour'],
      fechaInicio: DateTime.tryParse(json['fecha_inicio'] ?? '') ?? DateTime.now(),
      imagenUrl: json['imagen_url'],
      descripcion: json['descripcion'],
      asistentesRegistrados: json['asistentes_registrados'] ?? 0,
      estadio: json['estadio'] != null ? Estadio.fromJson(json['estadio']) : null,
      canciones: (json['canciones'] as List<dynamic>? ?? [])
          .map((c) => Cancion.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
