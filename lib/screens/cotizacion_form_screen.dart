import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/models/item_cotizacion.dart';
import 'package:zentri_vendedor/models/cotizacion.dart';
import 'package:zentri_vendedor/models/item_carrito.dart';
import 'package:zentri_vendedor/providers/cotizacion_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/providers/configuracion_provider.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/providers/producto_provider.dart';
import 'package:zentri_vendedor/providers/auth_provider.dart';
import 'package:zentri_vendedor/services/cliente_service.dart';
import 'package:zentri_vendedor/services/producto_service.dart';
import 'package:zentri_vendedor/models/producto.dart';
import 'package:zentri_vendedor/services/cotizacion_service.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class CotizacionFormScreen extends StatefulWidget {
  final int? cotizacionId;
  final List<ItemCotizacion>? itemsIniciales;

  const CotizacionFormScreen({
    super.key,
    this.cotizacionId,
    this.itemsIniciales,
  });

  @override
  State<CotizacionFormScreen> createState() => _CotizacionFormScreenState();
}

class _CotizacionFormScreenState extends State<CotizacionFormScreen> {
  final ClienteService _clienteService = ClienteService();
  final ProductoService _productoService = ProductoService();
  final CotizacionService _cotizacionService = CotizacionService();

  Cliente? _clienteSeleccionado;
  bool _buscandoClientes = false;
  final TextEditingController _searchClienteController = TextEditingController();
  List<Cliente> _clientesEncontrados = [];

  String _tipoVenta = 'mayor';
  double _margenGlobal = 20.0;
  String _moneda = 'USD';
  double _ivaPorcentaje = 16.0;
  String _metodoPago = 'Contado';

  List<ItemCotizacion> _items = [];
  bool _cargando = false;
  bool _editando = false;
  bool _cargandoItems = false;

  final TextEditingController _searchProductoController = TextEditingController();
  List<Producto> _productosEncontrados = [];
  bool _buscandoProductos = false;

  // FocusNode para el campo de cantidad (se crea uno por item)
  final Map<int, FocusNode> _cantidadFocusNodes = {};

  @override
  void initState() {
    super.initState();
    AppLogger.log('🔄 [CotizacionForm] initState()');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<ConfiguracionProvider>();
      final iva = config.ivaPorcentajeDefecto;
      setState(() {
        _ivaPorcentaje = iva;
      });
    });

    if (widget.itemsIniciales != null && widget.itemsIniciales!.isNotEmpty) {
      _items = widget.itemsIniciales!;
      AppLogger.log('📦 [CotizacionForm] Items iniciales cargados: ${_items.length}');
    }

    if (widget.cotizacionId != null) {
      _editando = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cargarCotizacionExistente();
      });
    }
  }

  @override
  void dispose() {
    // Liberar FocusNodes
    for (var node in _cantidadFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // CARGAR COTIZACIÓN EXISTENTE
  // ============================================================
  Future<void> _cargarCotizacionExistente() async {
    AppLogger.log('🔄 [CotizacionForm] _cargarCotizacionExistente()');
    setState(() => _cargandoItems = true);

    try {
      final cotizacion = await _cotizacionService.obtenerCotizacion(widget.cotizacionId!);
      if (cotizacion == null) {
        throw Exception('Cotización no encontrada');
      }

      AppLogger.log('📦 [CotizacionForm] Cotización cargada: id=${cotizacion.id}, cliente=${cotizacion.cliente}');

      List<ItemCotizacion> itemsList = [];

      if (cotizacion.items is List) {
        itemsList = cotizacion.items.cast<ItemCotizacion>();
      } else if (cotizacion.items is String) {
        try {
          final parsed = jsonDecode(cotizacion.items as String);
          if (parsed is List) {
            itemsList = parsed.map((item) => ItemCotizacion.fromJson(item)).toList();
          }
        } catch (e) {
          AppLogger.log('❌ [CotizacionForm] Error parseando items string: $e');
        }
      }

      final itemsValidados = itemsList.map((item) {
        final cant = (item.cantidad is num && item.cantidad.isFinite) ? item.cantidad : 0.0;
        final precio = (item.precioUnitario is num && item.precioUnitario.isFinite) ? item.precioUnitario : 0.0;
        return ItemCotizacion(
          id: item.id,
          nombre: item.nombre,
          codigo: item.codigo,
          cantidad: cant,
          precioUnitario: precio,
          precioBase: item.precioBase,
          imagen: item.imagen,
        );
      }).toList();

      setState(() {
        _clienteSeleccionado = Cliente(
          id: cotizacion.clienteId,
          nombre: cotizacion.cliente,
          cedula: cotizacion.clienteRif ?? '',
        );
        _tipoVenta = cotizacion.tipoVenta;
        _margenGlobal = cotizacion.margenGlobal;
        _moneda = cotizacion.moneda;
        _ivaPorcentaje = cotizacion.ivaPorcentaje;
        _items = itemsValidados;
        _cargandoItems = false;
      });

      AppLogger.log('✅ [CotizacionForm] Cotización cargada con ${_items.length} items');

    } catch (e) {
      AppLogger.log('❌ [CotizacionForm] Error al cargar cotización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _cargandoItems = false);
    }
  }

  // ============================================================
  // BUSCAR CLIENTES (CON FALLBACK OFFLINE)
  // ============================================================
  Future<void> _buscarClientes(String query) async {
    if (query.isEmpty) {
      setState(() {
        _clientesEncontrados = [];
        _buscandoClientes = false;
      });
      return;
    }

    setState(() => _buscandoClientes = true);
    AppLogger.log('🔍 [CotizacionForm] _buscarClientes("$query")');

    try {
      final resultados = await _clienteService.buscarClientes(query);
      if (resultados.isNotEmpty) {
        setState(() {
          _clientesEncontrados = resultados;
          _buscandoClientes = false;
        });
        AppLogger.log('✅ [CotizacionForm] Servidor devolvió ${resultados.length} clientes');
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionForm] Servidor falló para clientes: $e');
    }

    final clienteProvider = context.read<ClienteProvider>();
    if (clienteProvider.clientes.isEmpty) {
      AppLogger.log('📦 [CotizacionForm] Cargando clientes desde caché...');
      await clienteProvider.cargarClientes(forceRefresh: false);
    }
    final resultadosLocal = clienteProvider.buscarClientesLocal(query);
    setState(() {
      _clientesEncontrados = resultadosLocal;
      _buscandoClientes = false;
    });
    AppLogger.log('📦 [CotizacionForm] Resultados locales: ${resultadosLocal.length}');

    if (resultadosLocal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión, mostrando clientes locales'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================================
  // BUSCAR PRODUCTOS (CON FALLBACK OFFLINE)
  // ============================================================
  Future<void> _buscarProductos(String query) async {
    if (query.isEmpty) {
      setState(() {
        _productosEncontrados = [];
        _buscandoProductos = false;
      });
      return;
    }

    setState(() => _buscandoProductos = true);
    AppLogger.log('🔍 [CotizacionForm] _buscarProductos("$query")');

    try {
      final productos = await _productoService.getProductos();
      final filtrados = productos.where((p) =>
          p.nombre.toLowerCase().contains(query.toLowerCase()) ||
          p.codigo.toLowerCase().contains(query.toLowerCase())).toList();
      if (filtrados.isNotEmpty) {
        setState(() {
          _productosEncontrados = filtrados;
          _buscandoProductos = false;
        });
        AppLogger.log('✅ [CotizacionForm] Servidor devolvió ${filtrados.length} productos');
        return;
      }
    } catch (e) {
      AppLogger.log('⚠️ [CotizacionForm] Servidor falló para productos: $e');
    }

    final productoProvider = context.read<ProductoProvider>();
    if (productoProvider.productos.isEmpty) {
      AppLogger.log('📦 [CotizacionForm] Cargando productos desde caché...');
      await productoProvider.cargarProductos(forceRefresh: false);
    }
    final productosLocal = productoProvider.productos.where((p) =>
        p.nombre.toLowerCase().contains(query.toLowerCase()) ||
        p.codigo.toLowerCase().contains(query.toLowerCase())).toList();
    setState(() {
      _productosEncontrados = productosLocal;
      _buscandoProductos = false;
    });
    AppLogger.log('📦 [CotizacionForm] Productos locales: ${productosLocal.length}');

    if (productosLocal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión, mostrando productos locales'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================================
  // AGREGAR / QUITAR / ACTUALIZAR PRODUCTOS
  // ============================================================
  void _agregarProducto(Producto producto) {
    final existe = _items.any((item) => item.id == producto.id);
    if (existe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto ya está en la cotización'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _items.add(ItemCotizacion(
        id: producto.id,
        nombre: producto.nombre,
        codigo: producto.codigo,
        cantidad: 1.0,
        precioUnitario: producto.precio,
        precioBase: producto.precioBase,
        imagen: producto.imagen,
      ));
      AppLogger.log('📦 [CotizacionForm] Producto agregado: ${producto.nombre}, items: ${_items.length}');
    });

    _searchProductoController.clear();
    _productosEncontrados = [];
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Producto agregado a la cotización'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _quitarProducto(int id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
      // Eliminar FocusNode si existe
      _cantidadFocusNodes.remove(id);
      AppLogger.log('📦 [CotizacionForm] Producto removido, items: ${_items.length}');
    });
  }

  void _actualizarCantidad(int id, double nuevaCantidad) {
    if (nuevaCantidad < 0.001) return;
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      setState(() {
        _items[index] = _items[index].copyWith(cantidad: nuevaCantidad);
        AppLogger.log('📦 [CotizacionForm] Cantidad actualizada: ${_items[index].nombre} -> ${_items[index].cantidad}');
      });
    }
  }

  void _actualizarPrecio(int id, double nuevoPrecio) {
    if (nuevoPrecio < 0) return;
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      setState(() {
        _items[index] = _items[index].copyWith(precioUnitario: nuevoPrecio);
        AppLogger.log('📦 [CotizacionForm] Precio actualizado: ${_items[index].nombre} -> ${_items[index].precioUnitario}');
      });
    }
  }

  // ============================================================
  // TOTAL
  // ============================================================
  double get _total {
    if (_items.isEmpty) return 0.0;
    double total = 0.0;
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final cant = (item.cantidad is num && item.cantidad.isFinite) ? item.cantidad : 0.0;
      final precio = (item.precioUnitario is num && item.precioUnitario.isFinite) ? item.precioUnitario : 0.0;
      final subtotal = cant * precio;
      if (subtotal.isFinite) {
        total += subtotal;
      }
    }
    if (total.isNaN) return 0.0;
    return total;
  }

  // ============================================================
  // GUARDAR COTIZACIÓN (CON SOPORTE OFFLINE)
  // ============================================================
  Future<void> _guardar() async {
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _cargando = true);
    final provider = context.read<CotizacionProvider>();
    final tasas = context.read<TasasProvider>();
    final authProvider = context.read<AuthProvider>();
    final vendedorId = authProvider.usuarioId;

    final Map<String, dynamic> result;

    if (_editando && widget.cotizacionId != null) {
      result = await provider.actualizarCotizacion(
        id: widget.cotizacionId!,
        cliente: _clienteSeleccionado!.nombre,
        clienteRif: _clienteSeleccionado!.cedula,
        clienteId: _clienteSeleccionado!.id,
        tipoVenta: _tipoVenta,
        margenGlobal: _margenGlobal,
        moneda: _moneda,
        tasaBcv: tasas.tasaBCV,
        tasaParalelo: tasas.tasaParalelo,
        ivaPorcentaje: _ivaPorcentaje,
        metodoPago: _metodoPago,
        items: _items,
        vendedorId: vendedorId,
      );
    } else {
      result = await provider.crearCotizacion(
        cliente: _clienteSeleccionado!.nombre,
        clienteRif: _clienteSeleccionado!.cedula,
        clienteId: _clienteSeleccionado!.id,
        tipoVenta: _tipoVenta,
        margenGlobal: _margenGlobal,
        moneda: _moneda,
        tasaBcv: tasas.tasaBCV,
        tasaParalelo: tasas.tasaParalelo,
        ivaPorcentaje: _ivaPorcentaje,
        metodoPago: _metodoPago,
        items: _items,
        vendedorId: vendedorId,
      );
    }

    setState(() => _cargando = false);

    if (result['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cotización guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (result['offline'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 Cotización guardada localmente. Se sincronizará cuando haya internet.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${result['mensaje'] ?? 'Error al guardar'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // WIDGET ITEM CARD (CON CANTIDAD EDITABLE Y BOTONES FUNCIONALES)
  // ============================================================
  Widget _buildItemCard(ItemCotizacion item) {
    final subtotal = item.subtotal;
    final subtotalMostrar = subtotal.isNaN ? 0.0 : subtotal;
    final colorNaranja = const Color(0xFFf0872d);

    // Obtener o crear FocusNode para este item
    if (!_cantidadFocusNodes.containsKey(item.id)) {
      _cantidadFocusNodes[item.id] = FocusNode();
    }
    final focusNode = _cantidadFocusNodes[item.id]!;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: item.imagen != null && item.imagen!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imagen!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  : const Icon(Icons.image, color: Colors.grey),
            ),
            const SizedBox(width: 12),

            // Detalles (Expanded para ocupar el resto)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: Nombre + botón eliminar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _quitarProducto(item.id),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.delete_outline, size: 22, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cód: ${item.codigo}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  // Fila inferior: Controles (cantidad y precio) + Subtotal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Controles de cantidad y precio
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ============================================================
                            // SELECTOR DE CANTIDAD (ACEPTA DECIMALES)
                            // ============================================================
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _actualizarCantidad(
                                      item.id,
                                      (item.cantidad - 1.0).clamp(0.001, double.infinity),
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Icon(Icons.remove, size: 16),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      focusNode.requestFocus();
                                    },
                                    child: SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        focusNode: focusNode,
                                        initialValue: formatCantidad(item.cantidad),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                                        ],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Cant',
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blue, width: 2),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        ),
                                        onChanged: (value) {
                                          final parsed = double.tryParse(value.replaceAll(',', '.'));
                                          if (parsed != null && parsed >= 0.001) {
                                            _actualizarCantidad(item.id, parsed);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _actualizarCantidad(item.id, item.cantidad + 1.0),
                                    behavior: HitTestBehavior.opaque,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Icon(Icons.add, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Campo de precio
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: item.precioUnitario.toStringAsFixed(2),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  prefixText: '\$ ',
                                  prefixStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                onChanged: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null && parsed > 0) {
                                    _actualizarPrecio(item.id, parsed);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subtotal (derecha)
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Subtotal',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              '\$${subtotalMostrar.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: colorNaranja,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final tasas = context.watch<TasasProvider>();
    final config = context.watch<ConfiguracionProvider>();

    final colorPrimario = config.colorPrimario;
    final color = Color(int.parse('0xFF${colorPrimario.replaceAll('#', '')}'));

    double total = _total;
    if (total.isNaN) total = 0.0;
    final totalBs = total * tasas.tasaParalelo;
    final totalEqBcv = total * tasas.tasaParalelo / (tasas.tasaBCV > 0 ? tasas.tasaBCV : 1);

    AppLogger.log('🔍 [CotizacionForm] build() - total: $total, items: ${_items.length}');

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Cotización' : 'Nueva Cotización'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _cargandoItems
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ============================================================
                  // CLIENTE
                  // ============================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cliente',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_clienteSeleccionado != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _clienteSeleccionado!.nombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Cédula: ${_clienteSeleccionado!.cedula}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    setState(() => _clienteSeleccionado = null);
                                  },
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchClienteController,
                                    onChanged: _buscarClientes,
                                    decoration: const InputDecoration(
                                      hintText: 'Buscar cliente...',
                                      prefixIcon: Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  color: const Color(0xFFf0872d),
                                  onPressed: () {
                                    // TODO: crear cliente rápido
                                  },
                                ),
                              ],
                            ),
                            if (_buscandoClientes)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_clientesEncontrados.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _clientesEncontrados.length,
                                  itemBuilder: (context, index) {
                                    final cliente = _clientesEncontrados[index];
                                    return ListTile(
                                      title: Text(cliente.nombre),
                                      subtitle: Text('Cédula: ${cliente.cedula}'),
                                      onTap: () {
                                        setState(() {
                                          _clienteSeleccionado = cliente;
                                          _clientesEncontrados = [];
                                          _searchClienteController.clear();
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ============================================================
                  // CONFIGURACIÓN
                  // ============================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuración',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tipo Venta', style: TextStyle(fontSize: 12)),
                                    DropdownButton<String>(
                                      value: _tipoVenta,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'mayor', child: Text('Al Mayor')),
                                        DropdownMenuItem(value: 'detal', child: Text('Al Detal')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) setState(() => _tipoVenta = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Moneda', style: TextStyle(fontSize: 12)),
                                    DropdownButton<String>(
                                      value: _moneda,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                                        DropdownMenuItem(value: 'Bs', child: Text('Bolívares')),
                                        DropdownMenuItem(value: 'BCV', child: Text('Eq BCV')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) setState(() => _moneda = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Margen (%)', style: TextStyle(fontSize: 12)),
                                    TextFormField(
                                      initialValue: _margenGlobal.toString(),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final parsed = double.tryParse(value);
                                        if (parsed != null) setState(() => _margenGlobal = parsed);
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('IVA (%)', style: TextStyle(fontSize: 12)),
                                    TextFormField(
                                      initialValue: _ivaPorcentaje.toString(),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final parsed = double.tryParse(value);
                                        if (parsed != null && parsed >= 0) {
                                          setState(() => _ivaPorcentaje = parsed);
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        suffixText: '%',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ============================================================
                  // PRODUCTOS
                  // ============================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Productos',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_items.length} items',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchProductoController,
                                  onChanged: _buscarProductos,
                                  decoration: const InputDecoration(
                                    hintText: 'Buscar producto...',
                                    prefixIcon: Icon(Icons.search, size: 20),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final query = _searchProductoController.text;
                                  if (query.isNotEmpty) {
                                    _buscarProductos(query);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Buscar'),
                              ),
                            ],
                          ),
                          if (_buscandoProductos)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_productosEncontrados.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _productosEncontrados.length,
                                itemBuilder: (context, index) {
                                  final producto = _productosEncontrados[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(producto.nombre),
                                    subtitle: Text('Cód: ${producto.codigo} - \$${producto.precio.toStringAsFixed(2)}'),
                                    trailing: const Icon(Icons.add_circle, color: Colors.green),
                                    onTap: () => _agregarProducto(producto),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No hay productos agregados',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ..._items.map((item) => _buildItemCard(item)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ============================================================
                  // TOTALES
                  // ============================================================
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bs (Paralelo):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            Text('${totalBs.toStringAsFixed(2)} Bs', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Eq BCV:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            Text('${totalEqBcv.toStringAsFixed(2)} Eq BCV', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ============================================================
                  // BOTONES
                  // ============================================================
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cargando ? null : () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _guardar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFf0872d),
                            foregroundColor: Colors.white,
                          ),
                          child: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_editando ? 'Actualizar' : 'Guardar'),
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