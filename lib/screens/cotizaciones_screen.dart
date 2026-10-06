import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/cotizacion_provider.dart';
import 'package:zentri_vendedor/providers/auth_provider.dart';
import 'package:zentri_vendedor/models/cotizacion.dart';
import 'package:zentri_vendedor/screens/cotizacion_form_screen.dart';
import 'package:zentri_vendedor/screens/cotizacion_detail_screen.dart';
import 'package:zentri_vendedor/services/pdf_service.dart';

class CotizacionesScreen extends StatefulWidget {
  const CotizacionesScreen({super.key});

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CotizacionProvider>().cargarCotizaciones();
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
    print('🔍 Construyendo CotizacionesScreen (TabBar en cuerpo)');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizaciones'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CotizacionProvider>().cargarCotizaciones();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ============================================================
          // TABBAR (visible, con fondo)
          // ============================================================
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFf0872d),
              labelColor: const Color(0xFF1e293b),
              unselectedLabelColor: Colors.grey.shade600,
              tabs: const [
                Tab(text: 'MIS COTIZACIONES', icon: Icon(Icons.person_pin)),
                Tab(text: 'TODAS', icon: Icon(Icons.storefront)),
              ],
            ),
          ),
          // ============================================================
          // BARRA DE BÚSQUEDA (opcional, la dejamos igual que ventas)
          // ============================================================
          _buildBarraBusqueda(),
          // ============================================================
          // TABBAR VIEW
          // ============================================================
          Expanded(
            child: Consumer<CotizacionProvider>(
              builder: (context, provider, child) {
                final authProvider = context.watch<AuthProvider>();
                final currentUserId = authProvider.usuarioId;

                final misCotizaciones = provider.cotizaciones
                    .where((c) => c.vendedorId == currentUserId)
                    .toList();
                final todasCotizaciones = provider.cotizaciones;

                if (provider.cargando && provider.cotizaciones.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLista(
                      cotizaciones: misCotizaciones,
                      total: misCotizaciones.length,
                      pagina: provider.pagina,
                      totalPaginas: provider.totalPaginas,
                      onPageChange: (p) => provider.irPagina(p),
                      esMisCotizaciones: true,
                    ),
                    _buildLista(
                      cotizaciones: todasCotizaciones,
                      total: todasCotizaciones.length,
                      pagina: provider.pagina,
                      totalPaginas: provider.totalPaginas,
                      onPageChange: (p) => provider.irPagina(p),
                      esMisCotizaciones: false,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CotizacionFormScreen(),
            ),
          ).then((_) => context.read<CotizacionProvider>().cargarCotizaciones());
        },
        backgroundColor: const Color(0xFFf0872d),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Nueva cotización',
      ),
    );
  }

  // ============================================================
  // BARRA DE BÚSQUEDA (idéntica a ventas)
  // ============================================================
  Widget _buildBarraBusqueda() {
    final provider = context.watch<CotizacionProvider>();
    final searchController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por cliente o ID...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    searchController.clear();
                    provider.cargarCotizaciones(); // Reinicia la lista
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (value) {
          // Filtro local simple (opcional)
          // Si quieres filtro real, implementa en el provider
        },
      ),
    );
  }

  // ============================================================
  // LISTA DE COTIZACIONES (mismo estilo que ventas)
  // ============================================================
  Widget _buildLista({
    required List<Cotizacion> cotizaciones,
    required int total,
    required int pagina,
    required int totalPaginas,
    required Function(int) onPageChange,
    required bool esMisCotizaciones,
  }) {
    if (cotizaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esMisCotizaciones ? Icons.receipt_long : Icons.store_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              esMisCotizaciones
                  ? 'No has creado cotizaciones.'
                  : 'No hay cotizaciones para mostrar.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $total cotizaciones',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Página $pagina de $totalPaginas',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: cotizaciones.length,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemBuilder: (context, index) {
              final cotizacion = cotizaciones[index];
              return _buildCotizacionCard(cotizacion);
            },
          ),
        ),
        if (totalPaginas > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: pagina > 1 ? () => onPageChange(pagina - 1) : null,
                ),
                Text(
                  'Página $pagina de $totalPaginas',
                  style: const TextStyle(fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: pagina < totalPaginas ? () => onPageChange(pagina + 1) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CARD DE COTIZACIÓN (idéntico estilo a ventas)
  // ============================================================
  Widget _buildCotizacionCard(Cotizacion cotizacion) {
    final estado = cotizacion.isConvertida ? '✅ Convertida' : '⏳ Pendiente';
    final colorEstado = cotizacion.isConvertida ? Colors.green : Colors.orange;

    return Card(
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
                Expanded(
                  child: Text(
                    'Cotización #${cotizacion.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1e293b),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorEstado,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cotizacion.cliente,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      cotizacion.fecha,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  'Vendedor: ${cotizacion.vendedorNombre ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: \$${cotizacion.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${cotizacion.items.length} productos',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Botón: Ver detalle
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CotizacionDetailScreen(
                              cotizacionId: cotizacion.id,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Ver detalle',
                    ),
                    // Botón: Compartir PDF
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      onPressed: () {
                        PdfService.descargarYCompartirCotizacion(
                          context,
                          cotizacion.id,
                        );
                      },
                      tooltip: 'Compartir PDF',
                    ),
                    // Botón: Editar (solo pendientes)
                    if (!cotizacion.isConvertida)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CotizacionFormScreen(
                                cotizacionId: cotizacion.id,
                              ),
                            ),
                          ).then((_) =>
                              context.read<CotizacionProvider>().cargarCotizaciones());
                        },
                        tooltip: 'Editar cotización',
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIÁLOGO DE CONVERSIÓN (con todos los métodos de pago, incluyendo Bio Pago)
  // ============================================================
  void _mostrarDialogConvertir(BuildContext context, Cotizacion cotizacion) {
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
                DropdownMenuItem(value: 'bio_pago', child: Text('Bio Pago')),  // NUEVO
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
}