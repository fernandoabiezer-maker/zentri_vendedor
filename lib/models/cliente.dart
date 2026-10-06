class Cliente {
  final int? id;
  final String nombre;
  final String cedula;
  final String telefono;
  final String email;
  final String direccion;
  final String notas;
  final int activo;
  final int totalCompras;
  final double totalGastado;
  final String? ultimaCompra;
  final double deudaUsd;
  final double deudaBs;
  final int? vendedorId;
  final String? vendedorNombre;
  final String? ubicacionGps;
  final double? puntaje;
  final String? categoria;

  Cliente({
    this.id,
    required this.nombre,
    required this.cedula,
    this.telefono = '',
    this.email = '',
    this.direccion = '',
    this.notas = '',
    this.activo = 1,
    this.totalCompras = 0,
    this.totalGastado = 0.0,
    this.ultimaCompra,
    this.deudaUsd = 0.0,
    this.deudaBs = 0.0,
    this.vendedorId,
    this.vendedorNombre,
    this.ubicacionGps,
    this.puntaje,
    this.categoria,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para parsear int de forma robusta
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      return 0;
    }

    double _parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    int? _parseIntNullable(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed;
      }
      return null;
    }

    return Cliente(
      id: _parseIntNullable(json['id']),
      nombre: json['nombre'] ?? '',
      cedula: json['cedula'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
      direccion: json['direccion'] ?? '',
      notas: json['notas'] ?? '',
      activo: _parseInt(json['activo']),
      totalCompras: _parseInt(json['total_compras']),
      totalGastado: _parseDouble(json['total_gastado']),
      ultimaCompra: json['ultima_compra'],
      deudaUsd: _parseDouble(json['deuda_usd']),
      deudaBs: _parseDouble(json['deuda_bs']),
      vendedorId: _parseIntNullable(json['vendedor_id']),
      vendedorNombre: json['vendedor_nombre'],
      ubicacionGps: json['ubicacion_gps'],
      puntaje: _parseDouble(json['puntaje']),
      categoria: json['categoria'] ?? 'Nuevo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'cedula': cedula,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'notas': notas,
      'activo': activo,
      'total_compras': totalCompras,
      'total_gastado': totalGastado,
      'ultima_compra': ultimaCompra,
      'deuda_usd': deudaUsd,
      'deuda_bs': deudaBs,
      'vendedor_id': vendedorId,
      'vendedor_nombre': vendedorNombre,
      'ubicacion_gps': ubicacionGps,
      'puntaje': puntaje,
      'categoria': categoria,
    };
  }

  Cliente copyWith({
    int? id,
    String? nombre,
    String? cedula,
    String? telefono,
    String? email,
    String? direccion,
    String? notas,
    int? activo,
    int? totalCompras,
    double? totalGastado,
    String? ultimaCompra,
    double? deudaUsd,
    double? deudaBs,
    int? vendedorId,
    String? vendedorNombre,
    String? ubicacionGps,
    double? puntaje,
    String? categoria,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cedula: cedula ?? this.cedula,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      totalCompras: totalCompras ?? this.totalCompras,
      totalGastado: totalGastado ?? this.totalGastado,
      ultimaCompra: ultimaCompra ?? this.ultimaCompra,
      deudaUsd: deudaUsd ?? this.deudaUsd,
      deudaBs: deudaBs ?? this.deudaBs,
      vendedorId: vendedorId ?? this.vendedorId,
      vendedorNombre: vendedorNombre ?? this.vendedorNombre,
      ubicacionGps: ubicacionGps ?? this.ubicacionGps,
      puntaje: puntaje ?? this.puntaje,
      categoria: categoria ?? this.categoria,
    );
  }
}