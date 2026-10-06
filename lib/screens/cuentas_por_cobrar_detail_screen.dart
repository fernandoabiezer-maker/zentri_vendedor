import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/cuentas_por_cobrar_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/providers/venta_provider.dart';
import 'package:zentri_vendedor/models/abono.dart';
import 'package:zentri_vendedor/models/plan_cuota.dart';
import 'package:zentri_vendedor/models/cuota.dart';

class CuentasPorCobrarDetailScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;

  const CuentasPorCobrarDetailScreen({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
  });

  @override
  State<CuentasPorCobrarDetailScreen> createState() =>
      _CuentasPorCobrarDetailScreenState();
}

class _CuentasPorCobrarDetailScreenState
    extends State<CuentasPorCobrarDetailScreen>
    with SingleTickerProviderStateMixin {
  late CuentasPorCobrarProvider _provider;
  late TabController _tabController;

  static bool _esMetodoBs(String metodo) {
    return metodo == 'efectivo_bs' ||
        metodo == 'transferencia_bs' ||
        metodo == 'pago_movil_bs' ||
        metodo == 'tarjeta_bs' ||
        metodo == 'bio_pago';
  }

  @override
  void initState() {
    super.initState();
    _provider = context.read<CuentasPorCobrarProvider>();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _provider.cargarDetalleCliente(widget.clienteId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CuentasPorCobrarProvider>();
    final tasas = context.watch<TasasProvider>();
    final cargando = provider.cargandoDetalle;
    final cliente = provider.clienteSeleccionado;
    final error = provider.error;
    final tasaParalelo = tasas.tasaParalelo > 0 ? tasas.tasaParalelo : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Deuda de ${widget.clienteNombre}'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              provider.cargarDetalleCliente(widget.clienteId);
            },
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumenCompacto(cliente),
                if (error != null) _buildBannerError(error),
                Container(
                  color: Colors.grey.shade100,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFf0872d),
                    labelColor: const Color(0xFF1e293b),
                    unselectedLabelColor: Colors.grey.shade600,
                    tabs: const [
                      Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'FACTURAS'),
                      Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'PLANES'),
                      Tab(icon: Icon(Icons.history, size: 20), text: 'ABONOS'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TabFacturas(
                        facturas: provider.facturasPendientes,
                        pagina: provider.paginaFacturas,
                        totalPaginas: provider.totalPaginasFacturas,
                        onPageChange: (p) => provider.irPaginaFacturas(p),
                        onRecargar: () => provider.cargarDetalleCliente(widget.clienteId),
                        tasaParalelo: tasaParalelo,
                      ),
                      _TabPlanes(
                        planes: provider.planesCuotas,
                        pagina: provider.paginaPlanes,
                        totalPaginas: provider.totalPaginasPlanes,
                        onPageChange: (p) => provider.irPaginaPlanes(p),
                        tasaParalelo: tasaParalelo,
                      ),
                      _TabAbonos(
                        abonos: provider.abonosCliente,
                        pagina: provider.paginaAbonos,
                        totalPaginas: provider.totalPaginasAbonos,
                        cargando: provider.cargandoAbonos,
                        onPageChange: (p) => provider.irPaginaAbonos(p),
                        tasaParalelo: tasaParalelo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      // ============================================================
      // BOTÓN FIJO ABAJO (no flotante)
      // ============================================================
      bottomNavigationBar: cargando
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _mostrarDialogRegistrarAbono(context),
                    icon: const Icon(Icons.payments),
                    label: const Text(
                      'Registrar Abono',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf0872d),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ============================================================
  // RESUMEN COMPACTO
  // ============================================================
  Widget _buildResumenCompacto(dynamic cliente) {
    final deudaUsd = (cliente?.deudaUsd ?? 0).toDouble();
    final deudaBs = (cliente?.deudaBs ?? 0).toDouble();
    final facturas = cliente?.facturasPendientes ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildResumenItem(
              icono: Icons.attach_money,
              etiqueta: 'Deuda USD',
              valor: '\$${deudaUsd.toStringAsFixed(2)}',
              color: deudaUsd > 0 ? Colors.red : Colors.green,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _buildResumenItem(
              icono: Icons.currency_exchange,
              etiqueta: 'Deuda Bs',
              valor: deudaBs.toStringAsFixed(2),
              color: deudaBs > 0 ? Colors.red : Colors.green,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _buildResumenItem(
              icono: Icons.receipt,
              etiqueta: 'Facturas',
              valor: '$facturas',
              color: const Color(0xFF1e293b),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem({
    required IconData icono,
    required String etiqueta,
    required String valor,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              etiqueta,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerError(String error) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIÁLOGO REGISTRAR ABONO (con pago mixto completo)
  // ============================================================
  void _mostrarDialogRegistrarAbono(BuildContext context) {
    final provider = context.read<CuentasPorCobrarProvider>();
    final tasas = context.read<TasasProvider>();
    final tasa = tasas.tasaParalelo > 0 ? tasas.tasaParalelo : 1.0;
    final facturas = provider.facturasPendientes;

    if (facturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay facturas pendientes para abonar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final facturasValidas = facturas.where((f) => f['id'] != null).toList();
    if (facturasValidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay facturas válidas para abonar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int? ventaIdSeleccionada = facturasValidas.first['id'] as int;
    final montoController = TextEditingController();
    String metodoPago = 'efectivo_bs';
    final referenciaController = TextEditingController();

    final Map<String, TextEditingController> mixtoControllers = {
      'efectivo_bs': TextEditingController(),
      'efectivo_usd': TextEditingController(),
      'pago_movil_bs': TextEditingController(),
      'transferencia_bs': TextEditingController(),
      'transferencia_usd': TextEditingController(),
      'zelle': TextEditingController(),
      'tarjeta_bs': TextEditingController(),
      'tarjeta_usd': TextEditingController(),
      'bio_pago': TextEditingController(),
    };

    double parseMonto(String v) {
      if (v.isEmpty) return 0.0;
      return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    }

    double sumaMixtoUsd() {
      double suma = 0.0;
      for (final entry in mixtoControllers.entries) {
        final metodo = entry.key;
        final v = parseMonto(entry.value.text);
        if (v <= 0) continue;
        if (_esMetodoBs(metodo)) {
          if (tasa > 0) suma += v / tasa;
        } else {
          suma += v;
        }
      }
      return suma;
    }

    Map<String, double> construirPagoMixtoDetalle() {
      final detalle = <String, double>{};
      for (final entry in mixtoControllers.entries) {
        final metodo = entry.key;
        final v = parseMonto(entry.value.text);
        if (v <= 0) continue;
        double usd;
        if (_esMetodoBs(metodo)) {
          if (tasa <= 0) continue;
          usd = v / tasa;
        } else {
          usd = v;
        }
        detalle[metodo] = double.parse(usd.toStringAsFixed(2));
      }
      return detalle;
    }

    void limpiarMixto() {
      for (final c in mixtoControllers.values) {
        c.clear();
      }
    }

    double saldoSeleccionado() {
      final f = facturasValidas.firstWhere(
        (x) => x['id'] == ventaIdSeleccionada,
        orElse: () => facturasValidas.first,
      );
      return (f['saldo_pendiente'] ?? 0).toDouble();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final esBs = _esMetodoBs(metodoPago);
          final esMixto = metodoPago == 'mixto';
          final saldoUsd = saldoSeleccionado();
          final saldoBs = saldoUsd * tasa;

          final montoTexto = montoController.text.trim();
          final montoIngresado = parseMonto(montoTexto);
          final equivalenteUsd = esBs ? montoIngresado / tasa : montoIngresado;
          final equivalenteBs = esBs ? montoIngresado : montoIngresado * tasa;

          final sumaMixto = sumaMixtoUsd();
          final diferenciaMixto = saldoUsd - sumaMixto;
          final cuadraMixto = diferenciaMixto.abs() < 0.01;
          final excedeMixto = sumaMixto > saldoUsd + 0.01;

          Color colorBadge;
          String textoBadge;
          if (sumaMixto <= 0) {
            colorBadge = Colors.grey;
            textoBadge = 'Pendiente';
          } else if (excedeMixto) {
            colorBadge = Colors.red;
            textoBadge = 'Excede \$${(sumaMixto - saldoUsd).toStringAsFixed(2)}';
          } else if (cuadraMixto) {
            colorBadge = Colors.green;
            textoBadge = '✓ Saldo completo';
          } else {
            colorBadge = Colors.orange;
            textoBadge = 'Abono parcial de \$${sumaMixto.toStringAsFixed(2)}';
          }

          return AlertDialog(
            title: const Text('💰 Registrar Abono'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Factura a abonar:'),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: DropdownButton<int>(
                      value: ventaIdSeleccionada,
                      isExpanded: true,
                      hint: const Text('Seleccionar factura'),
                      items: facturasValidas.map<DropdownMenuItem<int>>((f) {
                        final id = f['id'] as int;
                        final numero = f['numero_factura']?.toString() ?? 'Sin número';
                        final saldo = (f['saldo_pendiente'] ?? 0).toDouble();
                        final sBs = f['deuda_bs'] != null
                            ? (f['deuda_bs'] as num).toDouble()
                            : saldo * tasa;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                numero,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                'Saldo: \$${saldo.toStringAsFixed(2)}  •  Bs ${sBs.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          ventaIdSeleccionada = value!;
                          montoController.clear();
                          limpiarMixto();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Método de pago:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: metodoPago,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'efectivo_bs', child: Text('Efectivo (Bs)')),
                      DropdownMenuItem(value: 'efectivo_usd', child: Text('Efectivo (USD)')),
                      DropdownMenuItem(value: 'transferencia_bs', child: Text('Transferencia (Bs)')),
                      DropdownMenuItem(value: 'transferencia_usd', child: Text('Transferencia (USD)')),
                      DropdownMenuItem(value: 'pago_movil_bs', child: Text('Pago Móvil (Bs)')),
                      DropdownMenuItem(value: 'zelle', child: Text('Zelle (USD)')),
                      DropdownMenuItem(value: 'tarjeta_bs', child: Text('Tarjeta (Bs)')),
                      DropdownMenuItem(value: 'tarjeta_usd', child: Text('Tarjeta (USD)')),
                      DropdownMenuItem(value: 'mixto', child: Text('Mixto')),
                      DropdownMenuItem(value: 'bio_pago', child: Text('Bio Pago')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          metodoPago = value;
                          montoController.clear();
                          limpiarMixto();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  if (!esMixto) ...[
                    Text(
                      esBs ? 'Monto a abonar (Bs):' : 'Monto a abonar (USD):',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '0.00',
                        prefixText: esBs ? 'Bs ' : '\$ ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    if (montoIngresado > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                esBs
                                    ? 'Equivalente: \$${equivalenteUsd.toStringAsFixed(2)} USD'
                                    : 'Equivalente: Bs ${equivalenteBs.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Saldo disponible: \$${saldoUsd.toStringAsFixed(2)}  •  Bs ${saldoBs.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],

                  if (esMixto) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart, size: 18, color: Colors.blue),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Distribución del pago',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    limpiarMixto();
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 14),
                                label: const Text('Limpiar'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Tasa paralelo: ${tasa.toStringAsFixed(2)} Bs/USD',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          _buildGridMixto(mixtoControllers, tasa, () => setState(() {})),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Asignado: \$${sumaMixto.toStringAsFixed(2)} (Bs ${(sumaMixto * tasa).toStringAsFixed(2)})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        'Saldo: \$${saldoUsd.toStringAsFixed(2)} (Bs ${saldoBs.toStringAsFixed(2)})',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorBadge.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: colorBadge),
                                  ),
                                  child: Text(
                                    textoBadge,
                                    style: TextStyle(
                                      color: colorBadge,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Text('Referencia (opcional):'),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: referenciaController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'N° de comprobante',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (ventaIdSeleccionada == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona una factura'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  double montoUsd = 0.0;
                  Map<String, double>? pagoMixtoDetalle;

                  if (esMixto) {
                    pagoMixtoDetalle = construirPagoMixtoDetalle();
                    if (pagoMixtoDetalle.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa al menos un monto en la distribución'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    montoUsd = pagoMixtoDetalle.values.fold(0.0, (a, b) => a + b);
                    if (montoUsd > saldoUsd + 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('La suma (\$${montoUsd.toStringAsFixed(2)}) supera el saldo (\$${saldoUsd.toStringAsFixed(2)})'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  } else {
                    final monto = parseMonto(montoController.text);
                    if (monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa un monto válido'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    montoUsd = esBs ? (monto / tasa) : monto;
                    if (montoUsd > saldoUsd + 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('El monto (\$${montoUsd.toStringAsFixed(2)}) supera el saldo (\$${saldoUsd.toStringAsFixed(2)})'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  // Capturamos el VentaProvider ANTES de cerrar el diálogo.
                  // Después del pop, el context del diálogo queda desmontado
                  // y context.read<>() lanzaría una excepción silenciosa.
                  final ventaProvider = context.read<VentaProvider>();

                  Navigator.of(dialogContext).pop();

                  final result = await provider.registrarAbono(
                    ventaId: ventaIdSeleccionada!,
                    montoUsd: montoUsd,
                    metodoPago: metodoPago,
                    referencia: referenciaController.text.trim(),
                    pagoMixtoDetalle: pagoMixtoDetalle,
                  );

                  if (result['ok'] == true) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Abono registrado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    provider.cargarDetalleCliente(widget.clienteId);
                    ventaProvider.sincronizarTodo();
                  } else if (result['offline'] == true) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('💾 Abono guardado localmente. Se sincronizará cuando haya internet.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    provider.cargarDetalleCliente(widget.clienteId);
                    ventaProvider.sincronizarTodo();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: ${result['mensaje'] ?? 'Error al registrar abono'}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Registrar Abono'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // GRID DE 9 INPUTS PARA PAGO MIXTO
  // ============================================================
  Widget _buildGridMixto(
    Map<String, TextEditingController> controllers,
    double tasa,
    VoidCallback onChanged,
  ) {
    final metodos = [
      {'id': 'efectivo_bs', 'label': 'Efectivo Bs', 'moneda': 'BS'},
      {'id': 'efectivo_usd', 'label': 'Efectivo USD', 'moneda': 'USD'},
      {'id': 'pago_movil_bs', 'label': 'Pago Móvil Bs', 'moneda': 'BS'},
      {'id': 'transferencia_bs', 'label': 'Transferencia Bs', 'moneda': 'BS'},
      {'id': 'transferencia_usd', 'label': 'Transferencia USD', 'moneda': 'USD'},
      {'id': 'zelle', 'label': 'Zelle USD', 'moneda': 'USD'},
      {'id': 'tarjeta_bs', 'label': 'Tarjeta Bs', 'moneda': 'BS'},
      {'id': 'tarjeta_usd', 'label': 'Tarjeta USD', 'moneda': 'USD'},
      {'id': 'bio_pago', 'label': 'Bio Pago Bs', 'moneda': 'BS'},
    ];

    final cells = metodos
        .map((m) => _buildCeldaMixto(m, controllers[m['id']]!, tasa, onChanged))
        .toList();

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 2) {
      if (i + 1 < cells.length) {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 6),
            Expanded(child: cells[i + 1]),
          ],
        ));
      } else {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 6),
            const Expanded(child: SizedBox()),
          ],
        ));
      }
    }
    return Column(children: rows);
  }

  Widget _buildCeldaMixto(
    Map<String, dynamic> m,
    TextEditingController ctrl,
    double tasa,
    VoidCallback onChanged,
  ) {
    final esBs = m['moneda'] == 'BS';
    final valor = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
    final usd = esBs ? (tasa > 0 ? valor / tasa : 0.0) : valor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m['label'],
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 3),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: const OutlineInputBorder(),
              prefixText: esBs ? null : '\$ ',
              suffixText: esBs ? 'Bs' : null,
              hintText: '0.00',
              hintStyle: const TextStyle(fontSize: 12),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (_) => onChanged(),
          ),
          if (esBs) ...[
            const SizedBox(height: 2),
            Text(
              '≈ \$${usd.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// WIDGET PAGINADOR REUTILIZABLE
// ============================================================
class _Paginador extends StatelessWidget {
  final int pagina;
  final int totalPaginas;
  final Function(int) onPageChange;

  const _Paginador({
    required this.pagina,
    required this.totalPaginas,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPaginas <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: pagina > 1 ? () => onPageChange(pagina - 1) : null,
          ),
          Text(
            'Página $pagina de $totalPaginas',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: pagina < totalPaginas ? () => onPageChange(pagina + 1) : null,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: FACTURAS PENDIENTES (con paginación)
// ============================================================
class _TabFacturas extends StatelessWidget {
  final List<Map<String, dynamic>> facturas;
  final int pagina;
  final int totalPaginas;
  final Function(int) onPageChange;
  final VoidCallback onRecargar;
  final double tasaParalelo;

  const _TabFacturas({
    required this.facturas,
    required this.pagina,
    required this.totalPaginas,
    required this.onPageChange,
    required this.onRecargar,
    required this.tasaParalelo,
  });

  @override
  Widget build(BuildContext context) {
    if (facturas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No hay facturas pendientes',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRecargar(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: facturas.length,
              itemBuilder: (context, index) {
                return _FacturaCard(
                  factura: facturas[index],
                  tasaParalelo: tasaParalelo,
                );
              },
            ),
          ),
        ),
        _Paginador(
          pagina: pagina,
          totalPaginas: totalPaginas,
          onPageChange: onPageChange,
        ),
      ],
    );
  }
}

class _FacturaCard extends StatelessWidget {
  final Map<String, dynamic> factura;
  final double tasaParalelo;

  const _FacturaCard({required this.factura, required this.tasaParalelo});

  @override
  Widget build(BuildContext context) {
    final numero = factura['numero_factura'] ?? 'Sin número';
    final saldo = (factura['saldo_pendiente'] ?? 0).toDouble();
    final total = (factura['total'] ?? 0).toDouble();
    final fecha = factura['fecha'] ?? '';

    final saldoBs = factura['deuda_bs'] != null
        ? (factura['deuda_bs'] as num).toDouble()
        : saldo * tasaParalelo;
    final totalBs = total * tasaParalelo;

    String fechaFormateada = fecha;
    try {
      final date = DateTime.parse(fecha);
      fechaFormateada =
          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  numero,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Saldo: \$${saldo.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Bs ${saldoBs.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      fechaFormateada,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Bs ${totalBs.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 2: PLANES DE CUOTAS (con paginación)
// ============================================================
class _TabPlanes extends StatelessWidget {
  final List<PlanCuota> planes;
  final int pagina;
  final int totalPaginas;
  final Function(int) onPageChange;
  final double tasaParalelo;

  const _TabPlanes({
    required this.planes,
    required this.pagina,
    required this.totalPaginas,
    required this.onPageChange,
    required this.tasaParalelo,
  });

  @override
  Widget build(BuildContext context) {
    if (planes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No hay planes de cuotas',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: planes.length,
            itemBuilder: (context, index) {
              return _PlanCuotaCard(
                plan: planes[index],
                tasaParalelo: tasaParalelo,
              );
            },
          ),
        ),
        _Paginador(
          pagina: pagina,
          totalPaginas: totalPaginas,
          onPageChange: onPageChange,
        ),
      ],
    );
  }
}

// ============================================================
// TAB 3: HISTORIAL DE ABONOS (con paginación)
// ============================================================
class _TabAbonos extends StatelessWidget {
  final List<Abono> abonos;
  final int pagina;
  final int totalPaginas;
  final bool cargando;
  final Function(int) onPageChange;
  final double tasaParalelo;

  const _TabAbonos({
    required this.abonos,
    required this.pagina,
    required this.totalPaginas,
    required this.cargando,
    required this.onPageChange,
    required this.tasaParalelo,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando && abonos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (abonos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No hay abonos registrados',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: abonos.length,
            itemBuilder: (context, index) {
              return _AbonoCard(
                abono: abonos[index],
                tasaParalelo: tasaParalelo,
              );
            },
          ),
        ),
        _Paginador(
          pagina: pagina,
          totalPaginas: totalPaginas,
          onPageChange: onPageChange,
        ),
      ],
    );
  }
}

class _AbonoCard extends StatelessWidget {
  final Abono abono;
  final double tasaParalelo;

  const _AbonoCard({required this.abono, required this.tasaParalelo});

  @override
  Widget build(BuildContext context) {
    String fechaFormateada = abono.fecha;
    try {
      final date = DateTime.parse(abono.fecha);
      fechaFormateada =
          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final montoMostrar = abono.montoUsd > 0 ? abono.montoUsd : 0.0;
    final montoBsMostrar = abono.montoBs > 0
        ? abono.montoBs
        : montoMostrar * tasaParalelo;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _mostrarDetalleAbono(context, abono, fechaFormateada, montoBsMostrar),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Factura: ${abono.numeroFactura}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$fechaFormateada  •  ${abono.metodoPago}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (abono.referencia != null && abono.referencia!.isNotEmpty)
                      Text(
                        'Ref: ${abono.referencia}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${montoMostrar.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: montoMostrar > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                  if (montoBsMostrar > 0)
                    Text(
                      'Bs ${montoBsMostrar.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleAbono(
    BuildContext context,
    Abono abono,
    String fechaFormateada,
    double montoBs,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Detalle del Abono',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetalleRow('Factura', abono.numeroFactura),
            _buildDetalleRow('Fecha', fechaFormateada),
            _buildDetalleRow('Monto USD', '\$${abono.montoUsd.toStringAsFixed(2)}'),
            if (montoBs > 0)
              _buildDetalleRow('Monto Bs', 'Bs ${montoBs.toStringAsFixed(2)}'),
            _buildDetalleRow('Método de pago', abono.metodoPago),
            if (abono.referencia != null && abono.referencia!.isNotEmpty)
              _buildDetalleRow('Referencia', abono.referencia!),
            if (abono.usuarioNombre != null && abono.usuarioNombre!.isNotEmpty)
              _buildDetalleRow('Registrado por', abono.usuarioNombre!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e293b),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD EXPANDIBLE PARA CADA PLAN DE CUOTAS
// ============================================================
class _PlanCuotaCard extends StatefulWidget {
  final PlanCuota plan;
  final double tasaParalelo;

  const _PlanCuotaCard({required this.plan, required this.tasaParalelo});

  @override
  State<_PlanCuotaCard> createState() => _PlanCuotaCardState();
}

class _PlanCuotaCardState extends State<_PlanCuotaCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final tasa = widget.tasaParalelo;

    Color colorEstado;
    String textoEstado;
    IconData iconoEstado;
    if (plan.isSaldado) {
      colorEstado = Colors.green;
      textoEstado = 'Saldado';
      iconoEstado = Icons.check_circle;
    } else if (plan.isAnulado) {
      colorEstado = Colors.grey;
      textoEstado = 'Anulado';
      iconoEstado = Icons.cancel;
    } else {
      colorEstado = const Color(0xFFf0872d);
      textoEstado = 'Activo';
      iconoEstado = Icons.pending_actions;
    }

    final financiadoBs = plan.montoFinanciado * tasa;
    final inicialBs = plan.montoInicial * tasa;
    final moraBs = plan.moraTotal * tasa;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Plan #${plan.id}  •  ${plan.numeroFactura}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorEstado.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorEstado, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconoEstado, size: 12, color: colorEstado),
                            const SizedBox(width: 4),
                            Text(
                              textoEstado,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorEstado,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Financiado:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${plan.montoFinanciado.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Bs ${financiadoBs.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Inicial:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${plan.montoInicial.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Bs ${inicialBs.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${plan.cuotasPagadas}/${plan.totalCuotas} cuotas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorEstado,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: plan.progreso,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: colorEstado,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(plan.progreso * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (plan.moraTotal > 0.01) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mora: \$${plan.moraTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              Text(
                                'Bs ${moraBs.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Inicio: ${plan.fechaInicio}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Spacer(),
                      Text(
                        _expandido ? 'Ocultar cuotas ▲' : 'Ver cuotas ▼',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: plan.cuotas
                    .map((c) => _buildCuotaRow(c, tasa))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCuotaRow(Cuota cuota, double tasa) {
    Color colorCuota;
    String textoCuota;
    if (cuota.isPagada) {
      colorCuota = Colors.green;
      textoCuota = 'Pagada';
    } else if (cuota.isVencida) {
      colorCuota = Colors.red;
      textoCuota = 'Vencida';
    } else if (cuota.isParcial) {
      colorCuota = Colors.blue;
      textoCuota = 'Parcial';
    } else {
      colorCuota = Colors.grey;
      textoCuota = 'Pendiente';
    }

    final montoBs = cuota.monto * tasa;
    final pagadoBs = cuota.montoPagado * tasa;
    final moraBs = cuota.moraPendiente * tasa;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorCuota.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorCuota.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cuota #${cuota.numeroCuota}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorCuota.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  textoCuota,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorCuota,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    cuota.fechaVencimiento,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${cuota.monto.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Bs ${montoBs.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          if (cuota.montoPagado > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pagado:',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${cuota.montoPagado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Bs ${pagadoBs.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (cuota.moraPendiente > 0.01) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cuota.moraCondonadaFlag ? 'Mora (condonada):' : 'Mora:',
                  style: TextStyle(
                    fontSize: 11,
                    color: cuota.moraCondonadaFlag ? Colors.grey : Colors.red,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${cuota.moraPendiente.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cuota.moraCondonadaFlag ? Colors.grey : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Bs ${moraBs.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: cuota.moraCondonadaFlag ? Colors.grey : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}