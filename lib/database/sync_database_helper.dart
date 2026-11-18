import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:zentri_vendedor/models/venta_pendiente.dart';
import 'package:zentri_vendedor/models/producto.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/models/venta.dart';
import 'package:zentri_vendedor/models/cotizacion.dart';
import 'package:zentri_vendedor/models/cliente_deuda.dart';
import 'package:zentri_vendedor/models/abono.dart';

// ============================================================
// MODELO PARA COTIZACIONES PENDIENTES
// ============================================================
class CotizacionPendiente {
  final int? id;
  final String payload;
  final String fechaCreacion;
  final int intentos;
  final String? ultimoError;
  final String estado;

  CotizacionPendiente({
    this.id,
    required this.payload,
    required this.fechaCreacion,
    this.intentos = 0,
    this.ultimoError,
    this.estado = 'pendiente',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payload': payload,
      'fecha_creacion': fechaCreacion,
      'intentos': intentos,
      'ultimo_error': ultimoError,
      'estado': estado,
    };
  }

  factory CotizacionPendiente.fromMap(Map<String, dynamic> map) {
    return CotizacionPendiente(
      id: map['id'],
      payload: map['payload'],
      fechaCreacion: map['fecha_creacion'],
      intentos: map['intentos'] ?? 0,
      ultimoError: map['ultimo_error'],
      estado: map['estado'] ?? 'pendiente',
    );
  }
}

// ============================================================
// MODELO PARA ABONOS PENDIENTES
// ============================================================
class AbonoPendiente {
  final int? id;
  final String payload;
  final String fechaCreacion;
  final int intentos;
  final String? ultimoError;
  final String estado;

  AbonoPendiente({
    this.id,
    required this.payload,
    required this.fechaCreacion,
    this.intentos = 0,
    this.ultimoError,
    this.estado = 'pendiente',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payload': payload,
      'fecha_creacion': fechaCreacion,
      'intentos': intentos,
      'ultimo_error': ultimoError,
      'estado': estado,
    };
  }

  factory AbonoPendiente.fromMap(Map<String, dynamic> map) {
    return AbonoPendiente(
      id: map['id'],
      payload: map['payload'],
      fechaCreacion: map['fecha_creacion'],
      intentos: map['intentos'] ?? 0,
      ultimoError: map['ultimo_error'],
      estado: map['estado'] ?? 'pendiente',
    );
  }
}

class SyncDatabaseHelper {
  static final SyncDatabaseHelper _instance = SyncDatabaseHelper._internal();
  factory SyncDatabaseHelper() => _instance;
  SyncDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/zentri_sync.db';
    return await openDatabase(
      path,
      version: 13,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Ventas pendientes
    await db.execute('''
      CREATE TABLE ventas_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        intentos INTEGER DEFAULT 0,
        ultimo_error TEXT,
        estado TEXT DEFAULT 'pendiente'
      )
    ''');

    // Cotizaciones pendientes
    await db.execute('''
      CREATE TABLE cotizaciones_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        intentos INTEGER DEFAULT 0,
        ultimo_error TEXT,
        estado TEXT DEFAULT 'pendiente'
      )
    ''');

    // Abonos pendientes
    await db.execute('''
      CREATE TABLE abonos_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        intentos INTEGER DEFAULT 0,
        ultimo_error TEXT,
        estado TEXT DEFAULT 'pendiente'
      )
    ''');

    // Productos (caché)
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY,
        codigo TEXT,
        nombre TEXT,
        precio REAL,
        precio_base REAL,
        stock REAL,
        categoria TEXT,
        imagen TEXT,
        fecha_actualizacion TEXT
      )
    ''');

    // Clientes (caché principal)
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY,
        nombre TEXT,
        cedula TEXT,
        telefono TEXT,
        email TEXT,
        direccion TEXT,
        deuda_usd REAL,
        activo INTEGER,
        puntaje REAL DEFAULT 0,
        categoria TEXT DEFAULT 'Nuevo',
        ubicacion_gps TEXT DEFAULT '',
        sincronizado INTEGER DEFAULT 1,
        fecha_actualizacion TEXT
      )
    ''');

    // Clientes pendientes (offline) con ubicacion_gps
    await db.execute('''
      CREATE TABLE clientes_pendientes (
        id_local TEXT PRIMARY KEY,
        nombre TEXT,
        cedula TEXT,
        telefono TEXT,
        email TEXT,
        direccion TEXT,
        ubicacion_gps TEXT,
        notas TEXT,
        activo INTEGER DEFAULT 1,
        vendedor_id INTEGER,
        payload TEXT,
        fecha_creacion TEXT,
        estado TEXT DEFAULT 'pendiente'
      )
    ''');

    // Tasas (caché)
    await db.execute('''
      CREATE TABLE tasas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bcv REAL,
        paralelo REAL,
        fecha_actualizacion TEXT
      )
    ''');

    // Configuración (caché)
    await db.execute('''
      CREATE TABLE configuracion (
        clave TEXT PRIMARY KEY,
        valor TEXT,
        fecha_actualizacion TEXT
      )
    ''');

    // Ventas (caché)
    await db.execute('''
      CREATE TABLE ventas (
        id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        fecha_actualizacion TEXT
      )
    ''');

    // Cotizaciones (caché)
    await db.execute('''
      CREATE TABLE cotizaciones (
        id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        fecha_actualizacion TEXT
      )
    ''');

    // Deudores
    await db.execute('''
      CREATE TABLE deudores (
        id INTEGER PRIMARY KEY,
        cliente_id INTEGER,
        nombre TEXT,
        cedula TEXT,
        deuda_usd REAL,
        deuda_bs REAL,
        facturas_pendientes INTEGER DEFAULT 0,
        fecha_actualizacion TEXT
      )
    ''');

    // Comportamiento de clientes
    await db.execute('''
      CREATE TABLE comportamiento_clientes (
        cliente_id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        fecha_actualizacion TEXT
      )
    ''');

    // Abonos de cliente
    await db.execute('''
      CREATE TABLE abonos_cliente (
        cliente_id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        fecha_actualizacion TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS productos (
          id INTEGER PRIMARY KEY,
          codigo TEXT,
          nombre TEXT,
          precio REAL,
          precio_base REAL,
          stock REAL,
          categoria TEXT,
          imagen TEXT,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clientes (
          id INTEGER PRIMARY KEY,
          nombre TEXT,
          cedula TEXT,
          telefono TEXT,
          email TEXT,
          direccion TEXT,
          deuda_usd REAL,
          activo INTEGER,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tasas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bcv REAL,
          paralelo REAL,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS configuracion (
          clave TEXT PRIMARY KEY,
          valor TEXT,
          fecha_actualizacion TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ventas (
          id INTEGER PRIMARY KEY,
          payload TEXT NOT NULL,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cotizaciones (
          id INTEGER PRIMARY KEY,
          payload TEXT NOT NULL,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deudores (
          id INTEGER PRIMARY KEY,
          cliente_id INTEGER,
          nombre TEXT,
          cedula TEXT,
          deuda_usd REAL,
          deuda_bs REAL,
          fecha_actualizacion TEXT
        )
      ''');
    }
    if (oldVersion < 4 && oldVersion >= 3) {
      await db.execute('DROP TABLE IF EXISTS ventas');
      await db.execute('DROP TABLE IF EXISTS cotizaciones');
      await db.execute('''
        CREATE TABLE ventas (
          id INTEGER PRIMARY KEY,
          payload TEXT NOT NULL,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE cotizaciones (
          id INTEGER PRIMARY KEY,
          payload TEXT NOT NULL,
          fecha_actualizacion TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS comportamiento_clientes (
          cliente_id INTEGER PRIMARY KEY,
          payload TEXT NOT NULL,
          fecha_actualizacion TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cotizaciones_pendientes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          fecha_creacion TEXT NOT NULL,
          intentos INTEGER DEFAULT 0,
          ultimo_error TEXT,
          estado TEXT DEFAULT 'pendiente'
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS abonos_pendientes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          fecha_creacion TEXT NOT NULL,
          intentos INTEGER DEFAULT 0,
          ultimo_error TEXT,
          estado TEXT DEFAULT 'pendiente'
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS abonos_cliente (
          cliente_id INTEGER PRIMARY KEY,
          payload TEXT NOT NULL,
          fecha_actualizacion TEXT
        )
      ''');
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE deudores ADD COLUMN facturas_pendientes INTEGER DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE clientes ADD COLUMN puntaje REAL DEFAULT 0');
        await db.execute('ALTER TABLE clientes ADD COLUMN categoria TEXT DEFAULT "Nuevo"');
        await db.execute('ALTER TABLE clientes ADD COLUMN ubicacion_gps TEXT DEFAULT ""');
        await db.execute('ALTER TABLE clientes ADD COLUMN sincronizado INTEGER DEFAULT 1');
      } catch (e) {}
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clientes_pendientes (
          id_local TEXT PRIMARY KEY,
          nombre TEXT,
          cedula TEXT,
          telefono TEXT,
          email TEXT,
          direccion TEXT,
          ubicacion_gps TEXT,
          notas TEXT,
          activo INTEGER DEFAULT 1,
          vendedor_id INTEGER,
          payload TEXT,
          fecha_creacion TEXT,
          estado TEXT DEFAULT 'pendiente'
        )
      ''');
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE productos ADD COLUMN precio_base REAL');
      } catch (e) {}
    }
  }

  // ==================== CLIENTES PENDIENTES (OFFLINE) ====================
  Future<void> guardarClientePendiente(Map<String, dynamic> cliente) async {
    final db = await database;
    final idLocal = cliente['id_local'] ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert(
      'clientes_pendientes',
      {
        'id_local': idLocal,
        'nombre': cliente['nombre'],
        'cedula': cliente['cedula'],
        'telefono': cliente['telefono'] ?? '',
        'email': cliente['email'] ?? '',
        'direccion': cliente['direccion'] ?? '',
        'ubicacion_gps': cliente['ubicacion_gps'] ?? '',   // ✅ CORRECCIÓN: se agrega el campo
        'notas': cliente['notas'] ?? '',
        'activo': cliente['activo'] ?? 1,
        'vendedor_id': cliente['vendedor_id'],
        'payload': jsonEncode(cliente),
        'fecha_creacion': DateTime.now().toIso8601String(),
        'estado': 'pendiente',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> obtenerClientesPendientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes_pendientes',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
      orderBy: 'fecha_creacion ASC',
    );
    return maps;
  }

  Future<int> eliminarClientePendiente(String idLocal) async {
    final db = await database;
    return await db.delete(
      'clientes_pendientes',
      where: 'id_local = ?',
      whereArgs: [idLocal],
    );
  }

  Future<int> limpiarClientesPendientes() async {
    final db = await database;
    return await db.delete('clientes_pendientes');
  }

  // ==================== VENTAS PENDIENTES ====================
  Future<int> guardarVentaPendiente(Map<String, dynamic> venta) async {
    final db = await database;
    final ventaPendiente = VentaPendiente(
      payload: jsonEncode(venta),
      fechaCreacion: DateTime.now().toIso8601String(),
      intentos: 0,
      estado: 'pendiente',
    );
    return await db.insert('ventas_pendientes', ventaPendiente.toMap());
  }

  Future<List<VentaPendiente>> obtenerPendientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ventas_pendientes',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
      orderBy: 'fecha_creacion ASC',
    );
    return maps.map((map) => VentaPendiente.fromMap(map)).toList();
  }

  Future<int> eliminarVentaPendiente(int id) async {
    final db = await database;
    return await db.delete(
      'ventas_pendientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> limpiarPendientes() async {
    final db = await database;
    return await db.delete('ventas_pendientes');
  }

  // ==================== COTIZACIONES PENDIENTES ====================
  Future<int> guardarCotizacionPendiente(Map<String, dynamic> cotizacion) async {
    final db = await database;
    final pendiente = CotizacionPendiente(
      payload: jsonEncode(cotizacion),
      fechaCreacion: DateTime.now().toIso8601String(),
      intentos: 0,
      estado: 'pendiente',
    );
    return await db.insert('cotizaciones_pendientes', pendiente.toMap());
  }

  Future<List<CotizacionPendiente>> obtenerCotizacionesPendientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cotizaciones_pendientes',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
      orderBy: 'fecha_creacion ASC',
    );
    return maps.map((map) => CotizacionPendiente.fromMap(map)).toList();
  }

  Future<int> eliminarCotizacionPendiente(int id) async {
    final db = await database;
    return await db.delete(
      'cotizaciones_pendientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> limpiarCotizacionesPendientes() async {
    final db = await database;
    return await db.delete('cotizaciones_pendientes');
  }

  // ==================== ABONOS PENDIENTES ====================
  Future<int> guardarAbonoPendiente(Map<String, dynamic> abono) async {
    final db = await database;
    final pendiente = AbonoPendiente(
      payload: jsonEncode(abono),
      fechaCreacion: DateTime.now().toIso8601String(),
      intentos: 0,
      estado: 'pendiente',
    );
    return await db.insert('abonos_pendientes', pendiente.toMap());
  }

  Future<List<AbonoPendiente>> obtenerAbonosPendientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'abonos_pendientes',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
      orderBy: 'fecha_creacion ASC',
    );
    return maps.map((map) => AbonoPendiente.fromMap(map)).toList();
  }

  Future<int> eliminarAbonoPendiente(int id) async {
    final db = await database;
    return await db.delete(
      'abonos_pendientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> limpiarAbonosPendientes() async {
    final db = await database;
    return await db.delete('abonos_pendientes');
  }

  // ==================== PRODUCTOS ====================
  Future<void> guardarProductos(List<Producto> productos) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('productos');
      for (var p in productos) {
        await txn.insert('productos', {
          'id': p.id,
          'codigo': p.codigo,
          'nombre': p.nombre,
          'precio': p.precio,
          'precio_base': p.precioBase,
          'stock': p.stock,
          'categoria': p.categoria,
          'imagen': p.imagen,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<Producto>> obtenerProductos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('productos');
    return maps.map((map) => Producto.fromJson(map)).toList();
  }

  // ==================== CLIENTES (CACHÉ PRINCIPAL) ====================
  Future<void> guardarClientes(List<Cliente> clientes) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('clientes');
      for (var c in clientes) {
        await txn.insert('clientes', {
          'id': c.id,
          'nombre': c.nombre,
          'cedula': c.cedula,
          'telefono': c.telefono,
          'email': c.email,
          'direccion': c.direccion,
          'deuda_usd': c.deudaUsd,
          'activo': c.activo,
          'puntaje': c.puntaje ?? 0,
          'categoria': c.categoria ?? 'Nuevo',
          'ubicacion_gps': c.ubicacionGps ?? '',
          'sincronizado': 1,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<Cliente>> obtenerClientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('clientes');
    return maps.map((map) => Cliente.fromJson(map)).toList();
  }

  // ==================== TASAS ====================
  Future<void> guardarTasas(double bcv, double paralelo) async {
    final db = await database;
    await db.delete('tasas');
    await db.insert('tasas', {
      'bcv': bcv,
      'paralelo': paralelo,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, double>> obtenerTasas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasas', limit: 1);
    if (maps.isEmpty) return {'bcv': 0.0, 'paralelo': 0.0};
    return {
      'bcv': (maps.first['bcv'] ?? 0.0).toDouble(),
      'paralelo': (maps.first['paralelo'] ?? 0.0).toDouble(),
    };
  }

  // ==================== CONFIGURACIÓN ====================
  Future<void> guardarConfiguracion(Map<String, dynamic> config) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var entry in config.entries) {
        await txn.insert(
          'configuracion',
          {
            'clave': entry.key,
            'valor': jsonEncode(entry.value),
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, dynamic>> obtenerConfiguracion() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('configuracion');
    final config = <String, dynamic>{};
    for (var map in maps) {
      final clave = map['clave'] as String;
      final valor = jsonDecode(map['valor'] as String);
      config[clave] = valor;
    }
    return config;
  }

  // ==================== VENTAS (CACHÉ) ====================
  Future<void> guardarVentas(List<Venta> ventas) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ventas');
      for (var v in ventas) {
        final map = v.toJson();
        await txn.insert('ventas', {
          'id': v.id,
          'payload': jsonEncode(map),
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<Venta>> obtenerVentas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('ventas');
    return maps.map((map) {
      final payload = jsonDecode(map['payload'] as String);
      return Venta.fromJson(payload);
    }).toList();
  }

  // ==================== COTIZACIONES (CACHÉ) ====================
  Future<void> guardarCotizaciones(List<Cotizacion> cotizaciones) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cotizaciones');
      for (var c in cotizaciones) {
        final map = c.toJson();
        await txn.insert('cotizaciones', {
          'id': c.id,
          'payload': jsonEncode(map),
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<Cotizacion>> obtenerCotizaciones() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cotizaciones');
    return maps.map((map) {
      final payload = jsonDecode(map['payload'] as String);
      return Cotizacion.fromJson(payload);
    }).toList();
  }

  // ============================================================
  // COTIZACIÓN INDIVIDUAL (CACHÉ)
  // ============================================================
  Future<void> guardarCotizacionIndividual(Cotizacion cotizacion) async {
    final db = await database;
    final map = cotizacion.toJson();
    await db.insert(
      'cotizaciones',
      {
        'id': cotizacion.id,
        'payload': jsonEncode(map),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Cotizacion?> obtenerCotizacionIndividual(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cotizaciones',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final payload = jsonDecode(maps.first['payload'] as String);
    return Cotizacion.fromJson(payload);
  }

  // ============================================================
  // DEUDORES
  // ============================================================
  Future<void> guardarDeudores(List<ClienteDeuda> deudores) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('deudores');
      for (var d in deudores) {
        await txn.insert('deudores', {
          'cliente_id': d.id,
          'nombre': d.nombre,
          'cedula': d.cedula,
          'deuda_usd': d.deudaUsd,
          'deuda_bs': d.deudaBs,
          'facturas_pendientes': d.facturasPendientes,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<ClienteDeuda>> obtenerDeudores() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('deudores');
    return maps.map((map) => ClienteDeuda(
      id: map['cliente_id'] as int,
      nombre: map['nombre'] as String,
      cedula: map['cedula'] as String? ?? '',
      deudaUsd: (map['deuda_usd'] as num).toDouble(),
      deudaBs: (map['deuda_bs'] as num).toDouble(),
      facturasPendientes: (map['facturas_pendientes'] as int?) ?? 0,
    )).toList();
  }

  // ============================================================
  // COMPORTAMIENTO DE CLIENTES
  // ============================================================
  Future<void> guardarComportamientoCliente(int clienteId, Map<String, dynamic> comportamiento) async {
    final db = await database;
    final payload = jsonEncode(comportamiento);
    await db.insert(
      'comportamiento_clientes',
      {
        'cliente_id': clienteId,
        'payload': payload,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> obtenerComportamientoCliente(int clienteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'comportamiento_clientes',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final payload = maps.first['payload'] as String;
    return jsonDecode(payload);
  }

  Future<int> eliminarComportamientoCliente(int clienteId) async {
    final db = await database;
    return await db.delete(
      'comportamiento_clientes',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
    );
  }

  // ============================================================
  // ABONOS DE CLIENTE
  // ============================================================
  Future<void> guardarAbonosCliente(int clienteId, List<Abono> abonos) async {
    final db = await database;
    final payload = jsonEncode(abonos.map((a) => a.toJson()).toList());
    await db.insert(
      'abonos_cliente',
      {
        'cliente_id': clienteId,
        'payload': payload,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Abono>?> obtenerAbonosCliente(int clienteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'abonos_cliente',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final payload = maps.first['payload'] as String;
    final List<dynamic> list = jsonDecode(payload);
    return list.map((item) => Abono.fromJson(item)).toList();
  }

  Future<int> eliminarAbonosCliente(int clienteId) async {
    final db = await database;
    return await db.delete(
      'abonos_cliente',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
    );
  }
}