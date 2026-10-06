import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuración centralizada de la URL del backend.
///
/// Multi-tenant: la app pide un "código de empresa" (ej. `hiferco`,
/// `imaginar`) y construye la URL automáticamente:
///   código `hiferco`  →  https://hiferco.sistemazentri.com
///
/// El código se guarda en el almacenamiento seguro del dispositivo.
/// Si no hay código guardado, la app debe mostrar una pantalla para
/// pedirlo (ver `CodigoEmpresaScreen`).
class ApiConfig {
  ApiConfig._();
  static final ApiConfig instance = ApiConfig._();

  static const String _dominioBase = 'sistemazentri.com';
  static const String _storageKey = 'empresa_slug';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _slugCache;
  String? _baseUrlCache;

  /// Código de empresa actual (ej. 'hiferco'), o null si no se ha configurado.
  String? get slug => _slugCache;

  /// True si la app ya tiene una empresa configurada.
  bool get hayEmpresa => _slugCache != null && _slugCache!.isNotEmpty;

  /// URL base del backend (sin barra final). Ej: 'https://hiferco.sistemazentri.com'
  /// Si no hay empresa configurada, devuelve una URL vacía (la app debe
  /// mostrar la pantalla de configuración antes de llamar a la API).
  String get baseUrl {
    if (_baseUrlCache != null) return _baseUrlCache!;
    if (!hayEmpresa) return '';
    _baseUrlCache = 'https://$_slugCache.$_dominioBase';
    return _baseUrlCache!;
  }

  /// Carga la empresa guardada desde el storage. Llamar una vez al inicio
  /// de la app (en `main()` o antes de crear los providers).
  Future<void> cargar() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _slugCache = saved.trim().toLowerCase();
        _baseUrlCache = 'https://$_slugCache.$_dominioBase';
      }
    } catch (_) {
      // Si falla la lectura, queda sin empresa configurada.
    }
  }

  /// Guarda un código de empresa. Valida que solo tenga letras minúsculas,
  /// números y guiones (formato válido para un subdominio).
  Future<bool> guardarEmpresa(String slug) async {
    final limpio = slug.trim().toLowerCase();
    if (limpio.isEmpty) return false;
    if (!RegExp(r'^[a-z0-9][a-z0-9\-]{0,40}$').hasMatch(limpio)) return false;

    await _storage.write(key: _storageKey, value: limpio);
    _slugCache = limpio;
    _baseUrlCache = 'https://$limpio.$_dominioBase';
    return true;
  }

  /// Borra la empresa configurada (para cambiar de cliente).
  Future<void> borrarEmpresa() async {
    await _storage.delete(key: _storageKey);
    _slugCache = null;
    _baseUrlCache = null;
  }

  /// URL completa hacia un endpoint. Ej:
  ///   ApiConfig.instance.url('/api/clientes')  →  'https://hiferco.sistemazentri.com/api/clientes'
  String url(String path) {
    final base = baseUrl;
    if (base.isEmpty) return '';
    final limpio = path.startsWith('/') ? path : '/$path';
    return '$base$limpio';
  }
}