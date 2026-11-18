import 'package:dio/dio.dart';
import 'package:zentri_vendedor/models/item_carrito.dart';
import 'package:zentri_vendedor/models/venta.dart';
import 'package:zentri_vendedor/services/api_dio.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class VentaService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  Future<Map<String, dynamic>> finalizarVenta({
    required List<ItemCarrito> items,
    required int clienteId,
    required String tipoVenta,
    required String metodoPago,
    required int diasCredito,
    required String referencia,
    required String usuarioNombre,
    String? idLocal,
    Map<String, double>? pagoMixtoDetalle,
    Map<String, dynamic>? planCuotas,
  }) async {
    final payload = {
      'items': items.map((item) => {
        'id': item.productoId,
        'nombre': item.nombre,
        'cantidad': item.cantidad,
        'precio_venta': item.precioParaVenta,
        'costo_actual': 0,
      }).toList(),
      'cliente_id': clienteId,
      'tipo_venta': tipoVenta,
      'dias_credito': diasCredito,
      'metodo_pago': metodoPago,
      'referencia': referencia,
      'usuario_nombre': usuarioNombre,
    };

    // Clave de idempotencia: el servidor puede descartar reintentos duplicados.
    if (idLocal != null && idLocal.isNotEmpty) {
      payload['id_local'] = idLocal;
    }

    // Solo se incluye cuando el pago es mixto y hay desglose.
    if (metodoPago == 'mixto' &&
        pagoMixtoDetalle != null &&
        pagoMixtoDetalle.isNotEmpty) {
      payload['pago_mixto_detalle'] = pagoMixtoDetalle;
    }

    // Solo se incluye cuando hay plan de cuotas activo.
    if (tipoVenta == 'credito' &&
        planCuotas != null &&
        planCuotas['activo'] == true) {
      payload['plan_cuotas'] = planCuotas;
    }

    try {
      final response = await _dio.post('/api/finalizar_venta', data: payload);
      AppLogger.log('✅ [VentaService] Venta completada online');
      return response.data;
    } catch (e) {
      AppLogger.log('❌ [VentaService] Error al finalizar venta: $e');
      return {
        'ok': false,
        'mensaje': 'Error de conexión. Venta guardada localmente.',
        'offline': true,
        'payload': payload,
      };
    }
  }

  Future<Map<String, dynamic>> listarVentas({
    String filtro = 'generales',
    String buscar = '',
    int page = 1,
    int limit = 28,
  }) async {
    try {
      final response = await _dio.get(
        '/api/todas_ventas',
        queryParameters: {
          'filtro': filtro,
          'buscar': buscar,
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data['ok'] == true) {
        return {
          'ok': true,
          'ventas': (data['data'] as List)
              .map((j) => Venta.fromJson(j))
              .toList(),
          'total': data['total'] ?? 0,
          'page': data['page'] ?? 1,
          'totalPages': data['totalPages'] ?? 1,
          'filtro': data['filtro'] ?? filtro,
        };
      } else {
        return {'ok': false, 'mensaje': data['mensaje'] ?? 'Error al cargar ventas'};
      }
    } on DioException catch (e) {
      AppLogger.log('❌ Error en listarVentas: ${e.response?.data}');
      return {
        'ok': false,
        'mensaje': e.response?.data['mensaje'] ?? 'Error de conexión',
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error inesperado: $e'};
    }
  }
}