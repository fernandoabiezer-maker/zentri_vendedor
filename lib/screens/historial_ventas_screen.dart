import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/venta_provider.dart';
import 'package:zentri_vendedor/models/venta.dart';
import 'package:zentri_vendedor/services/pdf_service.dart';

class HistorialVentasScreen extends StatefulWidget {
  const HistorialVentasScreen({super.key});

  @override
  State<HistorialVentasScreen> createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // forceRefresh: true → siempre trae datos frescos del server al entrar.
      // Sin esto, si hay datos en memoria no recarga y ves info vieja.
      context.read<VentaProvider>().cargarTodo(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 Construyendo HistorialVentasScreen (TabBar en cuerpo)');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<VentaProvider>().cargarTodo(forceRefresh: true);
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
                Tab(text: 'MIS VENTAS', icon: Icon(Icons.person_pin)),
                Tab(text: 'VENTAS GENERALES', icon: Icon(Icons.storefront)),
              ],
            ),
          ),
          // ============================================================
          // BARRA DE BÚSQUEDA
          // ============================================================
          _buildBarraBusqueda(),
          // ============================================================
          // TABBAR VIEW
          // ============================================================
          Expanded(
            child: Consumer<VentaProvider>(
              builder: (context, provider, child) {
                if (provider.cargando && provider.misVentas.isEmpty && provider.ventasGenerales.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLista(
                      ventas: provider.misVentas,
                      total: provider.misVentasTotal,
                      pagina: provider.misVentasPagina,
                      totalPaginas: provider.misVentasTotalPaginas,
                      onPageChange: (p) => provider.irPaginaMisVentas(p),
                      esMisVentas: true,
                    ),
                    _buildLista(
                      ventas: provider.ventasGenerales,
                      total: provider.ventasGeneralesTotal,
                      pagina: provider.ventasGeneralesPagina,
                      totalPaginas: provider.ventasGeneralesTotalPaginas,
                      onPageChange: (p) => provider.irPaginaVentasGenerales(p),
                      esMisVentas: false,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraBusqueda() {
    final provider = context.watch<VentaProvider>();
    final searchController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por factura o cliente...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    searchController.clear();
                    provider.limpiarBusqueda();
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
          provider.buscar(value);
        },
      ),
    );
  }

  Widget _buildLista({
    required List<Venta> ventas,
    required int total,
    required int pagina,
    required int totalPaginas,
    required Function(int) onPageChange,
    required bool esMisVentas,
  }) {
    if (ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              esMisVentas ? Icons.receipt_long : Icons.store_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              esMisVentas
                  ? 'No has realizado ventas registradas.'
                  : 'No hay ventas generales para mostrar.',
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
                'Total: $total ventas',
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
            itemCount: ventas.length,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemBuilder: (context, index) {
              final venta = ventas[index];
              return _buildVentaCard(venta);
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

  Widget _buildVentaCard(Venta venta) {
    final estado = venta.isAnulada
        ? '🚫 Anulada'
        : venta.isCredito && venta.saldoPendiente > 0
            ? '⚠️ Pendiente'
            : '✅ Pagada';
    final colorEstado = venta.isAnulada
        ? Colors.red
        : venta.isCredito && venta.saldoPendiente > 0
            ? Colors.orange
            : Colors.green;

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
                    venta.numeroFactura,
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
                    venta.clienteNombre,
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
                      venta.fecha,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  'Atendido por: ${venta.vendedorNombre}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
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
                      'Total: Bs ${venta.totalBs.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '(\$${venta.totalUsd.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (venta.isCredito && venta.saldoPendiente > 0)
                      Text(
                        'Saldo: \$${venta.saldoPendiente.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    PdfService.descargarYCompartirFactura(context, venta.numeroFactura);
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Compartir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf0872d),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}