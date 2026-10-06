import 'package:zentri_vendedor/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zentri_vendedor/models/usuario.dart';

class UsuarioService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UsuarioService() {
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