import 'package:zentri_vendedor/main.dart';
import 'package:zentri_vendedor/models/producto.dart';

class ProductoService {
  final ApiClient _api = ApiClient();

  Future<List<Producto>> getProductos() async {
    try {
      final response = await _api.dio.get(
        '/catalogo/api/productos',
        queryParameters: {
          'limit': 9999,
          'offset': 0,
        },
      );
      
      if (response.data['ok'] == true) {
        final List<dynamic> productosJson = response.data['productos'];
        final List<Producto> productos = 
            productosJson.map((json) => Producto.fromJson(json)).toList();
        return productos;
      } else {
        throw Exception('Error al obtener productos: ${response.data['error']}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, double>> getTasas() async {
    try {
      final response = await _api.dio.get('/api/configuracion/obtener_tasas');
      return {
        'bcv': (response.data['bcv'] ?? 0.0).toDouble(),
        'paralelo': (response.data['paralelo'] ?? 0.0).toDouble(),
      };
    } catch (e) {
      throw Exception('Error al obtener tasas: $e');
    }
  }

  Future<Map<String, dynamic>> getConfiguracionDocumento() async {
    try {
      final response = await _api.dio.get('/api/configuracion/obtener_configuracion_documento');
      return response.data;
    } catch (e) {
      throw Exception('Error al obtener configuración de documentos: $e');
    }
  }

  Future<Map<String, dynamic>> getEmpresa() async {
    try {
      final response = await _api.dio.get('/api/configuracion/empresa');
      return response.data;
    } catch (e) {
      throw Exception('Error al obtener datos de empresa: $e');
    }
  }
}