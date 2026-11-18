class ItemCarrito {
  final int productoId;
  final String nombre;
  final String codigo;

  /// Precio de venta al público (con IVA). Es el que se muestra.
  final double precio;

  /// Precio base sin IVA. Es el que se envía al servidor al vender.
  /// Si no está disponible, se usa [precio] para no romper datos viejos.
  final double? precioBase;

  final String? imagen;
  double cantidad;

  ItemCarrito({
    required this.productoId,
    required this.nombre,
    required this.codigo,
    required this.precio,
    this.precioBase,
    this.imagen,
    this.cantidad = 1.0,
  });

  /// Precio que debe viajar al backend: base si la conocemos.
  double get precioParaVenta =>
      (precioBase != null && precioBase! > 0) ? precioBase! : precio;

  double get subtotal => precio * cantidad;

  ItemCarrito copyWith({
    int? productoId,
    String? nombre,
    String? codigo,
    double? precio,
    double? precioBase,
    String? imagen,
    double? cantidad,
  }) {
    return ItemCarrito(
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      precio: precio ?? this.precio,
      precioBase: precioBase ?? this.precioBase,
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
      'precioBase': precioBase,
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
      precioBase: (json['precioBase'] as num?)?.toDouble(),
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
