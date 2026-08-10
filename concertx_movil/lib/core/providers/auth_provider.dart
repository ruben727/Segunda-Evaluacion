import 'package:flutter/foundation.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  bool isLoggedIn = false;
  Usuario? currentUser;
  bool isLoading = false;
  String? errorMessage;

  Future<void> cargarSesion() async {
    isLoading = true;
    notifyListeners();

    final token = await _authService.getToken();
    if (token != null) {
      final payload = _authService.decodePayload(token);
      isLoggedIn = true;
      if (payload != null) {
        currentUser = Usuario(
          id: payload['id'].toString(),
          nombre: payload['nombre'] ?? '',
          correo: payload['correo'] ?? '',
          tipo: payload['tipo'] ?? 'usuario',
        );
      }
    } else {
      isLoggedIn = false;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String correo, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.login(correo, password);
      currentUser = resultado.user;
      isLoggedIn = true;
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.register(
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        password: password,
      );
      currentUser = resultado.user;
      isLoggedIn = true;
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    isLoggedIn = false;
    currentUser = null;
    notifyListeners();
  }
}
