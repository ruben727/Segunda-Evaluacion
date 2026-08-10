import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/cancion.dart';
import '../../../core/models/concierto.dart';
import '../../../core/models/configuracion_luz.dart';
import '../../../core/providers/diseno_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class _SongConfig {
  final Cancion cancion;
  ConfiguracionLuz configuracion;
  bool expandido;

  _SongConfig({required this.cancion, required this.configuracion, this.expandido = false});
}

class CreateDesignScreen extends StatefulWidget {
  final String concertId;

  const CreateDesignScreen({super.key, required this.concertId});

  @override
  State<CreateDesignScreen> createState() => _CreateDesignScreenState();
}

class _CreateDesignScreenState extends State<CreateDesignScreen> {
  final _apiService = ApiService();
  Concierto? _concierto;
  bool _isLoading = true;
  String? _error;
  final List<_SongConfig> _configs = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final concierto = await _apiService.getConciertoById(widget.concertId);
      if (!mounted) return;
      setState(() {
        _concierto = concierto;
        _configs.addAll(concierto.canciones.asMap().entries.map((entry) {
          final i = entry.key;
          final cancion = entry.value;
          return _SongConfig(
            cancion: cancion,
            configuracion: ConfiguracionLuz(cancionId: cancion.id),
            expandido: i == 0,
          );
        }));
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

  void _agregarCancionManual() {
    final numero = _configs.length + 1;
    final cancionFalsa = Cancion(
      id: 'nueva-$numero',
      numero: numero,
      titulo: 'Nueva canción $numero',
      duracionSegundos: 180,
    );
    setState(() {
      _configs.add(_SongConfig(
        cancion: cancionFalsa,
        configuracion: ConfiguracionLuz(cancionId: cancionFalsa.id),
      ));
    });
  }

  Future<void> _generarCodigo() async {
    final provider = context.read<DisenoProvider>();
    final ok = await provider.crearDiseno(
      conciertoId: widget.concertId,
      nombre: '${_concierto?.artista ?? 'Diseño'} · ${DateTime.now().millisecondsSinceEpoch}',
      configuraciones: _configs.map((c) => c.configuracion).toList(),
    );

    if (!mounted) return;
    if (ok && provider.ultimoDisenoCreado != null) {
      context.push('/codigo-diseno', extra: {
        'diseno': provider.ultimoDisenoCreado,
        'concierto': _concierto,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'No se pudo generar el código')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisenoProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Crear diseño'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.save_outlined, color: AppColors.blue)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppColors.navyMid,
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '${_concierto?.artista} · ${_concierto?.estadio?.nombre ?? ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text(
                            'Configura los efectos por canción',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          ..._configs.map(_buildSongRow),
                          const SizedBox(height: 8),
                          _buildAgregarCancion(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton(
                        onPressed: provider.isLoading ? null : _generarCodigo,
                        child: provider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Generar código del evento'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAgregarCancion() {
    return InkWell(
      onTap: _agregarCancionManual,
      borderRadius: BorderRadius.circular(10),
      child: DottedBorderBox(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text('+ Agregar canción', style: TextStyle(color: AppColors.blue, fontSize: 13)),
          ),
        ),
      ),
    );
  }

  Widget _buildSongRow(_SongConfig item) {
    final expandido = item.expandido;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navyMid,
          borderRadius: BorderRadius.circular(10),
          border: expandido ? Border.all(color: AppColors.blue, width: 1.5) : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => item.expandido = !item.expandido),
              child: Row(
                children: [
                  Text('${item.cancion.numero}', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.cancion.titulo, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  Text(item.cancion.duracionFormateada, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  if (!expandido)
                    Switch(
                      value: item.configuracion.vibracion,
                      activeTrackColor: AppColors.blue,
                      onChanged: (v) => setState(() {
                        item.configuracion = item.configuracion.copyWith(vibracion: v);
                      }),
                    ),
                ],
              ),
            ),
            if (expandido) ...[
              const SizedBox(height: 14),
              const Text('Color del efecto:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: AppColors.paletaEfectos.map((color) {
                  final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                  final seleccionado = item.configuracion.colorHex.toUpperCase() == hex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => setState(() {
                        item.configuracion = item.configuracion.copyWith(colorHex: hex);
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: seleccionado ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Vibración', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Switch(
                    value: item.configuracion.vibracion,
                    activeTrackColor: AppColors.blue,
                    onChanged: (v) => setState(() {
                      item.configuracion = item.configuracion.copyWith(vibracion: v);
                    }),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón con borde punteado simple para "+ Agregar canción".
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(10),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
