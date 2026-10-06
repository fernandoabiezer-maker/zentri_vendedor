import 'package:dio/dio.dart';
import 'package:zentri_vendedor/services/api_dio.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Llama al endpoint /api/alertas/cobros_pendientes del backend Flask.
/// Devuelve cuotas vencidas, por vencer y créditos directos.
class NotificacionesCobroService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

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