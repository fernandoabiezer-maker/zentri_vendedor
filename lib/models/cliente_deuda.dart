class ClienteDeuda {
  final int id;
  final String nombre;
  final String? cedula;
  final String? telefono;
  final double deudaUsd;
  final double deudaBs;
  final int facturasPendientes;
  final String? ultimaFacturaFecha;

  ClienteDeuda({
    required this.id,
    required this.nombre,
    this.cedula,
    this.telefono,
    required this.deudaUsd,
    required this.deudaBs,
    required this.facturasPendientes,
    this.ultimaFacturaFecha,
  });

  factory ClienteDeuda.fromJson(Map<String, dynamic> json) {
    return ClienteDeuda(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      cedula: json['cedula'],
      telefono: json['telefono'],
      deudaUsd: (json['deuda_usd'] ?? 0.0).toDouble(),
      deudaBs: (json['deuda_bs'] ?? 0.0).toDouble(),
      facturasPendientes: (json['facturas_pendientes'] ?? 0) as int? ?? 0,
      ultimaFacturaFecha: json['ultima_factura_fecha'],
    );
  }
}