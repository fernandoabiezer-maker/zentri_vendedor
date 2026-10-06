import 'package:dio/dio.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Servicio encargado de resolver enlaces de Google Maps.
///
/// Los enlaces que se comparten desde WhatsApp o desde la app de Google Maps
/// suelen venir en formato **corto** (ej: `https://maps.app.goo.gl/xxxxx`),
/// que la app de Maps no resuelve bien cuando se abre vía intent.
///
/// Este servicio:
/// 1. Detecta si un enlace es corto.
/// 2. Sigue la redirección HTTP para obtener el enlace largo real.
/// 3. Extrae las coordenadas del enlace largo.
/// 4. Devuelve un enlace CANÓNICO del formato `https://maps.google.com/maps?q=LAT,LNG`
///    que sabemos que SIEMPRE funciona al abrirlo en Google Maps.
class UbicacionService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        // User-Agent de navegador móvil para que Google no bloquee la petición
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  /// Devuelve true si el enlace es un enlace corto de Google Maps
  /// (que requiere resolver la redirección).
  static bool esEnlaceCorto(String url) {
    if (url.isEmpty) return false;
    final u = url.toLowerCase();
    return u.contains('maps.app.goo.gl') ||
        u.contains('goo.gl/maps') ||
        u.contains('g.co/kgs') ||
        u.contains('waze.com/ul') ||
        u.contains('waze.com/livemap') ||
        u.contains('maps.apple.com');
  }

  /// Devuelve true si el enlace parece un URL válido http/https.
  static bool esEnlaceValido(String url) {
    if (url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Devuelve true si el enlace ya es un enlace canónico de coordenadas
  /// del estilo `https://maps.google.com/maps?q=LAT,LNG`.
  static bool esEnlaceCanonico(String url) {
    if (url.isEmpty) return false;
    final u = url.toLowerCase();
    return u.contains('maps.google.com/maps?q=') ||
        u.contains('maps.google.com/?q=');
  }

  /// Resuelve un enlace de Google Maps a un enlace canónico con coordenadas.
  ///
  /// - Si el enlace ya es canónico, lo devuelve tal cual.
  /// - Si el enlace es corto, sigue la redirección, extrae coordenadas
  ///   y devuelve un enlace `https://maps.google.com/maps?q=LAT,LNG`.
  /// - Si algo falla (sin internet, formato desconocido), devuelve el enlace
  ///   original sin modificar (para no perder información).
  static Future<String> resolverEnlaceUbicacion(String url) async {
    if (url.isEmpty) return url;
    if (!esEnlaceValido(url)) return url;
    if (esEnlaceCanonico(url)) return url;
    if (!esEnlaceCorto(url)) return url;

    try {
      AppLogger.log('🔗 Resolviendo enlace corto: $url');
      final response = await _dio.get(url);
      final urlFinal = response.realUri.toString();
      AppLogger.log('🔗 Enlace resuelto a: $urlFinal');

      final coords = _extraerCoordenadas(urlFinal);
      if (coords != null) {
        final canonico =
            'https://maps.google.com/maps?q=${coords[0]},${coords[1]}';
        AppLogger.log('✅ Enlace canónico generado: $canonico');
        return canonico;
      }

      // No pudimos extraer coordenadas → devolvemos el enlace largo tal cual
      AppLogger.log('⚠️ No se pudieron extraer coordenadas, usando enlace largo');
      return urlFinal;
    } catch (e) {
      AppLogger.log('❌ Error resolviendo enlace corto: $e');
      // Sin internet o fallo la redirección → devolvemos el original
      return url;
    }
  }

  /// Intenta extraer latitud y longitud de distintas variantes de URL de Google Maps.
  /// Devuelve `[lat, lng]` o `null` si no encuentra coordenadas.
  static List<double>? _extraerCoordenadas(String url) {
    // Formato 1: .../@10.0309216,-69.3970996,17z/...
    final regex1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final match1 = regex1.firstMatch(url);
    if (match1 != null) {
      final lat = double.tryParse(match1.group(1)!);
      final lng = double.tryParse(match1.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Formato 2: ...!3d10.0309216!4d-69.3970996...
    final regex2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final match2 = regex2.firstMatch(url);
    if (match2 != null) {
      final lat = double.tryParse(match2.group(1)!);
      final lng = double.tryParse(match2.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Formato 3: ...?q=10.0309216,-69.3970996...
    final regex3 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final match3 = regex3.firstMatch(url);
    if (match3 != null) {
      final lat = double.tryParse(match3.group(1)!);
      final lng = double.tryParse(match3.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Formato 4: ...?ll=10.0309216,-69.3970996...
    final regex4 = RegExp(r'[?&]ll=(-?\d+\.\d+),(-?\d+\.\d+)');
    final match4 = regex4.firstMatch(url);
    if (match4 != null) {
      final lat = double.tryParse(match4.group(1)!);
      final lng = double.tryParse(match4.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    return null;
  }
}