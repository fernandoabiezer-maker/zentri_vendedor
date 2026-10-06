import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:zentri_vendedor/models/cliente_deuda.dart';
import 'package:zentri_vendedor/models/abono.dart';
import 'package:zentri_vendedor/services/api_dio.dart';

class CuentasPorCobrarService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  Future<Map<String, dynamic>> obtenerMisDeudores({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'q': search,
      };

      final response = await _dio.get(
        '/api/cuentas_por_cobrar/mis_deudores',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> clientes = data['clientes'] ?? [];
        final deudores = clientes
            .where((c) => (c['deuda_usd'] ?? 0) > 0)
            .map((c) => ClienteDeuda.fromJson(c))
            .toList();
        return {
          'ok': true,
          'data': deudores,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? 1,
          'totalPages': data['total_pages'] ?? 1,
        };
      } else {
        throw Exception('Error al obtener mis deudores: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerTodosDeudores({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'q': search,
      };

      final response = await _dio.get(
        '/api/cuentas_por_cobrar/todos_deudores',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> clientes = data['clientes'] ?? [];
        final deudores = clientes
            .where((c) => (c['deuda_usd'] ?? 0) > 0)
            .map((c) => ClienteDeuda.fromJson(c))
            .toList();
        return {
          'ok': true,
          'data': deudores,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? 1,
          'totalPages': data['total_pages'] ?? 1,
        };
      } else {
        throw Exception('Error al obtener todos los deudores: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ============================================================
  // DETALLE DE DEUDA (con paginación de facturas, planes y abonos)
  // ============================================================
  Future<Map<String, dynamic>> obtenerDetalleDeuda(
    int clienteId, {
    int planPage = 1,
    int planLimit = 5,
    int facturaPage = 1,
    int facturaLimit = 5,
  }) async {
    try {
      final facturaOffset = (facturaPage - 1) * facturaLimit;
      final response = await _dio.get(
        '/api/cuentas_por_cobrar/detalle/$clienteId',
        queryParameters: {
          'plan_page': planPage,
          'plan_limit': planLimit,
          'factura_limit': facturaLimit,
          'factura_offset': facturaOffset,
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Error al obtener detalle de deuda: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerAbonosCliente(
    int clienteId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/cuentas_por_cobrar/abonos/$clienteId',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ok'] == true) {
          final List<dynamic> abonosJson = data['abonos'] ?? [];
          final abonos = abonosJson
              .map((json) => Abono.fromJson(json))
              .toList();
          return {
            'ok': true,
            'abonos': abonos,
            'total': data['total'] ?? 0,
            'page': data['page'] ?? page,
            'totalPages': data['total_pages'] ?? 1,
          };
        }
        return {'ok': false, 'abonos': [], 'total': 0, 'page': page, 'totalPages': 1};
      } else {
        throw Exception('Error al obtener abonos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> registrarAbono({
    required int ventaId,
    required double montoUsd,
    required String metodoPago,
    String? referencia,
    Map<String, double>? pagoMixtoDetalle,
  }) async {
    final data = <String, dynamic>{
      'venta_id': ventaId,
      'monto': montoUsd,
      'metodo_pago': metodoPago,
      if (referencia != null && referencia.isNotEmpty) 'referencia': referencia,
    };

    if (metodoPago == 'mixto' &&
        pagoMixtoDetalle != null &&
        pagoMixtoDetalle.isNotEmpty) {
      data['pago_mixto_detalle'] = pagoMixtoDetalle;
    }

    try {
      final response = await _dio.post(
        '/api/cuentas_por_cobrar/registrar_abono',
        data: jsonEncode(data),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final status = response.statusCode ?? 0;

      if (status == 200 || status == 201) {
        return response.data;
      }

      if (status >= 400 && status < 500) {
        String mensaje = 'Error del servidor ($status)';
        final body = response.data;
        if (body is Map && body['mensaje'] != null) {
          mensaje = body['mensaje'].toString();
        }
        return {
          'ok': false,
          'mensaje': mensaje,
          'status_code': status,
          'validacion': true,
        };
      }

      throw Exception('Error del servidor ($status)');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}