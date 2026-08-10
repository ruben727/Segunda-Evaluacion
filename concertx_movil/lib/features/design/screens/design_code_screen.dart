import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/concierto.dart';
import '../../../core/models/diseno.dart';
import '../../../core/theme/app_theme.dart';

class DesignCodeScreen extends StatelessWidget {
  final Diseno diseno;
  final Concierto? concierto;

  const DesignCodeScreen({super.key, required this.diseno, this.concierto});

  @override
  Widget build(BuildContext context) {
    final fecha = concierto != null
        ? DateFormat("d MMM yyyy", 'es_MX').format(concierto!.fechaInicio)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Código del evento'),
        actions: [
          IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.close, color: Colors.white)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Diseño creado!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comparte este código con los asistentes',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.navyMid,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.blue, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    diseno.codigo.split('').join(' '),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                      letterSpacing: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Válido para ${concierto?.artista ?? ''} · $fecha',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: diseno.codigo));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado al portapapeles')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar código'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      SharePlus.instance.share(ShareParams(
                        text: 'Únete a mi diseño de luces en ConcertX con el código: ${diseno.codigo}',
                      ));
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('VER MI DISEÑO'),
            ),
          ],
        ),
      ),
    );
  }
}
