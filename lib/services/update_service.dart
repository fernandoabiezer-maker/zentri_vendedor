import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Servicio de auto-actualización de la app.
///
/// Consulta el repo público de releases en GitHub, compara la versión
/// instalada con la última publicada, y si hay una nueva, la descarga
/// y lanza el instalador de Android.
class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/fernandoabiezer-maker/zentri_vendedor_apk/releases/latest';
  static const String _apkFileName = 'app-release.apk';

  // Throttle: no consultar GitHub más de una vez cada 6 horas.
  static DateTime? _ultimoChequeo;
  static const Duration _intervaloChequeo = Duration(hours: 6);

  /// Verifica si hay una versión nueva disponible.
  /// Devuelve un Map con {version, url} si hay actualización.
  /// Devuelve null si está al día, si hay error, o si ya chequeamos hace poco.
  static Future<Map<String, dynamic>?> verificarActualizacion() async {
    if (_ultimoChequeo != null &&
        DateTime.now().difference(_ultimoChequeo!) < _intervaloChequeo) {
      return null;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final versionActual = info.version;

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 15);

      final respuesta = await dio.get(
        _githubApiUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );

      final tagName = respuesta.data['tag_name'] as String?;
      if (tagName == null) return null;

      final versionRemota =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (!_esVersionMayor(versionRemota, versionActual)) {
        return null;
      }

      final assets = respuesta.data['assets'] as List? ?? [];
      String? urlApk;
      for (final asset in assets) {
        if (asset['name'] == _apkFileName) {
          urlApk = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (urlApk == null) return null;

            _ultimoChequeo = DateTime.now(); // solo si tuvo exito
      AppLogger.log(
          '🔄 [Update] Nueva versión disponible: $versionRemota (actual: $versionActual)');

      return {'version': versionRemota, 'url': urlApk};
    } catch (e) {
      AppLogger.log('❌ [Update] Error verificando actualización: $e');
      return null;
    }
  }

  /// Descarga el APK desde [url] a la carpeta temporal.
  /// Devuelve la ruta local del archivo o null si falla.
  static Future<String?> descargarApk(
    String url, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final destino = File('${dir.path}/$_apkFileName');

      if (await destino.exists()) {
        await destino.delete();
      }

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(minutes: 5);

      await dio.download(url, destino.path, onReceiveProgress: onProgress);

      if (await destino.exists()) {
        return destino.path;
      }
      return null;
    } catch (e) {
      AppLogger.log('❌ [Update] Error descargando APK: $e');
      return null;
    }
  }

  /// Lanza el instalador de Android para el APK en [ruta].
  static Future<bool> instalarApk(String ruta) async {
    try {
      final resultado = await OpenFilex.open(ruta);
      return resultado.type == ResultType.done;
    } catch (e) {
      AppLogger.log('❌ [Update] Error instalando APK: $e');
      return false;
    }
  }

  /// Compara versiones semánticas (X.Y.Z). Devuelve true si [nueva] > [actual].
  static bool _esVersionMayor(String nueva, String actual) {
    try {
      final a = _parseVersion(nueva);
      final b = _parseVersion(actual);
      for (var i = 0; i < 3; i++) {
        if (a[i] > b[i]) return true;
        if (a[i] < b[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static List<int> _parseVersion(String v) {
    final base = v.split('+').first;
    final partes = base.split('.');
    return [
      int.tryParse(partes.isNotEmpty ? partes[0] : '0') ?? 0,
      int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0,
      int.tryParse(partes.length > 2 ? partes[2] : '0') ?? 0,
    ];
  }
}