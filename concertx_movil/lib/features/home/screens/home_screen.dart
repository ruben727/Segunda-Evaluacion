import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/concierto_provider.dart';
import '../../../core/providers/wearable_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/salud_mini_card.dart';
import '../widgets/concert_card.dart';
import '../widgets/sync_status_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConciertoProvider>().fetchConciertos();
      // Empieza a escuchar al reloj (BLE real + puente HTTP de respaldo)
      // apenas se abre la app, para que la mini-tarjeta se llene sola.
      context.read<WearableProvider>().startScan();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conciertoProvider = context.watch<ConciertoProvider>();
    final wearableProvider = context.watch<WearableProvider>();
    final conciertos = conciertoProvider.searchConciertos(_query);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ConciertoProvider>().fetchConciertos(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ConcertX',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SaludMiniCard(),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar artista o estadio...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.navyMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (wearableProvider.bleStatus == WearableBleStatus.conectado) ...[
                SyncStatusBanner(
                  artista: conciertos.isNotEmpty ? conciertos.first.artista : 'Próximo evento',
                  tiempoRestante: '2:15',
                  onSincronizar: () => context.push('/wearable'),
                ),
                const SizedBox(height: 24),
              ],
              const Text(
                'Próximos conciertos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (conciertoProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
                )
              else if (conciertoProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    conciertoProvider.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              else if (conciertos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No hay conciertos disponibles', style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...conciertos.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ConcertCard(
                      concierto: c,
                      onTap: () => context.push('/conciertos/${c.id}'),
                      onUnirse: () => context.push('/unirse'),
                      onCrearDiseno: () => context.push('/crear-diseno/${c.id}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}
