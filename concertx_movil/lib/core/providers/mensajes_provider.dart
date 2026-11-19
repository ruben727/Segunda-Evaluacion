import 'package:flutter/foundation.dart';

/// Mensaje enviado entre los dos dispositivos simulados (Práctica 6).
class MensajeDispositivo {
  final String emisor; // 'A' o 'B'
  final String texto;
  final DateTime hora;

  const MensajeDispositivo({required this.emisor, required this.texto, required this.hora});

  String get receptor => emisor == 'A' ? 'B' : 'A';
}

/// Historial en memoria de mensajes entre el Dispositivo A y el B. Es una
/// simulación local dentro de la app: no usa red ni BLE.
class MensajesProvider extends ChangeNotifier {
  static const dispositivos = ['A', 'B'];
  static const longitudMaxima = 200;

  final List<MensajeDispositivo> _mensajes = [];

  List<MensajeDispositivo> get mensajes => List.unmodifiable(_mensajes);

  /// Cantidad de mensajes enviados por cada dispositivo.
  Map<String, int> get conteoPorDispositivo => {
        for (final d in dispositivos) d: _mensajes.where((m) => m.emisor == d).length,
      };

  /// Devuelve `null` si se envió, o el mensaje de error. No permite
  /// mensajes vacíos ni de solo espacios.
  String? enviar(String emisor, String texto, {DateTime? hora}) {
    if (!dispositivos.contains(emisor)) return 'Selecciona el dispositivo emisor';
    final limpio = texto.trim();
    if (limpio.isEmpty) return 'Escribe un mensaje antes de enviar';
    if (limpio.length > longitudMaxima) return 'Máximo $longitudMaxima caracteres';
    _mensajes.add(MensajeDispositivo(emisor: emisor, texto: limpio, hora: hora ?? DateTime.now()));
    notifyListeners();
    return null;
  }

  void limpiarHistorial() {
    _mensajes.clear();
    notifyListeners();
  }
}
