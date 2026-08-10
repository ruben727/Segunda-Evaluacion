import 'configuracion_luz.dart';

class Diseno {
  final String id;
  final String usuarioId;
  final String conciertoId;
  final String nombre;
  final String codigo;
  final List<ConfiguracionLuz> configuraciones;

  const Diseno({
    required this.id,
    required this.usuarioId,
    required this.conciertoId,
    required this.nombre,
    required this.codigo,
    this.configuraciones = const [],
  });

  factory Diseno.fromJson(Map<String, dynamic> json) {
    return Diseno(
      id: json['id'].toString(),
      usuarioId: (json['usuario_id'] ?? '').toString(),
      conciertoId: (json['concierto_id'] ?? '').toString(),
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      configuraciones: (json['configuraciones'] as List<dynamic>? ?? [])
          .map((c) => ConfiguracionLuz.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
