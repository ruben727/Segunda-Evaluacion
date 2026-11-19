import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pone toda la pantalla del teléfono del color de la canción (sin barras
/// del sistema). Se quita con doble toque en cualquier parte.
class PantallaColorScreen extends StatefulWidget {
  final Color color;

  const PantallaColorScreen({super.key, required this.color});

  static Future<void> abrir(BuildContext context, Color color) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => PantallaColorScreen(color: color),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<PantallaColorScreen> createState() => _PantallaColorScreenState();
}

class _PantallaColorScreenState extends State<PantallaColorScreen> {
  bool _mostrarAyuda = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // La pista "Toca dos veces para salir" desaparece sola para dejar
    // la pantalla 100% del color.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _mostrarAyuda = false);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textoClaro = widget.color.computeLuminance() < 0.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: widget.color,
        body: Center(
          child: AnimatedOpacity(
            opacity: _mostrarAyuda ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: Text(
              'Toca dos veces para salir',
              style: TextStyle(color: (textoClaro ? Colors.white : Colors.black).withValues(alpha: 0.7), fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
