import 'package:flutter/material.dart';

/// Poppins se empaqueta como fuente local (assets/fonts) en vez de usar
/// el paquete google_fonts, que la descarga de la red en tiempo de
/// ejecución y puede hacer que la app tarde en mostrar texto la primera
/// vez (sobre todo en el emulador, con red lenta o inestable).
const String _poppins = 'Poppins';

/// Paleta de colores oficial de Concertx. Úsala en vez de valores
/// hardcodeados para mantener consistencia visual en toda la app.
class AppColors {
  AppColors._();

  static const darkNavy = Color(0xFF0D1F3C); // Fondo
  static const navyMid = Color(0xFF1B3A6B); // Superficie / tarjetas
  static const inputBg = Color(0xFF0F2847); // Relleno de inputs
  static const blue = Color(0xFF3B82F6); // Acento primario
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF94A3B8);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFEF4444);
  static const border = Color(0xFF2563A8);

  // Colores de efectos disponibles para el diseño de luces.
  static const cyan = Color(0xFF06B6D4);
  static const purple = Color(0xFF7C3AED);
  static const orange = Color(0xFFF59E0B);

  static const List<Color> paletaEfectos = [error, cyan, blue, purple, orange];
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData.dark();
    final textTheme = base.textTheme.apply(
      fontFamily: _poppins,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkNavy,
      primaryColor: AppColors.blue,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.blue,
        secondary: AppColors.blue,
        surface: AppColors.navyMid,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkNavy,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.blue),
        titleTextStyle: const TextStyle(
          fontFamily: _poppins,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.navyMid,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(fontFamily: _poppins, color: AppColors.textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: _poppins, fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.blue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: _poppins, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(fontFamily: _poppins, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navyMid,
        contentTextStyle: const TextStyle(fontFamily: _poppins, color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerColor: AppColors.border,
    );
  }
}

/// Envoltura estándar de "tarjeta" usada en toda la app:
/// color navyMid, borderRadius 12, padding 16.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.navyMid,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}
