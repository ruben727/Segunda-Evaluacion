import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/diseno_provider.dart';
import '../../../core/theme/app_theme.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codigoController = TextEditingController();
  bool _validado = false;
  bool _verificando = false;

  String _zona = 'VIP';
  String _fila = '01';
  String _asiento = '01';

  final _zonas = const ['VIP', 'A', 'B', 'C'];
  final _filas = List.generate(30, (i) => (i + 1).toString().padLeft(2, '0'));
  final _asientos = List.generate(50, (i) => (i + 1).toString().padLeft(2, '0'));

  Future<void> _validarCodigo(String valor) async {
    if (valor.length < 6) {
      setState(() => _validado = false);
      return;
    }
    setState(() => _verificando = true);
    final ok = await context.read<DisenoProvider>().validarCodigo(valor);
    if (!mounted) return;
    setState(() {
      _validado = ok;
      _verificando = false;
    });
  }

  Future<void> _unirse() async {
    final provider = context.read<DisenoProvider>();
    final ok = await provider.unirseConCodigo(
      codigo: _codigoController.text.trim(),
      zona: _zona,
      fila: _fila,
      asiento: _asiento,
    );

    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'No se pudo unir al evento')),
      );
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisenoProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Unirme al evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.music_note, color: AppColors.blue, size: 48),
            const SizedBox(height: 20),
            const Text(
              'Ingresa el código del evento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pídele el código a quien creó el diseño',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.navyMid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _validado ? AppColors.success : AppColors.blue, width: 2),
              ),
              alignment: Alignment.center,
              child: _validado
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          _codigoController.text.toUpperCase().split('').join(' '),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            letterSpacing: 8,
                          ),
                        ),
                      ],
                    )
                  : TextField(
                      controller: _codigoController,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                        letterSpacing: 8,
                      ),
                      inputFormatters: [UpperCaseTextFormatter()],
                      onChanged: _validarCodigo,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
            ),
            if (_verificando) ...[
              const SizedBox(height: 12),
              const CircularProgressIndicator(color: AppColors.blue, strokeWidth: 2),
            ],
            const SizedBox(height: 28),
            if (_validado) ...[
              Row(
                children: [
                  Expanded(child: _buildDropdown('Zona', _zona, _zonas, (v) => setState(() => _zona = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown('Fila', _fila, _filas, (v) => setState(() => _fila = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown('Asiento', _asiento, _asientos, (v) => setState(() => _asiento = v!))),
                ],
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: (_validado && !provider.isLoading) ? _unirse : null,
              child: provider.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Unirme al evento'),
            ),
            const SizedBox(height: 20),
            if (_validado)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.circle, color: AppColors.success, size: 8),
                  SizedBox(width: 8),
                  Text(
                    'Sincronización de luces activada para este evento',
                    style: TextStyle(fontSize: 12, color: AppColors.success),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> opciones, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.navyMid, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.navyMid,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: onChanged,
          items: opciones.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
