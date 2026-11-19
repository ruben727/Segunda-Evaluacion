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

  /// Único artista cuyo diseño puede cambiarle el color a Concertx TV
  /// (concierto de prueba fijo de la Smart TV, ver db_concertx.sql). Los
  /// demás diseños (Bad Bunny, Karol G, Funky, etc.) siguen funcionando
  /// normal en el teléfono y en el reloj, pero no le mandan nada a la TV.
  static const String artistaAutorizadoTV = 'Evan Craft';

  String? _artistaActivo;

  /// El [ReproductorProvider] llama esto al iniciar/detener una canción
  /// para marcar qué artista está sonando ahora mismo (`null` = nada).
  /// Mientras no coincida con [artistaAutorizadoTV], `enviarEfecto` y
  /// `enviarCancion` no le mandan nada a la TV.
  void setArtistaActivo(String? artista) {
    _artistaActivo = artista;
  }

  bool get _autorizadoParaTV =>
      _artistaActivo != null &&
      _artistaActivo!.trim().toLowerCase() == artistaAutorizadoTV.toLowerCase();

  Future<void> conectar() async {
    if (_conectado) return; // ya conectado (instancia compartida) — no abrir otro socket
    _reconectar = true;
    await _abrirSocket();
  }

  Future<void> _abrirSocket() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConstants.wsUrl));
      // Sin límite, si la TV/backend local no está encendido esto podía
      // quedarse esperando mucho tiempo.
      await _channel!.ready.timeout(const Duration(seconds: 3));
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
  ///
  /// Siempre actualiza [efectoStream] (para la propia UI del teléfono),
  /// pero solo se lo manda a la TV si el diseño activo es el de
  /// [artistaAutorizadoTV] — ver [setArtistaActivo].
  void enviarEfecto(String colorHex, {String? nombre}) {
    final nombreFinal = nombre ?? _nombresColor[colorHex.toUpperCase()] ?? colorHex;
    _efectoController.add(colorHex);
    if (!_autorizadoParaTV) return;
    _enviar({'type': 'effect_update', 'color': colorHex, 'nombre': nombreFinal});
  }

  /// Igual que [enviarEfecto]: solo llega a la TV si el diseño activo es
  /// el de [artistaAutorizadoTV].
  void enviarCancion(String titulo, String artista, int duracionSeg) {
    if (!_autorizadoParaTV) return;
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
