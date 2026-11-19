import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/incidencia.dart';
import '../../../core/theme/app_theme.dart';

/// Color asociado a cada estado, usado en chips y contadores.
Color colorEstado(String estado) {
  switch (estado) {
    case 'Pendiente':
      return AppColors.orange;
    case 'En proceso':
      return AppColors.blue;
    case 'Resuelto':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

Color colorPrioridad(String prioridad) {
  switch (prioridad) {
    case 'Alta':
      return AppColors.error;
    case 'Media':
      return AppColors.orange;
    default:
      return AppColors.cyan;
  }
}

IconData iconoEquipo(String equipo) {
  switch (equipo) {
    case 'Teléfono':
      return Icons.phone_iphone;
    case 'Smartwatch':
      return Icons.watch_outlined;
    case 'Pantalla TV':
      return Icons.tv;
    case 'Pulsera LED':
      return Icons.light_mode_outlined;
    default:
      return Icons.devices_other;
  }
}

String formatearFecha(DateTime fecha) => DateFormat("d MMM yyyy, HH:mm", 'es_MX').format(fecha);

/// Etiqueta redondeada con color (estado o prioridad).
class EtiquetaColor extends StatelessWidget {
  final String texto;
  final Color color;

  const EtiquetaColor({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Fila de tres tarjetas con el número de incidencias por estado.
class ContadorEstados extends StatelessWidget {
  final Map<String, int> conteo;

  const ContadorEstados({super.key, required this.conteo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final estado in OpcionesIncidencia.estados) ...[
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    '${conteo[estado] ?? 0}',
                    key: Key('contador_$estado'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorEstado(estado),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estado,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (estado != OpcionesIncidencia.estados.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Encabezado común de la tarjeta de incidencia: icono del equipo, tipo,
/// equipo, fecha y etiquetas de estado/prioridad.
class EncabezadoIncidencia extends StatelessWidget {
  final Incidencia incidencia;
  final Widget? trailing;

  const EncabezadoIncidencia({super.key, required this.incidencia, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconoEquipo(incidencia.equipo), color: AppColors.blue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${incidencia.id} · ${incidencia.tipo}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                '${incidencia.equipo} · ${formatearFecha(incidencia.fecha)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  EtiquetaColor(texto: incidencia.estado, color: colorEstado(incidencia.estado)),
                  EtiquetaColor(
                    texto: 'Prioridad ${incidencia.prioridad}',
                    color: colorPrioridad(incidencia.prioridad),
                  ),
                ],
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
