import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:zentri_vendedor/screens/catalogo_screen.dart';
import 'package:zentri_vendedor/screens/sync_queue_screen.dart';
import 'package:zentri_vendedor/screens/carrito_screen.dart';
import 'package:zentri_vendedor/screens/checkout_screen.dart';
import 'package:zentri_vendedor/screens/clientes_screen.dart';
import 'package:zentri_vendedor/screens/cliente_form_screen.dart';
import 'package:zentri_vendedor/screens/cliente_detail_screen.dart';
import 'package:zentri_vendedor/screens/historial_ventas_screen.dart';
import 'package:zentri_vendedor/screens/cotizaciones_screen.dart';
import 'package:zentri_vendedor/screens/cotizacion_form_screen.dart';
import 'package:zentri_vendedor/screens/cotizacion_detail_screen.dart';
import 'package:zentri_vendedor/screens/cuentas_por_cobrar_screen.dart';
import 'package:zentri_vendedor/screens/cuentas_por_cobrar_detail_screen.dart';
import 'package:zentri_vendedor/providers/carrito_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/providers/configuracion_provider.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/services/connection_watcher.dart';
import 'package:zentri_vendedor/services/api_dio.dart';
import 'package:zentri_vendedor/config/api_config.dart';
import 'package:zentri_vendedor/screens/codigo_empresa_screen.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/providers/auth_provider.dart';
import 'package:zentri_vendedor/providers/venta_provider.dart';
import 'package:zentri_vendedor/providers/cotizacion_provider.dart';
import 'package:zentri_vendedor/providers/cuentas_por_cobrar_provider.dart';
import 'package:zentri_vendedor/providers/notificaciones_cobro_provider.dart';
import 'package:zentri_vendedor/providers/producto_provider.dart';
import 'package:zentri_vendedor/utils/logger.dart';
import 'package:zentri_vendedor/screens/home_screen.dart';
import 'package:zentri_vendedor/screens/suspendido_screen.dart';


// ============================================================
// EXCEPCIÓN: CREDENCIALES INVÁLIDAS (401 del server)
// Se distingue de errores de red para NO usar el fallback offline.
// ============================================================
class CredencialesInvalidasException implements Exception {
  final String mensaje;
  CredencialesInvalidasException(this.mensaje);
  @override
  String toString() => mensaje;
}

// ============================================================
// MODELO DE USUARIO
// ============================================================
class Usuario {
  final int id;
  final String nombre;
  final String rol;
  final String? fotoBase64;
  final List<String> permisos;

  Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    this.fotoBase64,
    this.permisos = const [],
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nombre: json['nombre'],
      rol: json['rol'],
      fotoBase64: json['foto_base64'],
      permisos: List<String>.from(json['permisos'] ?? []),
    );
  }
}

// ============================================================
// API CLIENT (GESTIÓN DE TOKENS Y LOGIN)
// Usa el Dio compartido de toda la app (ApiDio.instance).
// ============================================================
class ApiClient {
  final Dio dio = ApiDio.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient();

  Future<void> guardarToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> guardarNombreUsuario(String nombre) async {
    await _storage.write(key: 'usuario_nombre', value: nombre);
  }

  Future<void> guardarUsuarioId(int id) async {
    await _storage.write(key: 'usuario_id', value: id.toString());
  }

  Future<void> guardarRol(String rol) async {
    await _storage.write(key: 'usuario_rol', value: rol);
  }

  Future<void> guardarCredenciales(String user, String pass) async {
    await _storage.write(key: 'offline_user', value: user);
    await _storage.write(key: 'offline_pass', value: pass);
  }

  Future<Map<String, String?>> obtenerCredenciales() async {
    final user = await _storage.read(key: 'offline_user');
    final pass = await _storage.read(key: 'offline_pass');
    return {'user': user, 'pass': pass};
  }

  Future<void> eliminarCredenciales() async {
    await _storage.delete(key: 'offline_user');
    await _storage.delete(key: 'offline_pass');
  }

  Future<void> eliminarToken() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'usuario_nombre');
    await _storage.delete(key: 'usuario_id');
    await _storage.delete(key: 'usuario_rol');
    await eliminarCredenciales();
  }

  Future<String?> obtenerToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<Usuario?> login(String username, String password) async {
    try {
      final response = await dio.post(
        '/api/configuracion/login',
        data: {'username': username, 'password': password},
      );

      if (response.data['ok'] == true) {
        final token = response.data['access_token'];
        await guardarToken(token);

        final userJson = response.data['usuario'];
        final usuario = Usuario.fromJson(userJson);

        await guardarNombreUsuario(usuario.nombre);
        await guardarUsuarioId(usuario.id);
        await guardarRol(usuario.rol);
        await guardarCredenciales(username, password);

        return usuario;
      } else {
        throw CredencialesInvalidasException(
          (response.data['mensaje'] ?? 'Usuario o contraseña incorrectos')
              .toString(),
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        final data = e.response?.data;
        final msg = (data is Map && data['mensaje'] != null)
            ? data['mensaje'].toString()
            : 'Usuario o contraseña incorrectos';
        throw CredencialesInvalidasException(msg);
      }
      throw Exception('Error de conexión: $e');
    } on CredencialesInvalidasException {
      rethrow;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Usuario?> verificarSesion() async {
    try {
      final token = await obtenerToken();
      if (token == null) return null;
      final response = await dio.get('/api/configuracion/verificar_sesion');
      if (response.data['ok'] == true) {
        final userJson = response.data['usuario'];
        return Usuario.fromJson(userJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await eliminarToken();
    try {
      await dio.post('/api/configuracion/logout');
    } catch (e) {
      // Ignorar
    }
  }
}

// ============================================================
// PANTALLA DE LOGIN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _biometricAvailable = false;
  bool _mostrarFormularioManual = false;
  bool _mostrarDiagnostico = false;

  String _diagnostico = '';
  String _biometricError = '';

  final ApiClient _api = ApiClient();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAvailability();
      _cargarLogo();
      _validarSesionLocal();
    });
  }

  Future<void> _validarSesionLocal() async {
    final authProvider = context.read<AuthProvider>();
    final tokenEnStorage = await _api.obtenerToken();

    // Caso 1: hay sesión en memoria pero el token ya no es válido.
    if (authProvider.isAuthenticated && !authProvider.tokenValid) {
      await authProvider.logout();
      await _api.eliminarCredenciales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Caso 2: hay sesión en memoria PERO el storage no tiene token.
    // Esto pasa cuando el interceptor borró el token tras un 401 pero
    // el AuthProvider en memoria seguía diciendo "autenticado".
    if (authProvider.isAuthenticated &&
        (tokenEnStorage == null || tokenEnStorage.isEmpty)) {
      AppLogger.log(
          '🔒 [LoginScreen] Sesión fantasma detectada. Limpiando AuthProvider.');
      await authProvider.logout();
      if (mounted) {
        setState(() => _mostrarFormularioManual = true);
      }
    }
  }

  Future<void> _checkBiometricAvailability() async {
    if (kIsWeb) {
      setState(() {
        _biometricAvailable = false;
        _biometricError = 'No soportada en web';
      });
      return;
    }
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        setState(() {
          _biometricAvailable = false;
          _biometricError = 'El dispositivo no soporta biometría';
        });
        return;
      }
      final available = await _localAuth.getAvailableBiometrics();
      final hasFingerprint = available.contains(BiometricType.fingerprint) ||
                             available.contains(BiometricType.strong) ||
                             available.contains(BiometricType.weak);
      setState(() {
        _biometricAvailable = hasFingerprint || available.isNotEmpty;
        _biometricError = hasFingerprint ? '' : 'No se detectó huella específica';
      });
    } catch (e) {
      setState(() {
        _biometricAvailable = false;
        _biometricError = 'Error: $e';
      });
    }
  }

  Future<void> _cargarLogo() async {
    await context.read<ConfiguracionProvider>().cargarEmpresa();
  }

  Future<void> _cerrarSesion() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    await _api.logout();
    _usernameController.clear();
    _passwordController.clear();
    setState(() => _mostrarFormularioManual = true);
  }

  Future<void> _cargarDatosIniciales() async {
    await context.read<ProductoProvider>().cargarProductos(forceRefresh: false);
    await context.read<ConfiguracionProvider>().cargarConfiguracion(forceRefresh: false);
    await context.read<TasasProvider>().cargarTasas(forceRefresh: false);
    await context.read<SyncProvider>().cargarPendientes();
    await context.read<ClienteProvider>().cargarClientes(forceRefresh: false);
    await context.read<VentaProvider>().cargarTodo(forceRefresh: false);
    await context.read<CotizacionProvider>().cargarCotizaciones(forceRefresh: false);
    await context.read<CuentasPorCobrarProvider>().cargarMisDeudores(forceRefresh: false);
  }

  Future<void> _cargarDatosPostLogin() async {
    await context.read<ConfiguracionProvider>().cargarEmpresa();
    await context.read<ProductoProvider>().sincronizar();
    await context.read<ConfiguracionProvider>().sincronizar();
    await context.read<TasasProvider>().sincronizar();
    await context.read<ClienteProvider>().sincronizar();
    await context.read<VentaProvider>().sincronizarTodo();
    await context.read<CotizacionProvider>().sincronizarTodo();
    await context.read<CuentasPorCobrarProvider>().sincronizarTodo();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = _usernameController.text;
    final pass = _passwordController.text;

    try {
      final usuario = await _api.login(user, pass);
      if (usuario != null && mounted) {
        final authProvider = context.read<AuthProvider>();
        final token = await _api.obtenerToken() ?? '';
        await authProvider.setSesion(
          token: token,
          usuarioId: usuario.id,
          nombre: usuario.nombre,
          rol: usuario.rol,
          fotoBase64: usuario.fotoBase64,
        );
        marcarLoginExitoso();
        await _cargarDatosPostLogin();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on CredencialesInvalidasException catch (e) {
      await _api.eliminarCredenciales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.mensaje),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      final creds = await _api.obtenerCredenciales();
      final savedUser = creds['user'];
      final savedPass = creds['pass'];

      if (savedUser != null && savedPass != null && savedUser == user && savedPass == pass) {
        await _cargarDatosIniciales();
        if (mounted) {
          marcarLoginExitoso();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión a internet o credenciales incorrectas.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autenticarConBiometria() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometría no soportada en web'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    // PRIMERO: validar que el token existe en el storage (no solo en memoria).
    // Si el interceptor lo borró tras un 401, la huella no debe dejar entrar.
    final tokenEnStorage = await _api.obtenerToken();
    if (tokenEnStorage == null || tokenEnStorage.isEmpty) {
      await authProvider.logout();
      if (mounted) {
        setState(() => _mostrarFormularioManual = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión expirada. Inicia sesión con tu contraseña.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!authProvider.isAuthenticated || !authProvider.tokenValid) {
      await _validarSesionLocal();
      if (mounted) {
        setState(() => _mostrarFormularioManual = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión expirada. Inicia sesión con tu contraseña.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isBiometricLoading = true);
    bool exito = false;
    try {
      exito = await authProvider.autenticarConBiometria();
    } catch (e) {
      // silencioso
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }

    if (exito && mounted) {
      await _cargarDatosIniciales();
      if (mounted) {
        marcarLoginExitoso();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Huella cancelada o no reconocida. Usa tu contraseña.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() => _mostrarFormularioManual = true);
    }
  }

  // ============================================================
  // UI
  // ============================================================
  Widget _buildTarjetaUsuarioGuardado(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: (authProvider.fotoBase64 != null && authProvider.fotoBase64!.isNotEmpty)
                ? MemoryImage(base64Decode(authProvider.fotoBase64!))
                : null,
            child: (authProvider.fotoBase64 == null || authProvider.fotoBase64!.isEmpty)
                ? const Icon(Icons.person, size: 35, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 12),
          Text('¡Hola de nuevo!', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          Text(authProvider.nombre ?? 'Vendedor',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_biometricAvailable) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isBiometricLoading ? null : _autenticarConBiometria,
                icon: _isBiometricLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.fingerprint, size: 24),
                label: Text(_isBiometricLoading ? 'Abriendo escáner...' : 'Desbloquear con huella',
                    style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e293b),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('No se detectó huella. Usa tu contraseña.\nError: $_biometricError',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton(
              onPressed: () => setState(() => _mostrarFormularioManual = true),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Usar contraseña', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() => _mostrarFormularioManual = true);
              _cerrarSesion();
            },
            child: const Text('Iniciar con otro usuario', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioManual() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Usuario',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.lock),
            ),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf0872d),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Iniciar sesión',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _mostrarFormularioManual = false;
              });
            },
            child: const Text('Volver', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tieneSesionValida = authProvider.isAuthenticated && authProvider.tokenValid;
    final mostrarFormulario = _mostrarFormularioManual || !tieneSesionValida;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Consumer<ConfiguracionProvider>(
                builder: (context, configProvider, _) {
                  final logo = configProvider.logoBase64;
                  return Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: logo != null && logo.isNotEmpty
                          ? Image.memory(base64Decode(logo), fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.storefront, size: 60, color: Colors.grey))
                          : const Icon(Icons.storefront, size: 60, color: Colors.grey),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('Zentri',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
              const Text('Vendedor', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),
              if (tieneSesionValida && !mostrarFormulario)
                _buildTarjetaUsuarioGuardado(authProvider)
              else
                _buildFormularioManual(),
              const SizedBox(height: 16),
              if (kDebugMode)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _mostrarDiagnostico = !_mostrarDiagnostico;
                      if (_mostrarDiagnostico) {
                        final auth = context.read<AuthProvider>();
                        _diagnostico = '''
📊 DIAGNÓSTICO:
• Sesión: ${auth.isAuthenticated ? "SÍ" : "NO"}
• Token válido: ${auth.tokenValid ? "SÍ" : "NO"}
• Usuario: ${auth.nombre ?? "N/A"}
• Biometría disponible: $_biometricAvailable
• Error biometría: $_biometricError
• Inicializado: ${auth.isInitialized ? "SÍ" : "NO"}
• Token guardado: ${auth.token != null ? "SÍ (${auth.token!.substring(0, 10)}...)" : "NO"}
• Platform: ${kIsWeb ? "Web" : "Móvil"}
''';
                      }
                    });
                  },
                  icon: const Icon(Icons.bug_report, size: 18),
                  label: const Text('Diagnóstico'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                ),
              if (kDebugMode && _mostrarDiagnostico)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _diagnostico,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Versión 1.0.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Cambiar empresa'),
                onPressed: () async {
                  try {
                    await context.read<AuthProvider>().logout();
                    await _api.logout();
                  } catch (_) {}
                  await ApiConfig.instance.borrarEmpresa();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CodigoEmpresaScreen(
                        onConfigurado: (ctx) {
                          Navigator.of(ctx).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.instance.cargar();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CarritoProvider()),
        ChangeNotifierProvider(create: (_) => ProductoProvider()..cargarProductos(forceRefresh: false)),
        ChangeNotifierProvider(create: (_) => TasasProvider()..cargarTasas(forceRefresh: false)),
        ChangeNotifierProvider(create: (_) => ConfiguracionProvider()..cargarConfiguracion(forceRefresh: false)),
        ChangeNotifierProvider(create: (_) => SyncProvider()..cargarPendientes()),
        ChangeNotifierProvider(create: (_) => ClienteProvider()..cargarClientes(forceRefresh: false)),
        ChangeNotifierProvider(create: (_) => VentaProvider()),
        ChangeNotifierProvider(
          create: (context) => CotizacionProvider(
            context.read<SyncProvider>(),
          )..cargarCotizaciones(forceRefresh: false),
        ),
        ChangeNotifierProvider(
          create: (context) => CuentasPorCobrarProvider(
            context.read<SyncProvider>(),
          )..cargarMisDeudores(forceRefresh: false),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificacionesCobroProvider(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: zentriNavigatorKey,
        title: 'Zentri Vendedor',
        builder: (context, child) => _WatcherBootstrap(child: child!),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1e293b)),
          useMaterial3: true,
        ),
        home: ApiConfig.instance.hayEmpresa
            ? const LoginScreen()
            : CodigoEmpresaScreen(onConfigurado: (ctx) {
                Navigator.of(ctx).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }),
        debugShowCheckedModeBanner: false,
        routes: {
          '/carrito': (context) => const CarritoScreen(),
          '/checkout': (context) => const CheckoutScreen(),
          '/cuentas_por_cobrar': (context) => const CuentasPorCobrarScreen(),
          '/cuentas_por_cobrar/detalle': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return CuentasPorCobrarDetailScreen(
              clienteId: args['clienteId'],
              clienteNombre: args['clienteNombre'],
            );
          },
        },
      ),
    );
  }
}

// ============================================================
// BOOTSTRAP DEL VIGILANTE DE CONEXIÓN
// ============================================================
class _WatcherBootstrap extends StatefulWidget {
  final Widget child;
  const _WatcherBootstrap({required this.child});

  @override
  State<_WatcherBootstrap> createState() => _WatcherBootstrapState();
}

class _WatcherBootstrapState extends State<_WatcherBootstrap> {
  @override
  void initState() {
    super.initState();
    sesionRevocadaCallback = () {
      final nav = zentriNavigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    };

    suspendidoCallback = () {
      final nav = zentriNavigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SuspendidoScreen()),
          (route) => false,
        );
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final sync = context.read<SyncProvider>();
        ConnectionWatcher.instance.iniciar(sync);
        AppLogger.log('✅ [Bootstrap] ConnectionWatcher iniciado');
      } catch (e) {
        AppLogger.log('❌ [Bootstrap] Error iniciando ConnectionWatcher: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}