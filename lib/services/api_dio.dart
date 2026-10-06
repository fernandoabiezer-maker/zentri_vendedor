import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zentri_vendedor/config/api_config.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Navigator global para poder navegar al Login desde el interceptor
/// cuando el server revoca la sesión (401).
final GlobalKey<NavigatorState> zentriNavigatorKey = GlobalKey<NavigatorState>();

/// Bandera global para evitar múltiples redirecciones en cascada
/// cuando varios requests reciben 401 al mismo tiempo.
///
/// IMPORTANTE: NO se resetea con un timer. Solo se resetea cuando el
/// usuario hace login exitoso (ver `marcarLoginExitoso()`). Esto evita
/// un bucle infinito si hay varios providers pidiendo al server al
/// mismo tiempo después del primer 401.
bool _sesionYaRevocada = false;

/// Callback que el main.dart registra para navegar al Login.
/// Se ejecuta cuando el interceptor detecta 401 (sesión revocada).
typedef SesionRevocadaCallback = void Function();
SesionRevocadaCallback? sesionRevocadaCallback;

/// Resetear la bandera (uso interno: llamar al hacer login exitoso).
void marcarLoginExitoso() {
  _sesionYaRevocada = false;
  AppLogger.log('🔓 [ApiDio] Login exitoso. Se permite de nuevo navegar por 401.');
}

/// Cliente Dio compartido por TODA la app.
class ApiDio {
  ApiDio._();
  static final Dio instance = _crear();

  static Dio _crear() {
    final dio = Dio();
    // Nota: el baseUrl se actualiza dinámicamente en cada request
    // (ver onRequest más abajo), porque ApiConfig puede terminar de
    // cargarse DESPUÉS de crear este Dio.
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 20);

    if (kIsWeb) {
      dio.options.extra['withCredentials'] = false;
    }

    final storage = const FlutterSecureStorage();

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // ─────────────────────────────────────────────────────
        // ACTUALIZAR baseUrl EN CADA REQUEST
        // ApiConfig.instance puede no estar cargado cuando este
        // Dio se creó por primera vez. Aquí siempre leemos la URL
        // actual y la aplicamos.
        // ─────────────────────────────────────────────────────
        final baseUrlActual = ApiConfig.instance.baseUrl;
        if (baseUrlActual.isNotEmpty && options.baseUrl != baseUrlActual) {
          options.baseUrl = baseUrlActual;
        }

        final token = await storage.read(key: 'access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final code = error.response?.statusCode;
        final path = error.requestOptions.path;
        final esEndpointAuth =
            path.contains('/login') || path.contains('/logout');

        if (code == 401 && !esEndpointAuth && !_sesionYaRevocada) {
          _sesionYaRevocada = true;
          AppLogger.log(
              '🔒 [ApiDio] 401 detectado en $path. Cerrando sesión local.');

          try {
            await storage.delete(key: 'access_token');
            await storage.delete(key: 'usuario_nombre');
            await storage.delete(key: 'usuario_id');
            await storage.delete(key: 'usuario_rol');
          } catch (_) {}

          try {
            sesionRevocadaCallback?.call();
          } catch (_) {}
        }

        return handler.next(error);
      },
    ));

    return dio;
  }
}