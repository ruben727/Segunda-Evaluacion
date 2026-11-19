// Práctica 6 — Mensajes entre dispositivos simulados (MSG-01 a MSG-04).
import 'package:concertx_movil/core/providers/mensajes_provider.dart';
import 'package:concertx_movil/features/mensajes/screens/mensajes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('MSG-01 No se permite enviar un mensaje vacío o de solo espacios', () {
    final p = MensajesProvider();
    expect(p.enviar('A', ''), isNotNull);
    expect(p.enviar('A', '    '), isNotNull);
    expect(p.mensajes, isEmpty);
  });

  test('MSG-02 El contador por dispositivo cuenta los mensajes de cada emisor', () {
    final p = MensajesProvider();
    p.enviar('A', 'hola');
    p.enviar('A', '¿me escuchas?');
    p.enviar('B', 'sí');
    expect(p.conteoPorDispositivo, {'A': 2, 'B': 1});
    expect(p.mensajes.last.receptor, 'A');
  });

  test('MSG-03 Limpiar historial deja la lista y los contadores en cero', () {
    final p = MensajesProvider()..enviar('A', 'x')..enviar('B', 'y');
    p.limpiarHistorial();
    expect(p.mensajes, isEmpty);
    expect(p.conteoPorDispositivo, {'A': 0, 'B': 0});
  });

  testWidgets('MSG-04 Enviar desde B muestra el mensaje con emisor, hora y un SnackBar', (tester) async {
    final p = MensajesProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: p,
      child: const MaterialApp(home: MensajesScreen()),
    ));

    await tester.tap(find.text('Dispositivo B').last);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('campo_mensaje')), 'Prueba desde B');
    await tester.tap(find.byKey(const Key('enviar_mensaje')));
    await tester.pump();

    expect(find.text('Prueba desde B'), findsOneWidget);
    expect(find.text('Dispositivo B → A'), findsOneWidget);
    expect(find.text('Dispositivo B → Dispositivo A: mensaje enviado'), findsOneWidget);
    expect(p.conteoPorDispositivo['B'], 1);
  });
}
