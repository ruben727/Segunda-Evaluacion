/// Configuración base de la API REST (backend Express.js, desplegado en
/// Vercel con HTTPS).
class ApiConstants {
  ApiConstants._();

  /// Por defecto, producción (Vercel). Para pruebas contra el backend local:
  /// `flutter run --dart-define=API_URL=http://10.0.2.2:3000/api`
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://backend-three-xi-95.vercel.app/api');

  /// WebSocket del backend — usado para avisarle a la TV (Concertx TV) los
  /// cambios de efecto/canción en tiempo real. Vercel NO soporta conexiones
  /// WebSocket persistentes (funciones serverless sin estado), así que esto
  /// sigue apuntando al backend corriendo en tu red local (`npm run dev`),
  /// no a Vercel. Reemplaza 10.0.2.2 por la IP local de tu máquina
  /// (ej. 192.168.1.50) si pruebas en un teléfono físico en vez del
  /// emulador — 10.0.2.2 solo funciona dentro del emulador de Android.
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

  static String disenoPorId(String id) => '/disenos/$id';

  // Eventos
  static const String unirseEvento = '/eventos/unirse';
  static const String misEventos = '/eventos/mios';

  // Usuarios
  static const String perfil = '/usuarios/perfil';

  // Buscador difuso (pg_trgm)
  static const String buscar = '/buscar';

  // Incidencias (Prácticas 7-10)
  static const String incidencias = '/incidencias';
  static const String misIncidencias = '/incidencias/mias';
  static const String agentesIncidencias = '/incidencias/agentes';
  static String incidencia(String id) => '/incidencias/$id';

  // Wearable
  static const String wearableDatos = '/wearable/datos';
  static String wearableUltimos(String userId) => '/wearable/ultimos/$userId';

  // Puente público de simulación BLE↔HTTP (ver wearable.controller.js).
  static const String wearableSimulacion = '/wearable/simulacion';

  // Comando en dirección teléfono → reloj (canción activa: color + duración).
  static const String wearableComando = '/wearable/comando';
  static const String wearableComandoDetener = '/wearable/comando/detener';
}
