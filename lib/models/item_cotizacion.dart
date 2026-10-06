class ItemCotizacion {
  final int id;
  final String nombre;
  final String codigo;
  final double cantidad;
  final double precioUnitario;
  final String? imagen;

  ItemCotizacion({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.cantidad = 0.0,
    this.precioUnitario = 0.0,
    this.imagen,
  });

  // ============================================================
  // GETTER SUBTOTAL CON PRINTS DE DIAGNÓSTICO
  // ============================================================
  double get subtotal {
    print('🔍 [subtotal] item: $nombre');
    print('   cantidad: ${cantidad.runtimeType} = $cantidad');
    print('   precioUnitario: ${precioUnitario.runtimeType} = $precioUnitario');
    
    final cant = (cantidad is num && cantidad.isFinite) ? cantidad : 0.0;
    final precio = (precioUnitario is num && precioUnitario.isFinite) ? precioUnitario : 0.0;
    
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
      'precio_unitario': precioUnitario.isFinite ? precioUnitario : 0.0,
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

    return ItemCotizacion(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      cantidad: parseDouble(json['cantidad']),
      precioUnitario: parseDouble(json['precio_unitario']),
      imagen: json['imagen'],
    );
  }

  ItemCotizacion copyWith({
    int? id,
    String? nombre,
    String? codigo,
    double? cantidad,
    double? precioUnitario,
    String? imagen,
  }) {
    return ItemCotizacion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      imagen: imagen ?? this.imagen,
    );
  }
}