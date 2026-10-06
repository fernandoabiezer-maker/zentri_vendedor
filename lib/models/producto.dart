class Producto {
  final int id;
  final String codigo;
  final String nombre;
  final double precio;
  final double stock;
  final String categoria;
  final String? imagen;

  Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.precio,
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
      'stock': stock,
      'categoria': categoria,
      'imagen': imagen,
    };
  }
}