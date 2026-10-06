import 'dart:convert';
import 'package:zentri_vendedor/models/item_cotizacion.dart';

class Cotizacion {
  final int id;
  final String cliente;
  final String? clienteRif;
  final int clienteId;
  final int vendedorId;
  final String? vendedorNombre;
  final String fecha;
  final String fechaCreacion;
  final List<ItemCotizacion> items;
  final double total;
  final String tipoVenta;
  final double margenGlobal;
  final String moneda;
  final double tasaBcv;
  final double tasaParalelo;
  final double ivaPorcentaje;
  final String metodoPago;
  final int convertida;

  Cotizacion({
    required this.id,
    required this.cliente,
    this.clienteRif,
    required this.clienteId,
    required this.vendedorId,
    this.vendedorNombre,
    required this.fecha,
    required this.fechaCreacion,
    required this.items,
    required this.total,
    required this.tipoVenta,
    required this.margenGlobal,
    required this.moneda,
    required this.tasaBcv,
    required this.tasaParalelo,
    required this.ivaPorcentaje,
    required this.metodoPago,
    required this.convertida,
  });

  bool get isConvertida => convertida == 1;

  factory Cotizacion.fromJson(Map<String, dynamic> json) {
    List<ItemCotizacion> itemsList = [];
    final itemsRaw = json['items'];
    if (itemsRaw is List) {
      itemsList = itemsRaw.map((item) => ItemCotizacion.fromJson(item)).toList();
    } else if (itemsRaw is String) {
      try {
        final parsed = jsonDecode(itemsRaw);
        if (parsed is List) {
          itemsList = parsed.map((item) => ItemCotizacion.fromJson(item)).toList();
        }
      } catch (e) {
        print('⚠️ Error parseando items desde string: $e');
      }
    }
    return Cotizacion(
      id: json['id'] ?? 0,
      cliente: json['cliente'] ?? '',
      clienteRif: json['cliente_rif'],
      clienteId: json['cliente_id'] ?? 0,
      vendedorId: json['vendedor_id'] ?? 0,
      vendedorNombre: json['vendedor_nombre'],
      fecha: json['fecha'] ?? '',
      fechaCreacion: json['fecha_creacion'] ?? '',
      items: itemsList,
      total: (json['total'] ?? 0.0).toDouble(),
      tipoVenta: json['tipo_venta'] ?? 'mayor',
      margenGlobal: (json['margen_global'] ?? 0.0).toDouble(),
      moneda: json['moneda'] ?? 'USD',
      tasaBcv: (json['tasa_bcv'] ?? 0.0).toDouble(),
      tasaParalelo: (json['tasa_paralelo'] ?? 0.0).toDouble(),
      ivaPorcentaje: (json['iva_porcentaje'] ?? 0.0).toDouble(),
      metodoPago: json['metodo_pago'] ?? 'Contado',
      convertida: json['convertida'] ?? 0,
    );
  }

  // ============================================================
  // NUEVO: Método toJson() para guardar en caché
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente': cliente,
      'cliente_rif': clienteRif,
      'cliente_id': clienteId,
      'vendedor_id': vendedorId,
      'vendedor_nombre': vendedorNombre,
      'fecha': fecha,
      'fecha_creacion': fechaCreacion,
      'items': items.map((i) => i.toJson()).toList(),
      'total': total,
      'tipo_venta': tipoVenta,
      'margen_global': margenGlobal,
      'moneda': moneda,
      'tasa_bcv': tasaBcv,
      'tasa_paralelo': tasaParalelo,
      'iva_porcentaje': ivaPorcentaje,
      'metodo_pago': metodoPago,
      'convertida': convertida,
    };
  }

  Cotizacion copyWith({
    int? id,
    String? cliente,
    String? clienteRif,
    int? clienteId,
    int? vendedorId,
    String? vendedorNombre,
    String? fecha,
    String? fechaCreacion,
    List<ItemCotizacion>? items,
    double? total,
    String? tipoVenta,
    double? margenGlobal,
    String? moneda,
    double? tasaBcv,
    double? tasaParalelo,
    double? ivaPorcentaje,
    String? metodoPago,
    int? convertida,
  }) {
    return Cotizacion(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      clienteRif: clienteRif ?? this.clienteRif,
      clienteId: clienteId ?? this.clienteId,
      vendedorId: vendedorId ?? this.vendedorId,
      vendedorNombre: vendedorNombre ?? this.vendedorNombre,
      fecha: fecha ?? this.fecha,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      items: items ?? this.items,
      total: total ?? this.total,
      tipoVenta: tipoVenta ?? this.tipoVenta,
      margenGlobal: margenGlobal ?? this.margenGlobal,
      moneda: moneda ?? this.moneda,
      tasaBcv: tasaBcv ?? this.tasaBcv,
      tasaParalelo: tasaParalelo ?? this.tasaParalelo,
      ivaPorcentaje: ivaPorcentaje ?? this.ivaPorcentaje,
      metodoPago: metodoPago ?? this.metodoPago,
      convertida: convertida ?? this.convertida,
    );
  }
}