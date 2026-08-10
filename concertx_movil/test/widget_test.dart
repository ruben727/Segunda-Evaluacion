import 'package:flutter_test/flutter_test.dart';

import 'package:concertx_movil/app.dart';

void main() {
  testWidgets('ConcertxApp arranca en la pantalla splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ConcertxApp());
    await tester.pump();

    expect(find.text('ConcertX'), findsOneWidget);
    expect(find.text('Sé parte del espectáculo'), findsOneWidget);
  });
}
