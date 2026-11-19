import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/mi_diseno.dart';
import '../../../core/models/mi_evento.dart';
import '../../../core/providers/diseno_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

/// Pestaña "Conciertos": dos listas — los eventos a los que el usuario se
/// unió con un código ("Unidos") y los conciertos de los diseños que él
/// mismo creó ("Mis diseños"), con sus colores por canción.
class ConcertsScreen extends StatefulWidget {
  const ConcertsScreen({super.key});

  @override
  State<ConcertsScreen> createState() => _ConcertsScreenState();
}

class _ConcertsScreenState extends State<ConcertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DisenoProvider>();
      provider.fetchMisEventos();
      provider.fetchMisDisenos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisenoProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Conciertos'),
          bottom: const TabBar(
            indicatorColor: AppColors.blue,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Unidos'),
              Tab(text: 'Mis diseños'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLista(
              onRefresh: () => context.read<DisenoProvider>().fetchMisEventos(),
              cargando: provider.isLoadingMisEventos && provider.misEventos.isEmpty,
              vacioTexto: 'Aún no te has unido a ningún concierto.\nUsa un código desde el inicio para unirte.',
              items: provider.misEventos.map<Widget>((e) => _MiEventoCard(evento: e)).toList(),
            ),
            _buildLista(
              onRefresh: () => context.read<DisenoProvider>().fetchMisDisenos(),
              cargando: provider.isLoadingMisDisenos && provider.misDisenos.isEmpty,
              vacioTexto: 'Aún no has creado ningún diseño.\nEntra a un concierto y toca "Crear diseño de efectos".',
              items: provider.misDisenos.map<Widget>((d) => _MiDisenoConciertoCard(diseno: d)).toList(),
            ),
          ],
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
      ),
    );
  }

  Widget _buildLista({
    required Future<void> Function() onRefresh,
    required bool cargando,
    required String vacioTexto,
    required List<Widget> items,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Text(
                        vacioTexto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => items[i],
                ),
    );
  }
}

class _MiEventoCard extends StatelessWidget {
  final MiEvento evento;

  const _MiEventoCard({required this.evento});

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d MMM yyyy", 'es_MX').format(evento.fechaInicio);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evento.artista,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            [evento.estadioNombre, evento.estadioCiudad].where((e) => e != null && e.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(fecha, style: const TextStyle(fontSize: 12, color: AppColors.blue)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => context.push(
              '/reproducir/${evento.codigo}',
              extra: evento.artista,
            ),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
            child: const Text('Ver canciones', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Concierto de un diseño creado por el usuario: muestra sus colores por
/// canción y abre la lista de canciones para reproducirlas/verlas.
class _MiDisenoConciertoCard extends StatelessWidget {
  final MiDiseno diseno;

  const _MiDisenoConciertoCard({required this.diseno});

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d MMM yyyy", 'es_MX').format(diseno.fechaInicio);
    final lugar = [diseno.estadioNombre, diseno.estadioCiudad].where((e) => e != null && e.isNotEmpty).join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  diseno.artista,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
              Text(
                diseno.codigo,
                style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (opcion) =>
                    opcion == 'editar' ? _editarNombre(context) : _confirmarEliminar(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar nombre')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar diseño')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(diseno.nombre, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          if (lugar.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(lugar, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 4),
          Text(fecha, style: const TextStyle(fontSize: 12, color: AppColors.blue)),
          if (diseno.colores.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: diseno.colores
                  .map((hex) => Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _hexToColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => context.push('/reproducir/${diseno.codigo}', extra: diseno.artista),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
            child: const Text('Ver canciones y colores', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _editarNombre(BuildContext context) async {
    final controller = TextEditingController(text: diseno.nombre);
    final formKey = GlobalKey<FormState>();

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar nombre del diseño'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre no puede estar vacío' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevoNombre == null || nuevoNombre == diseno.nombre || !context.mounted) return;

    final error = await context.read<DisenoProvider>().renombrarDiseno(diseno.id, nuevoNombre);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Diseño actualizado')),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar diseño'),
        content: Text(
          '¿Seguro que quieres eliminar "${diseno.nombre}"? El código ${diseno.codigo} dejará de '
          'funcionar y los asistentes unidos perderán la sincronización. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final error = await context.read<DisenoProvider>().eliminarDiseno(diseno.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Diseño eliminado')),
    );
  }

  Color _hexToColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF3B82F6);
  }
}
