import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/screens/cliente_form_screen.dart';
import 'package:zentri_vendedor/services/pdf_service.dart';
import 'package:zentri_vendedor/services/ubicacion_service.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class ClienteDetailScreen extends StatefulWidget {
  final int clienteId;
  const ClienteDetailScreen({super.key, required this.clienteId});

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen> {
  bool _isDownloading = false;
  bool _errorCargando = false;
  String? _errorMensaje;
  bool _mostrarDiagnostico = false;

  // ✅ NUEVO: estado para saber si estamos resolviendo un enlace corto de ubicación
  bool _resolviendoUbicacion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDetalle();
    });
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _errorCargando = false;
      _errorMensaje = null;
    });
    final provider = context.read<ClienteProvider>();
    try {
      await provider.cargarDetalle(widget.clienteId);
    } catch (e) {
      setState(() {
        _errorCargando = true;
        _errorMensaje = e.toString();
      });
    }
  }

  @override
  void dispose() {
    context.read<ClienteProvider>().limpiarDetalle();
    super.dispose();
  }

  Future<void> _compartirFactura(String numeroFactura) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await PdfService.descargarYCompartirFactura(context, numeroFactura);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir factura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ============================================================
  // ABRIR UBICACIÓN (con resolución de enlaces cortos)
  // ============================================================
  Future<void> _abrirUbicacion(String url) async {
    if (_resolviendoUbicacion) return;

    String urlFinal = url;

    // ✅ NUEVO: Si es enlace corto, resolverlo antes de abrir
    if (UbicacionService.esEnlaceCorto(url)) {
      setState(() => _resolviendoUbicacion = true);
      try {
        urlFinal = await UbicacionService.resolverEnlaceUbicacion(url);
      } catch (e) {
        AppLogger.log('⚠️ Error resolviendo enlace en apertura: $e');
        urlFinal = url;
      } finally {
        if (mounted) setState(() => _resolviendoUbicacion = false);
      }
    }

    try {
      final uri = Uri.parse(urlFinal);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir la ubicación'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir la ubicación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // ✅ NUEVO: COPIAR UBICACIÓN AL PORTAPAPELES
  // ============================================================
  void _copiarUbicacion(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Ubicación copiada al portapapeles'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClienteProvider>();
    final cliente = provider.clienteSeleccionado;
    final cargando = provider.cargandoDetalle;
    final comportamiento = provider.comportamiento;

    if (cargando) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Cliente'),
          backgroundColor: const Color(0xFF1e293b),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorCargando || cliente == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Cliente'),
          backgroundColor: const Color(0xFF1e293b),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMensaje ?? 'No se pudo cargar el detalle del cliente',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _cargarDetalle,
                  child: const Text('Reintentar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final historial = comportamiento?['historial'] ?? [];
    final facturasPendientes = comportamiento?['facturas_pendientes'] ?? [];
    final totalDeudaUsd = comportamiento?['total_deuda_usd'] ?? 0.0;
    final totalDeudaBs = comportamiento?['total_deuda_bs'] ?? 0.0;
    final historialPage = provider.historialPage;
    final historialPages = provider.historialPages;
    final cargandoMasHistorial = provider.cargandoMasHistorial;
    final historialTotal = provider.historialTotal;
    final facturaPage = provider.facturaPage;
    final facturaPages = provider.facturaPages;
    final cargandoMasFacturas = provider.cargandoMasFacturas;
    final facturaTotal = provider.facturaTotal;

    // ✅ Scoring
    final puntaje = cliente.puntaje ?? 0;
    final categoria = cliente.categoria ?? 'Nuevo';
    Color categoriaColor;
    String categoriaEmoji;
    switch (categoria) {
      case 'Excelente':
        categoriaColor = Colors.green;
        categoriaEmoji = '⭐';
        break;
      case 'Bueno':
        categoriaColor = Colors.blue;
        categoriaEmoji = '👍';
        break;
      case 'Regular':
        categoriaColor = Colors.orange;
        categoriaEmoji = '👌';
        break;
      case 'Riesgoso':
        categoriaColor = Colors.red;
        categoriaEmoji = '⚠️';
        break;
      default:
        categoriaColor = Colors.grey;
        categoriaEmoji = '🆕';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(cliente.nombre),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClienteFormScreen(cliente: cliente),
                ),
              ).then((_) {
                provider.cargarDetalle(widget.clienteId);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              setState(() => _mostrarDiagnostico = !_mostrarDiagnostico);
            },
            tooltip: 'Diagnóstico',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DIAGNÓSTICO
                if (_mostrarDiagnostico)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      '''
📊 DIAGNÓSTICO DE DATOS:
• Cliente: ${cliente.nombre}
• Historial: ${historial.length} registros (pág $historialPage/$historialPages)
• Facturas pendientes: ${facturasPendientes.length} (pág $facturaPage/$facturaPages)
• Total deuda USD: ${totalDeudaUsd.toStringAsFixed(2)}
• Total deuda Bs: ${totalDeudaBs.toStringAsFixed(2)}
• Ubicación GPS: ${cliente.ubicacionGps != null && cliente.ubicacionGps!.isNotEmpty ? "SÍ" : "NO"}
• comportamiento != null: ${comportamiento != null ? "SÍ" : "NO"}
''',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                // ✅ TARJETA DE SCORING
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [categoriaColor.withOpacity(0.1), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: categoriaColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: categoriaColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          categoriaEmoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoria,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: categoriaColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Puntaje: ${puntaje.toInt()} / 100',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: puntaje / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                color: categoriaColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // INFORMACIÓN DEL CLIENTE
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                cliente.nombre,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // ✅ Íconos de ubicación: abrir + copiar (con spinner al resolver)
                            if (cliente.ubicacionGps != null && cliente.ubicacionGps!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: _resolviendoUbicacion
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.location_on, color: Color(0xFF1E40AF), size: 28),
                                    onPressed: _resolviendoUbicacion
                                        ? null
                                        : () => _abrirUbicacion(cliente.ubicacionGps!),
                                    tooltip: 'Ver ubicación en Google Maps',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.grey, size: 22),
                                    onPressed: _resolviendoUbicacion
                                        ? null
                                        : () => _copiarUbicacion(cliente.ubicacionGps!),
                                    tooltip: 'Copiar ubicación',
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Cédula/RIF', cliente.cedula),
                        _buildInfoRow('Teléfono', cliente.telefono),
                        _buildInfoRow('Email', cliente.email),
                        _buildInfoRow('Dirección', cliente.direccion),
                        // ✅ NUEVO: fila de Ubicación con el enlace visible y clickeable
                        if (cliente.ubicacionGps != null && cliente.ubicacionGps!.isNotEmpty)
                          _buildInfoRowUbicacion(cliente.ubicacionGps!),
                        _buildInfoRow('Vendedor', cliente.vendedorNombre ?? 'Sin asignar (público)'),
                        _buildInfoRow('Total compras', '${cliente.totalCompras}'),
                        _buildInfoRow('Total gastado', '\$${cliente.totalGastado.toStringAsFixed(2)}'),
                        _buildInfoRow(
                          'Estado',
                          cliente.activo == 1 ? 'Activo' : 'Inactivo',
                          color: cliente.activo == 1 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DEUDA TOTAL
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: totalDeudaUsd > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: totalDeudaUsd > 0 ? Colors.red.shade300 : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Deuda total:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${totalDeudaUsd.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: totalDeudaUsd > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            'Bs ${totalDeudaBs.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // FACTURAS PENDIENTES
                const Text(
                  'Facturas pendientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (facturasPendientes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay facturas pendientes',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...{
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: $facturaTotal facturas',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Página $facturaPage de $facturaPages',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ...facturasPendientes.map((factura) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(factura['numero_factura'] ?? 'Factura #${factura['id']}'),
                      subtitle: Text('Fecha: ${factura['fecha'] ?? '--'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${(factura['saldo_pendiente'] ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              Text(
                                'Bs ${factura['deuda_bs']?.toStringAsFixed(2) ?? '0.00'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.share, color: Color(0xFF1E40AF)),
                            onPressed: () => _compartirFactura(factura['numero_factura'] ?? ''),
                            tooltip: 'Compartir factura',
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                  if (facturaPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: facturaPage > 1
                              ? () {
                                  provider.cargarMasFacturas(widget.clienteId);
                                }
                              : null,
                        ),
                        Text(
                          'Página $facturaPage de $facturaPages',
                          style: const TextStyle(fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: facturaPage < facturaPages
                              ? () {
                                  provider.cargarMasFacturas(widget.clienteId);
                                }
                              : null,
                        ),
                      ],
                    ),
                },
                const SizedBox(height: 16),

                // HISTORIAL DE COMPRAS
                const Text(
                  'Historial de compras',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (historial.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay compras registradas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...{
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: $historialTotal compras',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Página $historialPage de $historialPages',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ...historial.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      title: Text('Compra #${item['venta_id'] ?? '--'}'),
                      subtitle: Text('Fecha: ${item['fecha'] ?? '--'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${(item['total'] ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (item['numero_factura'] != null && item['numero_factura'] != '')
                            IconButton(
                              icon: const Icon(Icons.share, color: Color(0xFF1E40AF)),
                              onPressed: () => _compartirFactura(item['numero_factura']),
                              tooltip: 'Compartir factura',
                            ),
                        ],
                      ),
                    ),
                  )).toList(),
                  if (historialPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: historialPage > 1
                              ? () {
                                  provider.cargarMasHistorial(widget.clienteId);
                                }
                              : null,
                        ),
                        Text(
                          'Página $historialPage de $historialPages',
                          style: const TextStyle(fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: historialPage < historialPages
                              ? () {
                                  provider.cargarMasHistorial(widget.clienteId);
                                }
                              : null,
                        ),
                      ],
                    ),
                },
              ],
            ),
          ),
          if (_isDownloading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Generando PDF...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '--',
              style: TextStyle(color: color ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ NUEVO: Fila de ubicación con enlace visible, clickeable, con spinner y botón de copiar
  // ============================================================
  Widget _buildInfoRowUbicacion(String ubicacion) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 120,
            child: Text(
              'Ubicación:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _resolviendoUbicacion ? null : () => _abrirUbicacion(ubicacion),
              child: Text(
                ubicacion,
                style: const TextStyle(
                  color: Color(0xFF1E40AF),
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (_resolviendoUbicacion)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              onPressed: () => _copiarUbicacion(ubicacion),
              tooltip: 'Copiar ubicación',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}