class Cancion {
  final String id;
  final int numero;
  final String titulo;
  final int duracionSegundos;

  const Cancion({
    required this.id,
    required this.numero,
    required this.titulo,
    required this.duracionSegundos,
  });

  String get duracionFormateada {
    final minutos = duracionSegundos ~/ 60;
    final segundos = duracionSegundos % 60;
    return '$minutos:${segundos.toString().padLeft(2, '0')}';
  }

  factory Cancion.fromJson(Map<String, dynamic> json) {
    return Cancion(
      id: json['id'].toString(),
      numero: json['numero'] ?? 0,
      titulo: json['titulo'] ?? '',
      duracionSegundos: json['duracion_segundos'] ?? 180,
    );
  }
}
