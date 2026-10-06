import 'package:dio/dio.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/services/api_dio.dart';

class ClienteService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  Future<Map<String, dynamic>> listarClientes({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/api/clientes/',  // ✅ CORREGIDO: antes era /api/configuracion/clientes
        queryParameters: {
          'q': query,
          'page': page,
          'limit': limit,
        },
      );
      final data = response.data;
      return {
        'ok': true,
        'clientes': (data['clientes'] as List)
            .map((j) => Cliente.fromJson(j))
            .toList(),
        'total': data['total'] ?? 0,
        'page': data['page'] ?? 1,
        'limit': data['limit'] ?? limit,
        'totalPages': data['total_pages'] ?? 1,
      };
    } on DioException catch (e) {
      return {
        'ok': false,
        'mensaje': e.response?.data['mensaje'] ?? 'Error de conexión',
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error inesperado: $e'};
    }
  }

  Future<Cliente?> obtenerCliente(int id) async {
    try {
      final response = await _dio.get('/api/clientes/cliente/$id');  // ✅ CORREGIDO
      if (response.data['ok'] == false) return null;
      return Cliente.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<Cliente> crearCliente({
    required String nombre,
    required String cedula,
    String telefono = '',
    String email = '',
    String direccion = '',
    String notas = '',
    int activo = 1,
    int? vendedorId,
    String? ubicacionGps,
  }) async {
    final payload = {
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'notas': notas,
      'activo': activo,
    };
    if (vendedorId != null) {
      payload['vendedor_id'] = vendedorId;
    }
    if (ubicacionGps != null && ubicacionGps.isNotEmpty) {
      payload['ubicacion_gps'] = ubicacionGps;
    }
    final response = await _dio.post(
      '/api/clientes/cliente',  // ✅ CORREGIDO
      data: payload,
    );
    if (response.data['ok'] != true) {
      throw Exception(response.data['mensaje'] ?? 'Error al crear cliente');
    }
    final id = response.data['id'];
    final cliente = await obtenerCliente(id);
    if (cliente == null) throw Exception('No se pudo recuperar el cliente creado');
    return cliente;
  }

  Future<Cliente> actualizarCliente({
    required int id,
    required String nombre,
    required String cedula,
    String telefono = '',
    String email = '',
    String direccion = '',
    String notas = '',
    int activo = 1,
    int? vendedorId,
    String? ubicacionGps,
  }) async {
    final payload = {
      'id': id,
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'notas': notas,
      'activo': activo,
    };
    if (vendedorId != null) {
      payload['vendedor_id'] = vendedorId;
    }
    if (ubicacionGps != null && ubicacionGps.isNotEmpty) {
      payload['ubicacion_gps'] = ubicacionGps;
    }
    final response = await _dio.post(
      '/api/clientes/cliente',  // ✅ CORREGIDO
      data: payload,
    );
    if (response.data['ok'] != true) {
      throw Exception(response.data['mensaje'] ?? 'Error al actualizar cliente');
    }
    final cliente = await obtenerCliente(id);
    if (cliente == null) throw Exception('No se pudo recuperar el cliente actualizado');
    return cliente;
  }

  Future<bool> eliminarCliente(int id) async {
    try {
      final response = await _dio.delete('/api/clientes/cliente/$id');  // ✅ CORREGIDO
      return response.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> obtenerComportamiento(
    int clienteId, {
    int historialPage = 1,
    int historialLimit = 10,
    int facturaPage = 1,
    int facturaLimit = 5,
  }) async {
    try {
      final response = await _dio.get(
        '/api/clientes/cliente_comportamiento/$clienteId',  // ✅ YA ESTÁ BIEN
        queryParameters: {
          'historial_page': historialPage,
          'historial_limit': historialLimit,
          'factura_page': facturaPage,
          'factura_limit': facturaLimit,
          'abono_page': 1,
          'abono_limit': 5,
        },
      );
      if (response.data['ok'] != true) {
        return {'ok': false, 'mensaje': response.data['mensaje'] ?? 'Error'};
      }
      return {
        'ok': true,
        'cliente': Cliente.fromJson(response.data['cliente']),
        'historial': response.data['historial'] ?? [],
        'historialTotal': response.data['historial_total'] ?? 0,
        'historialPage': response.data['historial_page'] ?? 1,
        'historialPages': response.data['historial_pages'] ?? 1,
        'facturas_pendientes': response.data['facturas_pendientes'] ?? [],
        'facturaTotal': response.data['factura_total'] ?? 0,
        'facturaPage': response.data['factura_page'] ?? 1,
        'facturaPages': response.data['factura_pages'] ?? 1,
        'total_deuda_usd': (response.data['total_deuda_usd'] ?? 0.0).toDouble(),
        'total_deuda_bs': (response.data['total_deuda_bs'] ?? 0.0).toDouble(),
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error de conexión: $e'};
    }
  }

  Future<List<Cliente>> buscarClientes(String query) async {
    if (query.isEmpty) return [];
    final result = await listarClientes(query: query, limit: 10);
    if (result['ok'] == true) {
      return result['clientes'] as List<Cliente>;
    }
    return [];
  }
}