import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/cotizacion_provider.dart';
import 'package:zentri_vendedor/screens/cotizacion_form_screen.dart';
import 'package:zentri_vendedor/services/pdf_service.dart';
import 'package:zentri_vendedor/models/item_carrito.dart';

class CotizacionDetailScreen extends StatefulWidget {
  final int cotizacionId;

  const CotizacionDetailScreen({super.key, required this.cotizacionId});

  @override
  State<CotizacionDetailScreen> createState() => _CotizacionDetailScreenState();
}

class _CotizacionDetailScreenState extends State<CotizacionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CotizacionProvider>().cargarDetalle(widget.cotizacionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CotizacionProvider>();
    final cotizacion = provider.cotizacionSeleccionada;
    final cargando = provider.cargando;

    if (cargando || cotizacion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de Cotización'),
          backgroundColor: const Color(0xFF1e293b),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Cotización'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          // Botón: Editar (solo pendientes)
          if (!cotizacion.isConvertida)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CotizacionFormScreen(
                      cotizacionId: cotizacion.id,
                    ),
                  ),
                ).then((_) => provider.cargarDetalle(widget.cotizacionId));
              },
              tooltip: 'Editar cotización',
            ),
          // Botón: Compartir PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            onPressed: () {
              PdfService.descargarYCompartirCotizacion(context, cotizacion.id);
            },
            tooltip: 'Compartir PDF',
          ),
          // Botón: Convertir (solo pendientes)
          if (!cotizacion.isConvertida)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.green),
              onPressed: () {
                _mostrarDialogConvertir(context, cotizacion);
              },
              tooltip: 'Convertir a venta',
            ),
          // Botón: Eliminar (solo pendientes)
          if (!cotizacion.isConvertida)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmarEliminar(context, cotizacion.id),
              tooltip: 'Eliminar cotización',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // CARD DE INFORMACIÓN GENERAL (mismo estilo que ventas)
            // ============================================================
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cotización #${cotizacion.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1e293b),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cotizacion.isConvertida
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cotizacion.isConvertida ? '✅ Convertida' : '⏳ Pendiente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cotizacion.isConvertida ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('Cliente', cotizacion.cliente),
                    _buildInfoRow('RIF', cotizacion.clienteRif ?? 'N/A'),
                    _buildInfoRow('Vendedor', cotizacion.vendedorNombre ?? 'N/A'),
                    _buildInfoRow('Fecha', cotizacion.fecha),
                    _buildInfoRow('Tipo Venta', cotizacion.tipoVenta),
                    _buildInfoRow('Moneda', cotizacion.moneda),
                    _buildInfoRow('Método Pago', cotizacion.metodoPago),
                    _buildInfoRow('IVA', '${cotizacion.ivaPorcentaje.toStringAsFixed(1)}%'),
                    _buildInfoRow('Margen Global', '${cotizacion.margenGlobal.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ============================================================
            // CARD DE PRODUCTOS (mismo estilo que ventas)
            // ============================================================
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1e293b),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (cotizacion.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Sin productos',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...cotizacion.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${formatCantidad(item.cantidad)} x ',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '\$${item.precioUnitario.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1e293b),
                          ),
                        ),
                        Text(
                          '\$${cotizacion.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFFf0872d),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ============================================================
            // BOTONES DE ACCIÓN (mismo estilo que ventas)
            // ============================================================
            if (!cotizacion.isConvertida) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarDialogConvertir(context, cotizacion),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Convertir a Venta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  PdfService.descargarYCompartirCotizacion(context, cotizacion.id);
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('Compartir PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf0872d),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIÁLOGO DE CONVERSIÓN (con todos los métodos de pago, incluyendo Bio Pago)
  // ============================================================
  void _mostrarDialogConvertir(BuildContext context, dynamic cotizacion) {
    String metodoPago = 'efectivo_bs';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔄 Convertir a Venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cotización #${cotizacion.id}'),
            Text('Cliente: ${cotizacion.cliente}'),
            Text('Total: \$${cotizacion.total.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text('Método de pago:'),
            DropdownButton<String>(
              value: metodoPago,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'efectivo_bs', child: Text('Efectivo (Bs)')),
                DropdownMenuItem(value: 'efectivo_usd', child: Text('Efectivo (USD)')),
                DropdownMenuItem(value: 'pago_movil_bs', child: Text('Pago Móvil (Bs)')),
                DropdownMenuItem(value: 'transferencia_bs', child: Text('Transferencia (Bs)')),
                DropdownMenuItem(value: 'transferencia_usd', child: Text('Transferencia (USD)')),
                DropdownMenuItem(value: 'zelle', child: Text('Zelle (USD)')),
                DropdownMenuItem(value: 'tarjeta_bs', child: Text('Tarjeta (Bs)')),
                DropdownMenuItem(value: 'tarjeta_usd', child: Text('Tarjeta (USD)')),
                DropdownMenuItem(value: 'mixto', child: Text('Mixto')),
                DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                DropdownMenuItem(value: 'bio_pago', child: Text('Bio Pago')),
              ],
              onChanged: (value) {
                if (value != null) metodoPago = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<CotizacionProvider>();
              final result = await provider.convertirAVenta(
                cotizacionId: cotizacion.id,
                metodoPago: metodoPago,
              );
              if (result['ok'] == true) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Cotización convertida a venta'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                final factura = result['numero_factura'];
                if (factura != null) {
                  await PdfService.descargarYCompartirFactura(context, factura);
                }
                if (context.mounted) Navigator.pop(context);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: ${result['mensaje'] ?? 'Error al convertir'}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Eliminar Cotización'),
        content: const Text('¿Seguro que quieres eliminar esta cotización? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<CotizacionProvider>();
              final ok = await provider.eliminarCotizacion(id);
              if (ok) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Cotización eliminada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Error al eliminar cotización'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}