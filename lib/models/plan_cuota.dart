import 'package:zentri_vendedor/models/cuota.dart';

class PlanCuota {
  final int id;
  final int? ventaId;
  final String numeroFactura;
  final int clienteId;
  final int? vendedorId;
  final double montoVenta;
  final double montoInicial;
  final double montoFinanciado;
  final int numeroCuotas;
  final int diasEntreCuotas;
  final String fechaInicio;
  final String estado; // 'activo' | 'saldado' | 'anulado'
  final String? observaciones;
  final int totalCuotas;
  final int cuotasPagadas;
  final double moraTotal;
  final List<Cuota> cuotas;

  PlanCuota({
    required this.id,
    this.ventaId,
    required this.numeroFactura,
    required this.clienteId,
    this.vendedorId,
    required this.montoVenta,
    required this.montoInicial,
    required this.montoFinanciado,
    required this.numeroCuotas,
    required this.diasEntreCuotas,
    required this.fechaInicio,
    required this.estado,
    this.observaciones,
    required this.totalCuotas,
    required this.cuotasPagadas,
    required this.moraTotal,
    required this.cuotas,
  });

  factory PlanCuota.fromJson(Map<String, dynamic> json) {
    final cuotasJson = (json['cuotas'] as List?) ?? const [];
    return PlanCuota(
      id: json['id'] ?? 0,
      ventaId: json['venta_id'],
      numeroFactura: json['numero_factura'] ?? '',
      clienteId: json['cliente_id'] ?? 0,
      vendedorId: json['vendedor_id'],
      montoVenta: (json['monto_venta'] as num?)?.toDouble() ?? 0.0,
      montoInicial: (json['monto_inicial'] as num?)?.toDouble() ?? 0.0,
      montoFinanciado: (json['monto_financiado'] as num?)?.toDouble() ?? 0.0,
      numeroCuotas: json['numero_cuotas'] ?? 0,
      diasEntreCuotas: json['dias_entre_cuotas'] ?? 0,
      fechaInicio: json['fecha_inicio'] ?? '',
      estado: json['estado'] ?? 'activo',
      observaciones: json['observaciones'],
      totalCuotas: json['total_cuotas'] ?? 0,
      cuotasPagadas: json['cuotas_pagadas'] ?? 0,
      moraTotal: (json['mora_total'] as num?)?.toDouble() ?? 0.0,
      cuotas: cuotasJson
          .whereType<Map<String, dynamic>>()
          .map((c) => Cuota.fromJson(c))
          .toList(),
    );
  }

  bool get isActivo => estado == 'activo';
  bool get isSaldado => estado == 'saldado';
  bool get isAnulado => estado == 'anulado';

  // Progreso de pago entre 0.0 y 1.0
  double get progreso {
    if (totalCuotas <= 0) return 0.0;
    final p = cuotasPagadas / totalCuotas;
    if (p < 0) return 0.0;
    if (p > 1) return 1.0;
    return p;
  }

  // Cuotas que aún no están pagadas
  int get cuotasPendientes => totalCuotas - cuotasPagadas;

  // Cuotas vencidas (según su estado)
  int get cuotasVencidas =>
      cuotas.where((c) => c.isVencida && !c.isPagada).length;
}