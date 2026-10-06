import 'package:flutter/material.dart';
import 'package:zentri_vendedor/models/producto.dart';
import 'package:zentri_vendedor/services/producto_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class ProductoProvider extends ChangeNotifier {
  final ProductoService _service = ProductoService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();

  List<Producto> _productos = [];
  bool _cargando = false;
  bool _actualizando = false;
  String? _error;

  List<Producto> get productos => _productos;
  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  String? get error => _error;

  ProductoProvider() {
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarProductos(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  // ============================================================
  // ORDENAR PRODUCTOS ALFABÉTICAMENTE
  // ============================================================
  List<Producto> _ordenarProductos(List<Producto> lista) {
    final ordenados = List<Producto>.from(lista);
    ordenados.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return ordenados;
  }

  Future<void> cargarProductos({bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    AppLogger.log('📦 [ProductoProvider] cargarProductos() - forceRefresh: $forceRefresh');

    try {
      if (_productos.isNotEmpty && !forceRefresh) {
        AppLogger.log('✅ [ProductoProvider] Datos ya en memoria, saltando carga');
        _cargando = false;
        notifyListeners();
        return;
      }

      // 1. Cargar desde caché
      AppLogger.log('📦 [ProductoProvider] Intentando cargar desde caché...');
      final productosCache = await _dbHelper.obtenerProductos();
      AppLogger.log('📦 [ProductoProvider] productosCache.length: ${productosCache.length}');

      if (productosCache.isNotEmpty) {
        _productos = _ordenarProductos(productosCache);
        _error = null;
        _cargando = false;
        notifyListeners();
        AppLogger.log('✅ [ProductoProvider] Cargados ${_productos.length} productos desde caché (ordenados)');
      } else {
        AppLogger.log('⚠️ [ProductoProvider] Caché vacía');
        _error = 'Sin datos locales. Conéctate para sincronizar.';
        _cargando = false;
        notifyListeners();
      }

      // 2. Si forceRefresh es true, forzar actualización desde servidor
      if (forceRefresh) {
        AppLogger.log('🔄 [ProductoProvider] forceRefresh activo, actualizando desde servidor...');
        await _actualizarDesdeServidor();
      }
    } catch (e) {
      AppLogger.log('❌ [ProductoProvider] Error en cargarProductos: $e');
      _error = e.toString();
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> _actualizarEnSegundoPlano() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _actualizarDesdeServidor(notify: true);
  }

  Future<void> _actualizarDesdeServidor({bool notify = false}) async {
    if (_actualizando) return;
    _actualizando = true;
    if (notify) notifyListeners();

    AppLogger.log('🔄 [ProductoProvider] Actualizando desde servidor...');
    try {
      final productos = await _service.getProductos();
      final productosOrdenados = _ordenarProductos(productos);
      await _dbHelper.guardarProductos(productosOrdenados);
      _productos = productosOrdenados;
      _error = null;
      AppLogger.log('✅ [ProductoProvider] Actualizados ${_productos.length} productos desde servidor');
    } catch (e) {
      AppLogger.log('❌ [ProductoProvider] Actualización desde servidor falló: $e');
    } finally {
      _actualizando = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> sincronizar() async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    AppLogger.log('🔄 [ProductoProvider] Sincronización manual iniciada...');
    try {
      final productos = await _service.getProductos();
      final productosOrdenados = _ordenarProductos(productos);
      await _dbHelper.guardarProductos(productosOrdenados);
      _productos = productosOrdenados;
      _error = null;
      AppLogger.log('✅ [ProductoProvider] Sincronización manual completada: ${_productos.length} productos');
    } catch (e) {
      AppLogger.log('❌ [ProductoProvider] Error en sincronización manual: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Producto? obtenerProductoPorId(int id) {
    try {
      return _productos.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}