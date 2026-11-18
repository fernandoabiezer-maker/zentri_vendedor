import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zentri_vendedor/services/venta_service.dart';
import 'package:zentri_vendedor/services/cotizacion_service.dart';
import 'package:zentri_vendedor/services/cuentas_por_cobrar_service.dart';
import 'package:zentri_vendedor/services/cliente_service.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'package:zentri_vendedor/models/venta_pendiente.dart';
import 'package:zentri_vendedor/models/item_carrito.dart';
import 'package:zentri_vendedor/models/item_cotizacion.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class SyncProvider extends ChangeNotifier {
  final SyncDatabaseHelper _dbHelper = SyncDatabaseHelper();
  final VentaService _ventaService = VentaService();
  final CotizacionService _cotizacionService = CotizacionService();
  final CuentasPorCobrarService _cuentasService = CuentasPorCobrarService();
  final ClienteService _clienteService = ClienteService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ============================================================
  // VENTAS PENDIENTES
  // ============================================================
  List<VentaPendiente> _pendientes = [];
  bool _cargando = false;
  bool _sincronizando = false;

  List<VentaPendiente> get pendientes => _pendientes;
  bool get cargando => _cargando;
  bool get sincronizando => _sincronizando;

  // ============================================================
  // COTIZACIONES PENDIENTES
  // ============================================================
  List<CotizacionPendiente> _cotizacionesPendientes = [];
  bool _cargandoCotizaciones = false;
  bool _sincronizandoCotizaciones = false;

  List<CotizacionPendiente> get cotizacionesPendientes => _cotizacionesPendientes;
  bool get cargandoCotizaciones => _cargandoCotizaciones;
  bool get sincronizandoCotizaciones => _sincronizandoCotizaciones;
  int get cotizacionesPendingCount => _cotizacionesPendientes.length;

  // ============================================================
  // ABONOS PENDIENTES
  // ============================================================
  List<AbonoPendiente> _abonosPendientes = [];
  bool _cargandoAbonos = false;
  bool _sincronizandoAbonos = false;

  List<AbonoPendiente> get abonosPendientes => _abonosPendientes;
  bool get cargandoAbonos => _cargandoAbonos;
  bool get sincronizandoAbonos => _sincronizandoAbonos;
  int get abonosPendingCount => _abonosPendientes.length;

  // ============================================================
  // CLIENTES PENDIENTES
  // ============================================================
  List<Map<String, dynamic>> _clientesPendientes = [];
  bool _cargandoClientes = false;
  bool _sincronizandoClientes = false;

  List<Map<String, dynamic>> get clientesPendientes => _clientesPendientes;
  bool get cargandoClientes => _cargandoClientes;
  bool get sincronizandoClientes => _sincronizandoClientes;
  int get clientesPendingCount => _clientesPendientes.length;

  int get pendingCount =>
      _pendientes.length +
      _cotizacionesPendientes.length +
      _abonosPendientes.length +
      _clientesPendientes.length;

  Future<void> cargarPendientes() async {
    await _cargarVentasPendientes();
    await _cargarCotizacionesPendientes();
    await _cargarAbonosPendientes();
    await _cargarClientesPendientes();
  }

  Future<void> recargarClientesPendientes() async {
    await _cargarClientesPendientes();
  }

  // ============================================================
  // HELPERS DE EXTRACCIÓN
  // ============================================================
  Map<String, double>? _extraerPagoMixto(Map<String, dynamic> payload) {
    final raw = payload['pago_mixto_detalle'];
    if (raw == null || raw is! Map) return null;
    final resultado = <String, double>{};
    raw.forEach((k, v) {
      if (v is num) {
        resultado[k.toString()] = v.toDouble();
      }
    });
    return resultado.isEmpty ? null : resultado;
  }

  Map<String, dynamic>? _extraerPlanCuotas(Map<String, dynamic> payload) {
    final raw = payload['plan_cuotas'];
    if (raw == null || raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['activo'] != true) return null;
    return map;
  }

  // ============================================================
  // VENTAS PENDIENTES
  // ============================================================
  Future<void> _cargarVentasPendientes() async {
    _cargando = true;
    notifyListeners();
    try {
      _pendientes = await _dbHelper.obtenerPendientes();
      AppLogger.log('📋 Ventas pendientes: ${_pendientes.length}');
    } catch (e) {
      AppLogger.log('❌ Error cargando ventas pendientes: $e');
      _pendientes = [];
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> agregarVenta(Map<String, dynamic> venta) async {
    await guardarVentaPendiente(venta);
  }

  Future<void> guardarVentaPendiente(Map<String, dynamic> venta) async {
    try {
      await _dbHelper.guardarVentaPendiente(venta);
      await _cargarVentasPendientes();
      AppLogger.log('💾 Venta pendiente guardada');
    } catch (e) {
      AppLogger.log('❌ Error al guardar venta pendiente: $e');
      rethrow;
    }
  }

  Future<void> eliminarVenta(int id) async {
    await eliminarVentaPendiente(id);
  }

  Future<void> eliminarVentaPendiente(int id) async {
    try {
      await _dbHelper.eliminarVentaPendiente(id);
      await _cargarVentasPendientes();
      AppLogger.log('🗑️ Venta pendiente eliminada: $id');
    } catch (e) {
      AppLogger.log('❌ Error al eliminar venta pendiente: $e');
    }
  }

  Future<void> reintentarVenta(VentaPendiente venta) async {
    if (venta.id == null) return;
    try {
      final payload = jsonDecode(venta.payload) as Map<String, dynamic>;

      String usuarioNombre = 'Vendedor';
      try {
        final nombre = await _storage.read(key: 'usuario_nombre');
        if (nombre != null && nombre.isNotEmpty) {
          usuarioNombre = nombre;
        }
      } catch (e) {
        AppLogger.log('⚠️ Error al leer usuario_nombre: $e');
      }

      final itemsData = payload['items'] as List? ?? [];
      final items = itemsData.map((i) => ItemCarrito(
        productoId: i['id'] ?? 0,
        nombre: i['nombre'] ?? 'Producto',
        cantidad: (i['cantidad'] as num?)?.toDouble() ?? 1.0,
        precio: (i['precio_venta'] as num?)?.toDouble() ?? 0.0,
        precioBase: (i['precio_venta'] as num?)?.toDouble(),
        codigo: i['codigo'] ?? '',
        imagen: i['imagen'] ?? '',
      )).toList();

      final result = await _ventaService.finalizarVenta(
        items: items,
        idLocal: payload['id_local'] as String?,
        clienteId: payload['cliente_id'] ?? 0,
        tipoVenta: payload['tipo_venta'] ?? 'contado',
        metodoPago: payload['metodo_pago'] ?? 'efectivo_bs',
        diasCredito: payload['dias_credito'] ?? 0,
        referencia: payload['referencia'] ?? '',
        usuarioNombre: usuarioNombre,
        pagoMixtoDetalle: _extraerPagoMixto(payload),
        planCuotas: _extraerPlanCuotas(payload),
      );

      if (result['ok'] == true) {
        await _dbHelper.eliminarVentaPendiente(venta.id!);
        await _cargarVentasPendientes();
        AppLogger.log('✅ Venta pendiente sincronizada: ${venta.id}');
      } else {
        AppLogger.log('❌ Reintento venta falló: ${result['mensaje']}');
      }
    } catch (e) {
      AppLogger.log('❌ Error en reintentarVenta: $e');
    }
  }

  Future<int> sincronizarVentasTodo() async {
    if (_sincronizando) return 0;
    _sincronizando = true;
    notifyListeners();

    int sincronizadas = 0;
    int errores = 0;

    try {
      String usuarioNombre = 'Vendedor';
      try {
        final nombre = await _storage.read(key: 'usuario_nombre');
        if (nombre != null && nombre.isNotEmpty) {
          usuarioNombre = nombre;
        }
      } catch (e) {
        AppLogger.log('⚠️ Error al leer usuario_nombre: $e');
      }

      final pendientes = await _dbHelper.obtenerPendientes();
      AppLogger.log('🔄 Sincronizando ${pendientes.length} ventas pendientes...');

      for (var venta in pendientes) {
        if (venta.id == null) continue;
        try {
          final payload = jsonDecode(venta.payload) as Map<String, dynamic>;
          final itemsData = payload['items'] as List? ?? [];
          final items = itemsData.map((i) => ItemCarrito(
            productoId: i['id'] ?? 0,
            nombre: i['nombre'] ?? 'Producto',
            cantidad: (i['cantidad'] as num?)?.toDouble() ?? 1.0,
            precio: (i['precio_venta'] as num?)?.toDouble() ?? 0.0,
            precioBase: (i['precio_venta'] as num?)?.toDouble(),
            codigo: i['codigo'] ?? '',
            imagen: i['imagen'] ?? '',
          )).toList();

          final result = await _ventaService.finalizarVenta(
            items: items,
            idLocal: payload['id_local'] as String?,
            clienteId: payload['cliente_id'] ?? 0,
            tipoVenta: payload['tipo_venta'] ?? 'contado',
            metodoPago: payload['metodo_pago'] ?? 'efectivo_bs',
            diasCredito: payload['dias_credito'] ?? 0,
            referencia: payload['referencia'] ?? '',
            usuarioNombre: usuarioNombre,
            pagoMixtoDetalle: _extraerPagoMixto(payload),
            planCuotas: _extraerPlanCuotas(payload),
          );

          if (result['ok'] == true) {
            await _dbHelper.eliminarVentaPendiente(venta.id!);
            sincronizadas++;
          } else {
            errores++;
            AppLogger.log('❌ Error sincronizando venta ${venta.id}: ${result['mensaje']}');
          }
        } catch (e) {
          errores++;
          AppLogger.log('❌ Excepción sincronizando venta ${venta.id}: $e');
        }
      }

      await _cargarVentasPendientes();
    } catch (e) {
      AppLogger.log('❌ Error en sincronización de ventas: $e');
    } finally {
      _sincronizando = false;
      notifyListeners();
    }

    return sincronizadas;
  }

  // ============================================================
  // COTIZACIONES PENDIENTES
  // ============================================================
  Future<void> _cargarCotizacionesPendientes() async {
    _cargandoCotizaciones = true;
    notifyListeners();
    try {
      _cotizacionesPendientes = await _dbHelper.obtenerCotizacionesPendientes();
    } catch (e) {
      _cotizacionesPendientes = [];
    } finally {
      _cargandoCotizaciones = false;
      notifyListeners();
    }
  }

  Future<void> agregarCotizacionPendiente(Map<String, dynamic> cotizacion) async {
    await guardarCotizacionPendiente(cotizacion);
  }

  Future<void> guardarCotizacionPendiente(Map<String, dynamic> cotizacion) async {
    try {
      await _dbHelper.guardarCotizacionPendiente(cotizacion);
      await _cargarCotizacionesPendientes();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> eliminarCotizacionPendiente(int id) async {
    try {
      await _dbHelper.eliminarCotizacionPendiente(id);
      await _cargarCotizacionesPendientes();
    } catch (e) {
      AppLogger.log('❌ Error al eliminar cotización pendiente: $e');
    }
  }

  Future<void> reintentarCotizacion(CotizacionPendiente cotizacion) async {
    if (cotizacion.id == null) return;
    try {
      final payload = jsonDecode(cotizacion.payload) as Map<String, dynamic>;
      final itemsData = payload['items'] as List? ?? [];
      final items = itemsData.map((i) => ItemCotizacion(
        id: i['id'] ?? 0,
        nombre: i['nombre'] ?? 'Producto',
        codigo: i['codigo'] ?? '',
        cantidad: (i['cantidad'] as num?)?.toDouble() ?? 1.0,
        precioUnitario: ((i['precio_final'] ?? i['precio_unitario']) as num?)?.toDouble() ?? 0.0,
        precioBase: (i['precio_unitario'] as num?)?.toDouble(),
        imagen: i['imagen'],
      )).toList();

      final cotizacionId = payload['id'] as int?;
      Map<String, dynamic> result;
      if (cotizacionId != null && cotizacionId > 0) {
        result = await _cotizacionService.actualizarCotizacion(
          id: cotizacionId,
          cliente: payload['cliente'] ?? '',
          clienteRif: payload['cliente_rif'],
          clienteId: payload['cliente_id'],
          tipoVenta: payload['tipo_venta'] ?? 'mayor',
          margenGlobal: (payload['margen_global'] ?? 20.0).toDouble(),
          moneda: payload['moneda'] ?? 'USD',
          tasaBcv: (payload['tasa_bcv'] ?? 0.0).toDouble(),
          tasaParalelo: (payload['tasa_paralelo'] ?? 0.0).toDouble(),
          ivaPorcentaje: (payload['iva_porcentaje'] ?? 16.0).toDouble(),
          metodoPago: payload['metodo_pago'] ?? 'Contado',
          items: items,
        );
      } else {
        result = await _cotizacionService.guardarCotizacion(
          cliente: payload['cliente'] ?? '',
          clienteRif: payload['cliente_rif'],
          clienteId: payload['cliente_id'],
          tipoVenta: payload['tipo_venta'] ?? 'mayor',
          margenGlobal: (payload['margen_global'] ?? 20.0).toDouble(),
          moneda: payload['moneda'] ?? 'USD',
          tasaBcv: (payload['tasa_bcv'] ?? 0.0).toDouble(),
          tasaParalelo: (payload['tasa_paralelo'] ?? 0.0).toDouble(),
          ivaPorcentaje: (payload['iva_porcentaje'] ?? 16.0).toDouble(),
          metodoPago: payload['metodo_pago'] ?? 'Contado',
          items: items,
        );
      }

      if (result['ok'] == true) {
        await _dbHelper.eliminarCotizacionPendiente(cotizacion.id!);
        await _cargarCotizacionesPendientes();
      }
    } catch (e) {
      AppLogger.log('❌ Error en reintentarCotizacion: $e');
    }
  }

  Future<int> sincronizarCotizacionesTodo() async {
    if (_sincronizandoCotizaciones) return 0;
    _sincronizandoCotizaciones = true;
    notifyListeners();

    int sincronizadas = 0;
    int errores = 0;

    try {
      final pendientes = await _dbHelper.obtenerCotizacionesPendientes();

      for (var cotizacion in pendientes) {
        if (cotizacion.id == null) continue;
        try {
          final payload = jsonDecode(cotizacion.payload) as Map<String, dynamic>;
          final itemsData = payload['items'] as List? ?? [];
          final items = itemsData.map((i) => ItemCotizacion(
            id: i['id'] ?? 0,
            nombre: i['nombre'] ?? 'Producto',
            codigo: i['codigo'] ?? '',
            cantidad: (i['cantidad'] as num?)?.toDouble() ?? 1.0,
            precioUnitario: ((i['precio_final'] ?? i['precio_unitario']) as num?)?.toDouble() ?? 0.0,
            precioBase: (i['precio_unitario'] as num?)?.toDouble(),
            imagen: i['imagen'],
          )).toList();

          final cotizacionId = payload['id'] as int?;
          Map<String, dynamic> result;
          if (cotizacionId != null && cotizacionId > 0) {
            result = await _cotizacionService.actualizarCotizacion(
              id: cotizacionId,
              cliente: payload['cliente'] ?? '',
              clienteRif: payload['cliente_rif'],
              clienteId: payload['cliente_id'],
              tipoVenta: payload['tipo_venta'] ?? 'mayor',
              margenGlobal: (payload['margen_global'] ?? 20.0).toDouble(),
              moneda: payload['moneda'] ?? 'USD',
              tasaBcv: (payload['tasa_bcv'] ?? 0.0).toDouble(),
              tasaParalelo: (payload['tasa_paralelo'] ?? 0.0).toDouble(),
              ivaPorcentaje: (payload['iva_porcentaje'] ?? 16.0).toDouble(),
              metodoPago: payload['metodo_pago'] ?? 'Contado',
              items: items,
            );
          } else {
            result = await _cotizacionService.guardarCotizacion(
              cliente: payload['cliente'] ?? '',
              clienteRif: payload['cliente_rif'],
              clienteId: payload['cliente_id'],
              tipoVenta: payload['tipo_venta'] ?? 'mayor',
              margenGlobal: (payload['margen_global'] ?? 20.0).toDouble(),
              moneda: payload['moneda'] ?? 'USD',
              tasaBcv: (payload['tasa_bcv'] ?? 0.0).toDouble(),
              tasaParalelo: (payload['tasa_paralelo'] ?? 0.0).toDouble(),
              ivaPorcentaje: (payload['iva_porcentaje'] ?? 16.0).toDouble(),
              metodoPago: payload['metodo_pago'] ?? 'Contado',
              items: items,
            );
          }

          if (result['ok'] == true) {
            await _dbHelper.eliminarCotizacionPendiente(cotizacion.id!);
            sincronizadas++;
          } else {
            errores++;
          }
        } catch (e) {
          errores++;
          AppLogger.log('❌ Excepción sincronizando cotización ${cotizacion.id}: $e');
        }
      }

      await _cargarCotizacionesPendientes();
    } catch (e) {
      AppLogger.log('❌ Error en sincronización de cotizaciones: $e');
    } finally {
      _sincronizandoCotizaciones = false;
      notifyListeners();
    }

    return sincronizadas;
  }

  // ============================================================
  // ABONOS PENDIENTES
  // ============================================================
  Future<void> _cargarAbonosPendientes() async {
    _cargandoAbonos = true;
    notifyListeners();
    try {
      _abonosPendientes = await _dbHelper.obtenerAbonosPendientes();
      AppLogger.log('📋 Abonos pendientes: ${_abonosPendientes.length}');
    } catch (e) {
      _abonosPendientes = [];
    } finally {
      _cargandoAbonos = false;
      notifyListeners();
    }
  }

  Future<void> agregarAbonoPendiente(Map<String, dynamic> abono) async {
    await guardarAbonoPendiente(abono);
  }

  Future<void> guardarAbonoPendiente(Map<String, dynamic> abono) async {
    try {
      await _dbHelper.guardarAbonoPendiente(abono);
      await _cargarAbonosPendientes();
      AppLogger.log('💾 Abono pendiente guardado');
    } catch (e) {
      AppLogger.log('❌ Error al guardar abono pendiente: $e');
      rethrow;
    }
  }

  Future<void> eliminarAbonoPendiente(int id) async {
    try {
      await _dbHelper.eliminarAbonoPendiente(id);
      await _cargarAbonosPendientes();
      AppLogger.log('🗑️ Abono pendiente eliminado: $id');
    } catch (e) {
      AppLogger.log('❌ Error al eliminar abono pendiente: $e');
    }
  }

  // ============================================================
  // REINTENTAR ABONO (con propagación de pago_mixto_detalle)
  // ============================================================
  Future<void> reintentarAbono(AbonoPendiente abono) async {
    if (abono.id == null) return;
    try {
      final payload = jsonDecode(abono.payload) as Map<String, dynamic>;
      final pagoMixto = _extraerPagoMixto(payload);

      final result = await _cuentasService.registrarAbono(
        ventaId: (payload['venta_id'] as num).toInt(),
        montoUsd: (payload['monto'] as num).toDouble(),
        metodoPago: payload['metodo_pago'] ?? 'efectivo_bs',
        referencia: payload['referencia'],
        pagoMixtoDetalle: pagoMixto,
      );

      if (result['ok'] == true) {
        await _dbHelper.eliminarAbonoPendiente(abono.id!);
        await _cargarAbonosPendientes();
        AppLogger.log('✅ Abono pendiente sincronizado: ${abono.id}');
      } else if (result['validacion'] == true) {
        await _dbHelper.eliminarAbonoPendiente(abono.id!);
        await _cargarAbonosPendientes();
        AppLogger.log('❌ Abono ${abono.id} rechazado por el servidor: ${result['mensaje']}');
      } else {
        AppLogger.log('⚠️ Abono ${abono.id} falló sin validación: ${result['mensaje']}');
      }
    } catch (e) {
      AppLogger.log('⚠️ Error de conexión en reintentarAbono (se mantiene pendiente): $e');
    }
  }

  Future<int> sincronizarAbonosTodo() async {
    if (_sincronizandoAbonos) return 0;
    _sincronizandoAbonos = true;
    notifyListeners();

    int sincronizadas = 0;
    int errores = 0;

    try {
      final pendientes = await _dbHelper.obtenerAbonosPendientes();
      AppLogger.log('🔄 Sincronizando ${pendientes.length} abonos pendientes...');

      for (var abono in pendientes) {
        if (abono.id == null) continue;
        try {
          final payload = jsonDecode(abono.payload) as Map<String, dynamic>;
          final pagoMixto = _extraerPagoMixto(payload);

          final result = await _cuentasService.registrarAbono(
            ventaId: (payload['venta_id'] as num).toInt(),
            montoUsd: (payload['monto'] as num).toDouble(),
            metodoPago: payload['metodo_pago'] ?? 'efectivo_bs',
            referencia: payload['referencia'],
            pagoMixtoDetalle: pagoMixto,
          );

          if (result['ok'] == true) {
            await _dbHelper.eliminarAbonoPendiente(abono.id!);
            sincronizadas++;
            AppLogger.log('✅ Abono ${abono.id} sincronizado');
          } else if (result['validacion'] == true) {
            await _dbHelper.eliminarAbonoPendiente(abono.id!);
            errores++;
            AppLogger.log('❌ Abono ${abono.id} rechazado (no aplica): ${result['mensaje']}');
          } else {
            errores++;
            AppLogger.log('❌ Error sincronizando abono ${abono.id}: ${result['mensaje']}');
          }
        } catch (e) {
          errores++;
          AppLogger.log('⚠️ Error de conexión sincronizando abono ${abono.id}: $e');
        }
      }

      await _cargarAbonosPendientes();
    } catch (e) {
      AppLogger.log('❌ Error en sincronización de abonos: $e');
    } finally {
      _sincronizandoAbonos = false;
      notifyListeners();
    }

    return sincronizadas;
  }

  // ============================================================
  // CLIENTES PENDIENTES
  // ============================================================
  Future<void> _cargarClientesPendientes() async {
    _cargandoClientes = true;
    notifyListeners();
    try {
      _clientesPendientes = await _dbHelper.obtenerClientesPendientes();
    } catch (e) {
      _clientesPendientes = [];
    } finally {
      _cargandoClientes = false;
      notifyListeners();
    }
  }

  Future<void> reintentarClientePendiente(Map<String, dynamic> pendiente) async {
    final idLocal = pendiente['id_local'];
    if (idLocal == null) return;
    try {
      final payload = jsonDecode(pendiente['payload']) as Map<String, dynamic>;
      final tieneId = payload.containsKey('id') &&
          payload['id'] != null &&
          (payload['id'] is num) &&
          (payload['id'] as num) > 0;

      if (tieneId) {
        await _clienteService.actualizarCliente(
          id: (payload['id'] as num).toInt(),
          nombre: payload['nombre'] ?? '',
          cedula: payload['cedula'] ?? '',
          telefono: payload['telefono'] ?? '',
          email: payload['email'] ?? '',
          direccion: payload['direccion'] ?? '',
          notas: payload['notas'] ?? '',
          activo: payload['activo'] ?? 1,
          vendedorId: payload['vendedor_id'],
          ubicacionGps: payload['ubicacion_gps'] ?? '',
        );
      } else {
        await _clienteService.crearCliente(
          nombre: payload['nombre'] ?? '',
          cedula: payload['cedula'] ?? '',
          telefono: payload['telefono'] ?? '',
          email: payload['email'] ?? '',
          direccion: payload['direccion'] ?? '',
          notas: payload['notas'] ?? '',
          activo: payload['activo'] ?? 1,
          vendedorId: payload['vendedor_id'],
          ubicacionGps: payload['ubicacion_gps'] ?? '',
        );
      }

      await _dbHelper.eliminarClientePendiente(idLocal);
      await _cargarClientesPendientes();
    } catch (e) {
      AppLogger.log('❌ Error en reintentarClientePendiente: $e');
      rethrow;
    }
  }

  Future<void> eliminarClientePendiente(String idLocal) async {
    try {
      await _dbHelper.eliminarClientePendiente(idLocal);
      await _cargarClientesPendientes();
    } catch (e) {
      AppLogger.log('❌ Error al eliminar cliente pendiente: $e');
    }
  }

  Future<int> sincronizarClientesPendientes() async {
    if (_sincronizandoClientes) return 0;
    _sincronizandoClientes = true;
    notifyListeners();

    int sincronizados = 0;
    int errores = 0;

    try {
      final pendientes = await _dbHelper.obtenerClientesPendientes();

      for (var pendiente in pendientes) {
        final idLocal = pendiente['id_local'];
        try {
          final payload = jsonDecode(pendiente['payload']) as Map<String, dynamic>;

          final tieneId = payload.containsKey('id') &&
              payload['id'] != null &&
              (payload['id'] is num) &&
              (payload['id'] as num) > 0;

          if (tieneId) {
            await _clienteService.actualizarCliente(
              id: (payload['id'] as num).toInt(),
              nombre: payload['nombre'] ?? '',
              cedula: payload['cedula'] ?? '',
              telefono: payload['telefono'] ?? '',
              email: payload['email'] ?? '',
              direccion: payload['direccion'] ?? '',
              notas: payload['notas'] ?? '',
              activo: payload['activo'] ?? 1,
              vendedorId: payload['vendedor_id'],
              ubicacionGps: payload['ubicacion_gps'] ?? '',
            );
          } else {
            await _clienteService.crearCliente(
              nombre: payload['nombre'] ?? '',
              cedula: payload['cedula'] ?? '',
              telefono: payload['telefono'] ?? '',
              email: payload['email'] ?? '',
              direccion: payload['direccion'] ?? '',
              notas: payload['notas'] ?? '',
              activo: payload['activo'] ?? 1,
              vendedorId: payload['vendedor_id'],
              ubicacionGps: payload['ubicacion_gps'] ?? '',
            );
          }

          await _dbHelper.eliminarClientePendiente(idLocal);
          sincronizados++;
        } catch (e) {
          errores++;
        }
      }

      await _cargarClientesPendientes();
    } catch (e) {
      AppLogger.log('❌ Error en sincronización de clientes: $e');
    } finally {
      _sincronizandoClientes = false;
      notifyListeners();
    }

    return sincronizados;
  }

  Future<int> sincronizarTodo() async {
    final totalVentas = await sincronizarVentasTodo();
    final totalCotizaciones = await sincronizarCotizacionesTodo();
    final totalAbonos = await sincronizarAbonosTodo();
    final totalClientes = await sincronizarClientesPendientes();
    final total = totalVentas + totalCotizaciones + totalAbonos + totalClientes;
    AppLogger.log(
      '✅ Sincronización completada: $totalVentas ventas, $totalCotizaciones cotizaciones, $totalAbonos abonos, $totalClientes clientes'
    );
    return total;
  }

  Future<void> limpiarTodas() async {
    try {
      await _dbHelper.limpiarPendientes();
      await _dbHelper.limpiarCotizacionesPendientes();
      await _dbHelper.limpiarAbonosPendientes();
      await _dbHelper.limpiarClientesPendientes();
      await cargarPendientes();
    } catch (e) {
      AppLogger.log('❌ Error al limpiar todas las pendientes: $e');
    }
  }
}