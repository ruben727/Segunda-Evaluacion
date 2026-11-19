// Regresiones de errores reportados en la app.
import 'dart:async';

import 'package:concertx_movil/app.dart';
import 'package:concertx_movil/core/providers/auth_provider.dart';
import 'package:concertx_movil/core/providers/reproductor_provider.dart';
import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/services/sync_service.dart';
import 'package:concertx_movil/features/auth/screens/splash_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// API cuyo aviso al reloj nunca responde (red lenta) o falla.
class ApiLenta extends ApiService {
  bool fallar = false;
  final _nunca = Completer<void>();

  @override
  Future<void> enviarComandoWearable({required String colorHex, required int duracionSeg, String? cancionTitulo}) =>
      fallar ? Future.error(Exception('sin red')) : _nunca.future;

  @override
  Future<void> detenerComandoWearable() async {}
}

/// Sin WebSocket real en las pruebas.
class SyncFalso extends SyncService {
  @override
  Future<void> conectar() async {}
}

void main() {
  testWidgets('REG-01 Un cambio en la sesión NO recrea el router (ir a Perfil no regresa a Inicio)', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const ConcertxApp());
    await tester.pump();

    final elemento = tester.element(find.byType(SplashScreen));
    final routerAntes = GoRouter.of(elemento);

    // Lo mismo que hace Perfil al llamar refrescarPerfil(): notifica cambios.
    Provider.of<AuthProvider>(elemento, listen: false).notifyListeners();
    await tester.pump();

    final routerDespues = GoRouter.of(tester.element(find.byType(SplashScreen)));
    expect(identical(routerAntes, routerDespues), isTrue);

    await tester.pump(const Duration(seconds: 3)); // deja terminar el splash
    await tester.pumpAndSettle();
  });

  test('REG-02 La canción arranca al instante aunque el aviso al reloj no responda', () async {
    final r = ReproductorProvider(apiService: ApiLenta(), syncService: SyncFalso());

    // Sin await a la red: reproducir() debe completar y dejar todo listo.
    await r.reproducir(cancionId: '1', titulo: 'Tu Gloria', colorHex: '#EF4444', duracionSeg: 200, artista: 'Monte Santo');

    expect(r.reproduciendo, isTrue);
    expect(r.tituloActual, 'Tu Gloria');
    expect(r.tiempoRestanteFormateado, '03:20');
    await r.detener();
    expect(r.reproduciendo, isFalse);
    r.dispose();
  });

  test('REG-03 Si el aviso al reloj falla, la canción sigue sonando en el teléfono', () async {
    final r = ReproductorProvider(apiService: ApiLenta()..fallar = true, syncService: SyncFalso());

    await r.reproducir(cancionId: '2', titulo: 'Presencia', colorHex: '#3B82F6', duracionSeg: 190);
    await Future<void>.delayed(Duration.zero); // deja fallar el aviso en segundo plano

    expect(r.reproduciendo, isTrue);
    expect(r.cancionId, '2');
    await r.detener();
    r.dispose();
  });
}
