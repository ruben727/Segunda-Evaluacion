import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

/// Puente HTTP hacia el backend: publica cada lectura simulada del reloj
/// (salud + color que se está mostrando ahora mismo) para que el
/// teléfono la vea aunque ambos corran en emuladores separados (los
/// emuladores de Android no comparten radio Bluetooth entre sí, así que
/// la NOTIFY real por BLE no llega de un emulador a otro). En un reloj y
/// teléfono físicos, este puente es redundante: los datos ya llegan por
/// BLE real (ver ble_server_service.dart).
class SyncBridgeService {
  Future<void> publicar({
    required int ritmo,
    required int oxigeno,
    required String colorHex,
    required bool vibracion,
  }) async {
    try {
      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.wearableSimulacion}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ritmo': ritmo,
              'oxigeno': oxigeno,
              'efecto_color': colorHex,
              'vibracion': vibracion,
            }),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Sin backend disponible: se ignora, el reloj sigue funcionando
      // localmente y por BLE real de todas formas.
    }
  }

  /// Consulta si el teléfono mandó un "comando" (reproducir canción con
  /// tal color, tal duración). Devuelve null si no hay backend o no hay
  /// comando activo.
  Future<Map<String, dynamic>?> consultarComando() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConstants.baseUrl}${ApiConstants.wearableComando}'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return null;
    }
  }
}
