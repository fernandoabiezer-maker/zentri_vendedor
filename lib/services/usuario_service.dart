import 'package:dio/dio.dart';
import 'package:zentri_vendedor/models/usuario.dart';
import 'package:zentri_vendedor/services/api_dio.dart';

class UsuarioService {
  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  // Obtener usuario actual (desde sesión o JWT)
  Future<Usuario?> obtenerUsuarioActual() async {
    try {
      final response = await _dio.get('/api/configuracion/verificar_sesion');
      if (response.data['ok'] == true) {
        final userJson = response.data['usuario'];
        return Usuario.fromJson(userJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Listar vendedores (para admin)
  Future<List<Map<String, dynamic>>> listarVendedores() async {
    try {
      final response = await _dio.get('/api/configuracion/vendedores');
      if (response.data['ok'] == true) {
        return List<Map<String, dynamic>>.from(response.data['vendedores']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}