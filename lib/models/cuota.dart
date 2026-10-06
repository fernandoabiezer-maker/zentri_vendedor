class Cuota {
  final int id;
  final int planId;
  final int numeroCuota;
  final double monto;
  final double montoPagado;
  final double moraAcumulada;
  final double moraCondonada;
  final String estadoMora; // 'sin_mora' | 'condonada'
  final String fechaVencimiento;
  final String estado; // 'pendiente' | 'parcial' | 'pagada' | 'vencida'
  final String? fechaUltimoPago;
  final int? condonadaPor;
  final String? condonadaEn;
  final String? motivoCondonacion;

  Cuota({
    required this.id,
    required this.planId,
    required this.numeroCuota,
    required this.monto,
    required this.montoPagado,
    required this.moraAcumulada,
    required this.moraCondonada,
    required this.estadoMora,
    required this.fechaVencimiento,
    required this.estado,
    this.fechaUltimoPago,
    this.condonadaPor,
    this.condonadaEn,
    this.motivoCondonacion,
  });

  factory Cuota.fromJson(Map<String, dynamic> json) {
    return Cuota(
      id: json['id'] ?? 0,
      planId: json['plan_id'] ?? 0,
      numeroCuota: json['numero_cuota'] ?? 0,
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      montoPagado: (json['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      moraAcumulada: (json['mora_acumulada'] as num?)?.toDouble() ?? 0.0,
      moraCondonada: (json['mora_condonada'] as num?)?.toDouble() ?? 0.0,
      estadoMora: json['estado_mora'] ?? 'sin_mora',
      fechaVencimiento: json['fecha_vencimiento'] ?? '',
      estado: json['estado'] ?? 'pendiente',
      fechaUltimoPago: json['fecha_ultimo_pago'],
      condonadaPor: json['condonada_por'],
      condonadaEn: json['condonada_en'],
      motivoCondonacion: json['motivo_condonacion'],
    );
  }

  // Saldo pendiente = (monto - pagado) + (mora - mora condonada)
  double get saldoPendiente {
    final base = monto - montoPagado;
    final mora = moraAcumulada - moraCondonada;
    final total = base + mora;
    return total > 0 ? total : 0.0;
  }

  double get moraPendiente {
    final m = moraAcumulada - moraCondonada;
    return m > 0 ? m : 0.0;
  }

  bool get isPagada => estado == 'pagada';
  bool get isParcial => estado == 'parcial';
  bool get isVencida => estado == 'vencida';
  bool get isPendiente => estado == 'pendiente';
  bool get tieneMora => moraPendiente > 0.01;
  bool get moraCondonadaFlag => estadoMora == 'condonada';
}