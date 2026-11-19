/// Reglas de validación de formularios compartidas por login_screen y
/// register_screen (Práctica 5). Son funciones puras: devuelven el mensaje
/// de error a mostrar o `null` si el valor es válido, así se pueden probar
/// sin levantar widgets (ver test/caja_negra_test.dart).
class Validadores {
  Validadores._();

  static const int passwordMin = 8;
  static const int passwordMax = 64;

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  static final RegExp _mayusculaYNumero = RegExp(r'^(?=.*[A-Z])(?=.*\d)');

  /// true si el texto es nulo, vacío o solo tiene espacios.
  static bool estaVacio(String? valor) => valor == null || valor.trim().isEmpty;

  static String? email(String? valor) {
    if (estaVacio(valor)) return 'Ingresa tu correo';
    return _email.hasMatch(valor!.trim()) ? null : 'Correo inválido';
  }

  /// Rango de longitud común a login y registro. La contraseña no se
  /// recorta (trim): un espacio también es un carácter válido, pero una
  /// contraseña hecha solo de espacios se rechaza.
  static String? passwordLongitud(String? valor) {
    if (estaVacio(valor)) return 'Ingresa tu contraseña';
    if (valor!.length < passwordMin) return 'Mínimo $passwordMin caracteres';
    if (valor.length > passwordMax) return 'Máximo $passwordMax caracteres';
    return null;
  }

  /// Registro: además del rango, exige una mayúscula y un número (misma
  /// regla que valida el backend en auth.controller.js).
  static String? passwordRegistro(String? valor) {
    final errorLongitud = passwordLongitud(valor);
    if (errorLongitud != null) return errorLongitud;
    if (!_mayusculaYNumero.hasMatch(valor!)) return 'Debe incluir una mayúscula y un número';
    return null;
  }

  static String? nombre(String? valor) {
    if (estaVacio(valor) || valor!.trim().length < 3) return 'Ingresa tu nombre completo';
    return null;
  }

  static String? telefono(String? valor) {
    final digitos = (valor ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 10 || digitos.length > 13) {
      return 'El teléfono debe tener entre 10 y 13 dígitos';
    }
    return null;
  }
}
