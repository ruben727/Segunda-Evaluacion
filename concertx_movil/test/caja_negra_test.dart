// Práctica 8 — Pruebas de caja negra de la app (REQ-01 a REQ-12).
//
// Cada prueba solo usa entradas y salidas públicas (validadores, provider,
// pantallas) y compara contra el criterio de aceptación de su nombre. El
// backend se sustituye por [ApiFalsa], que responde con los mismos códigos
// HTTP que la API real (201/400/403/500). Las reglas del SERVIDOR se prueban
// aparte contra la API real: backend/pruebas/incidencias_seguridad.js.
//
// Matriz: docs/matriz_pruebas.md

import 'package:concertx_movil/core/models/incidencia.dart';
import 'package:concertx_movil/core/providers/incidencia_provider.dart';
import 'package:concertx_movil/core/services/api_service.dart';
import 'package:concertx_movil/core/utils/validadores.dart';
import 'package:concertx_movil/features/incidencias/screens/reportar_incidencia_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Backend simulado en memoria con las mismas reglas de roles que la API.
class ApiFalsa extends ApiService {
  final List<Map<String, dynamic>> _bd = [];
  String usuarioId = '1';
  String rol = 'usuario';
  bool fallarRed = false;
  int llamadasCrear = 0;
  int _siguienteId = 1;

  bool get _staff => rol == 'agente' || rol == 'admin';

  void _comprobarRed() {
    if (fallarRed) throw const ApiException(500, 'error: relation "incidencias" violates constraint');
  }

  @override
  Future<Incidencia> crearIncidencia({
    required String tipo,
    required String equipo,
    required String prioridad,
  }) async {
    llamadasCrear++;
    _comprobarRed();
    final fila = {
      'id': _siguienteId++,
      'tipo': tipo,
      'equipo': equipo,
      'prioridad': prioridad,
      'estado': 'Pendiente',
      'creado_por': usuarioId,
      'agente_asignado': null,
      'fecha': DateTime.utc(2026, 11, 5, 18).toIso8601String(),
    };
    _bd.add(fila);
    return Incidencia.fromJson(fila);
  }

  @override
  Future<List<Incidencia>> getMisIncidencias() async {
    _comprobarRed();
    return _bd.where((f) => f['creado_por'] == usuarioId).map(Incidencia.fromJson).toList();
  }

  @override
  Future<List<Incidencia>> getTodasIncidencias() async {
    _comprobarRed();
    if (!_staff) throw const ApiException(403, 'No tienes permisos para esta acción');
    return _bd.map(Incidencia.fromJson).toList();
  }

  @override
  Future<List<Agente>> getAgentes() async {
    if (!_staff) throw const ApiException(403, 'No tienes permisos para esta acción');
    return const [Agente(id: '9', nombre: 'Agente Uno', rol: 'agente')];
  }

  @override
  Future<Incidencia> actualizarIncidencia(
    String id, {
    String? estado,
    String? agenteId,
    bool quitarAgente = false,
    String? prioridad,
  }) async {
    _comprobarRed();
    final fila = _bd.firstWhere((f) => f['id'].toString() == id);
    final propia = fila['creado_por'] == usuarioId;
    if (!propia && !_staff) throw const ApiException(403, 'No tienes permisos para esta acción');
    if (!_staff && (estado != null || agenteId != null || quitarAgente)) {
      throw const ApiException(403, 'No tienes permisos para esta acción');
    }
    if (estado != null) fila['estado'] = estado;
    if (prioridad != null) fila['prioridad'] = prioridad;
    if (agenteId != null) fila['agente_asignado'] = agenteId;
    if (quitarAgente) fila['agente_asignado'] = null;
    return Incidencia.fromJson(fila);
  }

  @override
  Future<int> limpiarIncidencias() async {
    if (rol != 'admin') throw const ApiException(403, 'No tienes permisos para esta acción');
    final n = _bd.length;
    _bd.clear();
    return n;
  }

  /// Simula cambiar de sesión (otro usuario en el mismo backend).
  void iniciarSesionComo(String id, String nuevoRol) {
    usuarioId = id;
    rol = nuevoRol;
  }
}

void main() {
  late ApiFalsa api;
  late IncidenciaProvider provider;

  setUp(() {
    api = ApiFalsa();
    provider = IncidenciaProvider(apiService: api);
  });

  Future<void> reportarValida({String prioridad = 'Alta'}) async {
    final error = await provider.reportar(tipo: 'Falla de equipo', equipo: 'Smartwatch', prioridad: prioridad);
    expect(error, isNull);
  }

  group('Operaciones principales', () {
    test('REQ-01 Reportar con las tres opciones guarda la incidencia en estado Pendiente', () async {
      await reportarValida();

      expect(provider.misIncidencias, hasLength(1));
      final i = provider.misIncidencias.first;
      expect(i.estado, 'Pendiente');
      expect(i.creadoPor, '1');
      expect([i.tipo, i.equipo, i.prioridad], ['Falla de equipo', 'Smartwatch', 'Alta']);
    });

    test('REQ-02 "Mis incidencias" muestra solo las del usuario autenticado', () async {
      await reportarValida(); // usuario 1
      api.iniciarSesionComo('2', 'usuario');
      await provider.reportar(tipo: 'Otro', equipo: 'Teléfono', prioridad: 'Baja');

      await provider.cargarMias();

      expect(provider.misIncidencias, hasLength(1));
      expect(provider.misIncidencias.every((i) => i.creadoPor == '2'), isTrue);
    });

    test('REQ-03 El administrador cambia el estado a "En proceso" y luego a "Resuelto"', () async {
      await reportarValida();
      api.iniciarSesionComo('5', 'admin');
      await provider.cargarTodas();
      final id = provider.todas.first.id;

      expect(await provider.cambiarEstado(id, 'En proceso'), isNull);
      expect(provider.todas.first.estado, 'En proceso');
      expect(await provider.cambiarEstado(id, 'Resuelto'), isNull);
      expect(provider.todas.first.estado, 'Resuelto');
    });

    test('REQ-04 El agente asigna un agente a la incidencia y puede quitarlo', () async {
      await reportarValida();
      api.iniciarSesionComo('9', 'agente');
      await provider.cargarTodas();
      final id = provider.todas.first.id;

      expect(await provider.asignarAgente(id, '9'), isNull);
      expect(provider.todas.first.agenteAsignado, '9');
      expect(await provider.asignarAgente(id, null), isNull);
      expect(provider.todas.first.agenteAsignado, isNull);
    });
  });

  group('Validaciones', () {
    testWidgets('REQ-05 Sin elegir todas las opciones no se guarda y se avisa; no hay campo de texto libre',
        (tester) async {
      await tester.pumpWidget(ChangeNotifierProvider<IncidenciaProvider>.value(
        value: provider,
        child: const MaterialApp(home: ReportarIncidenciaScreen()),
      ));

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byKey(const Key('opcion_Acceso perdido')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('guardar_incidencia')));
      await tester.tap(find.byKey(const Key('guardar_incidencia')));
      await tester.pump();

      expect(find.text('Selecciona: equipo, prioridad'), findsOneWidget);
      expect(api.llamadasCrear, 0);

      await tester.ensureVisible(find.byKey(const Key('opcion_Pantalla TV')));
      await tester.tap(find.byKey(const Key('opcion_Pantalla TV')));
      await tester.ensureVisible(find.byKey(const Key('opcion_Media')));
      await tester.tap(find.byKey(const Key('opcion_Media')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('guardar_incidencia')));
      await tester.tap(find.byKey(const Key('guardar_incidencia')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(api.llamadasCrear, 1);
      expect(find.textContaining('Incidencia registrada'), findsOneWidget);
    });

    test('REQ-06 La contraseña con menos de 8 o más de 64 caracteres se rechaza', () {
      expect(Validadores.passwordLongitud('Abc1234'), 'Mínimo 8 caracteres');
      expect(Validadores.passwordLongitud('A1${'a' * 63}'), 'Máximo 64 caracteres');
      expect(Validadores.passwordLongitud('Abc12345'), isNull);
      expect(Validadores.passwordLongitud('A1${'a' * 62}'), isNull); // 64 exactos
      expect(Validadores.passwordRegistro('abcdefgh'), 'Debe incluir una mayúscula y un número');
      expect(Validadores.passwordRegistro('Segura123'), isNull);
    });

    test('REQ-07 Los campos con solo espacios se tratan como vacíos', () {
      expect(Validadores.email('     '), 'Ingresa tu correo');
      expect(Validadores.passwordLongitud('          '), 'Ingresa tu contraseña');
      expect(Validadores.nombre('    '), 'Ingresa tu nombre completo');
      expect(Validadores.email('  ana@test.com  '), isNull);
    });
  });

  group('Persistencia y consistencia', () {
    test('REQ-08 Una incidencia guardada se recupera idéntica al recargar', () async {
      await reportarValida(prioridad: 'Media');
      final guardada = provider.misIncidencias.first;

      final otraSesion = IncidenciaProvider(apiService: api);
      await otraSesion.cargarMias();
      final recargada = otraSesion.misIncidencias.single;

      expect(recargada.toJson(), guardada.toJson());
      expect(Incidencia.fromJson(recargada.toJson()).toJson(), recargada.toJson());
    });

    test('REQ-09 El contador por estado coincide con la lista después de cambiar estados', () async {
      for (var n = 0; n < 3; n++) {
        await reportarValida();
      }
      api.iniciarSesionComo('5', 'admin');
      await provider.cargarTodas();
      await provider.cambiarEstado(provider.todas[0].id, 'En proceso');
      await provider.cambiarEstado(provider.todas[1].id, 'Resuelto');

      expect(provider.conteoTodas, {'Pendiente': 1, 'En proceso': 1, 'Resuelto': 1});
      final suma = provider.conteoTodas.values.reduce((a, b) => a + b);
      expect(suma, provider.todas.length);
    });
  });

  group('Roles y permisos', () {
    test('REQ-10 Un usuario normal no puede ver todas ni cambiar el estado (mensaje de permisos)', () async {
      await reportarValida();

      await provider.cargarTodas();
      expect(provider.todas, isEmpty);
      expect(provider.errorMessage, IncidenciaProvider.mensajeSinPermiso);

      final error = await provider.cambiarEstado(provider.misIncidencias.first.id, 'Resuelto');
      expect(error, IncidenciaProvider.mensajeSinPermiso);
      await provider.cargarMias();
      expect(provider.misIncidencias.first.estado, 'Pendiente');
    });

    test('REQ-11 Solo el administrador puede limpiar el historial (el agente es rechazado)', () async {
      await reportarValida();
      api.iniciarSesionComo('9', 'agente');
      await provider.cargarTodas();

      expect(await provider.limpiarHistorial(), IncidenciaProvider.mensajeSinPermiso);
      expect(provider.todas, hasLength(1));

      api.iniciarSesionComo('5', 'admin');
      expect(await provider.limpiarHistorial(), isNull);
      await provider.cargarTodas();
      expect(provider.todas, isEmpty);
    });
  });

  group('Manejo de errores', () {
    test('REQ-12 Un error del servidor muestra un mensaje genérico sin texto técnico', () async {
      api.fallarRed = true;

      final error = await provider.reportar(tipo: 'Otro', equipo: 'Otro', prioridad: 'Baja');
      await provider.cargarMias();

      expect(error, IncidenciaProvider.mensajeErrorGenerico);
      expect(provider.errorMessage, IncidenciaProvider.mensajeErrorGenerico);
      expect(error, isNot(contains('relation')));
      expect(provider.misIncidencias, isEmpty);
      expect(provider.isGuardando, isFalse);
    });
  });
}
