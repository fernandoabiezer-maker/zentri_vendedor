import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/models/venta_pendiente.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'dart:convert';

class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().cargarPendientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final ventasPendientes = syncProvider.pendientes;
    final cotizacionesPendientes = syncProvider.cotizacionesPendientes;
    final abonosPendientes = syncProvider.abonosPendientes;
    final clientesPendientes = syncProvider.clientesPendientes;
    final cargando = syncProvider.cargando;
    final sincronizandoVentas = syncProvider.sincronizando;
    final sincronizandoCotizaciones = syncProvider.sincronizandoCotizaciones;
    final sincronizandoAbonos = syncProvider.sincronizandoAbonos;
    final sincronizandoClientes = syncProvider.sincronizandoClientes;
    final totalPendientes = ventasPendientes.length +
        cotizacionesPendientes.length +
        abonosPendientes.length +
        clientesPendientes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes de sincronización'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          if (totalPendientes > 0)
            IconButton(
              icon: (sincronizandoVentas ||
                      sincronizandoCotizaciones ||
                      sincronizandoAbonos ||
                      sincronizandoClientes)
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              onPressed: (sincronizandoVentas ||
                      sincronizandoCotizaciones ||
                      sincronizandoAbonos ||
                      sincronizandoClientes)
                  ? null
                  : () async {
                      final total = await syncProvider.sincronizarTodo();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sincronización completada. $total pendientes sincronizados.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
              tooltip: 'Sincronizar todas',
            ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : totalPendientes == 0
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done, size: 80, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No hay pendientes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Todas las ventas, cotizaciones, abonos y clientes están sincronizados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============================================================
                      // VENTAS PENDIENTES
                      // ============================================================
                      if (ventasPendientes.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ventas pendientes (${ventasPendientes.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: sincronizandoVentas
                                  ? null
                                  : () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Limpiar todas las ventas'),
                                          content: const Text(
                                            '¿Seguro que quieres eliminar todas las ventas pendientes? Esta acción no se puede deshacer.'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await syncProvider.limpiarTodas();
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Todas las ventas pendientes fueron eliminadas'),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              },
                                              child: const Text('Eliminar todo', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                              child: const Text('Limpiar todo', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...ventasPendientes.map((venta) => _buildVentaCard(venta, syncProvider)),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // ============================================================
                      // COTIZACIONES PENDIENTES
                      // ============================================================
                      if (cotizacionesPendientes.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cotizaciones pendientes (${cotizacionesPendientes.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: sincronizandoCotizaciones
                                  ? null
                                  : () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Limpiar todas las cotizaciones'),
                                          content: const Text(
                                            '¿Seguro que quieres eliminar todas las cotizaciones pendientes? Esta acción no se puede deshacer.'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await syncProvider.limpiarTodas();
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Todas las cotizaciones pendientes fueron eliminadas'),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              },
                                              child: const Text('Eliminar todo', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                              child: const Text('Limpiar todo', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...cotizacionesPendientes.map((cotizacion) => _buildCotizacionCard(cotizacion, syncProvider)),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // ============================================================
                      // ABONOS PENDIENTES
                      // ============================================================
                      if (abonosPendientes.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Abonos pendientes (${abonosPendientes.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: sincronizandoAbonos
                                  ? null
                                  : () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Limpiar todos los abonos'),
                                          content: const Text(
                                            '¿Seguro que quieres eliminar todos los abonos pendientes? Esta acción no se puede deshacer.'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await syncProvider.limpiarTodas();
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Todos los abonos pendientes fueron eliminados'),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              },
                                              child: const Text('Eliminar todo', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                              child: const Text('Limpiar todo', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...abonosPendientes.map((abono) => _buildAbonoCard(abono, syncProvider)),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // ============================================================
                      // CLIENTES PENDIENTES (NUEVA SECCIÓN)
                      // ============================================================
                      if (clientesPendientes.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Clientes pendientes (${clientesPendientes.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: sincronizandoClientes
                                  ? null
                                  : () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Limpiar todos los clientes'),
                                          content: const Text(
                                            '¿Seguro que quieres eliminar todos los clientes pendientes? Esta acción no se puede deshacer.'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await syncProvider.limpiarTodas();
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Todos los clientes pendientes fueron eliminados'),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              },
                                              child: const Text('Eliminar todo', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                              child: const Text('Limpiar todo', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...clientesPendientes.map((cliente) => _buildClienteCard(cliente, syncProvider)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ============================================================
  // CARD PARA VENTA PENDIENTE
  // ============================================================
  Widget _buildVentaCard(VentaPendiente venta, SyncProvider syncProvider) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(venta.payload) as Map<String, dynamic>;
    } catch (e) {
      payload = {};
    }

    final items = payload['items'] as List? ?? [];
    final total = items.fold<double>(
      0,
      (sum, item) => sum + ((item['cantidad'] as num?)?.toDouble() ?? 0) * ((item['precio_venta'] as num?)?.toDouble() ?? 0),
    );

    final fecha = DateTime.tryParse(venta.fechaCreacion);
    final fechaStr = fecha != null
        ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
        : venta.fechaCreacion;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.orange.shade100,
              child: Text(
                '${items.length}',
                style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${items.length} productos',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Total: \$${total.toStringAsFixed(2)}  •  Fecha: $fechaStr  •  Intentos: ${venta.intentos}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue, size: 22),
                  onPressed: syncProvider.sincronizando
                      ? null
                      : () async {
                          await syncProvider.reintentarVenta(venta);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reintentando venta...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Reintentar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  onPressed: syncProvider.sincronizando
                      ? null
                      : () async {
                          await syncProvider.eliminarVenta(venta.id!);
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD PARA COTIZACIÓN PENDIENTE
  // ============================================================
  Widget _buildCotizacionCard(CotizacionPendiente cotizacion, SyncProvider syncProvider) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(cotizacion.payload) as Map<String, dynamic>;
    } catch (e) {
      payload = {};
    }

    final items = payload['items'] as List? ?? [];
    final total = items.fold<double>(
      0,
      (sum, item) => sum + ((item['cantidad'] as num?)?.toDouble() ?? 0) * ((item['precio_unitario'] as num?)?.toDouble() ?? 0),
    );
    final cliente = payload['cliente'] ?? 'Sin cliente';
    final esEdicion = payload['id'] != null && payload['id'] > 0;

    final fecha = DateTime.tryParse(cotizacion.fechaCreacion);
    final fechaStr = fecha != null
        ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
        : cotizacion.fechaCreacion;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.purple.shade100,
              child: Text(
                '${items.length}',
                style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${esEdicion ? '✏️ Edición' : '📄 Nueva'} - $cliente',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Total: \$${total.toStringAsFixed(2)}  •  Fecha: $fechaStr  •  Intentos: ${cotizacion.intentos}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue, size: 22),
                  onPressed: syncProvider.sincronizandoCotizaciones
                      ? null
                      : () async {
                          await syncProvider.reintentarCotizacion(cotizacion);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reintentando cotización...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Reintentar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  onPressed: syncProvider.sincronizandoCotizaciones
                      ? null
                      : () async {
                          await syncProvider.eliminarCotizacionPendiente(cotizacion.id!);
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD PARA ABONO PENDIENTE
  // ============================================================
  Widget _buildAbonoCard(AbonoPendiente abono, SyncProvider syncProvider) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(abono.payload) as Map<String, dynamic>;
    } catch (e) {
      payload = {};
    }

    final ventaId = payload['venta_id'] ?? 0;
    final monto = (payload['monto'] ?? 0.0).toDouble();
    final metodoPago = payload['metodo_pago'] ?? 'No especificado';
    final referencia = payload['referencia'] ?? '';

    final fecha = DateTime.tryParse(abono.fechaCreacion);
    final fechaStr = fecha != null
        ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
        : abono.fechaCreacion;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green.shade100,
              child: const Icon(Icons.payments, size: 20, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abono - Venta #$ventaId',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Monto: \$${monto.toStringAsFixed(2)}  •  Método: $metodoPago  •  Intentos: ${abono.intentos}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (referencia.isNotEmpty)
                    Text(
                      'Ref: $referencia',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue, size: 22),
                  onPressed: syncProvider.sincronizandoAbonos
                      ? null
                      : () async {
                          await syncProvider.reintentarAbono(abono);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reintentando abono...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Reintentar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  onPressed: syncProvider.sincronizandoAbonos
                      ? null
                      : () async {
                          await syncProvider.eliminarAbonoPendiente(abono.id!);
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD PARA CLIENTE PENDIENTE (NUEVO)
  // ============================================================
  Widget _buildClienteCard(Map<String, dynamic> pendiente, SyncProvider syncProvider) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(pendiente['payload'] as String) as Map<String, dynamic>;
    } catch (e) {
      payload = {};
    }

    final nombre = payload['nombre'] ?? 'Sin nombre';
    final cedula = payload['cedula'] ?? '';
    final telefono = payload['telefono'] ?? '';
    final ubicacion = payload['ubicacion_gps'] ?? '';
    final tieneId = payload['id'] != null && payload['id'] is num && (payload['id'] as num) > 0;
    final esEdicion = tieneId;
    final idLocal = pendiente['id_local'] as String? ?? '';

    final fechaCreacion = pendiente['fecha_creacion'] as String? ?? '';
    final fecha = DateTime.tryParse(fechaCreacion);
    final fechaStr = fecha != null
        ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
        : fechaCreacion;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                esEdicion ? Icons.edit : Icons.person_add,
                size: 20,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${esEdicion ? '✏️ Edición' : '🆕 Nuevo'} - $nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (cedula.isNotEmpty)
                    Text(
                      'Cédula: $cedula',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  if (telefono.isNotEmpty)
                    Text(
                      'Tel: $telefono  •  Fecha: $fechaStr',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    )
                  else
                    Text(
                      'Fecha: $fechaStr',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  if (ubicacion.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'GPS incluido',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue, size: 22),
                  onPressed: syncProvider.sincronizandoClientes
                      ? null
                      : () async {
                          try {
                            await syncProvider.reintentarClientePendiente(pendiente);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cliente sincronizado correctamente'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Reintentar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  onPressed: syncProvider.sincronizandoClientes
                      ? null
                      : () async {
                          await syncProvider.eliminarClientePendiente(idLocal);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cliente pendiente eliminado'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}