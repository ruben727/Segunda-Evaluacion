import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/mi_diseno.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/diseno_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisenoProvider>().fetchMisDisenos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final disenoProvider = context.watch<DisenoProvider>();
    final usuario = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, color: AppColors.blue)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: AppColors.navyMid, shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  usuario?.nombre ?? 'Invitado',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  usuario?.correo ?? '',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(minimumSize: const Size(160, 38)),
                  child: const Text('Editar perfil', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Mis diseños',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (disenoProvider.isLoadingMisDisenos && disenoProvider.misDisenos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
            )
          else if (disenoProvider.misDisenos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no has creado ningún diseño.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          else
            ...disenoProvider.misDisenos.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MiDisenoCard(diseno: d),
                )),
          const SizedBox(height: 20),
          _SettingsRow(icon: Icons.notifications_outlined, label: 'Notificaciones', onTap: () {}),
          _SettingsRow(icon: Icons.shield_outlined, label: 'Privacidad y seguridad', onTap: () {}),
          _SettingsRow(
            icon: Icons.phone_iphone_outlined,
            label: 'Dispositivos vinculados',
            trailing: _Badge(text: '1 SMARTWATCH'),
            onTap: () => context.push('/wearable'),
          ),
          _SettingsRow(icon: Icons.help_outline, label: 'Ayuda y soporte', onTap: () {}),
          _SettingsRow(
            icon: Icons.info_outline,
            label: 'Acerca de Concertx',
            trailing: const Text('v1.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            onTap: () {},
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.error, size: 20),
                  SizedBox(width: 14),
                  Text('Cerrar sesión', style: TextStyle(color: AppColors.error, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Experiencia Premium',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Tu sincronización con el show es del 98% esta temporada.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }
}

class _MiDisenoCard extends StatelessWidget {
  final MiDiseno diseno;

  const _MiDisenoCard({required this.diseno});

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d MMM yyyy", 'es_MX').format(diseno.fechaInicio);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diseno.artista,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(fecha, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  diseno.codigo.split('').join(' '),
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: diseno.codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy, color: AppColors.blue, size: 20),
          ),
          IconButton(
            onPressed: () {
              SharePlus.instance.share(ShareParams(
                text: 'Únete a mi diseño de luces en ConcertX para ${diseno.artista} con el código: ${diseno.codigo}',
              ));
            },
            icon: const Icon(Icons.share_outlined, color: AppColors.blue, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsRow({required this.icon, required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
            ?trailing,
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
      ),
    );
  }
}
