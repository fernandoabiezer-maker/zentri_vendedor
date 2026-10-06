import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zentri_vendedor/config/api_config.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Pantalla que se muestra cuando la app no tiene empresa configurada.
/// El usuario ingresa un código corto (slug) y la app construye la URL.
///
/// Ejemplos:
///   "hiferco"  →  https://hiferco.sistemazentri.com
///   "imaginar" →  https://imaginar.sistemazentri.com
class CodigoEmpresaScreen extends StatefulWidget {
  /// Callback que se llama cuando el usuario ya configuró la empresa.
  final VoidCallback onConfigurado;

  const CodigoEmpresaScreen({super.key, required this.onConfigurado});

  @override
  State<CodigoEmpresaScreen> createState() => _CodigoEmpresaScreenState();
}

class _CodigoEmpresaScreenState extends State<CodigoEmpresaScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalizar(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('.sistemazentri.com', '')
        .replaceAll('https://', '')
        .replaceAll('http://', '');
  }

  Future<void> _guardar() async {
    final slug = _normalizar(_controller.text);
    if (slug.isEmpty) {
      setState(() => _error = 'Ingresa un código de empresa');
      return;
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9\-]{0,40}$').hasMatch(slug)) {
      setState(() => _error = 'Solo letras minúsculas, números y guiones');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final ok = await ApiConfig.instance.guardarEmpresa(slug);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar el código';
      });
      return;
    }

    AppLogger.log('✅ [CodigoEmpresa] Configurada empresa: $slug');
    AppLogger.log('✅ [CodigoEmpresa] URL base: ${ApiConfig.instance.baseUrl}');
    widget.onConfigurado();
  }

  @override
  Widget build(BuildContext context) {
    final slugPreview = _normalizar(_controller.text);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.business, size: 60, color: Color(0xFF1e293b)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Configurar empresa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e293b),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa el código de tu empresa.\nEs el mismo del subdominio.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_guardando,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.url,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-\.]')),
                ],
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _guardar(),
                decoration: InputDecoration(
                  labelText: 'Código de empresa',
                  hintText: 'hiferco',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.domain),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              if (slugPreview.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'https://$slugPreview.sistemazentri.com',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf0872d),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}