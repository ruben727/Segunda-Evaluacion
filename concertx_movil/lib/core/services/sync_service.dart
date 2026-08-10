import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

const Map<String, String> _nombresColor = {
  '#3B82F6': 'Azul',
  '#7C3AED': 'Morado',
  '#EF4444': 'Rojo',
  '#06B6D4': 'Cian',
  '#FACC15': 'Amarillo',
  '#F59E0B': 'Naranja',
};

/// Conecta el teléfono al mismo backend (WebSocket) que usa Concertx TV,
/// para que la pantalla del recinto se actualice sola cuando cambia el
/// efecto/canción activo — sin que nadie tenga que tocar la TV.
///
/// También expone [efectoStream] para reflejar el efecto activo en la
/// propia UI del teléfono si hace falta.
class SyncService {
  final _efectoController = StreamController<String>.broadcast();
  Stream<String> get efectoStream => _efectoController.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _reconectar = true;
  bool _conectado = false;
  bool get conectado => _conectado;

  Future<void> conectar() async {
    if (_conectado) return; // ya conectado (instancia compartida) — no abrir otro socket
    _reconectar = true;
    await _abrirSocket();
  }

  Future<void> _abrirSocket() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConstants.wsUrl));
      await _channel!.ready;
      _conectado = true;
      _channel!.sink.add(jsonEncode({'type': 'phone_connect'}));

      _sub = _channel!.stream.listen(
        (mensaje) {
          // El teléfono no necesita reaccionar a nada que le mande el
          // servidor por ahora; solo publica cambios.
        },
        onDone: _onDesconectado,
        onError: (_) => _onDesconectado(),
      );
    } catch (_) {
      _onDesconectado();
    }
  }

  void _onDesconectado() {
    _conectado = false;
    if (!_reconectar) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (_reconectar) _abrirSocket();
    });
  }

  void _enviar(Map<String, dynamic> mensaje) {
    if (!_conectado || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(mensaje));
    } catch (_) {
      // Conexión perdida justo al enviar: se ignora, el auto-reconnect
      // ya está en marcha.
    }
  }

  /// Avisa a la TV que el efecto de luces activo cambió (color hex, ej.
  /// "#3B82F6"). Se usa cuando llega un dato nuevo del reloj (BLE/HTTP).
  void enviarEfecto(String colorHex, {String? nombre}) {
    final nombreFinal = nombre ?? _nombresColor[colorHex.toUpperCase()] ?? colorHex;
    _efectoController.add(colorHex);
    _enviar({'type': 'effect_update', 'color': colorHex, 'nombre': nombreFinal});
  }

  void enviarCancion(String titulo, String artista, int duracionSeg) {
    _enviar({
      'type': 'song_update',
      'titulo': titulo,
      'artista': artista,
      'duracion': duracionSeg,
    });
  }

  void enviarUsuarios(int total) {
    _enviar({'type': 'users_update', 'total': total});
  }

  void desconectar() {
    _reconectar = false;
    _sub?.cancel();
    _channel?.sink.close();
    _conectado = false;
  }

  void dispose() {
    desconectar();
    _efectoController.close();
  }
}
