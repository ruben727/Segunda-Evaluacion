import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wearable_provider.dart';
import '../../../core/theme/app_theme.dart';

class WearableMonitorScreen extends StatelessWidget {
  const WearableMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WearableProvider>();
    final data = provider.currentData;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Monitor Wearable'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEstado(provider.bleStatus),
            const SizedBox(height: 20),
            if (provider.isAlertActive) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt, color: Color(0xFFF59E0B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '¡Momento de alta energía!',
                        style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            AppCard(
              child: _MetricRow(
                icon: Icons.favorite,
                label: 'Ritmo',
                value: data != null ? '${data.ritmo} BPM' : '-- BPM',
                valueColor: (data?.ritmo ?? 0) > 100 ? AppColors.error : Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined, color: AppColors.blue),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Color efecto activo', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: data != null ? _hexToColor(data.colorHex) : AppColors.navyMid,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: _MetricRow(
                icon: Icons.vibration,
                label: 'Vibración activa',
                value: (data?.vibracion ?? false) ? 'Encendida' : 'Apagada',
                valueColor: (data?.vibracion ?? false) ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (provider.bleStatus != WearableBleStatus.conectado)
              ElevatedButton(
                onPressed: () => provider.startScan(),
                child: const Text('Conectar smartwatch'),
              )
            else
              OutlinedButton(
                onPressed: () => provider.disconnect(),
                child: const Text('Desconectar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstado(WearableBleStatus status) {
    late Color color;
    late String texto;
    switch (status) {
      case WearableBleStatus.conectado:
        color = AppColors.success;
        texto = 'Conectado';
        break;
      case WearableBleStatus.escaneando:
        color = AppColors.blue;
        texto = 'Buscando reloj...';
        break;
      case WearableBleStatus.error:
        color = AppColors.error;
        texto = 'Error de conexión';
        break;
      case WearableBleStatus.desconectado:
        color = AppColors.textSecondary;
        texto = 'Desconectado';
        break;
    }

    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _hexToColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF1B3A6B);
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.blue),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
