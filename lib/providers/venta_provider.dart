import 'package:flutter/material.dart';
import 'package:zentri_vendedor/models/venta.dart';
import 'package:zentri_vendedor/services/venta_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';

class VentaProvider extends ChangeNotifier {
  final VentaService _service = VentaService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();

  List<Venta> _misVentas = [];
  int _misVentasTotal = 0;
  int _misVentasPagina = 1;
  int _misVentasTotalPaginas = 1;

  List<Venta> _ventasGenerales = [];
  int _ventasGeneralesTotal = 0;
  int _ventasGeneralesPagina = 1;
  int _ventasGeneralesTotalPaginas = 1;

  bool _cargando = false;
  bool _actualizando = false;
  String _busqueda = '';
  final int _limite = 28;

  List<Venta> get misVentas => _misVentas;
  int get misVentasTotal => _misVentasTotal;
  int get misVentasPagina => _misVentasPagina;
  int get misVentasTotalPaginas => _misVentasTotalPaginas;

  List<Venta> get ventasGenerales => _ventasGenerales;
  int get ventasGeneralesTotal => _ventasGeneralesTotal;
  int get ventasGeneralesPagina => _ventasGeneralesPagina;
  int get ventasGeneralesTotalPaginas => _ventasGeneralesTotalPaginas;

  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  String get busqueda => _busqueda;

  VentaProvider() {
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarTodo(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  // ============================================================
  // CARGA PRINCIPAL (siempre desde caché primero)
  // ============================================================
  Future<void> cargarMisVentas({int? page, bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    notifyListeners();

    final p = page ?? _misVentasPagina;

    try {
      // 1. Cargar desde caché
      if (!forceRefresh && p == 1 && _misVentas.isEmpty) {
        final ventasCache = await _dbHelper.obtenerVentas();
        if (ventasCache.isNotEmpty) {
          _misVentas = ventasCache;
          _misVentasTotal = ventasCache.length;
          _misVentasTotalPaginas = 1;
          _misVentasPagina = 1;
          _cargando = false;
          notifyListeners();
        }
      }

      // 2. Si forceRefresh es true, forzar actualización desde servidor
      if (forceRefresh) {
        final result = await _service.listarVentas(
          filtro: 'mis_ventas',
          buscar: _busqueda,
          page: p,
          limit: _limite,
        );
        if (result['ok'] == true) {
          _misVentas = result['ventas'] ?? [];
          _misVentasTotal = result['total'] ?? 0;
          _misVentasTotalPaginas = result['totalPages'] ?? 1;
          _misVentasPagina = result['page'] ?? 1;
          await _dbHelper.guardarVentas(_misVentas);
        }
      }
    } catch (e) {
      print('❌ Error cargando mis ventas: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarVentasGenerales({int? page, bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    notifyListeners();

    final p = page ?? _ventasGeneralesPagina;

    try {
      // 1. Cargar desde caché
      if (!forceRefresh && p == 1 && _ventasGenerales.isEmpty) {
        final ventasCache = await _dbHelper.obtenerVentas();
        if (ventasCache.isNotEmpty) {
          _ventasGenerales = ventasCache;
          _ventasGeneralesTotal = ventasCache.length;
          _ventasGeneralesTotalPaginas = 1;
          _ventasGeneralesPagina = 1;
          _cargando = false;
          notifyListeners();
        }
      }

      // 2. Si forceRefresh es true, forzar actualización desde servidor
      if (forceRefresh) {
        final result = await _service.listarVentas(
          filtro: 'generales',
          buscar: _busqueda,
          page: p,
          limit: _limite,
        );
        if (result['ok'] == true) {
          _ventasGenerales = result['ventas'] ?? [];
          _ventasGeneralesTotal = result['total'] ?? 0;
          _ventasGeneralesTotalPaginas = result['totalPages'] ?? 1;
          _ventasGeneralesPagina = result['page'] ?? 1;
          await _dbHelper.guardarVentas(_ventasGenerales);
        }
      }
    } catch (e) {
      print('❌ Error cargando ventas generales: $e');
    } finally {
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
      // Actualizar mis ventas
      final resultMis = await _service.listarVentas(
        filtro: 'mis_ventas',
        buscar: _busqueda,
        page: _misVentasPagina,
        limit: _limite,
      );
      if (resultMis['ok'] == true) {
        _misVentas = resultMis['ventas'] ?? [];
        _misVentasTotal = resultMis['total'] ?? 0;
        _misVentasTotalPaginas = resultMis['totalPages'] ?? 1;
        _misVentasPagina = resultMis['page'] ?? 1;
        await _dbHelper.guardarVentas(_misVentas);
      }

      // Actualizar ventas generales
      final resultGen = await _service.listarVentas(
        filtro: 'generales',
        buscar: _busqueda,
        page: _ventasGeneralesPagina,
        limit: _limite,
      );
      if (resultGen['ok'] == true) {
        _ventasGenerales = resultGen['ventas'] ?? [];
        _ventasGeneralesTotal = resultGen['total'] ?? 0;
        _ventasGeneralesTotalPaginas = resultGen['totalPages'] ?? 1;
        _ventasGeneralesPagina = resultGen['page'] ?? 1;
        await _dbHelper.guardarVentas(_ventasGenerales);
      }
    } catch (e) {
      print('❌ Actualización en segundo plano falló: $e');
    } finally {
      _actualizando = false;
      if (notify) notifyListeners();
    }
  }

  // ============================================================
  // SINCRONIZACIÓN MANUAL (para el botón de refresh)
  // ============================================================
  Future<void> sincronizarTodo() async {
    if (_cargando) return;
    _cargando = true;
    notifyListeners();

    try {
      final resultMis = await _service.listarVentas(
        filtro: 'mis_ventas',
        buscar: _busqueda,
        page: _misVentasPagina,
        limit: _limite,
      );
      if (resultMis['ok'] == true) {
        _misVentas = resultMis['ventas'] ?? [];
        _misVentasTotal = resultMis['total'] ?? 0;
        _misVentasTotalPaginas = resultMis['totalPages'] ?? 1;
        _misVentasPagina = resultMis['page'] ?? 1;
        await _dbHelper.guardarVentas(_misVentas);
      }

      final resultGen = await _service.listarVentas(
        filtro: 'generales',
        buscar: _busqueda,
        page: _ventasGeneralesPagina,
        limit: _limite,
      );
      if (resultGen['ok'] == true) {
        _ventasGenerales = resultGen['ventas'] ?? [];
        _ventasGeneralesTotal = resultGen['total'] ?? 0;
        _ventasGeneralesTotalPaginas = resultGen['totalPages'] ?? 1;
        _ventasGeneralesPagina = resultGen['page'] ?? 1;
        await _dbHelper.guardarVentas(_ventasGenerales);
      }
    } catch (e) {
      print('❌ Error en sincronización manual: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================================
  // MÉTODOS DE NAVEGACIÓN
  // ============================================================
  void irPaginaMisVentas(int pagina) {
    if (pagina < 1 || pagina > _misVentasTotalPaginas || pagina == _misVentasPagina) return;
    _misVentasPagina = pagina;
    cargarMisVentas(page: pagina, forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  void irPaginaVentasGenerales(int pagina) {
    if (pagina < 1 || pagina > _ventasGeneralesTotalPaginas || pagina == _ventasGeneralesPagina) return;
    _ventasGeneralesPagina = pagina;
    cargarVentasGenerales(page: pagina, forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  void buscar(String query) {
    _busqueda = query;
    _misVentasPagina = 1;
    _ventasGeneralesPagina = 1;
    cargarMisVentas(forceRefresh: false);
    cargarVentasGenerales(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  void limpiarBusqueda() {
    _busqueda = '';
    _misVentasPagina = 1;
    _ventasGeneralesPagina = 1;
    cargarMisVentas(forceRefresh: false);
    cargarVentasGenerales(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  Future<void> cargarTodo({bool forceRefresh = false}) async {
    await cargarMisVentas(forceRefresh: forceRefresh);
    await cargarVentasGenerales(forceRefresh: forceRefresh);
  }
}