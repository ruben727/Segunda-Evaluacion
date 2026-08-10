import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../models/wearable_data.dart';

enum BleConnectionStatus { desconectado, escaneando, conectando, conectado, error }

/// Escanea, se conecta y se suscribe (NOTIFY) al reloj ConcertX.
///
/// Expone un [Stream<WearableData>] combinando las tres características
/// (ritmo, color, vibración) y maneja desconexiones sin crashear la app,
/// intentando reconectar automáticamente.
class BleService {
  final _dataController = StreamController<WearableData>.broadcast();
  final _statusController = StreamController<BleConnectionStatus>.broadcast();

  Stream<WearableData> get dataStream => _dataController.stream;
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  final List<StreamSubscription<List<int>>> _notifySubs = [];

  int _ultimoRitmo = 0;
  int _ultimoOxigeno = 98;
  String _ultimoColor = '#3B82F6';
  bool _ultimaVibracion = false;

  bool _reconectarAutomaticamente = true;
  BleConnectionStatus _status = BleConnectionStatus.desconectado;
  BleConnectionStatus get status => _status;

  void _setStatus(BleConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// Busca dispositivos que anuncien el servicio de ConcertX y se conecta
  /// al primero que encuentre.
  Future<void> scanAndConnect() async {
    _reconectarAutomaticamente = true;
    _setStatus(BleConnectionStatus.escaneando);

    try {
      final soportado = await FlutterBluePlus.isSupported;
      if (!soportado) {
        _setStatus(BleConnectionStatus.error);
        return;
      }

      await _scanSub?.cancel();
      await FlutterBluePlus.startScan(
        withServices: [Guid(concertxServiceUuid)],
        timeout: const Duration(seconds: 10),
      );

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        if (results.isEmpty) return;
        final encontrado = results.first.device;
        await FlutterBluePlus.stopScan();
        await _scanSub?.cancel();
        await connect(encontrado);
      }, onError: (_) => _setStatus(BleConnectionStatus.error));

      // Si el timeout expira sin encontrar nada, refleja "desconectado".
      Future.delayed(const Duration(seconds: 11), () {
        if (_status == BleConnectionStatus.escaneando) {
          _setStatus(BleConnectionStatus.desconectado);
        }
      });
    } catch (_) {
      _setStatus(BleConnectionStatus.error);
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    _setStatus(BleConnectionStatus.conectando);

    await _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _setStatus(BleConnectionStatus.desconectado);
        _limpiarSuscripcionesNotify();
        if (_reconectarAutomaticamente) {
          Future.delayed(const Duration(seconds: 3), () {
            if (_reconectarAutomaticamente) scanAndConnect();
          });
        }
      }
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      await _suscribirCaracteristicas(device);
      _setStatus(BleConnectionStatus.conectado);
    } catch (_) {
      _setStatus(BleConnectionStatus.error);
    }
  }

  Future<void> _suscribirCaracteristicas(BluetoothDevice device) async {
    final servicios = await device.discoverServices();
    final servicio = servicios.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == concertxServiceUuid.toLowerCase(),
      orElse: () => throw Exception('Servicio ConcertX no encontrado'),
    );

    for (final c in servicio.characteristics) {
      final uuid = c.uuid.toString().toLowerCase();
      if (uuid == ritmoCharUuid.toLowerCase()) {
        await _suscribir(c, _onRitmo);
      } else if (uuid == colorCharUuid.toLowerCase()) {
        await _suscribir(c, _onColor);
      } else if (uuid == vibracionCharUuid.toLowerCase()) {
        await _suscribir(c, _onVibracion);
      } else if (uuid == oxigenoCharUuid.toLowerCase()) {
        await _suscribir(c, _onOxigeno);
      }
    }
  }

  Future<void> _suscribir(
    BluetoothCharacteristic c,
    void Function(List<int> value) onData,
  ) async {
    await c.setNotifyValue(true);
    final sub = c.lastValueStream.listen(onData);
    _notifySubs.add(sub);
  }

  void _onRitmo(List<int> bytes) {
    if (bytes.length < 2) return;
    _ultimoRitmo = (bytes[0] << 8) | bytes[1];
    _emitirLectura();
  }

  void _onColor(List<int> bytes) {
    try {
      _ultimoColor = utf8.decode(bytes);
      _emitirLectura();
    } catch (_) {
      // Se ignoran paquetes corruptos.
    }
  }

  void _onVibracion(List<int> bytes) {
    if (bytes.isEmpty) return;
    _ultimaVibracion = bytes[0] == 0x01;
    _emitirLectura();
  }

  void _onOxigeno(List<int> bytes) {
    if (bytes.isEmpty) return;
    _ultimoOxigeno = bytes[0];
    _emitirLectura();
  }

  void _emitirLectura() {
    _dataController.add(WearableData(
      ritmo: _ultimoRitmo,
      oxigeno: _ultimoOxigeno,
      colorHex: _ultimoColor,
      vibracion: _ultimaVibracion,
    ));
  }

  void _limpiarSuscripcionesNotify() {
    for (final s in _notifySubs) {
      s.cancel();
    }
    _notifySubs.clear();
  }

  Future<void> disconnect() async {
    _reconectarAutomaticamente = false;
    _limpiarSuscripcionesNotify();
    await _connectionSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {
      // El dispositivo ya pudo haberse desconectado; se ignora.
    }
    _setStatus(BleConnectionStatus.desconectado);
  }

  void dispose() {
    _reconectarAutomaticamente = false;
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _limpiarSuscripcionesNotify();
    _dataController.close();
    _statusController.close();
  }
}
