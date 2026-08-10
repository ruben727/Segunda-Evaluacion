import 'package:flutter/material.dart';
import 'core/theme/wear_theme.dart';
import 'features/sync/screens/watch_face_screen.dart';

void main() {
  runApp(const ConcertxWearableApp());
}

class ConcertxWearableApp extends StatelessWidget {
  const ConcertxWearableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConcertX Wearable',
      debugShowCheckedModeBanner: false,
      theme: buildWearTheme(),
      home: const WatchFaceScreen(),
    );
  }
}
