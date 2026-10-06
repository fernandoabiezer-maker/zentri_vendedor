import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/screens/cliente_form_screen.dart';
import 'package:zentri_vendedor/screens/cliente_detail_screen.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _esBusquedaActiva = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ClienteProvider>();
      if (provider.clientes.isEmpty) {
        provider.cargarClientes(forceRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClienteProvider>();
    final cargando = provider.cargando;
    final total = provider.total;
    final pagina = provider.pagina;
    final totalPaginas = provider.totalPaginas;

    List<Cliente> clientesMostrar;
    if (_esBusquedaActiva && _searchController.text.isNotEmpty) {
      clientesMostrar = provider.filtrarClientesLocal(_searchController.text);
    } else {
      clientesMostrar = provider.clientes;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.cargarClientes(forceRefresh: true),
            tooltip: 'Sincronizar con servidor',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClienteFormScreen(),
                ),
              ).then((_) => provider.cargarClientes(forceRefresh: true));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o cédula...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _esBusquedaActiva
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _esBusquedaActiva = false;
                                provider.limpiarBusqueda();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        _esBusquedaActiva = true;
                        setState(() {});
                      } else if (value.isEmpty) {
                        _esBusquedaActiva = false;
                        provider.limpiarBusqueda();
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: cargando && provider.clientes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : clientesMostrar.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay clientes',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _esBusquedaActiva
                                  ? 'Intenta con otra búsqueda'
                                  : 'Agrega tu primer cliente o sincroniza',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: clientesMostrar.length,
                        itemBuilder: (context, index) {
                          final cliente = clientesMostrar[index];
                          return _buildClienteCard(cliente, context);
                        },
                      ),
          ),
          if (!_esBusquedaActiva && totalPaginas > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: pagina > 1 ? () => provider.irPagina(pagina - 1) : null,
                  ),
                  Text(
                    'Página $pagina de $totalPaginas',
                    style: const TextStyle(fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: pagina < totalPaginas ? () => provider.irPagina(pagina + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(Cliente cliente, BuildContext context) {
    // ✅ Colores según categoría para el badge
    Color getCategoriaColor(String categoria) {
      switch (categoria) {
        case 'Excelente': return Colors.green;
        case 'Bueno': return Colors.blue;
        case 'Regular': return Colors.orange;
        case 'Riesgoso': return Colors.red;
        default: return Colors.grey;
      }
    }

    String getCategoriaEmoji(String categoria) {
      switch (categoria) {
        case 'Excelente': return '⭐';
        case 'Bueno': return '👍';
        case 'Regular': return '👌';
        case 'Riesgoso': return '⚠️';
        default: return '🆕';
      }
    }

    final categoriaColor = getCategoriaColor(cliente.categoria ?? 'Nuevo');
    final puntaje = cliente.puntaje ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cliente.deudaUsd > 0 ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            cliente.deudaUsd > 0 ? Icons.warning : Icons.person,
            color: cliente.deudaUsd > 0 ? Colors.red : Colors.blue,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cliente.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            // ✅ Badge de puntaje
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: categoriaColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: categoriaColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getCategoriaEmoji(cliente.categoria ?? 'Nuevo'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${puntaje.toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: categoriaColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cédula: ${cliente.cedula}'),
            if (cliente.telefono.isNotEmpty)
              Text('Tel: ${cliente.telefono}'),
            if (cliente.vendedorNombre != null)
              Text('Vendedor: ${cliente.vendedorNombre}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (cliente.deudaUsd > 0)
              Text(
                'Deuda: \$${cliente.deudaUsd.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            // ✅ Mostrar categoría como texto
            if (cliente.categoria != null && cliente.categoria != 'Nuevo')
              Text(
                'Categoría: ${cliente.categoria}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: categoriaColor),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClienteDetailScreen(clienteId: cliente.id!),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClienteFormScreen(cliente: cliente),
                  ),
                ).then((_) => context.read<ClienteProvider>().cargarClientes(forceRefresh: true));
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClienteDetailScreen(clienteId: cliente.id!),
            ),
          );
        },
      ),
    );
  }
}