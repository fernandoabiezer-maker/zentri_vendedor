import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _token;
  int? _usuarioId;
  String? _nombre;
  String? _rol;
  String? _fotoBase64;
  bool _initialized = false;

  String? get token => _token;
  int? get usuarioId => _usuarioId;
  String? get nombre => _nombre;
  String? get rol => _rol;
  String? get fotoBase64 => _fotoBase64;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isInitialized => _initialized;

  bool get tokenValid {
    if (_token == null || _token!.isEmpty) return false;
    try {
      final decoded = JwtDecoder.decode(_token!);
      final exp = decoded['exp'] as int?;
      if (exp == null) return true;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  AuthProvider() {
    _cargarSesion().then((_) {
      _initialized = true;
      notifyListeners();
    });
  }

  String _limpiarBase64(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');
  }

  Future<void> _cargarSesion() async {
    try {
      _token = await _storage.read(key: 'access_token');
      final usuarioId = await _storage.read(key: 'usuario_id');
      _usuarioId = usuarioId != null ? int.tryParse(usuarioId) : null;
      _nombre = await _storage.read(key: 'usuario_nombre');
      _rol = await _storage.read(key: 'usuario_rol');
      final foto = await _storage.read(key: 'usuario_foto');
      _fotoBase64 = _limpiarBase64(foto);
    } catch (e) {
      print('❌ Error cargando sesión: $e');
    }
  }

  Future<void> setSesion({
    required String token,
    required int usuarioId,
    required String nombre,
    required String rol,
    String? fotoBase64,
  }) async {
    final fotoLimpia = _limpiarBase64(fotoBase64);

    await _storage.write(key: 'access_token', value: token);
    await _storage.write(key: 'usuario_id', value: usuarioId.toString());
    await _storage.write(key: 'usuario_nombre', value: nombre);
    await _storage.write(key: 'usuario_rol', value: rol);
    if (fotoLimpia.isNotEmpty) {
      await _storage.write(key: 'usuario_foto', value: fotoLimpia);
    }

    _token = token;
    _usuarioId = usuarioId;
    _nombre = nombre;
    _rol = rol;
    _fotoBase64 = fotoLimpia;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'usuario_id');
    await _storage.delete(key: 'usuario_nombre');
    await _storage.delete(key: 'usuario_rol');
    await _storage.delete(key: 'usuario_foto');

    _token = null;
    _usuarioId = null;
    _nombre = null;
    _rol = null;
    _fotoBase64 = null;
    notifyListeners();
  }

  Future<bool> autenticarConBiometria() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Desbloquea la app para continuar',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print('❌ Error en autenticación biométrica: $e');
      return false;
    }
  }

  Future<bool> tieneHuellaRegistrada() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.contains(BiometricType.fingerprint);
    } catch (e) {
      return false;
    }
  }
}