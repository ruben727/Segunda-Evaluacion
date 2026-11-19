import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/concierto.dart';

/// Widget de pantalla de inicio "Próximo concierto" (solo Android).
///
/// La app guarda aquí los datos del próximo concierto y Android los pinta
/// en `android/app/src/main/kotlin/.../ProximoConciertoWidget.kt`. Al tocar
/// el widget se abre la app con la ruta `concertx://concierto/<id>`.
class WidgetService {
  WidgetService._();

  static const _androidName = 'ProximoConciertoWidget';

  /// Un concierto sigue contando como "próximo" hasta 4 h después de que
  /// empieza (mientras está en curso).
  static const margenEnCurso = Duration(hours: 4);

  static bool get _esAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// El concierto más cercano que no haya terminado, o `null` si no hay.
  static Concierto? elegirProximo(List<Concierto> conciertos, {DateTime? ahora}) {
    final limite = (ahora ?? DateTime.now()).subtract(margenEnCurso);
    final futuros = conciertos.where((c) => c.fechaInicio.isAfter(limite)).toList()
      ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));
    return futuros.isEmpty ? null : futuros.first;
  }

  /// Texto de la segunda línea de detalle: "Sáb 7 nov · 20:00 · Estadio Azteca".
  static String detalle(Concierto c) {
    final fecha = DateFormat("EEE d MMM · HH:mm", 'es_MX').format(c.fechaInicio.toLocal());
    final lugar = c.estadio?.nombre;
    final texto = lugar == null || lugar.isEmpty ? fecha : '$fecha · $lugar';
    return texto[0].toUpperCase() + texto.substring(1);
  }

  /// Guarda el próximo concierto y redibuja el widget. Se llama cada vez
  /// que la app carga la lista de conciertos. Nunca lanza error: si el
  /// widget no está disponible (iOS, web, pruebas) simplemente no hace nada.
  static Future<void> actualizar(List<Concierto> conciertos) async {
    if (!_esAndroid) return;
    final c = elegirProximo(conciertos);
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('pc_id', c?.id),
        HomeWidget.saveWidgetData<String>('pc_artista', c?.artista),
        HomeWidget.saveWidgetData<String>('pc_tour', c?.nombreTour ?? ''),
        HomeWidget.saveWidgetData<String>('pc_detalle', c == null ? null : detalle(c)),
        HomeWidget.saveWidgetData<String>('pc_fecha_ms', c?.fechaInicio.millisecondsSinceEpoch.toString()),
      ]);
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (_) {
      // El widget es un extra: si falla, la app sigue normal.
    }
  }

  /// true si el launcher permite agregar el widget desde la app
  /// (Android 8+ y la mayoría de launchers).
  static Future<bool> puedePedirAgregar() async {
    if (!_esAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Muestra el diálogo del sistema "¿Agregar a la pantalla principal?".
  static Future<void> pedirAgregar() async {
    await HomeWidget.requestPinWidget(androidName: _androidName);
  }

  /// true si el usuario ya tiene el widget en su pantalla principal.
  static Future<bool> yaAgregado() async {
    if (!_esAndroid) return false;
    try {
      final instalados = await HomeWidget.getInstalledWidgets();
      return instalados.any((w) => w.androidClassName?.endsWith(_androidName) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Convierte el enlace del widget en una ruta de la app.
  /// `concertx://concierto/6` → `/conciertos/6`.
  static String? rutaDesdeUri(Uri? uri) {
    if (uri == null || uri.scheme != 'concertx') return null;
    if (uri.host == 'concierto' && uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.first;
      if (int.tryParse(id) != null) return '/conciertos/$id';
    }
    return null;
  }

  /// Ruta pendiente cuando la app se ABRIÓ desde el widget: el splash la
  /// toma al terminar (ver splash_screen.dart).
  static String? _rutaPendiente;

  static Future<void> revisarAperturaDesdeWidget() async {
    if (!_esAndroid) return;
    try {
      _rutaPendiente = rutaDesdeUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {}
  }

  static String? tomarRutaPendiente() {
    final ruta = _rutaPendiente;
    _rutaPendiente = null;
    return ruta;
  }

  /// Toques en el widget con la app ya abierta (en segundo plano).
  static Stream<String> get toques => _esAndroid
      ? HomeWidget.widgetClicked.map(rutaDesdeUri).where((r) => r != null).cast<String>()
      : const Stream.empty();
}
