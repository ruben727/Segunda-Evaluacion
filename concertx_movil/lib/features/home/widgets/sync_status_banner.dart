import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Banner inferior "MODO SINCRO ACTIVO" mostrado cuando el reloj está
/// conectado por BLE y hay un show próximo.
class SyncStatusBanner extends StatelessWidget {
  final String artista;
  final String tiempoRestante;
  final VoidCallback onSincronizar;

  const SyncStatusBanner({
    super.key,
    required this.artista,
    required this.tiempoRestante,
    required this.onSincronizar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MODO SINCRO ACTIVO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Próximo Show: $artista', style: const TextStyle(fontSize: 13, color: Colors.white)),
                Text(
                  'Sincroniza tus luces en $tiempoRestante',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSincronizar,
            icon: const Icon(Icons.sync, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
