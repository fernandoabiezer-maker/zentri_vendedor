class Producto {
  final int id;
  final String codigo;
  final String nombre;

  /// Precio de venta al público: ya incluye IVA.
  /// Es el que se muestra en catálogo, carrito y cotizaciones.
  final double precio;

  /// Precio base (sin IVA): es el que se envía al servidor al vender
  /// o cotizar. El servidor aplica el 16% una sola vez.
  final double precioBase;

  final double stock;
  final String categoria;
  final String? imagen;

  Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.precio,
    required this.precioBase,
    required this.stock,
    required this.categoria,
    this.imagen,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'],
      codigo: json['codigo'] ?? 'N/A',
      nombre: json['nombre'],
      precio: (json['precio'] ?? 0).toDouble(),
      // Compatibilidad: si el servidor no manda precio_base, se usa `precio`.
      precioBase: (json['precio_base'] ?? json['precio'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(),
      categoria: json['categoria'] ?? '',
      imagen: json['imagen'] is String ? json['imagen'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'precio': precio,
      'precio_base': precioBase,
      'stock': stock,
      'categoria': categoria,
      'imagen': imagen,
    };
  }
}
