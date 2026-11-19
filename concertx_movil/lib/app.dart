import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/models/concierto.dart';
import 'core/models/diseno.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/concierto_provider.dart';
import 'core/providers/diseno_provider.dart';
import 'core/providers/incidencia_provider.dart';
import 'core/providers/mensajes_provider.dart';
import 'core/providers/busqueda_provider.dart';
import 'core/providers/reproductor_provider.dart';
import 'core/providers/wearable_provider.dart';
import 'core/services/api_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/widget_service.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/concerts/screens/concerts_screen.dart';
import 'features/concerts/screens/concert_detail_screen.dart';
import 'features/design/screens/create_design_screen.dart';
import 'features/design/screens/design_code_screen.dart';
import 'features/concerts/screens/reproductor_screen.dart';
import 'features/join/screens/join_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/wearable/screens/wearable_monitor_screen.dart';
import 'features/incidencias/screens/reportar_incidencia_screen.dart';
import 'features/incidencias/screens/mis_incidencias_screen.dart';
import 'features/incidencias/screens/gestion_incidencias_screen.dart';
import 'features/mensajes/screens/mensajes_screen.dart';
import 'features/search/screens/buscar_screen.dart';

/// Rutas que exigen sesión iniciada. Si no hay token guardado, el
/// AuthGuard (ver [_router] -> redirect) manda al usuario a /login.
const _rutasProtegidas = [
  '/home',
  '/conciertos',
  '/crear-diseno',
  '/codigo-diseno',
  '/reproducir',
  '/unirse',
  '/perfil',
  '/wearable',
  '/incidencias',
  '/mensajes',
  '/buscar',
];

class ConcertxApp extends StatelessWidget {
  const ConcertxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final auth = AuthProvider()..cargarSesion();
          // Cualquier 401 de la API con token cierra la sesión y lleva al login.
          ApiService.onSesionExpirada = auth.sesionExpirada;
          return auth;
        }),
        ChangeNotifierProvider(create: (_) => ConciertoProvider()),
        ChangeNotifierProvider(create: (_) => DisenoProvider()),
        ChangeNotifierProvider(create: (_) => IncidenciaProvider()),
        ChangeNotifierProvider(create: (_) => MensajesProvider()),
        ChangeNotifierProvider(create: (_) => BusquedaProvider()),
        // Un solo WebSocket compartido hacia Concertx TV: tanto el color
        // del reloj (WearableProvider) como la canción activa
        // (ReproductorProvider) se avisan por el mismo socket.
        Provider<SyncService>(
          create: (_) => SyncService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider(create: (context) => WearableProvider(syncService: context.read<SyncService>())),
        ChangeNotifierProvider(create: (context) => ReproductorProvider(syncService: context.read<SyncService>())),
      ],
      child: const _AppConRouter(),
    );
  }
}

/// Crea el GoRouter UNA sola vez. Antes se creaba uno nuevo en cada cambio
/// del AuthProvider (context.watch), y como arranca en '/', cualquier
/// notifyListeners (p. ej. refrescar el perfil) mandaba de vuelta al splash
/// y de ahí a Inicio. Los cambios de sesión los atiende `refreshListenable`.
class _AppConRouter extends StatefulWidget {
  const _AppConRouter();

  @override
  State<_AppConRouter> createState() => _AppConRouterState();
}

class _AppConRouterState extends State<_AppConRouter> {
  late final GoRouter _router = _buildRouter(context.read<AuthProvider>());
  StreamSubscription<String>? _toquesWidget;

  @override
  void initState() {
    super.initState();
    // Toque en el widget "Próximo concierto" con la app ya abierta. Si no
    // hay sesión, el redirect del router manda primero a /login.
    _toquesWidget = WidgetService.toques.listen((ruta) => _router.push(ruta));
  }

  @override
  void dispose() {
    _toquesWidget?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ConcertX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
    );
  }

  GoRouter _buildRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        // Respaldo: si un enlace del widget (concertx://concierto/6) llega
        // al router, se traduce a su ruta en vez de "Page Not Found".
        if (state.uri.scheme == 'concertx') {
          return WidgetService.rutaDesdeUri(state.uri) ?? '/home';
        }

        // Mientras se revisa el token guardado, no redirigir todavía.
        if (authProvider.isLoading) return null;

        final protegida = _rutasProtegidas.any((r) => state.matchedLocation.startsWith(r));
        final enAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';

        if (protegida && !authProvider.isLoggedIn) return '/login';
        if (enAuth && authProvider.isLoggedIn) return '/home';
        // El panel de gestión solo se muestra a agente/admin. Es solo de
        // interfaz: el backend vuelve a validar el rol en cada petición.
        if (state.matchedLocation == '/incidencias/gestion' &&
            !(authProvider.currentUser?.esStaff ?? false)) {
          return '/perfil';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/conciertos', builder: (context, state) => const ConcertsScreen()),
        GoRoute(
          path: '/conciertos/:id',
          builder: (context, state) => ConcertDetailScreen(conciertoId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/crear-diseno/:concertId',
          builder: (context, state) =>
              CreateDesignScreen(concertId: state.pathParameters['concertId']!),
        ),
        GoRoute(
          path: '/codigo-diseno',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return DesignCodeScreen(
              diseno: extra?['diseno'] as Diseno,
              concierto: extra?['concierto'] as Concierto?,
            );
          },
        ),
        GoRoute(
          path: '/reproducir/:codigo',
          builder: (context, state) => ReproductorScreen(
            codigo: state.pathParameters['codigo']!,
            artista: (state.extra as String?) ?? 'Concierto',
          ),
        ),
        GoRoute(path: '/unirse', builder: (context, state) => const JoinScreen()),
        GoRoute(path: '/perfil', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: '/wearable', builder: (context, state) => const WearableMonitorScreen()),
        GoRoute(
          path: '/incidencias/reportar',
          builder: (context, state) => const ReportarIncidenciaScreen(),
        ),
        GoRoute(path: '/incidencias/mias', builder: (context, state) => const MisIncidenciasScreen()),
        GoRoute(path: '/mensajes', builder: (context, state) => const MensajesScreen()),
        GoRoute(path: '/buscar', builder: (context, state) => const BuscarScreen()),
        GoRoute(
          path: '/incidencias/gestion',
          builder: (context, state) => const GestionIncidenciasScreen(),
        ),
      ],
    );
  }
}
