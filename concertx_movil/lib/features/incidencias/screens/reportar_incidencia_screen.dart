import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/incidencia.dart';
import '../../../core/providers/incidencia_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/incidencia_widgets.dart';

/// "Reportar incidencia" (Prácticas 7 y 8): el usuario SOLO elige opciones
/// de listas cerradas. A propósito no hay ningún campo de texto libre.
class ReportarIncidenciaScreen extends StatefulWidget {
  const ReportarIncidenciaScreen({super.key});

  @override
  State<ReportarIncidenciaScreen> createState() => _ReportarIncidenciaScreenState();
}

class _ReportarIncidenciaScreenState extends State<ReportarIncidenciaScreen> {
  String? _tipo;
  String? _equipo;
  String? _prioridad;

  Future<void> _guardar() async {
    final provider = context.read<IncidenciaProvider>();
    final error = await provider.reportar(tipo: _tipo, equipo: _equipo, prioridad: _prioridad);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    messenger.showSnackBar(const SnackBar(
      content: Text('Incidencia registrada. Te avisaremos cuando cambie su estado.'),
      backgroundColor: AppColors.success,
    ));
    setState(() {
      _tipo = null;
      _equipo = null;
      _prioridad = null;
    });
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final guardando = context.watch<IncidenciaProvider>().isGuardando;

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar incidencia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Elige las opciones que describen el problema.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _SeccionOpciones(
            titulo: 'Tipo de incidencia',
            opciones: OpcionesIncidencia.tipos,
            seleccion: _tipo,
            onSeleccion: (v) => setState(() => _tipo = v),
          ),
          _SeccionOpciones(
            titulo: 'Equipo afectado',
            opciones: OpcionesIncidencia.equipos,
            seleccion: _equipo,
            iconos: iconoEquipo,
            onSeleccion: (v) => setState(() => _equipo = v),
          ),
          _SeccionOpciones(
            titulo: 'Prioridad',
            opciones: OpcionesIncidencia.prioridades,
            seleccion: _prioridad,
            colores: colorPrioridad,
            onSeleccion: (v) => setState(() => _prioridad = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('guardar_incidencia'),
            onPressed: guardando ? null : _guardar,
            child: guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }
}

class _SeccionOpciones extends StatelessWidget {
  final String titulo;
  final List<String> opciones;
  final String? seleccion;
  final ValueChanged<String> onSeleccion;
  final IconData Function(String)? iconos;
  final Color Function(String)? colores;

  const _SeccionOpciones({
    required this.titulo,
    required this.opciones,
    required this.seleccion,
    required this.onSeleccion,
    this.iconos,
    this.colores,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in opciones)
                ChoiceChip(
                  key: Key('opcion_$opcion'),
                  label: Text(opcion),
                  avatar: iconos == null
                      ? null
                      : Icon(
                          iconos!(opcion),
                          size: 16,
                          color: seleccion == opcion ? Colors.white : AppColors.textSecondary,
                        ),
                  selected: seleccion == opcion,
                  onSelected: (_) => onSeleccion(opcion),
                  showCheckmark: false,
                  backgroundColor: AppColors.inputBg,
                  selectedColor: colores?.call(opcion) ?? AppColors.blue,
                  side: BorderSide(
                    color: seleccion == opcion ? Colors.transparent : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: seleccion == opcion ? Colors.white : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
