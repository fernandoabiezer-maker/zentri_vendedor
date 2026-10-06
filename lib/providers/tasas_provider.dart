import 'package:flutter/material.dart';
import 'package:zentri_vendedor/services/producto_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';

class TasasProvider extends ChangeNotifier {
  final ProductoService _productoService = ProductoService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();

  double _tasaBCV = 0.0;
  double _tasaParalelo = 0.0;
  bool _cargando = false;
  bool _actualizando = false;
  String? _error;

  double get tasaBCV => _tasaBCV;
  double get tasaParalelo => _tasaParalelo;
  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  String? get error => _error;

  TasasProvider() {
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarTasas(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  // ============================================================
  // CARGA PRINCIPAL (siempre desde caché primero)
  // ============================================================
  Future<void> cargarTasas({bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Cargar desde caché
      final tasasCache = await _dbHelper.obtenerTasas();
      if (tasasCache['bcv'] != null && tasasCache['bcv']! > 0) {
        _tasaBCV = tasasCache['bcv']!;
        _tasaParalelo = tasasCache['paralelo']!;
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
      final tasas = await _productoService.getTasas();
      _tasaBCV = tasas['bcv'] ?? 0.0;
      _tasaParalelo = tasas['paralelo'] ?? 0.0;
      await _dbHelper.guardarTasas(_tasaBCV, _tasaParalelo);
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
      final tasas = await _productoService.getTasas();
      _tasaBCV = tasas['bcv'] ?? 0.0;
      _tasaParalelo = tasas['paralelo'] ?? 0.0;
      await _dbHelper.guardarTasas(_tasaBCV, _tasaParalelo);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}