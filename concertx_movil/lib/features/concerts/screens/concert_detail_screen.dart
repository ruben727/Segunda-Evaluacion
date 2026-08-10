import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/concierto.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class ConcertDetailScreen extends StatefulWidget {
  final String conciertoId;

  const ConcertDetailScreen({super.key, required this.conciertoId});

  @override
  State<ConcertDetailScreen> createState() => _ConcertDetailScreenState();
}

class _ConcertDetailScreenState extends State<ConcertDetailScreen> {
  final _apiService = ApiService();
  Concierto? _concierto;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final concierto = await _apiService.getConciertoById(widget.conciertoId);
      if (!mounted) return;
      setState(() {
        _concierto = concierto;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text(''),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined, color: AppColors.blue)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _buildContenido(_concierto!),
    );
  }

  Widget _buildContenido(Concierto c) {
    final fecha = DateFormat("d MMM yyyy · HH:mm'h'", 'es_MX').format(c.fechaInicio);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.album, color: AppColors.blue, size: 64),
          ),
          const SizedBox(height: 20),
          Text(
            c.artista,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (c.nombreTour != null) ...[
            const SizedBox(height: 4),
            Text(c.nombreTour!, style: const TextStyle(fontSize: 14, color: Color(0xFFDBEAFE))),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.navyMid,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(fecha, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${c.estadio?.nombre ?? ''}, ${c.estadio?.direccion ?? ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people_outline, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                '${c.asistentesRegistrados} asistentes registrados',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text('Setlist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: c.canciones.isEmpty
                  ? [const Text('Setlist por confirmar', style: TextStyle(color: AppColors.textSecondary))]
                  : c.canciones
                      .map((cancion) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${cancion.numero}',
                                    style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    cancion.titulo,
                                    style: const TextStyle(fontSize: 14, color: Colors.white),
                                  ),
                                ),
                                Text(
                                  cancion.duracionFormateada,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.push('/crear-diseno/${c.id}'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Crear diseño de efectos'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/unirse'),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Unirme con código'),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
