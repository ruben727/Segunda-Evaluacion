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

  /// Rol del usuario (usuario | agente | admin). En la BD vive en la
  /// columna `tipo`, que ya viajaba en el JWT; aquí se expone como `rol`.
  /// Solo se usa para decidir qué mostrar: los permisos reales los valida
  /// el backend en cada petición.
  String get rol => tipo;
  bool get esAdmin => tipo == 'admin';
  bool get esAgente => tipo == 'agente';
  bool get esStaff => esAdmin || esAgente;

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
