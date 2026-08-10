/// Configuración base de la API REST (backend Express.js).
///
/// En el emulador de Android, "localhost" apunta al propio emulador, no a
/// la máquina anfitriona; por eso se usa 10.0.2.2 para el emulador estándar.
/// Cambia [baseUrl] si pruebas en un dispositivo físico o en otra red.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://10.0.2.2:3000/api';

  /// WebSocket del mismo backend — usado para avisarle a la TV (Concertx
  /// TV) los cambios de efecto/canción en tiempo real.
  static const String wsUrl = 'ws://10.0.2.2:3000';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Conciertos
  static const String conciertos = '/conciertos';
  static String concierto(String id) => '/conciertos/$id';

  // Diseños
  static const String disenos = '/disenos';
  static const String misDisenos = '/disenos/mios';
  static String disenoPorCodigo(String codigo) => '/disenos/codigo/$codigo';

  // Eventos
  static const String unirseEvento = '/eventos/unirse';
  static const String misEventos = '/eventos/mios';

  // Usuarios
  static const String perfil = '/usuarios/perfil';

  // Wearable
  static const String wearableDatos = '/wearable/datos';
  static String wearableUltimos(String userId) => '/wearable/ultimos/$userId';

  // Puente público de simulación BLE↔HTTP (ver wearable.controller.js).
  static const String wearableSimulacion = '/wearable/simulacion';

  // Comando en dirección teléfono → reloj (canción activa: color + duración).
  static const String wearableComando = '/wearable/comando';
  static const String wearableComandoDetener = '/wearable/comando/detener';
}
