class ItemCarrito {
  final int productoId;
  final String nombre;
  final String codigo;
  final double precio;
  final String? imagen;
  double cantidad;

  ItemCarrito({
    required this.productoId,
    required this.nombre,
    required this.codigo,
    required this.precio,
    this.imagen,
    this.cantidad = 1.0,
  });

  double get subtotal => precio * cantidad;

  ItemCarrito copyWith({
    int? productoId,
    String? nombre,
    String? codigo,
    double? precio,
    String? imagen,
    double? cantidad,
  }) {
    return ItemCarrito(
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      precio: precio ?? this.precio,
      imagen: imagen ?? this.imagen,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productoId': productoId,
      'nombre': nombre,
      'codigo': codigo,
      'precio': precio,
      'imagen': imagen,
      'cantidad': cantidad,
    };
  }

  factory ItemCarrito.fromJson(Map<String, dynamic> json) {
    return ItemCarrito(
      productoId: json['productoId'],
      nombre: json['nombre'],
      codigo: json['codigo'],
      precio: (json['precio'] as num).toDouble(),
      imagen: json['imagen'],
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

// ============================================================
// Helper para mostrar cantidades sin ceros sobrantes.
// Ejemplos: 1.0 → "1" | 0.5 → "0.5" | 0.125 → "0.125"
// ============================================================
String formatCantidad(double c) {
  if (c == c.roundToDouble()) return c.toInt().toString();
  String s = c.toStringAsFixed(3);
  s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}