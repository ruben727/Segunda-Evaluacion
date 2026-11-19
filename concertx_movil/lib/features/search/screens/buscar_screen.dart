import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/resultado_busqueda.dart';
import '../../../core/providers/busqueda_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Buscador con sugerencias mientras escribes. Tolera errores de escritura
/// ("karl g" → Karol G, "azteka" → Estadio Azteca) porque el backend
/// compara por similitud (pg_trgm), no por coincidencia exacta.
class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key});

  @override
  State<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends State<BuscarScreen> {
  final _controller = TextEditingController();

  static const _ejemplos = ['Bad Bunny', 'Karol G', 'Foro Sol', 'Tu Gloria'];

  @override
  void initState() {
    super.initState();
    // Si se vuelve a la pantalla, se conserva lo último buscado.
    _controller.text = context.read<BusquedaProvider>().consulta;
  }

  void _usar(String texto) {
    _controller.text = texto;
    _controller.selection = TextSelection.collapsed(offset: texto.length);
    final provider = context.read<BusquedaProvider>()..consulta = texto;
    provider.buscarAhora(texto);
  }

  void _abrir(ResultadoBusqueda r) {
    FocusScope.of(context).unfocus();
    context.push('/conciertos/${r.conciertoId}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusquedaProvider>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            key: const Key('campo_buscar'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: (v) {
              provider.escribir(v);
              setState(() {}); // para mostrar/ocultar el botón de borrar
            },
            onSubmitted: provider.buscarAhora,
            decoration: InputDecoration(
              hintText: 'Artista, canción, estadio o ciudad…',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        _controller.clear();
                        provider.escribir('');
                        setState(() {});
                      },
                    ),
              isDense: true,
              fillColor: AppColors.navyMid,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.blue),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.blue, backgroundColor: Colors.transparent)
          else
            const SizedBox(height: 2),
          Expanded(child: _contenido(provider)),
        ],
      ),
    );
  }

  Widget _contenido(BusquedaProvider provider) {
    if (provider.consulta.trim().isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Prueba con', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _ejemplos)
                ActionChip(
                  label: Text(e),
                  onPressed: () => _usar(e),
                  backgroundColor: AppColors.navyMid,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'No importa si lo escribes con errores o sin acentos: te mostramos lo más parecido.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(provider.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        if (provider.sugerencia != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              key: const Key('quisiste_decir'),
              onTap: () => _usar(provider.sugerencia!),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: '¿Quisiste decir '),
                    TextSpan(
                      text: provider.sugerencia,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: '?'),
                  ],
                ),
              ),
            ),
          ),
        if (provider.buscado && provider.resultados.isEmpty && !provider.isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              'No encontramos nada parecido a "${provider.consulta.trim()}".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ...provider.resultados.map((r) => _TarjetaResultado(resultado: r, onTap: () => _abrir(r))),
      ],
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  final ResultadoBusqueda resultado;
  final VoidCallback onTap;

  const _TarjetaResultado({required this.resultado, required this.onTap});

  static IconData _icono(String campo) {
    switch (campo) {
      case 'cancion':
        return Icons.music_note;
      case 'estadio':
        return Icons.stadium_outlined;
      case 'ciudad':
        return Icons.location_on_outlined;
      case 'tour':
        return Icons.tour_outlined;
      default:
        return Icons.mic_external_on_outlined;
    }
  }

  static String _etiqueta(String campo) {
    switch (campo) {
      case 'cancion':
        return 'Canción';
      case 'estadio':
        return 'Estadio';
      case 'ciudad':
        return 'Ciudad';
      case 'tour':
        return 'Tour';
      default:
        return 'Artista';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si coincidió por estadio/tour/ciudad, se muestra qué fue lo que coincidió.
    final mostrarCoincidencia = !resultado.esCancion && resultado.campo != 'artista';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(_icono(resultado.campo), color: AppColors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resultado.titulo,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resultado.subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (mostrarCoincidencia) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_etiqueta(resultado.campo)}: ${resultado.texto}',
                      style: const TextStyle(color: AppColors.cyan, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                resultado.esCancion ? 'CANCIÓN' : 'CONCIERTO',
                style: const TextStyle(fontSize: 9, color: AppColors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
