class ItemCotizacion {
  final int id;
  final String nombre;
  final String codigo;
  final double cantidad;

  /// Precio de venta al público (con IVA). Es el que se muestra al cliente.
  final double precioUnitario;

  /// Precio base sin IVA. Es el que se envía al servidor, que aplica el 16%
  /// una sola vez para generar el desglose de la factura.
  final double? precioBase;

  final String? imagen;

  ItemCotizacion({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.cantidad = 0.0,
    this.precioUnitario = 0.0,
    this.precioBase,
    this.imagen,
  });

  /// Precio que debe viajar al backend: base si la conocemos.
  double get precioParaVenta =>
      (precioBase != null && precioBase! > 0) ? precioBase! : precioUnitario;

  // ============================================================
  // GETTER SUBTOTAL CON PRINTS DE DIAGNÓSTICO
  // ============================================================
  double get subtotal {
    print('🔍 [subtotal] item: $nombre');
    print('   cantidad: ${cantidad.runtimeType} = $cantidad');
    print('   precioUnitario: ${precioUnitario.runtimeType} = $precioUnitario');

    final cant = (cantidad is num && cantidad.isFinite) ? cantidad : 0.0;
    final precio =
        (precioUnitario is num && precioUnitario.isFinite) ? precioUnitario : 0.0;

    final result = cant * precio;
    print('   resultado: $result (${result.runtimeType})');
    if (result.isNaN) {
      print('   ⚠️ RESULTADO ES NaN!');
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'cantidad': cantidad.isFinite ? cantidad : 0.0,
      // El servidor espera la base en precio_unitario.
      'precio_unitario': precioParaVenta,
      // Precio final para volver a mostrar la cotización sin recalcular.
      'precio_final': precioUnitario.isFinite ? precioUnitario : 0.0,
      'imagen': imagen,
    };
  }

  factory ItemCotizacion.fromJson(Map<String, dynamic> json) {
    print('🔍 [fromJson] parseando item: ${json['nombre']}');

    double parseDouble(dynamic value) {
      if (value == null) {
        print('   ⚠️ valor null, usando 0.0');
        return 0.0;
      }
      if (value is double) {
        print('   valor double: $value');
        return value.isFinite ? value : 0.0;
      }
      if (value is int) {
        print('   valor int: $value, convirtiendo a double');
        return value.toDouble();
      }
      if (value is String) {
        print('   valor string: $value, parseando');
        final parsed = double.tryParse(value);
        return (parsed != null && parsed.isFinite) ? parsed : 0.0;
      }
      print('   ⚠️ tipo desconocido: ${value.runtimeType}, usando 0.0');
      return 0.0;
    }

    final tieneFinal = json['precio_final'] != null;

    return ItemCotizacion(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      cantidad: parseDouble(json['cantidad']),
      // Si viene precio_final, precio_unitario es la base.
      precioUnitario:
          parseDouble(tieneFinal ? json['precio_final'] : json['precio_unitario']),
      precioBase: tieneFinal ? parseDouble(json['precio_unitario']) : null,
      imagen: json['imagen'],
    );
  }

  ItemCotizacion copyWith({
    int? id,
    String? nombre,
    String? codigo,
    double? cantidad,
    double? precioUnitario,
    double? precioBase,
    String? imagen,
  }) {
    return ItemCotizacion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      precioBase: precioBase ?? this.precioBase,
      imagen: imagen ?? this.imagen,
    );
  }
}
