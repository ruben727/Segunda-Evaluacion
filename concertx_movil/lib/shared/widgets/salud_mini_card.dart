import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/wearable_provider.dart';
import '../../core/theme/app_theme.dart';

/// Tarjeta compacta "Tu salud": ritmo cardiaco y oxígeno en sangre que
/// llegan del reloj en tiempo real. Se usa arriba del Home y arriba del
/// reproductor de canciones.
class SaludMiniCard extends StatelessWidget {
  const SaludMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    final wearable = context.watch<WearableProvider>();
    final data = wearable.currentData;
    final conectado = wearable.bleStatus == WearableBleStatus.conectado;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: conectado ? AppColors.success : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Tu salud', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (data == null)
            const Text('Sin datos del reloj', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else ...[
            Icon(Icons.favorite, size: 15, color: wearable.isAlertActive ? AppColors.error : AppColors.blue),
            const SizedBox(width: 4),
            Text(
              '${data.ritmo} BPM',
              style: TextStyle(
                color: wearable.isAlertActive ? AppColors.error : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.water_drop, size: 15, color: AppColors.blue),
            const SizedBox(width: 4),
            Text(
              '${data.oxigeno}%',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
