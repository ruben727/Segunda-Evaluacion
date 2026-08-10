class Usuario {
  final String id;
  final String nombre;
  final String correo;
  final String? telefono;
  final String tipo;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    this.telefono,
    this.tipo = 'usuario',
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'].toString(),
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      telefono: json['telefono']?.toString(),
      tipo: json['tipo'] ?? 'usuario',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'tipo': tipo,
      };
}
