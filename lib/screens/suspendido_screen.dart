import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de bloqueo cuando el cliente está suspendido por falta de pago.
/// Se muestra al detectar {suspendido: true} en cualquier respuesta del backend.
class SuspendidoScreen extends StatelessWidget {
  const SuspendidoScreen({super.key});

  static const String _whatsappNumero = '584126461391';
  static const String _whatsappMensaje =
      'Hola, necesito reactivar mi servicio Zentri.';

  Future<void> _abrirWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/$_whatsappNumero?text=${Uri.encodeComponent(_whatsappMensaje)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🔒',
                    style: TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Servicio temporalmente suspendido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'El acceso a esta aplicación está temporalmente inactivo '
                    'por actualización de cuenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Por favor contacte a soporte técnico para reactivar '
                    'su servicio a la brevedad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _abrirWhatsApp,
                      icon: const Icon(Icons.chat_bubble, color: Colors.white),
                      label: const Text(
                        'Contactar por WhatsApp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Zentri — Gestor PyME',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}