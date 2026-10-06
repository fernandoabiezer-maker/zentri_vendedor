class Venta {
  final int id;
  final String fecha;
  final double cantidad;
  final double precioVentaFinal;
  final double costoAlMomento;
  final String tipoVenta;
  final String metodoPago;
  final double saldoPendiente;
  final int anulada;
  final String numeroFactura;
  final String vendedorNombre;
  final int? vendedorId;
  final String productoNombre;
  final int? clienteId;
  final String clienteNombre;
  final String clienteCedula;
  final int? clienteVendedorId;
  final double totalUsd;
  final double totalBs;
  final double tasaParalelo;

  Venta({
    required this.id,
    required this.fecha,
    required this.cantidad,
    required this.precioVentaFinal,
    required this.costoAlMomento,
    required this.tipoVenta,
    required this.metodoPago,
    required this.saldoPendiente,
    required this.anulada,
    required this.numeroFactura,
    required this.vendedorNombre,
    this.vendedorId,
    required this.productoNombre,
    this.clienteId,
    required this.clienteNombre,
    required this.clienteCedula,
    this.clienteVendedorId,
    required this.totalUsd,
    required this.totalBs,
    required this.tasaParalelo,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] ?? 0,
      fecha: json['fecha'] ?? '',
      cantidad: (json['cantidad'] ?? 0).toDouble(),
      precioVentaFinal: (json['precio_venta_final'] ?? 0).toDouble(),
      costoAlMomento: (json['costo_al_momento'] ?? 0).toDouble(),
      tipoVenta: json['tipo_venta'] ?? 'contado',
      metodoPago: json['metodo_pago'] ?? 'efectivo_bs',
      saldoPendiente: (json['saldo_pendiente'] ?? 0).toDouble(),
      anulada: json['anulada'] ?? 0,
      numeroFactura: json['numero_factura'] ?? '',
      vendedorNombre: json['vendedor_nombre'] ?? 'Vendedor',
      vendedorId: json['vendedor_id'],
      productoNombre: json['producto_nombre'] ?? 'Producto',
      clienteId: json['cliente_id'],
      clienteNombre: json['cliente_nombre'] ?? 'Consumidor Final',
      clienteCedula: json['cliente_cedula'] ?? 'N/A',
      clienteVendedorId: json['cliente_vendedor_id'],
      totalUsd: (json['total_usd'] ?? 0).toDouble(),
      totalBs: (json['total_bs'] ?? 0).toDouble(),
      tasaParalelo: (json['tasa_paralelo'] ?? 90.0).toDouble(),
    );
  }

  // ============================================================
  // NUEVO: Método toJson() para guardar en caché
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha,
      'cantidad': cantidad,
      'precio_venta_final': precioVentaFinal,
      'costo_al_momento': costoAlMomento,
      'tipo_venta': tipoVenta,
      'metodo_pago': metodoPago,
      'saldo_pendiente': saldoPendiente,
      'anulada': anulada,
      'numero_factura': numeroFactura,
      'vendedor_nombre': vendedorNombre,
      'vendedor_id': vendedorId,
      'producto_nombre': productoNombre,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'cliente_cedula': clienteCedula,
      'cliente_vendedor_id': clienteVendedorId,
      'total_usd': totalUsd,
      'total_bs': totalBs,
      'tasa_paralelo': tasaParalelo,
    };
  }

  bool get isAnulada => anulada == 1;
  bool get isCredito => tipoVenta == 'credito';
  bool get isPagada => !isAnulada && (!isCredito || saldoPendiente <= 0);
}