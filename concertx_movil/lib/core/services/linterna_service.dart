import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';

/// Resultado de intentar encender/apagar la linterna, para que la UI
/// muestre el mensaje correcto.
enum ResultadoLinterna { ok, permisoDenegado, permisoBloqueado, noDisponible, error }

/// Enciende/apaga la linterna (flash) del teléfono. El permiso de cámara
/// se pide justo en el momento en que el usuario toca "Encender lámpara",
/// no al abrir la app.
class LinternaService {
  LinternaService._();
  static final LinternaService instance = LinternaService._();

  bool _encendida = false;
  bool get encendida => _encendida;

  Future<ResultadoLinterna> encender() async {
    var estado = await Permission.camera.status;
    if (!estado.isGranted) {
      estado = await Permission.camera.request();
    }
    if (estado.isPermanentlyDenied) return ResultadoLinterna.permisoBloqueado;
    if (!estado.isGranted) return ResultadoLinterna.permisoDenegado;

    try {
      if (!await TorchLight.isTorchAvailable()) {
        return ResultadoLinterna.noDisponible;
      }
      await TorchLight.enableTorch();
      _encendida = true;
      return ResultadoLinterna.ok;
    } catch (_) {
      return ResultadoLinterna.error;
    }
  }

  Future<void> apagar() async {
    if (!_encendida) return;
    try {
      await TorchLight.disableTorch();
    } catch (_) {
      // Si falla al apagar no hay mucho que hacer; se marca como apagada.
    }
    _encendida = false;
  }

  /// Abre los ajustes de la app para que el usuario habilite el permiso
  /// si lo bloqueó ("No volver a preguntar").
  Future<void> abrirAjustes() => openAppSettings();
}
