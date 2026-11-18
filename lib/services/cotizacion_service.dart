import 'package:dio/dio.dart';
import 'package:zentri_vendedor/models/cotizacion.dart';
import 'package:zentri_vendedor/models/item_cotizacion.dart';
import 'package:zentri_vendedor/services/api_dio.dart';
import 'dart:convert';

class CotizacionService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  Future<Map<String, dynamic>> listarCotizaciones({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get('/api/cotizaciones');
      final data = response.data;
      if (data['ok'] == true) {
        final List<dynamic> cotizacionesData = data['data'] ?? [];
        final List<Cotizacion> cotizaciones = cotizacionesData
            .map((json) => Cotizacion.fromJson(json))
            .toList();
        return {
          'ok': true,
          'cotizaciones': cotizaciones,
          'total': data['total'] ?? cotizaciones.length,
          'page': page,
          'totalPages': 1,
        };
      } else {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'Error al cargar cotizaciones',
        };
      }
    } on DioException catch (e) {
      print('❌ Error en listarCotizaciones: ${e.response?.data}');
      return {
        'ok': false,
        'mensaje': e.response?.data['mensaje'] ?? 'Error de conexión',
      };
    } catch (e) {
      print('❌ Error inesperado: $e');
      return {'ok': false, 'mensaje': 'Error inesperado: $e'};
    }
  }

  Future<Cotizacion?> obtenerCotizacion(int id) async {
    try {
      final response = await _dio.get('/api/cotizacion/$id');
      final data = response.data;
      if (data['ok'] == true && data['data'] != null) {
        return Cotizacion.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('❌ Error en obtenerCotizacion: $e');
      return null;
    }
  }

  // ✅ SOLO AÑADIDO: PARÁMETRO vendedorId
  Future<Map<String, dynamic>> guardarCotizacion({
    required String cliente,
    String? clienteRif,
    int? clienteId,
    required String tipoVenta,
    required double margenGlobal,
    required String moneda,
    required double tasaBcv,
    required double tasaParalelo,
    required double ivaPorcentaje,
    required String metodoPago,
    required List<ItemCotizacion> items,
    int? vendedorId, // <-- NUEVO
  }) async {
    try {
      final payload = {
        'cliente': cliente,
        'cliente_rif': clienteRif,
        'cliente_id': clienteId,
        'tipo_venta': tipoVenta,
        'margen_global': margenGlobal,
        'moneda': moneda,
        'tasa_bcv': tasaBcv,
        'tasa_paralelo': tasaParalelo,
        'iva_porcentaje': ivaPorcentaje,
        'metodo_pago': metodoPago,
        'items': items.map((i) => {
          'id': i.id,
          'nombre': i.nombre,
          'codigo': i.codigo,
          'cantidad': i.cantidad,
          'precio_unitario': i.precioParaVenta,
          'precio_final': i.precioUnitario,
          'imagen': i.imagen,
        }).toList(),
      };
      // ✅ SOLO AÑADIDO: incluir vendedorId en payload si existe
      if (vendedorId != null) {
        payload['vendedor_id'] = vendedorId;
      }

      final response = await _dio.post(
        '/api/guardar_cotizacion',
        data: payload,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'ok': false,
        'mensaje': e.response?.data['mensaje'] ?? 'Error al guardar cotización',
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error inesperado: $e'};
    }
  }

  // ✅ SOLO AÑADIDO: PARÁMETRO vendedorId
  Future<Map<String, dynamic>> actualizarCotizacion({
    required int id,
    required String cliente,
    String? clienteRif,
    int? clienteId,
    required String tipoVenta,
    required double margenGlobal,
    required String moneda,
    required double tasaBcv,
    required double tasaParalelo,
    required double ivaPorcentaje,
    required String metodoPago,
    required List<ItemCotizacion> items,
    int? vendedorId, // <-- NUEVO
  }) async {
    try {
      final payload = {
        'id': id,
        'cliente': cliente,
        'cliente_rif': clienteRif,
        'cliente_id': clienteId,
        'tipo_venta': tipoVenta,
        'margen_global': margenGlobal,
        'moneda': moneda,
        'tasa_bcv': tasaBcv,
        'tasa_paralelo': tasaParalelo,
        'iva_porcentaje': ivaPorcentaje,
        'metodo_pago': metodoPago,
        'items': items.map((i) => {
          'id': i.id,
          'nombre': i.nombre,
          'codigo': i.codigo,
          'cantidad': i.cantidad,
          'precio_unitario': i.precioParaVenta,
          'precio_final': i.precioUnitario,
          'imagen': i.imagen,
        }).toList(),
      };
      // ✅ SOLO AÑADIDO: incluir vendedorId en payload si existe
      if (vendedorId != null) {
        payload['vendedor_id'] = vendedorId;
      }

      final response = await _dio.post(
        '/api/actualizar_cotizacion',
        data: payload,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'ok': false,
        'mensaje': e.response?.data['mensaje'] ?? 'Error al actualizar cotización',
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error inesperado: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarCotizacion(int id) async {
    try {
      final response = await _dio.post(
        '/api/eliminar_cotizacion',
        data: {'id': id},
      );
      return response.data;
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error al eliminar cotización: $e'};
    }
  }

  Future<Map<String, dynamic>> convertirAVenta({
    required int cotizacionId,
    required String metodoPago,
  }) async {
    try {
      final response = await _dio.post(
        '/api/cotizacion_convertir/$cotizacionId',
        data: {'metodo_pago': metodoPago},
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'ok': false,
        'mensaje': e.response?.data['mensaje'] ?? 'Error al convertir cotización',
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error inesperado: $e'};
    }
  }

  Future<Response> generarPDF(int id) async {
    return await _dio.get(
      '/api/cotizacion_pdf/$id',
      options: Options(responseType: ResponseType.bytes),
    );
  }
}