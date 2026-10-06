import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:zentri_vendedor/services/configuracion_service.dart';
import 'package:zentri_vendedor/services/api_dio.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';

class ConfiguracionProvider extends ChangeNotifier {
  final ConfiguracionService _service = ConfiguracionService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();

  /// Dio compartido con interceptor global de 401.
  /// Si el server revoca la sesión, ApiDio dispara el logout automático.
  final Dio _dio = ApiDio.instance;

  String _colorPrimario = '#1E40AF';
  String _fuente = 'helvetica';
  int _tamanoTitulo = 16;
  double _margen = 12;
  int _plantillaId = 1;
  String _titulo = 'FACTURA';
  String _subtitulo = 'Documento de Venta';
  int _incluirIva = 1;
  double _ivaPorcentajeDefecto = 16.0;
  int _mostrarCliente = 1;
  String _prefijoFactura = 'NOT-';
  String? _logoBase64;
  String? _nombreEmpresa;
  bool _cargando = false;
  bool _actualizando = false;
  String? _error;

  // Getters
  String get colorPrimario => _colorPrimario;
  String get fuente => _fuente;
  int get tamanoTitulo => _tamanoTitulo;
  double get margen => _margen;
  int get plantillaId => _plantillaId;
  String get titulo => _titulo;
  String get subtitulo => _subtitulo;
  int get incluirIva => _incluirIva;
  double get ivaPorcentajeDefecto => _ivaPorcentajeDefecto;
  int get mostrarCliente => _mostrarCliente;
  String get prefijoFactura => _prefijoFactura;
  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  String? get error => _error;
  String? get logoBase64 => _logoBase64;
  String? get nombreEmpresa => _nombreEmpresa;

  ConfiguracionProvider() {
    // Usa el Dio compartido de la app (con interceptor global de 401).
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarConfiguracion(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  // ============================================================
  // CARGA PRINCIPAL (siempre desde caché primero)
  // ============================================================
  Future<void> cargarConfiguracion({bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Cargar desde caché
      final configCache = await _dbHelper.obtenerConfiguracion();
      if (configCache.isNotEmpty) {
        _aplicarConfig(configCache);
        _error = null;
        _cargando = false;
        notifyListeners();
      } else {
        _error = 'Sin datos locales. Conéctate para sincronizar.';
        _cargando = false;
        notifyListeners();
      }

      // 2. Si forceRefresh es true, forzar actualización desde servidor
      if (forceRefresh) {
        await _actualizarDesdeServidor();
      }
    } catch (e) {
      _error = e.toString();
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================================
  // ACTUALIZACIÓN EN SEGUNDO PLANO
  // ============================================================
  Future<void> _actualizarEnSegundoPlano() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _actualizarDesdeServidor(notify: true);
  }

  Future<void> _actualizarDesdeServidor({bool notify = false}) async {
    if (_actualizando) return;
    _actualizando = true;
    if (notify) notifyListeners();

    try {
      final config = await _service.obtenerConfiguracionDocumentos();
      await _dbHelper.guardarConfiguracion(config);
      _aplicarConfig(config);
      _error = null;
    } catch (e) {
      print('❌ Actualización en segundo plano falló: $e');
    } finally {
      _actualizando = false;
      if (notify) notifyListeners();
    }
  }

  // ============================================================
  // SINCRONIZACIÓN MANUAL
  // ============================================================
  Future<void> sincronizar() async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final config = await _service.obtenerConfiguracionDocumentos();
      await _dbHelper.guardarConfiguracion(config);
      _aplicarConfig(config);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void _aplicarConfig(Map<String, dynamic> config) {
    _colorPrimario = config['color_primario'] ?? '#1E40AF';
    _fuente = config['fuente'] ?? 'helvetica';
    _tamanoTitulo = config['tamano_titulo'] ?? 16;
    _margen = (config['margen'] ?? 12).toDouble();
    _plantillaId = config['plantilla_id'] ?? 1;
    _titulo = config['titulo'] ?? 'FACTURA';
    _subtitulo = config['subtitulo'] ?? 'Documento de Venta';
    _incluirIva = config['incluir_iva'] ?? 1;
    _ivaPorcentajeDefecto = (config['iva_porcentaje_defecto'] ?? 16).toDouble();
    _mostrarCliente = config['mostrar_cliente'] ?? 1;
    _prefijoFactura = config['prefijo_factura'] ?? 'NOT-';
  }

  Future<void> cargarEmpresa() async {
    try {
      final response = await _dio.get('/api/configuracion/empresa');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          _nombreEmpresa = data['nombre'] as String?;
          String? logo = data['logo_base64'] as String?;
          if (logo != null && logo.contains(',')) {
            logo = logo.split(',').last;
          }
          _logoBase64 = logo;
          notifyListeners();
        }
      }
    } catch (e) {
      // Si falla, no afecta la funcionalidad principal
    }
  }
}