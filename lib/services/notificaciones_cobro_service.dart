import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zentri_vendedor/config/api_config.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Llama al endpoint /api/alertas/cobros_pendientes del backend Flask.
/// Devuelve cuotas vencidas, por vencer y créditos directos.
class NotificacionesCobroService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  NotificacionesCobroService() {
    _dio.options.baseUrl = ApiConfig.instance.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
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

  /// diasAviso = días de anticipación para "por vencer" (default 3, max 30).
  Future<Map<String, dynamic>> obtenerCobrosPendientes({
    int diasAviso = 3,
  }) async {
    try {
      final response = await _dio.get(
        '/api/alertas/cobros_pendientes',
        queryParameters: {
          'dias_aviso': diasAviso,
          '_': DateTime.now().millisecondsSinceEpoch,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'ok': false, 'mensaje': 'Respuesta inválida del servidor'};
    } catch (e) {
      AppLogger.log('❌ [NotificacionesCobroService] Error: $e');
      return {'ok': false, 'mensaje': 'Error de conexión: $e'};
    }
  }
}