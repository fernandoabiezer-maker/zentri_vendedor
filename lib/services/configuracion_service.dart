import 'package:zentri_vendedor/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConfiguracionService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ConfiguracionService() {
    _dio.options.baseUrl = ApiConfig.instance.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

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