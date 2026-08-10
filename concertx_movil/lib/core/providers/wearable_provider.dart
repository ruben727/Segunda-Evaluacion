import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/ble_constants.dart';
import '../models/wearable_data.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../services/sync_service.dart';

enum WearableBleStatus { desconectado, escaneando, conectado, error }

class WearableProvider extends ChangeNotifier {
  final BleService _bleService;
  final ApiService _apiService;
  final SyncService _syncService;

  WearableProvider({BleService? bleService, ApiService? apiService, SyncService? syncService})
      : _bleService = bleService ?? BleService(),
        _apiService = apiService ?? ApiService(),
        _syncService = syncService ?? SyncService() {
    _dataSub = _bleService.dataStream.listen(_onBleData);
    _statusSub = _bleService.statusStream.listen(_onStatus);
  }

  String? _ultimoColorEnviado;

  WearableBleStatus bleStatus = WearableBleStatus.desconectado;
  WearableData? currentData;
  final List<WearableData> dataHistory = [];
  bool isAlertActive = false;

  StreamSubscription? _dataSub;
  StreamSubscription? _statusSub;
  Timer? _pollTimer;
  DateTime? _ultimoDatoHttp;

  static const _maxHistorial = 60;
  static const _intervaloPolling = Duration(milliseconds: 1200);
  static const _ventanaFrescoHttp = Duration(seconds: 5);

  void _onBleData(WearableData data) => _registrarLectura(data);

  void _registrarLectura(WearableData data, {bool viaHttp = false}) {
    currentData = data;
    dataHistory.add(data);
    if (dataHistory.length > _maxHistorial) {
      dataHistory.removeAt(0);
    }
    isAlertActive = data.ritmo > umbralBpmAlerta;
    if (viaHttp) {
      _ultimoDatoHttp = DateTime.now();
      bleStatus = WearableBleStatus.conectado;
    }
    // Reenvía el efecto a Concertx TV solo cuando el color realmente
    // cambia (evita saturar el WebSocket con el mismo dato cada tick).
    if (data.colorHex != _ultimoColorEnviado) {
      _ultimoColorEnviado = data.colorHex;
      _syncService.enviarEfecto(data.colorHex);
    }
    notifyListeners();
  }

  bool get _puenteHttpActivo =>
      _ultimoDatoHttp != null && DateTime.now().difference(_ultimoDatoHttp!) < _ventanaFrescoHttp;

  void _onStatus(BleConnectionStatus status) {
    // Si el puente HTTP tiene datos frescos del reloj (emuladores sin BLE
    // real entre sí), no lo pisamos con el estado "desconectado" del BLE
    // real que sigue intentando conectar en paralelo.
    if (_puenteHttpActivo && status != BleConnectionStatus.conectado) {
      return;
    }

    switch (status) {
      case BleConnectionStatus.escaneando:
      case BleConnectionStatus.conectando:
        bleStatus = WearableBleStatus.escaneando;
        break;
      case BleConnectionStatus.conectado:
        bleStatus = WearableBleStatus.conectado;
        break;
      case BleConnectionStatus.error:
        bleStatus = WearableBleStatus.error;
        break;
      case BleConnectionStatus.desconectado:
        bleStatus = WearableBleStatus.desconectado;
        break;
    }
    notifyListeners();
  }

  Future<void> startScan() async {
    // BLE real: best-effort. En un emulador de Android no hay radio
    // Bluetooth real entre dos AVDs, así que esto puede quedarse
    // "escaneando" indefinidamente sin encontrar nada — no es un error.
    unawaited(_bleService.scanAndConnect());
    unawaited(_syncService.conectar());
    _iniciarPolling();
  }

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_intervaloPolling, (_) => _consultarSimulacion());
    _consultarSimulacion();
  }

  Future<void> _consultarSimulacion() async {
    try {
      final data = await _apiService.getWearableSimulacion();
      if (data == null) return;
      _registrarLectura(
        WearableData(
          ritmo: (data['ritmo'] as num).toInt(),
          oxigeno: (data['oxigeno'] as num?)?.toInt() ?? 98,
          colorHex: data['efecto_color'] as String,
          vibracion: data['vibracion'] as bool? ?? false,
        ),
        viaHttp: true,
      );
    } catch (_) {
      // Backend no disponible: se ignora, se reintenta en el próximo tick.
    }
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _ultimoDatoHttp = null;
    await _bleService.disconnect();
    bleStatus = WearableBleStatus.desconectado;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dataSub?.cancel();
    _statusSub?.cancel();
    _bleService.dispose();
    // _syncService NO se cierra aquí: es una instancia compartida con
    // ReproductorProvider (ver app.dart), la cierra su propio Provider.
    super.dispose();
  }
}
