import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/incidencia.dart';
import '../../../core/providers/incidencia_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/incidencia_widgets.dart';

/// "Mis incidencias": solo las del usuario autenticado (el backend filtra
/// por el id del token en GET /incidencias/mias).
class MisIncidenciasScreen extends StatefulWidget {
  const MisIncidenciasScreen({super.key});

  @override
  State<MisIncidenciasScreen> createState() => _MisIncidenciasScreenState();
}

class _MisIncidenciasScreenState extends State<MisIncidenciasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidenciaProvider>().cargarMias();
    });
  }

  Future<void> _cambiarPrioridad(Incidencia incidencia, String prioridad) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<IncidenciaProvider>().cambiarPrioridad(incidencia.id, prioridad);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Prioridad actualizada'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidenciaProvider>();
    final lista = provider.misIncidencias;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis incidencias')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/incidencias/reportar'),
        icon: const Icon(Icons.add),
        label: const Text('Reportar', style: TextStyle(fontFamily: 'Poppins')),
      ),
      body: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: provider.cargarMias,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            ContadorEstados(conteo: provider.conteoMias),
            const SizedBox(height: 20),
            if (provider.isLoading && lista.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
              )
            else if (provider.errorMessage != null && lista.isEmpty)
              Text(provider.errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))
            else if (lista.isEmpty)
              const Text(
                'No has reportado ninguna incidencia.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              ...lista.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EncabezadoIncidencia(
                            incidencia: i,
                            trailing: i.estado == 'Pendiente'
                                ? PopupMenuButton<String>(
                                    tooltip: 'Cambiar prioridad',
                                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                    color: AppColors.navyMid,
                                    onSelected: (p) => _cambiarPrioridad(i, p),
                                    itemBuilder: (_) => [
                                      for (final p in OpcionesIncidencia.prioridades)
                                        PopupMenuItem(value: p, child: Text('Prioridad $p')),
                                    ],
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i.agenteNombre == null
                                ? 'Sin agente asignado todavía'
                                : 'Atendida por ${i.agenteNombre}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
