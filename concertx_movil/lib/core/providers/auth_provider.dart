import 'package:flutter/foundation.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  bool isLoggedIn = false;
  Usuario? currentUser;
  bool isLoading = false;
  String? errorMessage;

  /// Aviso para mostrar una sola vez en el login (p. ej. sesión expirada).
  String? avisoSesion;

  Future<void> cargarSesion() async {
    isLoading = true;
    notifyListeners();

    var token = await _authService.getToken();
    if (token != null && _authService.tokenVencido(token)) {
      // El token guardado ya no sirve: se borra y se pide login de nuevo.
      await _authService.logout();
      token = null;
      avisoSesion = MensajesAuth.sesionExpirada;
    }
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
      errorMessage = _mensajeSeguro(e, MensajesAuth.credencialesIncorrectas);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Solo deja pasar los mensajes genéricos de [MensajesAuth]; cualquier
  /// otro error (texto técnico, excepción inesperada) se cambia por
  /// [porDefecto].
  static String _mensajeSeguro(Object error, String porDefecto) {
    final texto = error.toString().replaceFirst('Exception: ', '');
    const permitidos = {
      MensajesAuth.credencialesIncorrectas,
      MensajesAuth.registroFallido,
      MensajesAuth.sinConexion,
    };
    return permitidos.contains(texto) ? texto : porDefecto;
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
      errorMessage = _mensajeSeguro(e, MensajesAuth.registroFallido);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Vuelve a leer el perfil del backend (nombre y rol actuales). El JWT
  /// guardado no trae el nombre y su rol puede estar desactualizado si se
  /// cambió después del login. Si falla, se conserva lo que había.
  Future<void> refrescarPerfil() async {
    if (!isLoggedIn) return;
    try {
      final data = await ApiService(authService: _authService).getProfile();
      currentUser = Usuario.fromJson(data);
      notifyListeners();
    } catch (_) {
      // Sin red o token vencido: se mantiene el usuario local.
    }
  }

  /// El backend rechazó el token (401). Cierra la sesión una sola vez
  /// aunque fallen varias peticiones a la vez; el router manda a /login.
  Future<void> sesionExpirada() async {
    if (!isLoggedIn) return;
    isLoggedIn = false;
    currentUser = null;
    avisoSesion = MensajesAuth.sesionExpirada;
    await _authService.logout();
    notifyListeners();
  }

  /// Devuelve el aviso pendiente y lo borra.
  String? tomarAvisoSesion() {
    final aviso = avisoSesion;
    avisoSesion = null;
    return aviso;
  }

  Future<void> logout() async {
    await _authService.logout();
    isLoggedIn = false;
    currentUser = null;
    notifyListeners();
  }
}
