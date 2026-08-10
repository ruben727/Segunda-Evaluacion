import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Texto completo del Aviso de Privacidad mostrado en el registro.
const String _avisoPrivacidadTexto = '''
Concertx ("nosotros") es responsable del tratamiento de tus datos personales conforme a este Aviso de Privacidad.

1. Datos que recabamos
Al crear tu cuenta recabamos tu nombre completo, correo electrónico, teléfono y contraseña (esta última se almacena cifrada, nunca en texto plano). Durante el uso del servicio, si vinculas un smartwatch por Bluetooth, también se procesan datos de salud generados por el reloj (ritmo cardiaco y oxígeno en sangre) únicamente para sincronizar los efectos de luces y vibración del show.

2. Finalidades
Usamos tus datos para: crear y administrar tu cuenta, generar y validar los códigos de acceso a eventos, sincronizar tu teléfono y reloj con la pantalla del recinto en tiempo real, y comunicarnos contigo sobre el servicio.

3. Datos de salud
Los datos de ritmo cardiaco y oxígeno se usan solo mientras el evento está activo, para animar los efectos visuales; no se comparten con anunciantes ni se utilizan con fines médicos o de diagnóstico.

4. Compartición de datos
No vendemos ni transferimos tus datos personales a terceros con fines comerciales. Solo se comparten con proveedores de infraestructura estrictamente necesarios para operar el servicio (por ejemplo, hosting de base de datos), bajo obligaciones de confidencialidad.

5. Derechos ARCO
Puedes solicitar en cualquier momento el Acceso, Rectificación, Cancelación u Oposición (ARCO) al tratamiento de tus datos, así como revocar tu consentimiento, escribiendo a privacidad@concertx.app.

6. Seguridad
Aplicamos medidas técnicas razonables (contraseñas cifradas, tokens de sesión) para proteger tu información contra accesos no autorizados.

7. Cambios a este aviso
Cualquier cambio a este Aviso de Privacidad se notificará dentro de la app antes de que entre en vigor.

Al marcar la casilla "Acepto el Aviso de Privacidad" confirmas que leíste y entendiste este documento.
''';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmarVisible = false;
  bool _aceptaPrivacidad = false;

  late final TapGestureRecognizer _tapAvisoPrivacidad;

  final _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  final _passwordRegExp = RegExp(r'^(?=.*[A-Z])(?=.*\d).{8,}$');

  @override
  void initState() {
    super.initState();
    _tapAvisoPrivacidad = TapGestureRecognizer()..onTap = _mostrarAvisoPrivacidad;
  }

  /// Muestra el Aviso de Privacidad completo en un diálogo desplazable,
  /// para que se pueda leer entero (no solo aceptar la casilla).
  void _mostrarAvisoPrivacidad() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aviso de Privacidad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: Text(
                        _avisoPrivacidadTexto.trim(),
                        style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_aceptaPrivacidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar el Aviso de Privacidad')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      nombre: _nombreController.text.trim(),
      correo: _correoController.text.trim(),
      telefono: _telefonoController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'No se pudo crear la cuenta')),
      );
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    _tapAvisoPrivacidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Únete a Concertx',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Crea tu cuenta gratuita',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nombreController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Ingresa tu nombre completo' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                  ),
                  validator: (v) =>
                      (v == null || !_emailRegExp.hasMatch(v.trim())) ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                  ),
                  validator: (v) {
                    final digitos = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digitos.length < 10 || digitos.length > 13) {
                      return 'El teléfono debe tener entre 10 y 13 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  validator: (v) => (v == null || !_passwordRegExp.hasMatch(v))
                      ? 'Mínimo 8 caracteres, con mayúscula y número'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmarController,
                  obscureText: !_confirmarVisible,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmarVisible ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _confirmarVisible = !_confirmarVisible),
                    ),
                  ),
                  validator: (v) => v != _passwordController.text ? 'Las contraseñas no coinciden' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _aceptaPrivacidad,
                      activeColor: AppColors.blue,
                      onChanged: (v) => setState(() => _aceptaPrivacidad = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                children: [
                                  const TextSpan(text: 'Acepto el '),
                                  TextSpan(
                                    text: 'Aviso de Privacidad',
                                    style: const TextStyle(
                                      color: AppColors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: _tapAvisoPrivacidad,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: _mostrarAvisoPrivacidad,
                              child: const Text(
                                'Leer completo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        children: [
                          TextSpan(text: '¿Ya tienes cuenta? '),
                          TextSpan(
                            text: 'Inicia sesión',
                            style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
