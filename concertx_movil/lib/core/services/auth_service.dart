import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/usuario.dart';

/// Mensajes genéricos que ve el usuario (Práctica 5). Nunca se muestra el
/// texto que manda el backend ni el de la excepción, para no filtrar
/// detalles técnicos ni confirmar si un correo está registrado.
class MensajesAuth {
  MensajesAuth._();

  static const credencialesIncorrectas = 'Correo o contraseña incorrectos';
  static const registroFallido = 'No se pudo crear la cuenta. Verifica tus datos e intenta de nuevo';
  static const sinConexion = 'No se pudo conectar con el servidor. Intenta más tarde';
  static const sesionExpirada = 'Tu sesión expiró. Inicia sesión de nuevo';
}

/// Maneja login/registro contra el backend y la persistencia segura del
/// token JWT (flutter_secure_storage, no SharedPreferences, por seguridad).
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'concertx_token';
  static const _timeout = Duration(seconds: 20);

  /// Hace el POST y convierte cualquier fallo de red o respuesta no-JSON en
  /// una excepción con mensaje genérico. No imprime nada: el body lleva la
  /// contraseña.
  Future<(int, Map<String, dynamic>)> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      return (response.statusCode, data is Map<String, dynamic> ? data : <String, dynamic>{});
    } on TimeoutException {
      throw Exception(MensajesAuth.sinConexion);
    } on http.ClientException {
      throw Exception(MensajesAuth.sinConexion);
    } on FormatException {
      throw Exception(MensajesAuth.sinConexion);
    }
  }

  Future<({String token, Usuario user})> login(String correo, String password) async {
    final (status, data) = await _post(ApiConstants.login, {'correo': correo, 'password': password});

    if (status != 200) {
      // 400/401: credenciales; 5xx: servidor. Ninguno muestra el detalle.
      throw Exception(status >= 500 ? MensajesAuth.sinConexion : MensajesAuth.credencialesIncorrectas);
    }

    final token = data['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return (token: token, user: Usuario.fromJson(data['user']));
  }

  Future<({String token, Usuario user})> register({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    final (status, data) = await _post(ApiConstants.register, {
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
      'password': password,
    });

    if (status != 201) {
      throw Exception(status >= 500 ? MensajesAuth.sinConexion : MensajesAuth.registroFallido);
    }

    final token = data['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return (token: token, user: Usuario.fromJson(data['user']));
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Hay sesión solo si hay token guardado y todavía no vence.
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && !tokenVencido(token);
  }

  /// true si el token no se puede leer o su `exp` ya pasó (con 1 minuto de
  /// margen por diferencias de reloj). El backend firma tokens de 7 días.
  bool tokenVencido(String token, {DateTime? ahora}) {
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp is! num) return false; // sin exp: no caduca
    final vence = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    return !(ahora ?? DateTime.now().toUtc()).isBefore(vence.subtract(const Duration(minutes: 1)));
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  /// Decodifica el payload del JWT (sin verificar la firma; solo lectura
  /// local para mostrar datos del usuario mientras llega la respuesta del
  /// backend).
  Map<String, dynamic>? decodePayload(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return null;
      final normalizado = base64Url.normalize(partes[1]);
      final payload = utf8.decode(base64Url.decode(normalizado));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
