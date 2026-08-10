import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/usuario.dart';

/// Maneja login/registro contra el backend y la persistencia segura del
/// token JWT (flutter_secure_storage, no SharedPreferences, por seguridad).
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'concertx_token';

  Future<({String token, Usuario user})> login(String correo, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'No se pudo iniciar sesión');
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
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'No se pudo crear la cuenta');
    }

    final token = data['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return (token: token, user: Usuario.fromJson(data['user']));
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<bool> isLoggedIn() async => (await getToken()) != null;

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
