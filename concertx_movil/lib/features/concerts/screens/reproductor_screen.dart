import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/configuracion_luz.dart';
import '../../../core/models/diseno.dart';
import '../../../core/providers/reproductor_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/salud_mini_card.dart';

/// Lista de canciones de un diseño al que el usuario se unió. Cada
/// canción tiene un botón para "reproducirla": manda su color al reloj
/// (que se pone de ese color) y arranca una cuenta regresiva con su
/// duración; al terminar, el reloj vuelve a negro. También se puede
/// repetir o quitar (detener) manualmente.
class ReproductorScreen extends StatefulWidget {
  final String codigo;
  final String artista;

  const ReproductorScreen({super.key, required this.codigo, required this.artista});

  @override
  State<ReproductorScreen> createState() => _ReproductorScreenState();
}

class _ReproductorScreenState extends State<ReproductorScreen> {
  final _apiService = ApiService();
  Diseno? _diseno;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final diseno = await _apiService.getDisenoPorCodigo(widget.codigo);
      if (!mounted) return;
      setState(() {
        _diseno = diseno;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Si el usuario sale de la pantalla con una canción sonando, se
    // detiene para que el reloj no se quede pegado en ese color.
    final reproductor = context.read<ReproductorProvider>();
    if (reproductor.reproduciendo) reproductor.detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reproductor = context.watch<ReproductorProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(widget.artista),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SaludMiniCard(),
                    const SizedBox(height: 20),
                    if (reproductor.reproduciendo) ...[
                      _buildBannerActivo(reproductor),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'Canciones',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ...(_diseno?.configuraciones ?? []).map((cfg) => _buildCancionRow(cfg, reproductor)),
                  ],
                ),
    );
  }

  Widget _buildBannerActivo(ReproductorProvider reproductor) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.blue,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.6), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reproductor.tituloActual ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Sonando en el reloj · ${reproductor.tiempoRestanteFormateado} restante',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => reproductor.repetir(),
            icon: const Icon(Icons.replay, color: AppColors.blue),
            tooltip: 'Repetir',
          ),
          IconButton(
            onPressed: () => reproductor.detener(),
            icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
            tooltip: 'Quitar',
          ),
        ],
      ),
    );
  }

  Widget _buildCancionRow(ConfiguracionLuz cfg, ReproductorProvider reproductor) {
    final activa = reproductor.cancionId == cfg.cancionId;
    final color = _hexToColor(cfg.colorHex);
    final duracion = cfg.duracionSegundos ?? 180;
    final minutos = duracion ~/ 60;
    final segundos = duracion % 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _alternarCancion(cfg, reproductor, activa),
        child: Row(
          children: [
            Text(
              '${cfg.numeroCancion ?? ''}',
              style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cfg.tituloCancion ?? 'Canción',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$minutos:${segundos.toString().padLeft(2, '0')}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(width: 10),
            Icon(
              activa ? Icons.stop_circle : Icons.play_circle_outline,
              color: activa ? AppColors.error : AppColors.blue,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _alternarCancion(ConfiguracionLuz cfg, ReproductorProvider reproductor, bool activa) async {
    if (activa) {
      await reproductor.detener();
      return;
    }
    await reproductor.reproducir(
      cancionId: cfg.cancionId,
      titulo: cfg.tituloCancion ?? 'Canción',
      colorHex: cfg.colorHex,
      duracionSeg: cfg.duracionSegundos ?? 180,
      artista: widget.artista,
    );
  }

  Color _hexToColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF3B82F6);
  }
}
