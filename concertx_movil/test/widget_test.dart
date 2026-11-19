import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:concertx_movil/app.dart';

void main() {
  testWidgets('ConcertxApp arranca en la pantalla splash', (WidgetTester tester) async {
    // Sin token guardado: el splash debe mandar a /login tras 2 s.
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ConcertxApp());
    await tester.pump();

    expect(find.text('ConcertX'), findsOneWidget);
    expect(find.text('Sé parte del espectáculo'), findsOneWidget);

    // Deja correr el temporizador del splash para que no quede pendiente
    // al terminar la prueba (antes el test fallaba por eso).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
  });
}
