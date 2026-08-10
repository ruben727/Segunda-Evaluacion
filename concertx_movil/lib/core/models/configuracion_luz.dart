class ConfiguracionLuz {
  final String cancionId;
  final String colorHex;
  final bool vibracion;
  final int intensidad;

  // Datos de la canción, presentes cuando esta configuración viene
  // adjunta a un diseño consultado por código (GET /disenos/codigo/:c).
  final String? tituloCancion;
  final int? numeroCancion;
  final int? duracionSegundos;

  const ConfiguracionLuz({
    required this.cancionId,
    this.colorHex = '#3B82F6',
    this.vibracion = false,
    this.intensidad = 50,
    this.tituloCancion,
    this.numeroCancion,
    this.duracionSegundos,
  });

  ConfiguracionLuz copyWith({String? colorHex, bool? vibracion, int? intensidad}) {
    return ConfiguracionLuz(
      cancionId: cancionId,
      colorHex: colorHex ?? this.colorHex,
      vibracion: vibracion ?? this.vibracion,
      intensidad: intensidad ?? this.intensidad,
      tituloCancion: tituloCancion,
      numeroCancion: numeroCancion,
      duracionSegundos: duracionSegundos,
    );
  }

  Map<String, dynamic> toJson() => {
        'cancion_id': cancionId,
        'color_hex': colorHex,
        'vibracion': vibracion,
        'intensidad': intensidad,
      };

  factory ConfiguracionLuz.fromJson(Map<String, dynamic> json) {
    return ConfiguracionLuz(
      cancionId: (json['cancion_id'] ?? json['id']).toString(),
      colorHex: json['color_hex'] ?? '#3B82F6',
      vibracion: json['vibracion'] ?? false,
      intensidad: json['intensidad'] ?? 50,
      tituloCancion: json['titulo'],
      numeroCancion: json['numero'],
      duracionSegundos: json['duracion_segundos'],
    );
  }
}
