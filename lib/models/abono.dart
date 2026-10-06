class Abono {
  final int id;
  final int ventaId;
  final String numeroFactura;
  final double montoUsd;
  final double montoBs;
  final String metodoPago;
  final String? referencia;
  final String fecha;
  final String? usuarioNombre;

  Abono({
    required this.id,
    required this.ventaId,
    required this.numeroFactura,
    required this.montoUsd,
    required this.montoBs,
    required this.metodoPago,
    this.referencia,
    required this.fecha,
    this.usuarioNombre,
  });

  factory Abono.fromJson(Map<String, dynamic> json) {
    final monto = (json['monto'] ?? 0.0).toDouble();
    return Abono(
      id: json['id'] ?? 0,
      ventaId: json['venta_id'] ?? 0,
      numeroFactura: json['numero_factura'] ?? '',
      montoUsd: monto,
      montoBs: (json['monto_bs'] ?? 0.0).toDouble(),
      metodoPago: json['metodo_pago'] ?? '',
      referencia: json['referencia'],
      fecha: json['fecha'] ?? '',
      usuarioNombre: json['usuario_nombre'],
    );
  }

  // ============================================================
  // AÑADIDO: toJson para guardar en caché
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venta_id': ventaId,
      'numero_factura': numeroFactura,
      'monto': montoUsd,
      'monto_bs': montoBs,
      'metodo_pago': metodoPago,
      'referencia': referencia,
      'fecha': fecha,
      'usuario_nombre': usuarioNombre,
    };
  }
}