import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/configuracion_luz.dart';
import '../../../core/models/diseno.dart';
import '../../../core/providers/reproductor_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/linterna_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/salud_mini_card.dart';
import 'pantalla_color_screen.dart';

/// Lista de canciones de un diseño al que el usuario se unió. Cada
/// canción tiene un botón para "reproducirla": manda su color al reloj
/// (que se pone de ese color) y arranca una cuenta regresiva con su
/// duración; al terminar, el reloj vuelve a negro. También se puede
/// repetir o quitar (detener) manualmente. Mientras suena, se puede poner
/// la pantalla completa del color de la canción (doble toque para salir)
/// o encender la linterna del teléfono.
class ReproductorScreen extends StatefulWidget {
  final String codigo;
  final String artista;

  const ReproductorScreen({super.key, required this.codigo, required this.artista});

  @override
  State<ReproductorScreen> createState() => _ReproductorScreenState();
}

class _ReproductorScreenState extends State<ReproductorScreen> {
  final _apiService = ApiService();
  final _linterna = LinternaService.instance;
  late final ReproductorProvider _reproductor;
  Diseno? _diseno;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reproductor = context.read<ReproductorProvider>();
    _reproductor.addListener(_alCambiarReproduccion);
    _cargar();
  }

  /// Cuando la canción termina (o se detiene) se apaga la linterna.
  void _alCambiarReproduccion() {
    if (!_reproductor.reproduciendo && _linterna.encendida) {
      _linterna.apagar().then((_) {
        if (mounted) setState(() {});
      });
    }
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
    _reproductor.removeListener(_alCambiarReproduccion);
    if (_reproductor.reproduciendo) _reproductor.detener();
    _linterna.apagar();
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
          ? Center(
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SaludMiniCard(),
                const SizedBox(height: 20),
                if (reproductor.reproduciendo) ...[_buildBannerActivo(reproductor), const SizedBox(height: 20)],
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
    final color = _hexToColor(reproductor.colorActual ?? '#3B82F6');
    return AppCard(
      child: Column(children: [_buildBannerInfo(reproductor), const SizedBox(height: 12), _buildOpcionesLuz(color)]),
    );
  }

  /// Botones "Pantalla completa" y "Encender/Apagar lámpara".
  Widget _buildOpcionesLuz(Color color) {
    final encendida = _linterna.encendida;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => PantallaColorScreen.abrir(context, color),
            icon: Icon(Icons.fullscreen, size: 18, color: color),
            label: const Text('Pantalla completa', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _alternarLinterna,
            icon: Icon(encendida ? Icons.flashlight_off : Icons.flashlight_on, size: 18),
            label: Text(encendida ? 'Apagar lámpara' : 'Encender lámpara', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Future<void> _alternarLinterna() async {
    if (_linterna.encendida) {
      await _linterna.apagar();
      if (mounted) setState(() {});
      return;
    }

    final resultado = await _linterna.encender();
    if (!mounted) return;
    setState(() {});

    final messenger = ScaffoldMessenger.of(context);
    switch (resultado) {
      case ResultadoLinterna.ok:
        break;
      case ResultadoLinterna.permisoDenegado:
        messenger.showSnackBar(const SnackBar(content: Text('Necesitamos permiso de cámara para usar la linterna')));
      case ResultadoLinterna.permisoBloqueado:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Activa el permiso de cámara en Ajustes para usar la linterna'),
            action: SnackBarAction(label: 'Ajustes', onPressed: _linterna.abrirAjustes),
          ),
        );
      case ResultadoLinterna.noDisponible:
        messenger.showSnackBar(const SnackBar(content: Text('Este dispositivo no tiene linterna')));
      case ResultadoLinterna.error:
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo encender la linterna')));
    }
  }

  /// Muestra las opciones de luz justo después de elegir una canción.
  void _mostrarOpcionesLuz(ConfiguracionLuz cfg) {
    final color = _hexToColor(cfg.colorHex);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyMid,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cfg.tituloCancion ?? 'Canción',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.fullscreen, color: color),
              title: const Text('Pantalla completa de este color', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Toca dos veces para salir', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                PantallaColorScreen.abrir(context, color);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flashlight_on, color: AppColors.blue),
              title: Text(
                _linterna.encendida ? 'Apagar lámpara' : 'Encender lámpara',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _alternarLinterna();
              },
            ),
            ListTile(
              leading: const Icon(Icons.watch, color: AppColors.textSecondary),
              title: const Text('Solo en el reloj', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerInfo(ReproductorProvider reproductor) {
    return Row(
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
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
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
    // reproducir() ya no espera a la red: la canción arranca y las
    // opciones de luz aparecen en el mismo instante.
    await reproductor.reproducir(
      cancionId: cfg.cancionId,
      titulo: cfg.tituloCancion ?? 'Canción',
      colorHex: cfg.colorHex,
      duracionSeg: cfg.duracionSegundos ?? 180,
      artista: widget.artista,
    );
    if (mounted) _mostrarOpcionesLuz(cfg);
  }

  Color _hexToColor(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF3B82F6);
  }
}
