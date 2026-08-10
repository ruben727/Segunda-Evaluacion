import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:concertx_wearable/main.dart';

void main() {
  testWidgets('ConcertxWearableApp muestra la esfera del reloj', (WidgetTester tester) async {
    await tester.pumpWidget(const ConcertxWearableApp());
    await tester.pump();

    expect(find.text('CONCERTX'), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });
}
