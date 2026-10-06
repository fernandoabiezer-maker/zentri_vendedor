import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/notificaciones_cobro_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/screens/cuentas_por_cobrar_detail_screen.dart';

class NotificacionesCobroScreen extends StatefulWidget {
  const NotificacionesCobroScreen({super.key});

  @override
  State<NotificacionesCobroScreen> createState() =>
      _NotificacionesCobroScreenState();
}

class _NotificacionesCobroScreenState extends State<NotificacionesCobroScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificacionesCobroProvider>().refrescar();
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
    final prov = context.watch<NotificacionesCobroProvider>();
    final tasas = context.watch<TasasProvider>();
    final tasa = tasas.tasaParalelo > 0 ? tasas.tasaParalelo : prov.tasaParalelo;

    final totalCuotas = prov.cuotasVencidas.length + prov.cuotasPorVencer.length;
    final totalCreditos = prov.creditosVencidos.length + prov.creditosPorVencer.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('💵 Notificaciones de Cobro'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.refrescar(),
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFf0872d),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade400,
          tabs: [
            Tab(
              icon: const Icon(Icons.calendar_month),
              text: 'Cuotas ($totalCuotas)',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long),
              text: 'Créditos ($totalCreditos)',
            ),
          ],
        ),
      ),
      body: prov.cargando && prov.totalNotificaciones == 0
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumen(prov, tasa),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaCuotas(prov, tasa),
                      _buildListaCreditos(prov, tasa),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumen(NotificacionesCobroProvider prov, double tasa) {
    final resumen = prov.resumen;
    final vencidas = (resumen['total_vencidas'] as num?)?.toInt() ?? 0;
    final porVencer = (resumen['total_por_vencer'] as num?)?.toInt() ?? 0;
    final moraUsd = (resumen['mora_total_usd'] as num?)?.toDouble() ?? 0;

    if (vencidas == 0 && porVencer == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.green.shade50,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¡Todo al día! No hay cuotas vencidas ni por vencer.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildCard(
              icono: Icons.warning,
              color: Colors.red,
              etiqueta: 'Vencidas',
              valor: '$vencidas',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCard(
              icono: Icons.schedule,
              color: Colors.orange,
              etiqueta: 'Por vencer',
              valor: '$porVencer',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCard(
              icono: Icons.attach_money,
              color: Colors.deepOrange,
              etiqueta: 'Mora total',
              valor: '\$${moraUsd.toStringAsFixed(2)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icono,
    required Color color,
    required String etiqueta,
    required String valor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaCuotas(NotificacionesCobroProvider prov, double tasa) {
    final items = <Map<String, dynamic>>[];
    for (final c in prov.cuotasVencidas) {
      items.add({...c, '_vencida': true});
    }
    for (final c in prov.cuotasPorVencer) {
      items.add({...c, '_vencida': false});
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('No hay cuotas pendientes', style: TextStyle(fontSize: 15)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildCuotaCard(items[i], tasa),
    );
  }

  Widget _buildCuotaCard(Map<String, dynamic> item, double tasa) {
    final vencida = item['_vencida'] == true;
    final clienteNombre = item['cliente_nombre']?.toString() ?? 'Cliente';
    final clienteId = (item['cliente_id'] as num?)?.toInt() ?? 0;
    final numeroFactura = item['numero_factura']?.toString() ?? '--';
    final numeroCuota = item['numero_cuota']?.toString() ?? '?';
    final fechaVenc = item['fecha_vencimiento']?.toString() ?? '--';
    final monto = (item['monto'] as num?)?.toDouble() ?? 0;
    final pagado = (item['monto_pagado'] as num?)?.toDouble() ?? 0;
    final saldoCuota = (item['saldo_cuota_usd'] as num?)?.toDouble() ?? 0;
    final moraUsd = (item['mora_pendiente_usd'] as num?)?.toDouble() ?? 0;
    final totalCobrar = (item['total_a_cobrar_usd'] as num?)?.toDouble() ?? 0;
    final diasAtraso = (item['dias_atraso'] as num?)?.toInt() ?? 0;
    final diasRestantes = (item['dias_restantes'] as num?)?.toInt() ?? 0;

    final color = vencida ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    clienteNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vencida ? '$diasAtraso d atraso' : '$diasRestantes d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Factura: $numeroFactura  •  Cuota #$numeroCuota',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Vence: $fechaVenc',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monto: \$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12)),
                Text('Pagado: \$${pagado.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
            if (moraUsd > 0.01)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Mora: \$${moraUsd.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total a cobrar: \$${totalCobrar.toStringAsFixed(2)}'
                    '${tasa > 0 ? '  (Bs ${(totalCobrar * tasa).toStringAsFixed(2)})' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _abrirCliente(clienteId, clienteNombre),
                  icon: const Icon(Icons.payments, size: 16),
                  label: const Text('Cobrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaCreditos(NotificacionesCobroProvider prov, double tasa) {
    final items = <Map<String, dynamic>>[];
    for (final c in prov.creditosVencidos) {
      items.add({...c, '_vencida': true});
    }
    for (final c in prov.creditosPorVencer) {
      items.add({...c, '_vencida': false});
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('No hay créditos pendientes', style: TextStyle(fontSize: 15)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildCreditoCard(items[i], tasa),
    );
  }

  Widget _buildCreditoCard(Map<String, dynamic> item, double tasa) {
    final vencida = item['_vencida'] == true;
    final clienteNombre = item['cliente_nombre']?.toString() ?? 'Cliente';
    final clienteId = (item['cliente_id'] as num?)?.toInt() ?? 0;
    final numeroFactura = item['numero_factura']?.toString() ?? '--';
    final fechaVenc = item['fecha_vencimiento']?.toString() ?? '--';
    final monto = (item['monto'] as num?)?.toDouble() ?? 0;
    final pagado = (item['monto_pagado'] as num?)?.toDouble() ?? 0;
    final totalCobrar = (item['total_a_cobrar_usd'] as num?)?.toDouble() ?? 0;
    final diasAtraso = (item['dias_atraso'] as num?)?.toInt() ?? 0;
    final diasRestantes = (item['dias_restantes'] as num?)?.toInt() ?? 0;

    final color = vencida ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    clienteNombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vencida ? '$diasAtraso d atraso' : '$diasRestantes d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Factura: $numeroFactura',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Vence: $fechaVenc',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monto: \$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12)),
                Text('Abonado: \$${pagado.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total a cobrar: \$${totalCobrar.toStringAsFixed(2)}'
                    '${tasa > 0 ? '  (Bs ${(totalCobrar * tasa).toStringAsFixed(2)})' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _abrirCliente(clienteId, clienteNombre),
                  icon: const Icon(Icons.payments, size: 16),
                  label: const Text('Cobrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCliente(int clienteId, String clienteNombre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuentasPorCobrarDetailScreen(
          clienteId: clienteId,
          clienteNombre: clienteNombre,
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<NotificacionesCobroProvider>().refrescar();
      }
    });
  }
}