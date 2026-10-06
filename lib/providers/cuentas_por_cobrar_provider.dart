import 'package:flutter/material.dart';
import 'package:zentri_vendedor/models/cliente_deuda.dart';
import 'package:zentri_vendedor/models/abono.dart';
import 'package:zentri_vendedor/models/plan_cuota.dart';
import 'package:zentri_vendedor/services/cuentas_por_cobrar_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class CuentasPorCobrarProvider extends ChangeNotifier {
  final CuentasPorCobrarService _service = CuentasPorCobrarService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();
  final SyncProvider _syncProvider;

  // ============================================================
  // DEUDORES
  // ============================================================
  List<ClienteDeuda> _misDeudores = [];
  List<ClienteDeuda> _todosDeudores = [];
  bool _cargandoMis = false;
  bool _cargandoTodos = false;
  bool _cargandoDetalle = false;
  bool _actualizando = false;

  int _paginaMisDeudores = 1;
  int _totalMisDeudores = 0;
  int _totalPaginasMisDeudores = 1;

  int _paginaTodosDeudores = 1;
  int _totalTodosDeudores = 0;
  int _totalPaginasTodosDeudores = 1;

  String _searchQuery = '';

  ClienteDeuda? _clienteSeleccionado;

  // ============================================================
  // PRECARGA AUTOMÁTICA DE DETALLES EN SEGUNDO PLANO
  // ============================================================
  bool _precargando = false;

  // ============================================================
  // FACTURAS
  // ============================================================
  List<Map<String, dynamic>> _facturasPendientes = [];
  List<Map<String, dynamic>> _todasFacturasCache = [];
  int _paginaFacturas = 1;
  int _totalFacturas = 0;
  int _totalPaginasFacturas = 1;
  static const int _facturasPorPagina = 5;

  // ============================================================
  // PLANES
  // ============================================================
  List<PlanCuota> _planesCuotas = [];
  List<PlanCuota> _todosPlanesCache = [];
  int _paginaPlanes = 1;
  int _totalPlanes = 0;
  int _totalPaginasPlanes = 1;
  static const int _planesPorPagina = 5;

  // ============================================================
  // ABONOS
  // ============================================================
  List<Abono> _abonosCliente = [];
  int _paginaAbonos = 1;
  int _totalAbonos = 0;
  int _totalPaginasAbonos = 1;
  static const int _abonosPorPagina = 10;
  bool _cargandoAbonos = false;

  String? _error;

  // ============================================================
  // GETTERS
  // ============================================================
  List<ClienteDeuda> get misDeudores => _misDeudores;
  List<ClienteDeuda> get todosDeudores => _todosDeudores;
  bool get cargandoMis => _cargandoMis;
  bool get cargandoTodos => _cargandoTodos;
  bool get cargando => _cargandoMis || _cargandoTodos;
  bool get cargandoDetalle => _cargandoDetalle;
  bool get actualizando => _actualizando;
  int get paginaMisDeudores => _paginaMisDeudores;
  int get totalMisDeudores => _totalMisDeudores;
  int get totalPaginasMisDeudores => _totalPaginasMisDeudores;
  int get paginaTodosDeudores => _paginaTodosDeudores;
  int get totalTodosDeudores => _totalTodosDeudores;
  int get totalPaginasTodosDeudores => _totalPaginasTodosDeudores;
  String get searchQuery => _searchQuery;
  ClienteDeuda? get clienteSeleccionado => _clienteSeleccionado;

  List<Map<String, dynamic>> get facturasPendientes => _facturasPendientes;
  int get paginaFacturas => _paginaFacturas;
  int get totalFacturas => _totalFacturas;
  int get totalPaginasFacturas => _totalPaginasFacturas;

  List<PlanCuota> get planesCuotas => _planesCuotas;
  int get paginaPlanes => _paginaPlanes;
  int get totalPlanes => _totalPlanes;
  int get totalPaginasPlanes => _totalPaginasPlanes;

  List<Abono> get abonosCliente => _abonosCliente;
  int get paginaAbonos => _paginaAbonos;
  int get totalAbonos => _totalAbonos;
  int get totalPaginasAbonos => _totalPaginasAbonos;
  bool get cargandoAbonos => _cargandoAbonos;

  String? get error => _error;

  CuentasPorCobrarProvider(this._syncProvider) {
    _inicializar();
  }

  Future<void> _inicializar() async {
    await cargarMisDeudores(forceRefresh: false);
    // Precarga automática: trae el detalle de cada deudor y lo deja en
    // caché para uso offline. Corre en segundo plano (no se espera).
    _precargarDetallesDeudores();
    _actualizarEnSegundoPlano();
  }

  /// Convierte un raw (List dinámico con mapas de cualquier tipo) a
  /// List<PlanCuota>, forzando la conversión de cada mapa a
  /// Map<String, dynamic> para tolerar mapas con tipo dinámico.
  List<PlanCuota> _parsearPlanes(dynamic raw) {
    if (raw == null || raw is! List) return [];
    final resultado = <PlanCuota>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          final map = Map<String, dynamic>.from(item);
          resultado.add(PlanCuota.fromJson(map));
        } catch (e) {
          AppLogger.log('⚠️ [CuentasPorCobrar] Error parseando plan: $e');
        }
      }
    }
    return resultado;
  }

  int _leerTotalFacturasCache(Map<String, dynamic> cache, int fallback) {
    final nuevo = cache['facturas_total'];
    if (nuevo is int) return nuevo;
    final viejo = cache['facturaTotal'];
    if (viejo is int) return viejo;
    return fallback;
  }

  void _aplicarPaginaPlanesDesdeCache(int pagina) {
    final total = _todosPlanesCache.length;
    _totalPlanes = total;
    _totalPaginasPlanes = _calcularPaginas(total, _planesPorPagina);
    final inicio = (pagina - 1) * _planesPorPagina;
    final fin = (inicio + _planesPorPagina).clamp(0, total);
    if (inicio >= total) {
      _planesCuotas = [];
    } else {
      _planesCuotas = _todosPlanesCache.sublist(inicio, fin);
    }
    _paginaPlanes = pagina;
  }

  void _aplicarPaginaFacturasDesdeCache(int pagina) {
    final total = _todasFacturasCache.length;
    _totalFacturas = total;
    _totalPaginasFacturas = _calcularPaginas(total, _facturasPorPagina);
    final inicio = (pagina - 1) * _facturasPorPagina;
    final fin = (inicio + _facturasPorPagina).clamp(0, total);
    if (inicio >= total) {
      _facturasPendientes = [];
    } else {
      _facturasPendientes = _todasFacturasCache.sublist(inicio, fin);
    }
    _paginaFacturas = pagina;
  }

  // ============================================================
  // PRECARGA DE DETALLES (SEGUNDO PLANO)
  // ============================================================
  //
  // Recorre la lista de deudores y trae el detalle completo de cada uno
  // (planes + facturas + abonos). Guarda todo en el caché local para que
  // funcione offline aunque el usuario nunca abra manualmente cada cliente.
  //
  // Igual que hace ClienteProvider con "precarga de comportamiento".
  // Silencioso: no toca la UI ni el estado visible.
  // ============================================================
  Future<void> _precargarDetallesDeudores() async {
    if (_precargando) return;
    _precargando = true;
    try {
      // Espera un momento para no pelear con la carga inicial de la pantalla
      await Future.delayed(const Duration(milliseconds: 1500));

      if (_misDeudores.isEmpty) {
        AppLogger.log('ℹ️ [CuentasPorCobrar] Sin deudores para precargar');
        return;
      }

      AppLogger.log('🔄 [CuentasPorCobrar] Iniciando precarga de detalle para ${_misDeudores.length} deudores...');

      int exitosos = 0;
      int fallidos = 0;

      for (final deudor in _misDeudores) {
        try {
          final result = await _service.obtenerDetalleDeuda(
            deudor.id,
            planPage: 1,
            planLimit: 500,
            facturaPage: 1,
            facturaLimit: 500,
          );
          if (result['ok'] == true) {
            await _dbHelper.guardarComportamientoCliente(deudor.id, result);

            // Guardar abonos del cliente en su tabla separada
            try {
              final abonosResp = await _service.obtenerAbonosCliente(
                deudor.id,
                page: 1,
                limit: 100,
              );
              if (abonosResp['ok'] == true) {
                final abonos = List<Abono>.from(abonosResp['abonos'] ?? []);
                await _dbHelper.guardarAbonosCliente(deudor.id, abonos);
              }
            } catch (_) {
              // Si abonos falla, no importa: lo importante es el detalle
            }

            exitosos++;
            AppLogger.log('✅ [CuentasPorCobrar] Precargado detalle de ${deudor.nombre} (${deudor.id})');
          } else {
            fallidos++;
          }
        } catch (e) {
          fallidos++;
          AppLogger.log('⚠️ [CuentasPorCobrar] Error precargando ${deudor.nombre} (${deudor.id}): $e');
        }
      }

      AppLogger.log('✅ [CuentasPorCobrar] Precarga completada: $exitosos exitosos, $fallidos fallidos');
    } catch (e) {
      AppLogger.log('❌ [CuentasPorCobrar] Error en precarga de detalles: $e');
    } finally {
      _precargando = false;
    }
  }

  // ============================================================
  // CARGAR MIS DEUDORES
  // ============================================================
  Future<void> cargarMisDeudores({int? page, bool forceRefresh = false}) async {
    if (_cargandoMis) return;
    _cargandoMis = true;
    notifyListeners();

    final p = page ?? _paginaMisDeudores;

    try {
      if (_misDeudores.isNotEmpty && !forceRefresh && p == 1) {
        _cargandoMis = false;
        notifyListeners();
        return;
      }

      if (!forceRefresh && p == 1 && _misDeudores.isEmpty) {
        final deudoresCache = await _dbHelper.obtenerDeudores();
        if (deudoresCache.isNotEmpty) {
          _misDeudores = deudoresCache;
          _totalMisDeudores = deudoresCache.length;
          _totalPaginasMisDeudores = 1;
          _paginaMisDeudores = 1;
          _cargandoMis = false;
          notifyListeners();
          AppLogger.log('✅ [CuentasPorCobrar] Cargados ${_misDeudores.length} deudores desde caché');
        }
      }

      if (forceRefresh || _misDeudores.isEmpty) {
        AppLogger.log('🔄 [CuentasPorCobrar] Actualizando mis deudores desde servidor...');
        final result = await _service.obtenerMisDeudores(
          page: p,
          limit: 20,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );

        if (result['ok'] == true) {
          _misDeudores = List<ClienteDeuda>.from(result['data'] ?? []);
          _totalMisDeudores = result['total'] ?? 0;
          _totalPaginasMisDeudores = result['totalPages'] ?? 1;
          _paginaMisDeudores = result['page'] ?? 1;
          await _dbHelper.guardarDeudores(_misDeudores);
          AppLogger.log('✅ [CuentasPorCobrar] Actualizados ${_misDeudores.length} deudores desde servidor');
        }
      }
    } catch (e) {
      AppLogger.log('❌ [CuentasPorCobrar] Error cargando mis deudores: $e');
    } finally {
      _cargandoMis = false;
      notifyListeners();
    }
  }

  // ============================================================
  // CARGAR TODOS DEUDORES
  // ============================================================
  Future<void> cargarTodosDeudores({int? page, bool forceRefresh = false}) async {
    if (_cargandoTodos) return;
    _cargandoTodos = true;
    notifyListeners();

    final p = page ?? _paginaTodosDeudores;

    try {
      if (_todosDeudores.isNotEmpty && !forceRefresh && p == 1) {
        _cargandoTodos = false;
        notifyListeners();
        return;
      }

      if (!forceRefresh && p == 1 && _todosDeudores.isEmpty) {
        final deudoresCache = await _dbHelper.obtenerDeudores();
        if (deudoresCache.isNotEmpty) {
          _todosDeudores = deudoresCache;
          _totalTodosDeudores = deudoresCache.length;
          _totalPaginasTodosDeudores = 1;
          _paginaTodosDeudores = 1;
          _cargandoTodos = false;
          notifyListeners();
        }
      }

      if (forceRefresh || _todosDeudores.isEmpty) {
        final result = await _service.obtenerTodosDeudores(
          page: p,
          limit: 20,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );

        if (result['ok'] == true) {
          _todosDeudores = List<ClienteDeuda>.from(result['data'] ?? []);
          _totalTodosDeudores = result['total'] ?? 0;
          _totalPaginasTodosDeudores = result['totalPages'] ?? 1;
          _paginaTodosDeudores = result['page'] ?? 1;
          await _dbHelper.guardarDeudores(_todosDeudores);
        }
      }
    } catch (e) {
      AppLogger.log('❌ [CuentasPorCobrar] Error cargando todos los deudores: $e');
    } finally {
      _cargandoTodos = false;
      notifyListeners();
    }
  }

  // ============================================================
  // DETALLE DE CLIENTE
  // ============================================================
  Future<void> cargarDetalleCliente(int clienteId) async {
    _cargandoDetalle = true;
    _clienteSeleccionado = null;
    _facturasPendientes = [];
    _todasFacturasCache = [];
    _paginaFacturas = 1;
    _totalFacturas = 0;
    _totalPaginasFacturas = 1;
    _abonosCliente = [];
    _planesCuotas = [];
    _todosPlanesCache = [];
    _paginaPlanes = 1;
    _totalPlanes = 0;
    _totalPaginasPlanes = 1;
    _paginaAbonos = 1;
    _totalAbonos = 0;
    _totalPaginasAbonos = 1;
    _error = null;
    notifyListeners();

    AppLogger.log('🔄 [CuentasPorCobrar] cargarDetalleCliente($clienteId)');

    ClienteDeuda? clienteEnMemoria;
    try {
      clienteEnMemoria = _misDeudores.firstWhere((d) => d.id == clienteId);
      AppLogger.log('✅ [CuentasPorCobrar] Cliente encontrado en memoria');
    } catch (e) {
      AppLogger.log('ℹ️ [CuentasPorCobrar] Cliente NO encontrado en memoria');
    }

    // 1. Intentar caché primero
    bool hayDetalleCache = false;
    try {
      final comportamientoCache = await _dbHelper.obtenerComportamientoCliente(clienteId);
      if (comportamientoCache != null && comportamientoCache.isNotEmpty) {
        AppLogger.log('💾 [CuentasPorCobrar] Detalle encontrado en caché local');

        final facturasRaw = List<Map<String, dynamic>>.from(
            comportamientoCache['facturas_pendientes'] ?? []);
        _todasFacturasCache = facturasRaw;
        _totalFacturas = _leerTotalFacturasCache(comportamientoCache, facturasRaw.length);
        _totalPaginasFacturas = _calcularPaginas(_totalFacturas, _facturasPorPagina);
        _aplicarPaginaFacturasDesdeCache(1);

        // Planes: si el caché los tiene (formato nuevo), usarlos.
        // Si no (formato viejo), quedarán vacíos y se refresca online.
        final tienePlanes = comportamientoCache.containsKey('planes_cuotas') &&
            comportamientoCache['planes_cuotas'] is List;
        if (tienePlanes) {
          final planesRaw = _parsearPlanes(comportamientoCache['planes_cuotas']);
          _todosPlanesCache = planesRaw;
          _totalPlanes = comportamientoCache['planes_total'] ?? planesRaw.length;
          _totalPaginasPlanes = _calcularPaginas(_totalPlanes, _planesPorPagina);
          _aplicarPaginaPlanesDesdeCache(1);
          AppLogger.log('✅ [CuentasPorCobrar] Planes desde caché: ${_planesCuotas.length} (total ${_todosPlanesCache.length})');
        } else {
          AppLogger.log('⚠️ [CuentasPorCobrar] Caché sin planes (formato viejo). Se refrescará online.');
        }

        _clienteSeleccionado = clienteEnMemoria ?? ClienteDeuda(
          id: clienteId,
          nombre: comportamientoCache['cliente']?['nombre'] ?? 'Cliente',
          cedula: comportamientoCache['cliente']?['cedula'],
          deudaUsd: (comportamientoCache['total_deuda_usd'] ?? 0.0).toDouble(),
          deudaBs: (comportamientoCache['total_deuda_bs'] ?? 0.0).toDouble(),
          facturasPendientes: _totalFacturas,
        );
        _error = null;
        hayDetalleCache = true;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Error al leer caché de detalle: $e');
    }

    // 2. Si hay caché, mostrarlo y actualizar en segundo plano
    if (hayDetalleCache) {
      await _cargarAbonosDesdeCache(clienteId);
      _cargandoDetalle = false;
      notifyListeners();
      _actualizarDetalleDesdeServidor(clienteId);
      return;
    }

    // 3. Sin caché: ir directo al servidor
    try {
      AppLogger.log('🌐 [CuentasPorCobrar] Intentando obtener detalle desde servidor...');
      final result = await _service.obtenerDetalleDeuda(
        clienteId,
        planPage: 1,
        planLimit: 500,
        facturaPage: 1,
        facturaLimit: 500,
      );
      if (result['ok'] == true) {
        final facturasRaw = List<Map<String, dynamic>>.from(result['facturas_pendientes'] ?? []);
        _todasFacturasCache = facturasRaw;
        _totalFacturas = result['facturas_total'] ?? facturasRaw.length;
        _totalPaginasFacturas = _calcularPaginas(_totalFacturas, _facturasPorPagina);
        _aplicarPaginaFacturasDesdeCache(1);

        final planesRaw = _parsearPlanes(result['planes_cuotas']);
        _todosPlanesCache = planesRaw;
        _totalPlanes = result['planes_total'] ?? planesRaw.length;
        _totalPaginasPlanes = _calcularPaginas(_totalPlanes, _planesPorPagina);
        _aplicarPaginaPlanesDesdeCache(1);

        final clienteData = result['cliente'] ?? {};
        _clienteSeleccionado = ClienteDeuda(
          id: clienteData['id'] ?? clienteId,
          nombre: clienteData['nombre'] ?? 'Cliente',
          cedula: clienteData['cedula'],
          telefono: clienteData['telefono'],
          deudaUsd: (result['total_deuda_usd'] ?? 0.0).toDouble(),
          deudaBs: (result['total_deuda_bs'] ?? 0.0).toDouble(),
          facturasPendientes: _totalFacturas,
        );
        await _dbHelper.guardarComportamientoCliente(clienteId, result);
        await cargarAbonosCliente(clienteId, page: 1);
        _cargandoDetalle = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Servidor falló: $e');
    }

    if (clienteEnMemoria != null) {
      _clienteSeleccionado = clienteEnMemoria;
      _error = 'Modo offline: datos limitados';
    } else {
      _clienteSeleccionado = null;
      _error = 'No se pudo cargar el detalle del deudor';
    }

    _cargandoDetalle = false;
    notifyListeners();
  }

  int _calcularPaginas(int total, int porPagina) {
    if (total <= 0) return 1;
    return (total + porPagina - 1) ~/ porPagina;
  }

  Future<void> _cargarAbonosDesdeCache(int clienteId) async {
    try {
      final abonosCache = await _dbHelper.obtenerAbonosCliente(clienteId);
      if (abonosCache != null && abonosCache.isNotEmpty) {
        _abonosCliente = abonosCache;
        _totalAbonos = abonosCache.length;
        _totalPaginasAbonos = 1;
      } else {
        _abonosCliente = [];
        _totalAbonos = 0;
        _totalPaginasAbonos = 1;
      }
    } catch (e) {
      _abonosCliente = [];
      _totalAbonos = 0;
      _totalPaginasAbonos = 1;
    }
  }

  Future<void> _actualizarDetalleDesdeServidor(int clienteId) async {
    try {
      final result = await _service.obtenerDetalleDeuda(
        clienteId,
        planPage: 1,
        planLimit: 500,
        facturaPage: 1,
        facturaLimit: 500,
      );
      if (result['ok'] == true) {
        final facturasRaw = List<Map<String, dynamic>>.from(result['facturas_pendientes'] ?? []);
        _todasFacturasCache = facturasRaw;
        _totalFacturas = result['facturas_total'] ?? facturasRaw.length;
        _totalPaginasFacturas = _calcularPaginas(_totalFacturas, _facturasPorPagina);
        _aplicarPaginaFacturasDesdeCache(_paginaFacturas);

        final planesRaw = _parsearPlanes(result['planes_cuotas']);
        _todosPlanesCache = planesRaw;
        _totalPlanes = result['planes_total'] ?? planesRaw.length;
        _totalPaginasPlanes = _calcularPaginas(_totalPlanes, _planesPorPagina);
        _aplicarPaginaPlanesDesdeCache(_paginaPlanes);

        final clienteData = result['cliente'] ?? {};
        _clienteSeleccionado = ClienteDeuda(
          id: clienteData['id'] ?? clienteId,
          nombre: clienteData['nombre'] ?? 'Cliente',
          cedula: clienteData['cedula'],
          telefono: clienteData['telefono'],
          deudaUsd: (result['total_deuda_usd'] ?? 0.0).toDouble(),
          deudaBs: (result['total_deuda_bs'] ?? 0.0).toDouble(),
          facturasPendientes: _totalFacturas,
        );
        await _dbHelper.guardarComportamientoCliente(clienteId, result);
        await cargarAbonosCliente(clienteId, page: _paginaAbonos);
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Actualización en segundo plano falló: $e');
    }
  }

  // ============================================================
  // CARGAR ABONOS
  // ============================================================
  Future<void> cargarAbonosCliente(int clienteId, {int? page}) async {
    if (_cargandoAbonos) return;
    _cargandoAbonos = true;
    notifyListeners();

    final p = page ?? _paginaAbonos;

    try {
      final result = await _service.obtenerAbonosCliente(
        clienteId,
        page: p,
        limit: _abonosPorPagina,
      );

      if (result['ok'] == true) {
        _abonosCliente = List<Abono>.from(result['abonos'] ?? []);
        _totalAbonos = result['total'] ?? 0;
        _paginaAbonos = result['page'] ?? p;
        _totalPaginasAbonos = result['totalPages'] ?? 1;
        await _dbHelper.guardarAbonosCliente(clienteId, _abonosCliente);
        _cargandoAbonos = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Servidor falló, usando caché: $e');
    }

    try {
      final abonosCache = await _dbHelper.obtenerAbonosCliente(clienteId);
      if (abonosCache != null && abonosCache.isNotEmpty) {
        _abonosCliente = abonosCache;
        _totalAbonos = abonosCache.length;
        _totalPaginasAbonos = 1;
        _paginaAbonos = 1;
      } else {
        _abonosCliente = [];
        _totalAbonos = 0;
        _totalPaginasAbonos = 1;
      }
    } catch (e) {
      _abonosCliente = [];
      _totalAbonos = 0;
      _totalPaginasAbonos = 1;
    }

    _cargandoAbonos = false;
    notifyListeners();
  }

  // ============================================================
  // REGISTRAR ABONO
  // ============================================================
  Future<Map<String, dynamic>> registrarAbono({
    required int ventaId,
    required double montoUsd,
    required String metodoPago,
    String? referencia,
    Map<String, double>? pagoMixtoDetalle,
  }) async {
    AppLogger.log('🔄 [CuentasPorCobrar] registrarAbono: ventaId=$ventaId, monto=$montoUsd, metodo=$metodoPago');

    final Map<String, dynamic> payload = {
      'venta_id': ventaId,
      'monto': montoUsd,
      'metodo_pago': metodoPago,
      'referencia': referencia,
    };
    if (pagoMixtoDetalle != null && pagoMixtoDetalle.isNotEmpty) {
      payload['pago_mixto_detalle'] = pagoMixtoDetalle;
    }

    try {
      final result = await _service.registrarAbono(
        ventaId: ventaId,
        montoUsd: montoUsd,
        metodoPago: metodoPago,
        referencia: referencia,
        pagoMixtoDetalle: pagoMixtoDetalle,
      );

      if (result['ok'] == true) {
        AppLogger.log('✅ [CuentasPorCobrar] Abono registrado exitosamente');
        if (_clienteSeleccionado != null) {
          await cargarDetalleCliente(_clienteSeleccionado!.id);
        }
        return result;
      }

      if (result['validacion'] == true) {
        AppLogger.log('⚠️ [CuentasPorCobrar] Validación rechazada: ${result['mensaje']}');
        return result;
      }

      return result;
    } catch (e) {
      AppLogger.log('🆘 [CuentasPorCobrar] Error de conexión, guardando abono offline: $e');
      await _syncProvider.agregarAbonoPendiente(payload);
      return {
        'ok': false,
        'offline': true,
        'mensaje': 'Abono guardado localmente. Se sincronizará cuando haya internet.',
      };
    }
  }

  Future<void> _actualizarEnSegundoPlano() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _actualizarDesdeServidor(notify: true);
    // Después de refrescar la lista de deudores, dispara la precarga de
    // detalles (planes + facturas + abonos) para tener todo en caché.
    _precargarDetallesDeudores();
  }

  Future<void> _actualizarDesdeServidor({bool notify = false}) async {
    if (_actualizando) return;
    _actualizando = true;
    if (notify) notifyListeners();

    try {
      final result = await _service.obtenerMisDeudores(
        page: _paginaMisDeudores,
        limit: 20,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (result['ok'] == true) {
        _misDeudores = List<ClienteDeuda>.from(result['data'] ?? []);
        _totalMisDeudores = result['total'] ?? 0;
        _totalPaginasMisDeudores = result['totalPages'] ?? 1;
        _paginaMisDeudores = result['page'] ?? 1;
        await _dbHelper.guardarDeudores(_misDeudores);
      }

      final resultTodos = await _service.obtenerTodosDeudores(
        page: _paginaTodosDeudores,
        limit: 20,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (resultTodos['ok'] == true) {
        _todosDeudores = List<ClienteDeuda>.from(resultTodos['data'] ?? []);
        _totalTodosDeudores = resultTodos['total'] ?? 0;
        _totalPaginasTodosDeudores = resultTodos['totalPages'] ?? 1;
        _paginaTodosDeudores = resultTodos['page'] ?? 1;
        await _dbHelper.guardarDeudores(_todosDeudores);
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Actualización en segundo plano falló: $e');
    } finally {
      _actualizando = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> sincronizarTodo() async {
    if (_cargandoMis || _cargandoTodos) return;
    _cargandoMis = true;
    _cargandoTodos = true;
    notifyListeners();

    try {
      final result = await _service.obtenerMisDeudores(
        page: _paginaMisDeudores,
        limit: 20,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (result['ok'] == true) {
        _misDeudores = List<ClienteDeuda>.from(result['data'] ?? []);
        _totalMisDeudores = result['total'] ?? 0;
        _totalPaginasMisDeudores = result['totalPages'] ?? 1;
        _paginaMisDeudores = result['page'] ?? 1;
        await _dbHelper.guardarDeudores(_misDeudores);
      }

      final resultTodos = await _service.obtenerTodosDeudores(
        page: _paginaTodosDeudores,
        limit: 20,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (resultTodos['ok'] == true) {
        _todosDeudores = List<ClienteDeuda>.from(resultTodos['data'] ?? []);
        _totalTodosDeudores = resultTodos['total'] ?? 0;
        _totalPaginasTodosDeudores = resultTodos['totalPages'] ?? 1;
        _paginaTodosDeudores = resultTodos['page'] ?? 1;
        await _dbHelper.guardarDeudores(_todosDeudores);
      }

      // Después de actualizar la lista, dispara precarga en segundo plano
      _precargarDetallesDeudores();
    } catch (e) {
      AppLogger.log('❌ [CuentasPorCobrar] Error en sincronización manual: $e');
    } finally {
      _cargandoMis = false;
      _cargandoTodos = false;
      notifyListeners();
    }
  }

  // ============================================================
  // NAVEGACIÓN Y BÚSQUEDA
  // ============================================================
  void buscar(String query) {
    _searchQuery = query.trim();
    _paginaMisDeudores = 1;
    _paginaTodosDeudores = 1;
    cargarMisDeudores(forceRefresh: false);
    cargarTodosDeudores(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  void limpiarBusqueda() {
    _searchQuery = '';
    _paginaMisDeudores = 1;
    _paginaTodosDeudores = 1;
    cargarMisDeudores(forceRefresh: false);
    cargarTodosDeudores(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  void irPaginaMisDeudores(int pagina) {
    if (pagina < 1 || pagina > _totalPaginasMisDeudores || pagina == _paginaMisDeudores) return;
    _paginaMisDeudores = pagina;
    cargarMisDeudores(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  void irPaginaTodosDeudores(int pagina) {
    if (pagina < 1 || pagina > _totalPaginasTodosDeudores || pagina == _paginaTodosDeudores) return;
    _paginaTodosDeudores = pagina;
    cargarTodosDeudores(forceRefresh: false);
    _actualizarEnSegundoPlano();
  }

  // ============================================================
  // PAGINACIÓN DE FACTURAS
  // ============================================================
  Future<void> irPaginaFacturas(int pagina) async {
    if (pagina < 1 || pagina > _totalPaginasFacturas || pagina == _paginaFacturas) return;
    final clienteId = _clienteSeleccionado?.id;
    if (clienteId == null) return;

    try {
      final result = await _service.obtenerDetalleDeuda(
        clienteId,
        planPage: 1,
        planLimit: 500,
        facturaPage: 1,
        facturaLimit: 500,
      );
      if (result['ok'] == true) {
        final facturasRaw = List<Map<String, dynamic>>.from(result['facturas_pendientes'] ?? []);
        _todasFacturasCache = facturasRaw;
        _totalFacturas = result['facturas_total'] ?? facturasRaw.length;
        _totalPaginasFacturas = _calcularPaginas(_totalFacturas, _facturasPorPagina);
        _aplicarPaginaFacturasDesdeCache(pagina);
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Server falló al paginar facturas, uso caché local: $e');
    }

    _aplicarPaginaFacturasDesdeCache(pagina);
    notifyListeners();
  }

  // ============================================================
  // PAGINACIÓN DE PLANES
  // ============================================================
  Future<void> irPaginaPlanes(int pagina) async {
    if (pagina < 1 || pagina > _totalPaginasPlanes || pagina == _paginaPlanes) return;
    final clienteId = _clienteSeleccionado?.id;
    if (clienteId == null) return;

    try {
      final result = await _service.obtenerDetalleDeuda(
        clienteId,
        planPage: 1,
        planLimit: 500,
        facturaPage: 1,
        facturaLimit: 500,
      );
      if (result['ok'] == true) {
        final planesRaw = _parsearPlanes(result['planes_cuotas']);
        _todosPlanesCache = planesRaw;
        _totalPlanes = result['planes_total'] ?? planesRaw.length;
        _totalPaginasPlanes = _calcularPaginas(_totalPlanes, _planesPorPagina);
        _aplicarPaginaPlanesDesdeCache(pagina);
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CuentasPorCobrar] Server falló al paginar planes, uso caché local: $e');
    }

    _aplicarPaginaPlanesDesdeCache(pagina);
    notifyListeners();
  }

  // ============================================================
  // PAGINACIÓN DE ABONOS
  // ============================================================
  void irPaginaAbonos(int pagina) {
    if (pagina < 1 || pagina > _totalPaginasAbonos || pagina == _paginaAbonos) return;
    _paginaAbonos = pagina;
    final clienteId = _clienteSeleccionado?.id;
    if (clienteId != null) {
      cargarAbonosCliente(clienteId, page: pagina);
    }
  }

  void recargarTodo() {
    _paginaMisDeudores = 1;
    _paginaTodosDeudores = 1;
    cargarMisDeudores(forceRefresh: true);
    cargarTodosDeudores(forceRefresh: true);
  }

  void limpiarDetalle({bool notificar = true}) {
    _clienteSeleccionado = null;
    _facturasPendientes = [];
    _todasFacturasCache = [];
    _paginaFacturas = 1;
    _totalFacturas = 0;
    _totalPaginasFacturas = 1;
    _abonosCliente = [];
    _planesCuotas = [];
    _todosPlanesCache = [];
    _paginaPlanes = 1;
    _totalPlanes = 0;
    _totalPaginasPlanes = 1;
    _paginaAbonos = 1;
    _totalAbonos = 0;
    _totalPaginasAbonos = 1;
    if (notificar) {
      notifyListeners();
    }
  }
}