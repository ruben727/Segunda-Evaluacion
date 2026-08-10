/// Backend Express.js. 10.0.2.2 es la forma estándar en que CUALQUIER
/// emulador de Android (incluido Wear OS) alcanza el "localhost" de la
/// máquina anfitriona donde corre `npm run dev`. Como el teléfono
/// emulado usa la misma dirección para llegar al mismo backend, ambos
/// terminan hablando con el mismo servidor aunque sean dos emuladores
/// distintos.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const String wearableSimulacion = '/wearable/simulacion';

  /// Comando en dirección teléfono → reloj (color + duración de la
  /// canción activa). Ver sync_bridge_service.dart.
  static const String wearableComando = '/wearable/comando';
}
