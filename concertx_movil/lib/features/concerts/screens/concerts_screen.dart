import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/mi_evento.dart';
import '../../../core/providers/diseno_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

/// Pestaña "Conciertos": lista los eventos a los que el usuario ya se
/// unió con un código (no es un buscador general de conciertos).
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
      context.read<DisenoProvider>().fetchMisEventos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisenoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Conciertos')),
      body: RefreshIndicator(
        onRefresh: () => context.read<DisenoProvider>().fetchMisEventos(),
        child: provider.isLoadingMisEventos && provider.misEventos.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
            : provider.misEventos.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: const [
                      SizedBox(height: 60),
                      Center(
                        child: Text(
                          'Aún no te has unido a ningún concierto.\nUsa un código desde el inicio para unirte.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: provider.misEventos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _MiEventoCard(evento: provider.misEventos[i]),
                  ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
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
