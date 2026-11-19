import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/mensajes_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Práctica 6: mensajes entre dos dispositivos simulados (A y B) dentro de
/// la app. Se elige el emisor, se escribe y se envía; la lista muestra
/// emisor y hora, hay contador por dispositivo y botón para limpiar.
class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  final _controller = TextEditingController();
  String _emisor = 'A';

  static Color _colorDe(String d) => d == 'A' ? AppColors.blue : AppColors.purple;

  void _enviar() {
    final provider = context.read<MensajesProvider>();
    final error = provider.enviar(_emisor, _controller.text);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
      return;
    }
    final receptor = _emisor == 'A' ? 'B' : 'A';
    _controller.clear();
    messenger.showSnackBar(SnackBar(
      content: Text('Dispositivo $_emisor → Dispositivo $receptor: mensaje enviado'),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MensajesProvider>();
    final conteo = provider.conteoPorDispositivo;
    final mensajes = provider.mensajes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes entre dispositivos'),
        actions: [
          IconButton(
            key: const Key('limpiar_mensajes'),
            tooltip: 'Limpiar historial',
            onPressed: mensajes.isEmpty
                ? null
                : () {
                    provider.limpiarHistorial();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Historial limpiado')));
                  },
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                for (final d in MensajesProvider.dispositivos) ...[
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.smartphone, color: _colorDe(d)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dispositivo $d',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Text(
                            '${conteo[d]}',
                            key: Key('contador_dispositivo_$d'),
                            style: TextStyle(
                              color: _colorDe(d),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (d == 'A') const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          Expanded(
            child: mensajes.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no hay mensajes. Elige un emisor y envía el primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: mensajes.length,
                    itemBuilder: (_, i) => _Burbuja(mensaje: mensajes[i], color: _colorDe(mensajes[i].emisor)),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.navyMid,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Emisor:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SegmentedButton<String>(
                          key: const Key('selector_emisor'),
                          segments: const [
                            ButtonSegment(value: 'A', label: Text('Dispositivo A')),
                            ButtonSegment(value: 'B', label: Text('Dispositivo B')),
                          ],
                          selected: {_emisor},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() => _emisor = s.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (st) => st.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary,
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (st) => st.contains(WidgetState.selected) ? _colorDe(_emisor) : AppColors.inputBg,
                            ),
                            side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('campo_mensaje'),
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [LengthLimitingTextInputFormatter(MensajesProvider.longitudMaxima)],
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _enviar(),
                          decoration: const InputDecoration(hintText: 'Escribe un mensaje…'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        key: const Key('enviar_mensaje'),
                        style: IconButton.styleFrom(backgroundColor: AppColors.blue),
                        onPressed: _enviar,
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final MensajeDispositivo mensaje;
  final Color color;

  const _Burbuja({required this.mensaje, required this.color});

  @override
  Widget build(BuildContext context) {
    final deA = mensaje.emisor == 'A';
    return Align(
      alignment: deA ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dispositivo ${mensaje.emisor} → ${mensaje.receptor}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(mensaje.texto, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm:ss').format(mensaje.hora),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
