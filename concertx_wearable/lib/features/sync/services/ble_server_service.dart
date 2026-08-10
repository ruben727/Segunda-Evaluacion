import 'dart:async';
import 'package:flutter/services.dart';

/// Estado de la conexión del servidor GATT del reloj.
enum BleServerStatus { detenido, anunciando, conectado, desconectado, error }

/// Envuelve el canal de plataforma (Android nativo) que implementa un
/// servidor GATT BLE con características NOTIFY para:
///   - ritmo (BPM)
///   - oxígeno en sangre (SpO2)
///   - color del efecto activo
///   - estado de vibración
///
/// La implementación nativa vive en MainActivity.kt (BluetoothGattServer +
/// BluetoothLeAdvertiser), ya que flutter_blue_plus solo soporta el rol
/// central (no periférico/GATT server).
class BleServerService {
  static const _methodChannel = MethodChannel('com.concertx/ble_gatt_server');
  static const _eventChannel = EventChannel('com.concertx/ble_gatt_server_status');

  final _statusController = StreamController<BleServerStatus>.broadcast();
  Stream<BleServerStatus> get statusStream => _statusController.stream;

  StreamSubscription? _eventSub;
  bool _activo = false;
  bool get activo => _activo;

  void _escucharEventos() {
    _eventSub ??= _eventChannel.receiveBroadcastStream().listen((evento) {
      final texto = evento.toString();
      if (texto == 'advertising') {
        _statusController.add(BleServerStatus.anunciando);
      } else if (texto == 'connected') {
        _statusController.add(BleServerStatus.conectado);
      } else if (texto == 'disconnected') {
        _statusController.add(BleServerStatus.desconectado);
      } else if (texto == 'detenido') {
        _statusController.add(BleServerStatus.detenido);
      } else if (texto.startsWith('error')) {
        _statusController.add(BleServerStatus.error);
      }
    }, onError: (_) => _statusController.add(BleServerStatus.error));
  }

  /// Inicia el servidor GATT y comienza a anunciarse por BLE.
  Future<bool> iniciar() async {
    _escucharEventos();
    try {
      final ok = await _methodChannel.invokeMethod<bool>('iniciar') ?? false;
      _activo = ok;
      return ok;
    } on PlatformException {
      _statusController.add(BleServerStatus.error);
      return false;
    }
  }

  /// Detiene el anuncio y cierra el servidor GATT.
  Future<void> detener() async {
    try {
      await _methodChannel.invokeMethod('detener');
    } on PlatformException {
      // Se ignora: el adaptador pudo haberse desactivado externamente.
    }
    _activo = false;
    _statusController.add(BleServerStatus.detenido);
  }

  Future<void> enviarRitmo(int bpm) async {
    if (!_activo) return;
    await _methodChannel.invokeMethod('actualizarRitmo', {'bpm': bpm});
  }

  Future<void> enviarColor(String colorHex) async {
    if (!_activo) return;
    await _methodChannel.invokeMethod('actualizarColor', {'color': colorHex});
  }

  Future<void> enviarVibracion(bool activa) async {
    if (!_activo) return;
    await _methodChannel.invokeMethod('actualizarVibracion', {'activa': activa});
  }

  Future<void> enviarOxigeno(int porcentaje) async {
    if (!_activo) return;
    await _methodChannel.invokeMethod('actualizarOxigeno', {'porcentaje': porcentaje});
  }

  void dispose() {
    _eventSub?.cancel();
    _statusController.close();
  }
}
