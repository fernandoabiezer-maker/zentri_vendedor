import 'package:dio/dio.dart';
import 'package:zentri_vendedor/services/api_dio.dart';

class ConfiguracionService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  // ============================================================
  // OBTENER CONFIGURACIÓN DE DOCUMENTOS
  // ============================================================
  Future<Map<String, dynamic>> obtenerConfiguracionDocumentos() async {
    try {
      final response = await _dio.get('/api/configuracion/obtener_configuracion_documento');
      return response.data;
    } catch (e) {
      return {
        'color_primario': '#1E40AF',
        'fuente': 'helvetica',
        'tamano_titulo': 16,
        'margen': 12,
        'plantilla_id': 1,
        'titulo': 'FACTURA',
        'subtitulo': 'Documento de Venta',
        'incluir_iva': 1,
        'iva_porcentaje_defecto': 16,
        'mostrar_cliente': 1,
        'prefijo_factura': 'NOT-',
      };
    }
  }

  // ============================================================
  // GUARDAR CONFIGURACIÓN DE DOCUMENTOS
  // ============================================================
  Future<void> guardarConfiguracionDocumentos(Map<String, dynamic> data) async {
    await _dio.post(
      '/api/configuracion/guardar_configuracion_documento',
      data: data,
    );
  }
}