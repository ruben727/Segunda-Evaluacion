import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/theme/app_theme.dart';

const _claveDescartado = 'widget_proximo_aviso_descartado';

/// Pide al sistema agregar el widget "Próximo concierto" a la pantalla
/// principal. Si el launcher no lo permite desde la app, explica cómo
/// hacerlo a mano. Se usa en la tarjeta de Inicio y en Perfil.
Future<void> agregarWidgetPantallaPrincipal(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await WidgetService.yaAgregado()) {
    messenger.showSnackBar(const SnackBar(content: Text('El widget ya está en tu pantalla principal')));
    return;
  }
  if (await WidgetService.puedePedirAgregar()) {
    await WidgetService.pedirAgregar();
    messenger.showSnackBar(const SnackBar(
      content: Text('Confirma en el aviso del sistema para colocar el widget'),
    ));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.navyMid,
      title: const Text('Agregar widget', style: TextStyle(color: Colors.white)),
      content: const Text(
        '1. Mantén presionado un espacio vacío de tu pantalla principal.\n'
        '2. Toca "Widgets".\n'
        '3. Busca "ConcertX" y arrastra "Próximo concierto".',
        style: TextStyle(color: AppColors.textSecondary, height: 1.5),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Entendido')),
      ],
    ),
  );
}

/// Tarjeta en Inicio que invita a agregar el widget. Solo aparece en
/// Android, si el widget todavía no está puesto y si el usuario no eligió
/// "Ahora no" antes.
class AgregarWidgetCard extends StatefulWidget {
  const AgregarWidgetCard({super.key});

  @override
  State<AgregarWidgetCard> createState() => _AgregarWidgetCardState();
}

class _AgregarWidgetCardState extends State<AgregarWidgetCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final disponible = await WidgetService.puedePedirAgregar();
    if (!disponible || await WidgetService.yaAgregado()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_claveDescartado) ?? false) return;
    } catch (_) {
      // Sin preferencias: se muestra la tarjeta.
    }
    if (mounted) setState(() => _visible = true);
  }

  Future<void> _ahoraNo() async {
    setState(() => _visible = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveDescartado, true);
    } catch (_) {}
  }

  Future<void> _agregar() async {
    await agregarWidgetPantallaPrincipal(context);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.widgets_outlined, color: AppColors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu próximo concierto en la pantalla principal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Agrega el widget de ConcertX para ver la fecha y la cuenta regresiva sin abrir la app.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _ahoraNo,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: const Text('Ahora no', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('agregar_widget'),
                    onPressed: _agregar,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: const Text('Agregar', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
