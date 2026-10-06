import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zentri_vendedor/models/cotizacion.dart';
import 'package:zentri_vendedor/models/item_cotizacion.dart';
import 'package:zentri_vendedor/services/cotizacion_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class CotizacionProvider extends ChangeNotifier {
  final CotizacionService _service = CotizacionService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();
  final SyncProvider _syncProvider;

  List<Cotizacion> _cotizaciones = [];
  Cotizacion? _cotizacionSeleccionada;
  bool _cargando = false;
  bool _actualizando = false;
  int _pagina = 1;
  int _total = 0;
  int _totalPaginas = 1;
  final int _limite = 20;

  List<ItemCotizacion> _itemsEditando = [];
  bool _editando = false;
  String? _error;

  List<Cotizacion> get cotizaciones => _cotizaciones;
  Cotizacion? get cotizacionSeleccionada => _cotizacionSeleccionada;
  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  int get pagina => _pagina;
  int get total => _total;
  int get totalPaginas => _totalPaginas;
  List<ItemCotizacion> get itemsEditando => _itemsEditando;
  bool get editando => _editando;
  String? get error => _error;

  CotizacionProvider(this._syncProvider) {
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarCotizaciones(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  Future<void> cargarCotizaciones({int? page, bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    notifyListeners();

    final p = page ?? _pagina;

    try {
      if (!forceRefresh && p == 1 && _cotizaciones.isEmpty) {
        final cotizacionesCache = await _dbHelper.obtenerCotizaciones();
        if (cotizacionesCache.isNotEmpty) {
          _cotizaciones = cotizacionesCache;
          _total = cotizacionesCache.length;
          _totalPaginas = 1;
          _pagina = 1;
          _cargando = false;
          notifyListeners();
          AppLogger.log('✅ [CotizacionProvider] Cargadas ${_cotizaciones.length} cotizaciones desde caché');
        }
      }

      if (forceRefresh || _cotizaciones.isEmpty) {
        AppLogger.log('🔄 [CotizacionProvider] Actualizando desde servidor...');
        final result = await _service.listarCotizaciones(page: p, limit: _limite);
        if (result['ok'] == true) {
          _cotizaciones = result['cotizaciones'] ?? [];
          _total = result['total'] ?? 0;
          _totalPaginas = result['totalPages'] ?? 1;
          _pagina = result['page'] ?? 1;
          await _dbHelper.guardarCotizaciones(_cotizaciones);
          AppLogger.log('✅ [CotizacionProvider] Actualizadas ${_cotizaciones.length} cotizaciones desde servidor');
        }
      }
    } catch (e) {
      AppLogger.log('❌ [CotizacionProvider] Error cargando cotizaciones: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<Cotizacion?> cargarDetalle(int id) async {
    AppLogger.log('🔍 [CotizacionProvider] cargarDetalle($id)');

    try {
      final enMemoria = _cotizaciones.firstWhere((c) => c.id == id);
      _cotizacionSeleccionada = enMemoria;
      AppLogger.log('✅ [CotizacionProvider] Cotización encontrada en memoria');
      notifyListeners();
      return enMemoria;
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionProvider] No en memoria');
    }

    try {
      final enCache = await _dbHelper.obtenerCotizacionIndividual(id);
      if (enCache != null) {
        _cotizacionSeleccionada = enCache;
        _error = null;
        AppLogger.log('✅ [CotizacionProvider] Cotización cargada desde caché local');
        notifyListeners();
        _actualizarDetalleDesdeServidor(id);
        return enCache;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionProvider] Error al leer caché: $e');
    }

    _cargando = true;
    notifyListeners();
    try {
      final cotizacion = await _service.obtenerCotizacion(id);
      if (cotizacion != null) {
        _cotizacionSeleccionada = cotizacion;
        _error = null;
        await _dbHelper.guardarCotizacionIndividual(cotizacion);
        AppLogger.log('✅ [CotizacionProvider] Detalle cargado desde servidor y guardado en caché');
        _cargando = false;
        notifyListeners();
        return cotizacion;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionProvider] Servidor falló: $e');
    }

    try {
      final basico = _cotizaciones.firstWhere((c) => c.id == id);
      _cotizacionSeleccionada = basico;
      _error = 'Modo offline: datos limitados';
      AppLogger.log('✅ [CotizacionProvider] Datos básicos desde lista');
    } catch (e) {
      _cotizacionSeleccionada = null;
      _error = 'No se encontró la cotización';
      AppLogger.log('❌ [CotizacionProvider] Cotización no encontrada');
    }

    _cargando = false;
    notifyListeners();
    return _cotizacionSeleccionada;
  }

  Future<void> _actualizarDetalleDesdeServidor(int id) async {
    try {
      AppLogger.log('🔄 [CotizacionProvider] Actualizando detalle desde servidor en segundo plano...');
      final cotizacion = await _service.obtenerCotizacion(id);
      if (cotizacion != null) {
        _cotizacionSeleccionada = cotizacion;
        _error = null;
        await _dbHelper.guardarCotizacionIndividual(cotizacion);
        AppLogger.log('✅ [CotizacionProvider] Detalle actualizado desde servidor en segundo plano');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionProvider] Actualización en segundo plano falló: $e');
    }
  }

  Future<void> _guardarEnCache(Cotizacion cotizacion) async {
    try {
      await _dbHelper.guardarCotizacionIndividual(cotizacion);
      AppLogger.log('📦 [CotizacionProvider] Cotización #${cotizacion.id} guardada en caché');
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionProvider] Error al guardar en caché: $e');
    }
  }

  Future<void> _actualizarEnSegundoPlano() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _actualizarDesdeServidor(notify: true);
  }

  Future<void> _actualizarDesdeServidor({bool notify = false}) async {
    if (_actualizando) return;
    _actualizando = true;
    if (notify) notifyListeners();

    AppLogger.log('🔄 [CotizacionProvider] Actualizando en segundo plano...');
    try {
      final result = await _service.listarCotizaciones(page: _pagina, limit: _limite);
      if (result['ok'] == true) {
        _cotizaciones = result['cotizaciones'] ?? [];
        _total = result['total'] ?? 0;
        _totalPaginas = result['totalPages'] ?? 1;
        _pagina = result['page'] ?? 1;
        await _dbHelper.guardarCotizaciones(_cotizaciones);
        AppLogger.log('✅ [CotizacionProvider] Actualización en segundo plano completada');
      }
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionProvider] Actualización en segundo plano falló: $e');
    } finally {
      _actualizando = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> sincronizarTodo() async {
    if (_cargando) return;
    _cargando = true;
    notifyListeners();

    AppLogger.log('🔄 [CotizacionProvider] Sincronización manual...');
    try {
      final result = await _service.listarCotizaciones(page: _pagina, limit: _limite);
      if (result['ok'] == true) {
        _cotizaciones = result['cotizaciones'] ?? [];
        _total = result['total'] ?? 0;
        _totalPaginas = result['totalPages'] ?? 1;
        _pagina = result['page'] ?? 1;
        await _dbHelper.guardarCotizaciones(_cotizaciones);
        AppLogger.log('✅ [CotizacionProvider] Sincronización manual completada');
      }
    } catch (e) {
      AppLogger.log('❌ [CotizacionProvider] Error en sincronización manual: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> crearCotizacion({
    required String cliente,
    String? clienteRif,
    int? clienteId,
    required String tipoVenta,
    required double margenGlobal,
    required String moneda,
    required double tasaBcv,
    required double tasaParalelo,
    required double ivaPorcentaje,
    required String metodoPago,
    required List<ItemCotizacion> items,
    int? vendedorId,
  }) async {
    _cargando = true;
    notifyListeners();

    final Map<String, dynamic> payload = {
      'cliente': cliente,
      'cliente_rif': clienteRif,
      'cliente_id': clienteId,
      'tipo_venta': tipoVenta,
      'margen_global': margenGlobal,
      'moneda': moneda,
      'tasa_bcv': tasaBcv,
      'tasa_paralelo': tasaParalelo,
      'iva_porcentaje': ivaPorcentaje,
      'metodo_pago': metodoPago,
      'items': items.map((i) => {
        'id': i.id,
        'nombre': i.nombre,
        'codigo': i.codigo,
        'cantidad': i.cantidad,
        'precio_unitario': i.precioUnitario,
        'imagen': i.imagen,
      }).toList(),
      'vendedor_id': vendedorId,
    };

    try {
      final result = await _service.guardarCotizacion(
        cliente: cliente,
        clienteRif: clienteRif,
        clienteId: clienteId,
        tipoVenta: tipoVenta,
        margenGlobal: margenGlobal,
        moneda: moneda,
        tasaBcv: tasaBcv,
        tasaParalelo: tasaParalelo,
        ivaPorcentaje: ivaPorcentaje,
        metodoPago: metodoPago,
        items: items,
        vendedorId: vendedorId,
      );

      _cargando = false;
      notifyListeners();

      if (result['ok'] == true) {
        final id = result['id'] as int?;
        if (id != null) {
          final cotizacion = await _service.obtenerCotizacion(id);
          if (cotizacion != null) {
            await _guardarEnCache(cotizacion);
          }
        }
        await sincronizarTodo();
        return result;
      } else {
        throw Exception('Error del servidor');
      }
    } catch (e) {
      AppLogger.log('💾 [CotizacionProvider] Error de conexión, guardando cotización offline: $e');
      await _syncProvider.agregarCotizacionPendiente(payload);
      _cargando = false;
      notifyListeners();
      return {
        'ok': false,
        'offline': true,
        'mensaje': 'Cotización guardada localmente. Se sincronizará cuando haya internet.',
      };
    }
  }

  Future<Map<String, dynamic>> actualizarCotizacion({
    required int id,
    required String cliente,
    String? clienteRif,
    int? clienteId,
    required String tipoVenta,
    required double margenGlobal,
    required String moneda,
    required double tasaBcv,
    required double tasaParalelo,
    required double ivaPorcentaje,
    required String metodoPago,
    required List<ItemCotizacion> items,
    int? vendedorId,
  }) async {
    _cargando = true;
    notifyListeners();

    final Map<String, dynamic> payload = {
      'id': id,
      'cliente': cliente,
      'cliente_rif': clienteRif,
      'cliente_id': clienteId,
      'tipo_venta': tipoVenta,
      'margen_global': margenGlobal,
      'moneda': moneda,
      'tasa_bcv': tasaBcv,
      'tasa_paralelo': tasaParalelo,
      'iva_porcentaje': ivaPorcentaje,
      'metodo_pago': metodoPago,
      'items': items.map((i) => {
        'id': i.id,
        'nombre': i.nombre,
        'codigo': i.codigo,
        'cantidad': i.cantidad,
        'precio_unitario': i.precioUnitario,
        'imagen': i.imagen,
      }).toList(),
      'vendedor_id': vendedorId,
    };

    try {
      final result = await _service.actualizarCotizacion(
        id: id,
        cliente: cliente,
        clienteRif: clienteRif,
        clienteId: clienteId,
        tipoVenta: tipoVenta,
        margenGlobal: margenGlobal,
        moneda: moneda,
        tasaBcv: tasaBcv,
        tasaParalelo: tasaParalelo,
        ivaPorcentaje: ivaPorcentaje,
        metodoPago: metodoPago,
        items: items,
        vendedorId: vendedorId,
      );

      _cargando = false;
      notifyListeners();

      if (result['ok'] == true) {
        final cotizacion = await _service.obtenerCotizacion(id);
        if (cotizacion != null) {
          await _guardarEnCache(cotizacion);
        }
        await sincronizarTodo();
        await cargarDetalle(id);
        return result;
      } else {
        throw Exception('Error del servidor');
      }
    } catch (e) {
      AppLogger.log('💾 [CotizacionProvider] Error de conexión, guardando actualización offline: $e');
      await _syncProvider.agregarCotizacionPendiente(payload);
      _cargando = false;
      notifyListeners();
      return {
        'ok': false,
        'offline': true,
        'mensaje': 'Actualización guardada localmente. Se sincronizará cuando haya internet.',
      };
    }
  }

  Future<bool> eliminarCotizacion(int id) async {
    final result = await _service.eliminarCotizacion(id);
    if (result['ok'] == true) {
      await sincronizarTodo();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> convertirAVenta({
    required int cotizacionId,
    required String metodoPago,
  }) async {
    _cargando = true;
    notifyListeners();

    final result = await _service.convertirAVenta(
      cotizacionId: cotizacionId,
      metodoPago: metodoPago,
    );

    _cargando = false;
    notifyListeners();

    if (result['ok'] == true) {
      await sincronizarTodo();
      await cargarDetalle(cotizacionId);
    }

    return result;
  }

  void iniciarEdicion(Cotizacion cotizacion) {
    List<ItemCotizacion> itemsList = [];
    if (cotizacion.items is List) {
      itemsList = cotizacion.items.cast<ItemCotizacion>();
    } else if (cotizacion.items is String) {
      try {
        final parsed = jsonDecode(cotizacion.items as String);
        if (parsed is List) {
          itemsList = parsed.map((item) => ItemCotizacion.fromJson(item)).toList();
        }
      } catch (e) {
        AppLogger.log('❌ Error parseando items en iniciarEdicion: $e');
      }
    }
    _itemsEditando = itemsList.map((item) =>
      ItemCotizacion(
        id: item.id,
        nombre: item.nombre,
        codigo: item.codigo,
        cantidad: (item.cantidad is num && item.cantidad.isFinite) ? item.cantidad : 0.0,
        precioUnitario: (item.precioUnitario is num && item.precioUnitario.isFinite) ? item.precioUnitario : 0.0,
        imagen: item.imagen,
      )
    ).toList();
    _editando = true;
    notifyListeners();
  }

  void agregarItemAEdicion(ItemCotizacion item) {
    _itemsEditando.add(item);
    notifyListeners();
  }

  void quitarItemDeEdicion(int id) {
    _itemsEditando.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void actualizarItemEnEdicion(int id, {double? cantidad, double? precioUnitario}) {
    final index = _itemsEditando.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _itemsEditando[index];
      _itemsEditando[index] = item.copyWith(
        cantidad: cantidad ?? item.cantidad,
        precioUnitario: precioUnitario ?? item.precioUnitario,
      );
      notifyListeners();
    }
  }

  void limpiarEdicion() {
    _itemsEditando = [];
    _editando = false;
    notifyListeners();
  }

  double get totalItemsEditando {
    if (_itemsEditando.isEmpty) return 0.0;
    return _itemsEditando.fold(0.0, (sum, item) {
      final cant = (item.cantidad is num && item.cantidad.isFinite) ? item.cantidad : 0.0;
      final precio = (item.precioUnitario is num && item.precioUnitario.isFinite) ? item.precioUnitario : 0.0;
      return sum + (cant * precio);
    });
  }

  void irPagina(int pagina) {
    if (pagina < 1 || pagina > _totalPaginas || pagina == _pagina) return;
    _pagina = pagina;
    cargarCotizaciones(page: pagina, forceRefresh: false);
    _actualizarEnSegundoPlano();
  }
}