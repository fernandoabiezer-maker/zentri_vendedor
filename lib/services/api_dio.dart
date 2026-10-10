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
bool _sesionYaRevocada = false;

/// Bandera global para evitar múltiples redirecciones cuando el
/// cliente está suspendido por falta de pago. El backend devuelve
/// 200 con {suspendido: true} en TODAS las rutas /api/*.
bool _suspendidoDetectado = false;

/// Callback que el main.dart registra para navegar al Login.
/// Se ejecuta cuando el interceptor detecta 401 (sesión revocada).
typedef SesionRevocadaCallback = void Function();
SesionRevocadaCallback? sesionRevocadaCallback;

/// Callback que el main.dart registra para navegar a la pantalla de
/// suspensión. Se ejecuta cuando el interceptor detecta suspendido: true.
typedef SuspendidoCallback = void Function();
SuspendidoCallback? suspendidoCallback;

/// Resetear las banderas (uso interno: llamar al hacer login exitoso).
void marcarLoginExitoso() {
  _sesionYaRevocada = false;
  _suspendidoDetectado = false;
  AppLogger.log('🔓 [ApiDio] Login exitoso. Banderas reseteadas.');
}

/// Verificar si ya se detectó suspensión (para evitar redirigir varias veces).
bool get suspendidoDetectado => _suspendidoDetectado;

/// Cliente Dio compartido por TODA la app.
class ApiDio {
  ApiDio._();
  static final Dio instance = _crear();

  static Dio _crear() {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 20);

    if (kIsWeb) {
      dio.options.extra['withCredentials'] = false;
    }

    final storage = const FlutterSecureStorage();

    /// Helper que revisa si la respuesta indica suspensión y dispara
    /// el callback una sola vez.
    void _revisarSuspension(dynamic data) {
      if (_suspendidoDetectado) return;
      if (data is Map && data['suspendido'] == true) {
        _suspendidoDetectado = true;
        AppLogger.log('🔒 [ApiDio] Suspensión detectada. Redirigiendo.');
        try {
          suspendidoCallback?.call();
        } catch (_) {}
      }
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // ──────────────────────────────────────────────────────────
        // ACTUALIZAR baseUrl EN CADA REQUEST
        // ──────────────────────────────────────────────────────────
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

      onResponse: (response, handler) async {
        // El backend devuelve 200 con {suspendido: true} cuando el
        // cliente está suspendido. Detectarlo y disparar callback.
        _revisarSuspension(response.data);
        return handler.next(response);
      },

      onError: (error, handler) async {
        final code = error.response?.statusCode;
        final path = error.requestOptions.path;
        final esEndpointAuth =
            path.contains('/login') || path.contains('/logout');

        // Suspensión puede venir también como error en algunas rutas.
        _revisarSuspension(error.response?.data);

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