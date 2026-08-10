import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/concierto.dart';
import '../../../core/theme/app_theme.dart';

class ConcertCard extends StatelessWidget {
  final Concierto concierto;
  final VoidCallback onUnirse;
  final VoidCallback onCrearDiseno;
  final VoidCallback? onTap;

  const ConcertCard({
    super.key,
    required this.concierto,
    required this.onUnirse,
    required this.onCrearDiseno,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d MMM yyyy · HH:mm'h'", 'es_MX').format(concierto.fechaInicio);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.album, color: AppColors.blue, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            concierto.artista,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (concierto.esHoy)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HOY',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${concierto.estadio?.nombre ?? ''} · ${concierto.estadio?.ciudad ?? ''}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(fecha, style: const TextStyle(fontSize: 12, color: AppColors.blue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onUnirse,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Unirse', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onCrearDiseno,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Crear diseño', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
