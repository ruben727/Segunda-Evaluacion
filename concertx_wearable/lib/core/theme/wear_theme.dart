import 'package:flutter/material.dart';

/// Poppins se empaqueta como fuente local (assets/fonts) en vez de usar
/// google_fonts, que la descarga de la red en tiempo de ejecución.
const String poppinsFamily = 'Poppins';

/// Colores y estilos del reloj, adaptados a una pantalla circular de 384x384.
class WearColors {
  WearColors._();

  static const darkNavy = Color(0xFF0D1F3C);
  static const navyMid = Color(0xFF1B3A6B);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF7C3AED);
  static const red = Color(0xFFEF4444);
  static const cyan = Color(0xFF06B6D4);
  static const orange = Color(0xFFF59E0B);
  static const white = Color(0xFFFFFFFF);

  /// Convierte un color en formato "#RRGGBB" al tipo [Color] de Flutter.
  static Color fromHex(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  }
}

ThemeData buildWearTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: WearColors.darkNavy,
    textTheme: base.textTheme.apply(
      fontFamily: poppinsFamily,
      bodyColor: WearColors.white,
      displayColor: WearColors.white,
    ),
  );
}
