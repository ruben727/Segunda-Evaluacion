/// Opciones cerradas del reporte de incidencias (Prácticas 7 y 8). El
/// usuario solo elige de estas listas; no hay texto libre. Deben coincidir
/// con backend/src/models/incidencia.model.js y los CHECK de la BD.
class OpcionesIncidencia {
  OpcionesIncidencia._();

  static const tipos = ['Falla de equipo', 'Acceso perdido', 'Proceso de atención', 'Otro'];
  static const equipos = ['Teléfono', 'Smartwatch', 'Pantalla TV', 'Pulsera LED', 'Otro'];
  static const prioridades = ['Baja', 'Media', 'Alta'];
  static const estados = ['Pendiente', 'En proceso', 'Resuelto'];

  /// Devuelve el mensaje de error si falta alguna opción (o no es válida),
  /// o `null` si las tres están seleccionadas.
  static String? validarSeleccion({String? tipo, String? equipo, String? prioridad}) {
    final faltantes = <String>[
      if (tipo == null || !tipos.contains(tipo)) 'tipo',
      if (equipo == null || !equipos.contains(equipo)) 'equipo',
      if (prioridad == null || !prioridades.contains(prioridad)) 'prioridad',
    ];
    if (faltantes.isEmpty) return null;
    return 'Selecciona: ${faltantes.join(', ')}';
  }

  /// Conteo de incidencias por estado, siempre con las tres claves.
  static Map<String, int> contarPorEstado(Iterable<Incidencia> incidencias) {
    final conteo = {for (final e in estados) e: 0};
    for (final i in incidencias) {
      conteo[i.estado] = (conteo[i.estado] ?? 0) + 1;
    }
    return conteo;
  }
}

class Incidencia {
  final String id;
  final String tipo;
  final String equipo;
  final String prioridad;
  final String estado;
  final String creadoPor;
  final String? creadoPorNombre;
  final String? agenteAsignado;
  final String? agenteNombre;
  final DateTime fecha;

  const Incidencia({
    required this.id,
    required this.tipo,
    required this.equipo,
    required this.prioridad,
    required this.estado,
    required this.creadoPor,
    this.creadoPorNombre,
    this.agenteAsignado,
    this.agenteNombre,
    required this.fecha,
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    return Incidencia(
      id: json['id'].toString(),
      tipo: json['tipo'] ?? '',
      equipo: json['equipo'] ?? '',
      prioridad: json['prioridad'] ?? '',
      estado: json['estado'] ?? 'Pendiente',
      creadoPor: json['creado_por'].toString(),
      creadoPorNombre: json['creado_por_nombre'] as String?,
      agenteAsignado: json['agente_asignado']?.toString(),
      agenteNombre: json['agente_nombre'] as String?,
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'equipo': equipo,
        'prioridad': prioridad,
        'estado': estado,
        'creado_por': creadoPor,
        'creado_por_nombre': creadoPorNombre,
        'agente_asignado': agenteAsignado,
        'agente_nombre': agenteNombre,
        'fecha': fecha.toUtc().toIso8601String(),
      };
}

/// Agente o administrador al que se le puede asignar una incidencia.
class Agente {
  final String id;
  final String nombre;
  final String rol;

  const Agente({required this.id, required this.nombre, required this.rol});

  factory Agente.fromJson(Map<String, dynamic> json) => Agente(
        id: json['id'].toString(),
        nombre: json['nombre'] ?? '',
        rol: json['tipo'] ?? 'agente',
      );
}
