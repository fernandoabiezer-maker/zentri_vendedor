import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/carrito_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/providers/configuracion_provider.dart';
import 'package:zentri_vendedor/screens/checkout_screen.dart';
import 'package:zentri_vendedor/screens/cotizacion_form_screen.dart';
import 'package:zentri_vendedor/models/item_carrito.dart';
import 'package:zentri_vendedor/models/item_cotizacion.dart';

const double kCantidadMinima = 0.001;

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  double _descuentoPorcentaje = 0.0;
  double _descuentoMontoFijo = 0.0;
  String _tipoDescuento = 'ninguno';

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();
    final tasas = context.watch<TasasProvider>();
    final config = context.watch<ConfiguracionProvider>();

    final colorPrimario = config.colorPrimario;
    final color = Color(int.parse('0xFF${colorPrimario.replaceAll('#', '')}'));

    double totalUsd = carrito.totalUsd;
    double descuentoAplicado = 0.0;

    if (_tipoDescuento == 'porcentaje' && _descuentoPorcentaje > 0) {
      descuentoAplicado = totalUsd * (_descuentoPorcentaje / 100);
    } else if (_tipoDescuento == 'monto' && _descuentoMontoFijo > 0) {
      descuentoAplicado = _descuentoMontoFijo;
    }

    final totalConDescuento = totalUsd - descuentoAplicado;
    final totalBs = totalConDescuento * tasas.tasaParalelo;
    final totalEqBcv = totalConDescuento * tasas.tasaParalelo / (tasas.tasaBCV > 0 ? tasas.tasaBCV : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Compras'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              if (carrito.items.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Vaciar carrito'),
                    content: const Text('¿Seguro que quieres eliminar todos los productos?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          carrito.vaciarCarrito();
                          _resetearDescuentos();
                          Navigator.pop(context);
                        },
                        child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: carrito.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Tu carrito está vacío',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Agrega productos desde el catálogo',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: carrito.items.length,
                    itemBuilder: (context, index) {
                      final item = carrito.items[index];
                      return _CarritoItemWidget(
                        key: ValueKey(item.productoId),
                        item: item,
                        color: color,
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _mostrarModalDescuento(context),
                              icon: const Icon(Icons.local_offer_outlined, size: 18),
                              label: const Text('Aplicar descuento'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: color),
                                foregroundColor: color,
                              ),
                            ),
                          ),
                          if (_tipoDescuento != 'ninguno')
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: _resetearDescuentos,
                              tooltip: 'Quitar descuento',
                            ),
                        ],
                      ),
                      if (_tipoDescuento != 'ninguno') ...[
                        const SizedBox(height: 4),
                        Text(
                          _tipoDescuento == 'porcentaje'
                              ? 'Descuento: ${_descuentoPorcentaje.toStringAsFixed(1)}% (- \$${descuentoAplicado.toStringAsFixed(2)})'
                              : 'Descuento: - \$${_descuentoMontoFijo.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total USD:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${totalConDescuento.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Bs (Paralelo):',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '${totalBs.toStringAsFixed(2)} Bs',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Eq BCV:',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '${totalEqBcv.toStringAsFixed(2)} Eq BCV',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'FINALIZAR VENTA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final items = carrito.items.map((item) => ItemCotizacion(
                              id: item.productoId,
                              nombre: item.nombre,
                              codigo: item.codigo,
                              cantidad: item.cantidad,
                              precioUnitario: item.precio,
                              imagen: item.imagen,
                            )).toList();

                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CotizacionFormScreen(
                                  itemsIniciales: items,
                                ),
                              ),
                            );

                            if (result == true) {
                              carrito.vaciarCarrito();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Cotización guardada, carrito vaciado'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.save_alt),
                          label: const Text(
                            'Guardar como Cotización',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color, width: 2),
                            foregroundColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _mostrarModalDescuento(BuildContext context) {
    String tipo = _tipoDescuento;
    double porcentaje = _descuentoPorcentaje;
    double montoFijo = _descuentoMontoFijo;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Aplicar descuento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Ninguno'),
                        value: 'ninguno',
                        groupValue: tipo,
                        onChanged: (value) {
                          setStateDialog(() {
                            tipo = value!;
                            porcentaje = 0;
                            montoFijo = 0;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Porcentaje'),
                        value: 'porcentaje',
                        groupValue: tipo,
                        onChanged: (value) {
                          setStateDialog(() {
                            tipo = value!;
                            montoFijo = 0;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Monto fijo'),
                        value: 'monto',
                        groupValue: tipo,
                        onChanged: (value) {
                          setStateDialog(() {
                            tipo = value!;
                            porcentaje = 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (tipo == 'porcentaje')
                  TextFormField(
                    initialValue: porcentaje > 0 ? porcentaje.toString() : '',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Porcentaje (%)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setStateDialog(() => porcentaje = parsed);
                      }
                    },
                  ),
                if (tipo == 'monto')
                  TextFormField(
                    initialValue: montoFijo > 0 ? montoFijo.toString() : '',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto fijo (USD)',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setStateDialog(() => montoFijo = parsed);
                      }
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tipoDescuento = tipo;
                    _descuentoPorcentaje = porcentaje;
                    _descuentoMontoFijo = montoFijo;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _resetearDescuentos() {
    setState(() {
      _tipoDescuento = 'ninguno';
      _descuentoPorcentaje = 0.0;
      _descuentoMontoFijo = 0.0;
    });
  }
}

// ============================================================
// WIDGET PARA CADA ITEM DEL CARRITO
// ============================================================
class _CarritoItemWidget extends StatefulWidget {
  final ItemCarrito item;
  final Color color;

  const _CarritoItemWidget({
    super.key,
    required this.item,
    required this.color,
  });

  @override
  State<_CarritoItemWidget> createState() => _CarritoItemWidgetState();
}

class _CarritoItemWidgetState extends State<_CarritoItemWidget> {
  late TextEditingController _cantidadController;

  @override
  void initState() {
    super.initState();
    _cantidadController = TextEditingController(
      text: formatCantidad(widget.item.cantidad),
    );
    _cantidadController.addListener(_onCantidadChanged);
  }

  @override
  void didUpdateWidget(_CarritoItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.cantidad != widget.item.cantidad) {
      final currentText = _cantidadController.text.replaceAll(',', '.');
      final currentValue = double.tryParse(currentText);
      if (currentValue != widget.item.cantidad) {
        _cantidadController.text = formatCantidad(widget.item.cantidad);
      }
    }
  }

  @override
  void dispose() {
    _cantidadController.removeListener(_onCantidadChanged);
    _cantidadController.dispose();
    super.dispose();
  }

  void _onCantidadChanged() {
    final text = _cantidadController.text.replaceAll(',', '.');
    final parsed = double.tryParse(text);
    if (parsed != null && parsed >= kCantidadMinima && parsed != widget.item.cantidad) {
      final carrito = context.read<CarritoProvider>();
      carrito.actualizarCantidad(widget.item.productoId, parsed);
    }
  }

  void _actualizarCantidad(double nuevaCantidad) {
    if (nuevaCantidad < kCantidadMinima) return;
    final carrito = context.read<CarritoProvider>();
    carrito.actualizarCantidad(widget.item.productoId, nuevaCantidad);
  }

  @override
  Widget build(BuildContext context) {
    final tasas = context.watch<TasasProvider>();
    final item = widget.item;

    final subtotalUsd = item.subtotal;
    final subtotalBs = subtotalUsd * tasas.tasaParalelo;
    final subtotalEqBcv = subtotalUsd * tasas.tasaParalelo / (tasas.tasaBCV > 0 ? tasas.tasaBCV : 1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: item.imagen != null && item.imagen!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item.imagen!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.grey),
                    ),
                  )
                : const Icon(Icons.image, size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      onPressed: () {
                        final nueva = (item.cantidad - 1.0).clamp(kCantidadMinima, double.infinity);
                        _actualizarCantidad(nueva);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        controller: _cantidadController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      onPressed: () {
                        _actualizarCantidad(item.cantidad + 1.0);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _mostrarBottomSheetEditarPrecio(context, item),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(40, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Editar',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\$${subtotalUsd.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '|',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${subtotalBs.toStringAsFixed(2)} Bs',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '|',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${subtotalEqBcv.toStringAsFixed(2)} Eq BCV',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () {
              final carrito = context.read<CarritoProvider>();
              carrito.eliminarProducto(item.productoId);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM SHEET EDITAR PRECIO (SIN TextEditingController — evita crash)
  // ============================================================
  void _mostrarBottomSheetEditarPrecio(BuildContext context, ItemCarrito item) {
    final carrito = context.read<CarritoProvider>();
    final tasas = context.read<TasasProvider>();

    String cantidadTexto = formatCantidad(item.cantidad);
    double precioUnitario = item.precio;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isDismissible: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final cantidad = double.tryParse(cantidadTexto.replaceAll(',', '.')) ?? 1.0;
            final subtotalUsd = cantidad * precioUnitario;
            final subtotalBs = subtotalUsd * tasas.tasaParalelo;
            final subtotalEqBcv = subtotalUsd * tasas.tasaParalelo / (tasas.tasaBCV > 0 ? tasas.tasaBCV : 1);

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.nombre,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 32),
                        onPressed: () {
                          final actual = double.tryParse(cantidadTexto.replaceAll(',', '.')) ?? 1.0;
                          final nueva = (actual - 1.0).clamp(kCantidadMinima, double.infinity);
                          setStateSheet(() {
                            cantidadTexto = formatCantidad(nueva);
                          });
                        },
                      ),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          key: const ValueKey('cantidad_sheet_field'),
                          initialValue: cantidadTexto,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (value) {
                            setStateSheet(() {
                              cantidadTexto = value;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 32),
                        onPressed: () {
                          final actual = double.tryParse(cantidadTexto.replaceAll(',', '.')) ?? 1.0;
                          setStateSheet(() {
                            cantidadTexto = formatCantidad(actual + 1.0);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Precio unitario:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: precioUnitario.toStringAsFixed(2),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            prefixText: '\$ ',
                          ),
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              setStateSheet(() => precioUnitario = parsed);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal USD:'),
                            Text(
                              '\$${subtotalUsd.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bs (Paralelo):'),
                            Text('${subtotalBs.toStringAsFixed(2)} Bs'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Eq BCV:'),
                            Text('${subtotalEqBcv.toStringAsFixed(2)} Eq BCV'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final cant = double.tryParse(cantidadTexto.replaceAll(',', '.')) ?? 1.0;
                            carrito.eliminarProducto(item.productoId);
                            carrito.agregarProducto(
                              productoId: item.productoId,
                              nombre: item.nombre,
                              codigo: item.codigo,
                              precio: precioUnitario,
                              imagen: item.imagen,
                              cantidad: cant,
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.of(sheetContext).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Producto actualizado'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Actualizar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}