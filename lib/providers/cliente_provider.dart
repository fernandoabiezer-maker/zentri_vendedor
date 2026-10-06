import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/services/cliente_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class ClienteProvider extends ChangeNotifier {
  final ClienteService _service = ClienteService();
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();

  List<Cliente> _clientes = [];
  bool _cargando = false;
  bool _actualizando = false;
  String _busqueda = '';
  int _pagina = 1;
  int _total = 0;
  int _totalPaginas = 1;
  final int _limite = 20;

  Cliente? _clienteSeleccionado;
  Map<String, dynamic>? _comportamiento;
  bool _cargandoDetalle = false;
  bool _cargandoMasHistorial = false;
  bool _cargandoMasFacturas = false;
  String? _error;

  int _historialPage = 1;
  int _historialTotal = 0;
  int _historialPages = 1;
  final int _historialLimit = 10;

  int _facturaPage = 1;
  int _facturaTotal = 0;
  int _facturaPages = 1;
  final int _facturaLimit = 5;

  bool _precargando = false;

  // Getters
  List<Cliente> get clientes => _clientes;
  bool get cargando => _cargando;
  bool get actualizando => _actualizando;
  String get busqueda => _busqueda;
  int get pagina => _pagina;
  int get total => _total;
  int get totalPaginas => _totalPaginas;
  Cliente? get clienteSeleccionado => _clienteSeleccionado;
  Map<String, dynamic>? get comportamiento => _comportamiento;
  bool get cargandoDetalle => _cargandoDetalle;
  bool get cargandoMasHistorial => _cargandoMasHistorial;
  bool get cargandoMasFacturas => _cargandoMasFacturas;
  String? get error => _error;
  int get historialPage => _historialPage;
  int get historialTotal => _historialTotal;
  int get historialPages => _historialPages;
  int get facturaPage => _facturaPage;
  int get facturaTotal => _facturaTotal;
  int get facturaPages => _facturaPages;
  bool get precargando => _precargando;

  List<Cliente> filtrarClientesLocal(String query) {
    if (query.isEmpty) return List.from(_clientes);
    final q = query.toLowerCase().trim();
    return _clientes.where((cliente) {
      return cliente.nombre.toLowerCase().contains(q) ||
          cliente.cedula.toLowerCase().contains(q);
    }).toList();
  }

  List<Cliente> buscarClientesLocal(String query) {
    return filtrarClientesLocal(query);
  }

  Future<void> cargarClientes({String? query, int? page, bool forceRefresh = false}) async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    notifyListeners();

    final q = query ?? _busqueda;
    final p = page ?? _pagina;

    AppLogger.log('📦 [ClienteProvider] cargarClientes() - forceRefresh: $forceRefresh');

    try {
      if (_clientes.isNotEmpty && !forceRefresh) {
        AppLogger.log('✅ [ClienteProvider] Datos ya en memoria, saltando carga');
        _cargando = false;
        notifyListeners();
        return;
      }

      AppLogger.log('📦 [ClienteProvider] Intentando cargar desde caché...');
      final clientesCache = await _dbHelper.obtenerClientes();
      AppLogger.log('📦 [ClienteProvider] clientesCache.length: ${clientesCache.length}');

      if (clientesCache.isNotEmpty) {
        _clientes = clientesCache;
        _total = clientesCache.length;
        _totalPaginas = 1;
        _pagina = 1;
        if (query != null) _busqueda = query;
        _error = null;
        _cargando = false;
        notifyListeners();
        AppLogger.log('✅ [ClienteProvider] Cargados ${_clientes.length} clientes desde caché');
      } else {
        AppLogger.log('⚠️ [ClienteProvider] Caché vacía');
        _error = 'Sin datos locales. Conéctate para sincronizar.';
        _cargando = false;
        notifyListeners();
      }

      if (forceRefresh) {
        AppLogger.log('🔄 [ClienteProvider] forceRefresh activo, actualizando desde servidor...');
        await _actualizarDesdeServidor(query: q, page: p);
      }
    } catch (e) {
      AppLogger.log('❌ [ClienteProvider] Error en cargarClientes: $e');
      _error = e.toString();
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> _actualizarDesdeServidor({String? query, int? page, bool notify = false}) async {
    if (_actualizando) return;
    _actualizando = true;
    if (notify) notifyListeners();

    AppLogger.log('🔄 [ClienteProvider] Actualizando desde servidor...');
    try {
      final q = query ?? _busqueda;
      final p = page ?? _pagina;
      final result = await _service.listarClientes(query: q, page: p, limit: _limite);
      if (result['ok'] == true) {
        _clientes = result['clientes'] ?? [];
        _total = result['total'] ?? 0;
        _totalPaginas = result['totalPages'] ?? 1;
        _pagina = result['page'] ?? 1;
        if (query != null) _busqueda = query;
        await _dbHelper.guardarClientes(_clientes);
        _error = null;
        AppLogger.log('✅ [ClienteProvider] Actualizados ${_clientes.length} clientes desde servidor');
      } else {
        AppLogger.log('⚠️ [ClienteProvider] Servidor devolvió ok=false: ${result['mensaje']}');
      }
    } catch (e) {
      AppLogger.log('❌ [ClienteProvider] Actualización desde servidor falló: $e');
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

    AppLogger.log('🔄 [ClienteProvider] Sincronización manual iniciada...');
    try {
      final result = await _service.listarClientes(query: _busqueda, page: _pagina, limit: _limite);
      if (result['ok'] == true) {
        _clientes = result['clientes'] ?? [];
        _total = result['total'] ?? 0;
        _totalPaginas = result['totalPages'] ?? 1;
        _pagina = result['page'] ?? 1;
        await _dbHelper.guardarClientes(_clientes);
        _error = null;
        AppLogger.log('✅ [ClienteProvider] Sincronización manual completada: ${_clientes.length} clientes');
      } else {
        AppLogger.log('⚠️ [ClienteProvider] Sincronización manual falló: ${result['mensaje']}');
        _error = result['mensaje'] ?? 'Error al sincronizar';
      }
    } catch (e) {
      AppLogger.log('❌ [ClienteProvider] Error en sincronización manual: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================================
  // DETALLE DE CLIENTE
  // ============================================================
  Future<void> cargarDetalle(int clienteId) async {
    if (_cargandoDetalle) return;
    _cargandoDetalle = true;
    _clienteSeleccionado = null;
    _comportamiento = null;
    _error = null;
    _historialPage = 1;
    _historialTotal = 0;
    _historialPages = 1;
    _facturaPage = 1;
    _facturaTotal = 0;
    _facturaPages = 1;
    notifyListeners();

    AppLogger.log('🔍 [ClienteProvider] cargarDetalle() para clienteId: $clienteId');

    Cliente? clienteEnMemoria;
    try {
      clienteEnMemoria = _clientes.firstWhere((c) => c.id == clienteId);
      AppLogger.log('✅ [ClienteProvider] Cliente encontrado en memoria: ${clienteEnMemoria.nombre}');
    } catch (e) {
      AppLogger.log('⚠️ [ClienteProvider] Cliente NO encontrado en memoria');
    }

    try {
      AppLogger.log('🌐 [ClienteProvider] Intentando obtener comportamiento desde servidor...');
      final result = await _service.obtenerComportamiento(
        clienteId,
        historialPage: _historialPage,
        historialLimit: _historialLimit,
        facturaPage: _facturaPage,
        facturaLimit: _facturaLimit,
      );

      AppLogger.log('📦 [ClienteProvider] Respuesta del servidor:');
      AppLogger.log('   - ok: ${result['ok']}');
      AppLogger.log('   - historial length: ${result['historial']?.length ?? 0}');
      AppLogger.log('   - facturas_pendientes length: ${result['facturas_pendientes']?.length ?? 0}');

      if (result['ok'] == true) {
        _clienteSeleccionado = result['cliente'];
        _comportamiento = result;
        _historialPage = result['historialPage'] ?? 1;
        _historialTotal = result['historialTotal'] ?? 0;
        _historialPages = result['historialPages'] ?? 1;
        _facturaPage = result['facturaPage'] ?? 1;
        _facturaTotal = result['facturaTotal'] ?? 0;
        _facturaPages = result['facturaPages'] ?? 1;

        await _dbHelper.guardarComportamientoCliente(clienteId, result);
        _error = null;
        _cargandoDetalle = false;
        notifyListeners();
        AppLogger.log('✅ [ClienteProvider] Detalle cargado desde servidor y guardado en caché');
        return;
      } else {
        AppLogger.log('⚠️ [ClienteProvider] Servidor devolvió ok=false: ${result['mensaje']}');
      }
    } catch (e) {
      AppLogger.log('⚠️ [ClienteProvider] Servidor falló: $e');
    }

    try {
      final comportamientoCache = await _dbHelper.obtenerComportamientoCliente(clienteId);
      if (comportamientoCache != null && comportamientoCache.isNotEmpty) {
        AppLogger.log('📦 [ClienteProvider] Comportamiento encontrado en caché local');
        _clienteSeleccionado = clienteEnMemoria ?? Cliente(
          id: clienteId,
          nombre: comportamientoCache['cliente']?['nombre'] ?? 'Cliente',
          cedula: comportamientoCache['cliente']?['cedula'] ?? '',
        );
        _comportamiento = comportamientoCache;
        _historialPage = comportamientoCache['historialPage'] ?? 1;
        _historialTotal = comportamientoCache['historialTotal'] ?? 0;
        _historialPages = comportamientoCache['historialPages'] ?? 1;
        _facturaPage = comportamientoCache['facturaPage'] ?? 1;
        _facturaTotal = comportamientoCache['facturaTotal'] ?? 0;
        _facturaPages = comportamientoCache['facturaPages'] ?? 1;
        _error = null;
        _cargandoDetalle = false;
        notifyListeners();
        AppLogger.log('✅ [ClienteProvider] Detalle cargado desde caché local');
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [ClienteProvider] Error al leer caché de comportamiento: $e');
    }

    if (clienteEnMemoria != null) {
      _clienteSeleccionado = clienteEnMemoria;
      _comportamiento = {
        'historial': [],
        'facturas_pendientes': [],
        'total_deuda_usd': clienteEnMemoria.deudaUsd,
        'total_deuda_bs': clienteEnMemoria.deudaBs,
      };
      _historialPage = 1;
      _historialTotal = 0;
      _historialPages = 1;
      _facturaPage = 1;
      _facturaTotal = 0;
      _facturaPages = 1;
      _error = 'Modo offline: datos limitados';
      AppLogger.log('✅ [ClienteProvider] Datos básicos cargados desde memoria');
    } else {
      _clienteSeleccionado = null;
      _comportamiento = null;
      _error = 'No se pudo cargar el detalle del cliente';
      AppLogger.log('❌ [ClienteProvider] No se encontró el cliente');
    }

    _cargandoDetalle = false;
    notifyListeners();
  }

  // ============================================================
  // CARGAR MÁS HISTORIAL (PAGINACIÓN)
  // ============================================================
  Future<void> cargarMasHistorial(int clienteId) async {
    if (_cargandoMasHistorial || _historialPage >= _historialPages) {
      AppLogger.log('⚠️ [ClienteProvider] No hay más páginas de historial');
      return;
    }

    _cargandoMasHistorial = true;
    notifyListeners();

    try {
      final nextPage = _historialPage + 1;
      AppLogger.log('🔄 [ClienteProvider] Cargando página $nextPage de historial...');
      final result = await _service.obtenerComportamiento(
        clienteId,
        historialPage: nextPage,
        historialLimit: _historialLimit,
        facturaPage: _facturaPage,
        facturaLimit: _facturaLimit,
      );

      if (result['ok'] == true) {
        final nuevosHistorial = result['historial'] ?? [];
        final historialActual = _comportamiento?['historial'] ?? [];
        _comportamiento?['historial'] = [...historialActual, ...nuevosHistorial];
        _historialPage = result['historialPage'] ?? nextPage;
        _historialTotal = result['historialTotal'] ?? _historialTotal;
        _historialPages = result['historialPages'] ?? _historialPages;
        _facturaPage = result['facturaPage'] ?? _facturaPage;
        _facturaTotal = result['facturaTotal'] ?? _facturaTotal;
        _facturaPages = result['facturaPages'] ?? _facturaPages;

        await _dbHelper.guardarComportamientoCliente(clienteId, _comportamiento!);
        AppLogger.log('✅ [ClienteProvider] Cargada página $nextPage de historial');
      } else {
        AppLogger.log('⚠️ [ClienteProvider] Error al cargar más historial: ${result['mensaje']}');
      }
    } catch (e) {
      AppLogger.log('❌ [ClienteProvider] Error cargando más historial: $e');
    } finally {
      _cargandoMasHistorial = false;
      notifyListeners();
    }
  }

  // ============================================================
  // CARGAR MÁS FACTURAS (PAGINACIÓN)
  // ============================================================
  Future<void> cargarMasFacturas(int clienteId) async {
    if (_cargandoMasFacturas || _facturaPage >= _facturaPages) {
      AppLogger.log('⚠️ [ClienteProvider] No hay más páginas de facturas');
      return;
    }

    _cargandoMasFacturas = true;
    notifyListeners();

    try {
      final nextPage = _facturaPage + 1;
      AppLogger.log('🔄 [ClienteProvider] Cargando página $nextPage de facturas...');
      final result = await _service.obtenerComportamiento(
        clienteId,
        historialPage: _historialPage,
        historialLimit: _historialLimit,
        facturaPage: nextPage,
        facturaLimit: _facturaLimit,
      );

      if (result['ok'] == true) {
        final nuevasFacturas = result['facturas_pendientes'] ?? [];
        final facturasActual = _comportamiento?['facturas_pendientes'] ?? [];
        _comportamiento?['facturas_pendientes'] = [...facturasActual, ...nuevasFacturas];
        _facturaPage = result['facturaPage'] ?? nextPage;
        _facturaTotal = result['facturaTotal'] ?? _facturaTotal;
        _facturaPages = result['facturaPages'] ?? _facturaPages;
        _historialPage = result['historialPage'] ?? _historialPage;
        _historialTotal = result['historialTotal'] ?? _historialTotal;
        _historialPages = result['historialPages'] ?? _historialPages;

        await _dbHelper.guardarComportamientoCliente(clienteId, _comportamiento!);
        AppLogger.log('✅ [ClienteProvider] Cargada página $nextPage de facturas');
      } else {
        AppLogger.log('⚠️ [ClienteProvider] Error al cargar más facturas: ${result['mensaje']}');
      }
    } catch (e) {
      AppLogger.log('❌ [ClienteProvider] Error cargando más facturas: $e');
    } finally {
      _cargandoMasFacturas = false;
      notifyListeners();
    }
  }

  // ============================================================
  // PRECARGA DE COMPORTAMIENTO (UNA SOLA VEZ)
  // ============================================================
  Future<void> precargarComportamientoClientes({int limite = 20}) async {
    if (_precargando) return;
    if (_clientes.isEmpty) {
      AppLogger.log('⚠️ [ClienteProvider] No hay clientes para precargar');
      return;
    }

    _precargando = true;
    AppLogger.log('🔄 [ClienteProvider] Iniciando precarga de comportamiento para hasta $limite clientes...');

    List<Cliente> clientesParaPrecargar = _clientes
        .where((c) => c.activo == 1)
        .toList()
      ..sort((a, b) => b.deudaUsd.compareTo(a.deudaUsd));

    if (clientesParaPrecargar.length > limite) {
      clientesParaPrecargar = clientesParaPrecargar.sublist(0, limite);
    }

    int exitosos = 0;
    int fallidos = 0;

    for (var cliente in clientesParaPrecargar) {
      try {
        final result = await _service.obtenerComportamiento(
          cliente.id!,
          historialPage: 1,
          historialLimit: _historialLimit,
          facturaPage: 1,
          facturaLimit: _facturaLimit,
        );
        if (result['ok'] == true) {
          await _dbHelper.guardarComportamientoCliente(cliente.id!, result);
          exitosos++;
          AppLogger.log('✅ [ClienteProvider] Precargado cliente ${cliente.nombre} (${cliente.id})');
        } else {
          fallidos++;
        }
      } catch (e) {
        fallidos++;
        AppLogger.log('⚠️ [ClienteProvider] Error precargando cliente ${cliente.id}: $e');
      }
    }

    _precargando = false;
    AppLogger.log('✅ [ClienteProvider] Precarga completada: $exitosos exitosos, $fallidos fallidos');
    notifyListeners();
  }

  void limpiarDetalle() {
    _clienteSeleccionado = null;
    _comportamiento = null;
    _historialPage = 1;
    _historialTotal = 0;
    _historialPages = 1;
    _facturaPage = 1;
    _facturaTotal = 0;
    _facturaPages = 1;
    notifyListeners();
  }

  void irPagina(int pagina) {
    if (pagina < 1 || pagina > _totalPaginas || pagina == _pagina) return;
    _pagina = pagina;
    cargarClientes(forceRefresh: false);
  }

  void buscar(String query) {
    _busqueda = query;
    _pagina = 1;
    notifyListeners();
    _actualizarDesdeServidor(query: query, page: 1, notify: true);
  }

  void limpiarBusqueda() {
    _busqueda = '';
    _pagina = 1;
    cargarClientes(forceRefresh: false);
  }

  // ============================================================
  // CREAR CLIENTE CON GUARDADO OFFLINE CORRECTO
  // ============================================================
  Future<Cliente?> crearCliente({
    required String nombre,
    required String cedula,
    String telefono = '',
    String email = '',
    String direccion = '',
    String notas = '',
    int activo = 1,
    int? vendedorId,
    String? ubicacionGps,
  }) async {
    try {
      final cliente = await _service.crearCliente(
        nombre: nombre,
        cedula: cedula,
        telefono: telefono,
        email: email,
        direccion: direccion,
        notas: notas,
        activo: activo,
        vendedorId: vendedorId,
        ubicacionGps: ubicacionGps,
      );
      await sincronizar();
      return cliente;
    } catch (e) {
      AppLogger.log('⚠️ Servidor falló al crear cliente. Guardando offline...');
      final idLocal = 'local_${DateTime.now().millisecondsSinceEpoch}';

      // ✅ CREACIÓN: no se incluye 'id' (es nuevo)
      await _dbHelper.guardarClientePendiente({
        'id_local': idLocal,
        'nombre': nombre,
        'cedula': cedula,
        'telefono': telefono,
        'email': email,
        'direccion': direccion,
        'ubicacion_gps': ubicacionGps ?? '',
        'notas': notas,
        'activo': activo,
        'vendedor_id': vendedorId,
        // No incluimos 'id' → SyncProvider lo tratará como creación
      });

      final clienteLocal = Cliente(
        id: null,
        nombre: nombre,
        cedula: cedula,
        telefono: telefono,
        email: email,
        direccion: direccion,
        notas: notas,
        activo: activo,
        vendedorId: vendedorId,
        ubicacionGps: ubicacionGps,
        puntaje: 0,
        categoria: 'Nuevo',
      );
      _clientes.add(clienteLocal);
      notifyListeners();
      throw Exception('Cliente guardado localmente (offline). Se sincronizará cuando haya conexión.');
    }
  }

  // ============================================================
  // ACTUALIZAR CLIENTE CON GUARDADO OFFLINE CORRECTO
  // ============================================================
  Future<Cliente?> actualizarCliente({
    required int id,
    required String nombre,
    required String cedula,
    String telefono = '',
    String email = '',
    String direccion = '',
    String notas = '',
    int activo = 1,
    int? vendedorId,
    String? ubicacionGps,
  }) async {
    try {
      final cliente = await _service.actualizarCliente(
        id: id,
        nombre: nombre,
        cedula: cedula,
        telefono: telefono,
        email: email,
        direccion: direccion,
        notas: notas,
        activo: activo,
        vendedorId: vendedorId,
        ubicacionGps: ubicacionGps,
      );
      await sincronizar();
      return cliente;
    } catch (e) {
      AppLogger.log('⚠️ Servidor falló al actualizar cliente. Guardando offline...');
      final index = _clientes.indexWhere((c) => c.id == id);
      if (index != -1) {
        final clienteActualizado = _clientes[index].copyWith(
          nombre: nombre,
          cedula: cedula,
          telefono: telefono,
          email: email,
          direccion: direccion,
          notas: notas,
          activo: activo,
          vendedorId: vendedorId,
          ubicacionGps: ubicacionGps,
        );
        _clientes[index] = clienteActualizado;
        await _dbHelper.guardarClientes(_clientes);

        final idLocal = 'local_${DateTime.now().millisecondsSinceEpoch}';

        // ✅ ACTUALIZACIÓN: SÍ se incluye 'id' para que SyncProvider sepa que es update
        await _dbHelper.guardarClientePendiente({
          'id_local': idLocal,
          'id': id, // 👈 CLAVE: esto permite que SyncProvider llame a actualizarCliente() en vez de crearCliente()
          'nombre': nombre,
          'cedula': cedula,
          'telefono': telefono,
          'email': email,
          'direccion': direccion,
          'ubicacion_gps': ubicacionGps ?? '',
          'notas': notas,
          'activo': activo,
          'vendedor_id': vendedorId,
        });

        notifyListeners();
        throw Exception('Cliente actualizado localmente (offline). Se sincronizará cuando haya conexión.');
      } else {
        rethrow;
      }
    }
  }

  // ============================================================
  // SINCRONIZAR CLIENTES PENDIENTES (MÉTODO ANTIGUO — se mantiene por compatibilidad)
  // ============================================================
  Future<int> sincronizarClientesPendientes() async {
    final pendientes = await _dbHelper.obtenerClientesPendientes();
    int sincronizados = 0;

    for (var pendiente in pendientes) {
      try {
        final payload = jsonDecode(pendiente['payload']) as Map<String, dynamic>;
        if (payload.containsKey('id') && payload['id'] != null && payload['id'] > 0) {
          await _service.actualizarCliente(
            id: payload['id'],
            nombre: payload['nombre'],
            cedula: payload['cedula'],
            telefono: payload['telefono'] ?? '',
            email: payload['email'] ?? '',
            direccion: payload['direccion'] ?? '',
            notas: payload['notas'] ?? '',
            activo: payload['activo'] ?? 1,
            vendedorId: payload['vendedor_id'],
            ubicacionGps: payload['ubicacion_gps'] ?? '',
          );
        } else {
          await _service.crearCliente(
            nombre: payload['nombre'],
            cedula: payload['cedula'],
            telefono: payload['telefono'] ?? '',
            email: payload['email'] ?? '',
            direccion: payload['direccion'] ?? '',
            notas: payload['notas'] ?? '',
            activo: payload['activo'] ?? 1,
            vendedorId: payload['vendedor_id'],
            ubicacionGps: payload['ubicacion_gps'] ?? '',
          );
        }
        await _dbHelper.eliminarClientePendiente(pendiente['id_local']);
        sincronizados++;
      } catch (e) {
        AppLogger.log('❌ Error sincronizando cliente pendiente: $e');
      }
    }

    if (sincronizados > 0) {
      await sincronizar();
    }

    return sincronizados;
  }

  Future<bool> eliminarCliente(int id) async {
    final ok = await _service.eliminarCliente(id);
    if (ok) await sincronizar();
    return ok;
  }
}