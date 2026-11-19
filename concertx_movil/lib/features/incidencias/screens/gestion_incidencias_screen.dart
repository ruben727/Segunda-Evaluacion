import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/incidencia.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/incidencia_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/incidencia_widgets.dart';

/// Panel de agente/administrador: ve TODOS los tickets levantados por los
/// clientes, cambia su estado (Pendiente / En proceso / Resuelto) y asigna
/// un agente. Solo el admin ve "Limpiar historial".
///
/// Ocultar esta pantalla a los usuarios es solo cosmético: el backend
/// responde 403 a GET /incidencias, PATCH estado y DELETE si el rol no
/// corresponde.
class GestionIncidenciasScreen extends StatefulWidget {
  const GestionIncidenciasScreen({super.key});

  @override
  State<GestionIncidenciasScreen> createState() => _GestionIncidenciasScreenState();
}

class _GestionIncidenciasScreenState extends State<GestionIncidenciasScreen> {
  /// null = todos los estados.
  String? _filtro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidenciaProvider>().cargarTodas();
    });
  }

  void _avisar(String? error, String exito) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? exito),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _cambiarEstado(Incidencia i, String estado) async {
    if (estado == i.estado) return;
    final error = await context.read<IncidenciaProvider>().cambiarEstado(i.id, estado);
    if (mounted) _avisar(error, 'Incidencia #${i.id} → $estado');
  }

  Future<void> _asignar(Incidencia i, String? agenteId) async {
    final error = await context.read<IncidenciaProvider>().asignarAgente(i.id, agenteId);
    if (mounted) _avisar(error, agenteId == null ? 'Asignación quitada' : 'Agente asignado');
  }

  Future<void> _confirmarLimpiar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navyMid,
        title: const Text('Limpiar historial', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se eliminarán TODAS las incidencias registradas. Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final error = await context.read<IncidenciaProvider>().limpiarHistorial();
    if (mounted) _avisar(error, 'Historial de incidencias eliminado');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidenciaProvider>();
    final usuario = context.watch<AuthProvider>().currentUser;
    final esAdmin = usuario?.esAdmin ?? false;
    final visibles = _filtro == null ? provider.todas : provider.todas.where((i) => i.estado == _filtro).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(esAdmin ? 'Panel de administrador' : 'Panel de agente'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: provider.cargarTodas,
            icon: const Icon(Icons.refresh, color: AppColors.blue),
          ),
          if (esAdmin)
            IconButton(
              key: const Key('limpiar_historial'),
              tooltip: 'Limpiar historial',
              onPressed: provider.todas.isEmpty ? null : _confirmarLimpiar,
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: provider.cargarTodas,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ContadorEstados(conteo: provider.conteoTodas),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final estado in [null, ...OpcionesIncidencia.estados])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(estado ?? 'Todas (${provider.todas.length})'),
                        selected: _filtro == estado,
                        onSelected: (_) => setState(() => _filtro = estado),
                        showCheckmark: false,
                        backgroundColor: AppColors.inputBg,
                        selectedColor: estado == null ? AppColors.blue : colorEstado(estado),
                        labelStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _filtro == estado ? Colors.white : AppColors.textSecondary,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (provider.isLoading && provider.todas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
              )
            else if (provider.errorMessage != null && provider.todas.isEmpty)
              Text(provider.errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))
            else if (visibles.isEmpty)
              const Text(
                'No hay incidencias en este estado.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              ...visibles.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TarjetaGestion(
                      incidencia: i,
                      agentes: provider.agentes,
                      onEstado: (e) => _cambiarEstado(i, e),
                      onAgente: (a) => _asignar(i, a),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _TarjetaGestion extends StatelessWidget {
  final Incidencia incidencia;
  final List<Agente> agentes;
  final ValueChanged<String> onEstado;
  final ValueChanged<String?> onAgente;

  const _TarjetaGestion({
    required this.incidencia,
    required this.agentes,
    required this.onEstado,
    required this.onAgente,
  });

  @override
  Widget build(BuildContext context) {
    final agenteValido = agentes.any((a) => a.id == incidencia.agenteAsignado);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoIncidencia(incidencia: incidencia),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cliente: ${incidencia.creadoPorNombre ?? 'Usuario #${incidencia.creadoPor}'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Estado', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            key: Key('estado_${incidencia.id}'),
            segments: [
              for (final e in OpcionesIncidencia.estados)
                ButtonSegment(value: e, label: Text(e, style: const TextStyle(fontSize: 11))),
            ],
            selected: {incidencia.estado},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onEstado(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colorEstado(incidencia.estado)
                    : AppColors.inputBg,
              ),
              side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: agenteValido ? incidencia.agenteAsignado : null,
            dropdownColor: AppColors.navyMid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Agente asignado',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              isDense: true,
            ),
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Sin asignar')),
              for (final a in agentes)
                DropdownMenuItem<String?>(
                  value: a.id,
                  child: Text('${a.nombre} (${a.rol == 'admin' ? 'admin' : 'agente'})'),
                ),
            ],
            onChanged: onAgente,
          ),
        ],
      ),
    );
  }
}
