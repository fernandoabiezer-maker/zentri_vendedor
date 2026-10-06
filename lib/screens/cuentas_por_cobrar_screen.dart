import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/cuentas_por_cobrar_provider.dart';
import 'package:zentri_vendedor/providers/auth_provider.dart';
import 'package:zentri_vendedor/models/cliente_deuda.dart';
import 'package:zentri_vendedor/screens/cuentas_por_cobrar_detail_screen.dart';

class CuentasPorCobrarScreen extends StatefulWidget {
  const CuentasPorCobrarScreen({super.key});

  @override
  State<CuentasPorCobrarScreen> createState() => _CuentasPorCobrarScreenState();
}

class _CuentasPorCobrarScreenState extends State<CuentasPorCobrarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _esAdmin = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final rol = authProvider.rol ?? '';
    _esAdmin = rol.toLowerCase() == 'admin' || rol.toLowerCase() == 'gerente';

    _tabController = TabController(
      length: _esAdmin ? 2 : 1,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CuentasPorCobrarProvider>();
      // forceRefresh: true → SIEMPRE trae datos frescos del server al entrar.
      // Sin esto, si ya hay datos en memoria, no recarga y ves info vieja
      // hasta que tocas el botón de refresh manual.
      provider.cargarMisDeudores(forceRefresh: true);
      if (_esAdmin) {
        provider.cargarTodosDeudores(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CuentasPorCobrarProvider>().recargarTodo();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFf0872d),
              labelColor: const Color(0xFF1e293b),
              unselectedLabelColor: Colors.grey.shade600,
              tabs: _esAdmin
                  ? const [
                      Tab(text: 'FACTURAS POR COBRAR', icon: Icon(Icons.person_pin)),
                      Tab(text: 'TODAS LAS FACTURAS PENDIENTES', icon: Icon(Icons.storefront)),
                    ]
                  : const [
                      Tab(text: 'FACTURAS POR COBRAR', icon: Icon(Icons.person_pin)),
                    ],
            ),
          ),
          _buildBarraBusqueda(),
          Expanded(
            child: Consumer<CuentasPorCobrarProvider>(
              builder: (context, provider, child) {
                if (provider.cargando &&
                    provider.misDeudores.isEmpty &&
                    provider.todosDeudores.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return TabBarView(
                  controller: _tabController,
                  children: _esAdmin
                      ? [
                          _buildLista(
                            deudores: provider.misDeudores,
                            total: provider.totalMisDeudores,
                            pagina: provider.paginaMisDeudores,
                            totalPaginas: provider.totalPaginasMisDeudores,
                            onPageChange: (p) => provider.irPaginaMisDeudores(p),
                            esMisDeudores: true,
                            cargando: provider.cargandoMis,
                          ),
                          _buildLista(
                            deudores: provider.todosDeudores,
                            total: provider.totalTodosDeudores,
                            pagina: provider.paginaTodosDeudores,
                            totalPaginas: provider.totalPaginasTodosDeudores,
                            onPageChange: (p) => provider.irPaginaTodosDeudores(p),
                            esMisDeudores: false,
                            cargando: provider.cargandoTodos,
                          ),
                        ]
                      : [
                          _buildLista(
                            deudores: provider.misDeudores,
                            total: provider.totalMisDeudores,
                            pagina: provider.paginaMisDeudores,
                            totalPaginas: provider.totalPaginasMisDeudores,
                            onPageChange: (p) => provider.irPaginaMisDeudores(p),
                            esMisDeudores: true,
                            cargando: provider.cargandoMis,
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por cliente...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    context.read<CuentasPorCobrarProvider>().limpiarBusqueda();
                    setState(() {});
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
          context.read<CuentasPorCobrarProvider>().buscar(value);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildLista({
    required List<ClienteDeuda> deudores,
    required int total,
    required int pagina,
    required int totalPaginas,
    required Function(int) onPageChange,
    required bool esMisDeudores,
    required bool cargando,
  }) {
    if (cargando && deudores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (deudores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.money_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              esMisDeudores
                  ? 'No tienes facturas pendientes.'
                  : 'No hay facturas pendientes.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
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
                'Total: $total deudores',
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
            itemCount: deudores.length,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemBuilder: (context, index) {
              final deudor = deudores[index];
              return _buildDeudorCard(deudor);
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

  Widget _buildDeudorCard(ClienteDeuda deudor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CuentasPorCobrarDetailScreen(
                clienteId: deudor.id,
                clienteNombre: deudor.nombre,
              ),
            ),
          );
          // Al volver del detalle, recargar la lista para reflejar abonos.
          // forceRefresh: true para que NO use el caché en memoria y traiga
          // la deuda actualizada del servidor.
          if (mounted) {
            final provider = context.read<CuentasPorCobrarProvider>();
            provider.cargarMisDeudores(forceRefresh: true);
            if (_esAdmin) {
              provider.cargarTodosDeudores(forceRefresh: true);
            }
          }
        },
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
                      deudor.nombre,
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
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${deudor.facturasPendientes} facturas',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (deudor.cedula != null && deudor.cedula!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      deudor.cedula!,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Deuda: \$${deudor.deudaUsd.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (deudor.ultimaFacturaFecha != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          deudor.ultimaFacturaFecha!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Deuda en Bs: Bs ${deudor.deudaBs.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}