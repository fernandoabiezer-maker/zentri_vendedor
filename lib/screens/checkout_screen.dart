import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/providers/carrito_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/providers/configuracion_provider.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/providers/venta_provider.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/services/cliente_service.dart';
import 'package:zentri_vendedor/services/venta_service.dart';
import 'package:zentri_vendedor/services/pdf_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Cliente? _clienteSeleccionado;
  String _tipoVenta = 'contado';
  String _metodoPago = '';
  String _referencia = '';
  int _diasCredito = 15;

  // ============================================================
  // ESTADO DE PAGO MIXTO
  // ============================================================
  final Map<String, TextEditingController> _mixtoControllers = {};
  String? _mixtoError;

  // ============================================================
  // ESTADO DE PLAN DE CUOTAS
  // ============================================================
  bool _planCuotasActivo = false;
  final TextEditingController _planMontoInicialController = TextEditingController();
  final TextEditingController _planNumeroCuotasController = TextEditingController(text: '3');
  final TextEditingController _planDiasEntreCuotasController = TextEditingController(text: '30');
  final TextEditingController _planObservacionesController = TextEditingController();
  DateTime _planFechaInicio = DateTime.now();
  String? _planCuotasError;
  // Si es true, el campo Inicial se interpreta en Bs y se
  // convierte a USD usando la tasa paralelo antes de enviarlo al server.
  bool _planInicialEnBs = false;

  final TextEditingController _searchController = TextEditingController();
  List<Cliente> _clientesEncontrados = [];
  bool _buscandoClientes = false;
  bool _mostrarBusquedaClientes = false;

  final ClienteService _clienteService = ClienteService();
  final VentaService _ventaService = VentaService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final List<Map<String, dynamic>> _metodosPago = [
    {'id': 'efectivo_bs', 'label': 'Efectivo (Bs)', 'icon': Icons.money},
    {'id': 'efectivo_usd', 'label': 'Efectivo (USD)', 'icon': Icons.money},
    {'id': 'transferencia_bs', 'label': 'Transferencia (Bs)', 'icon': Icons.account_balance},
    {'id': 'transferencia_usd', 'label': 'Transferencia (USD)', 'icon': Icons.account_balance},
    {'id': 'pago_movil_bs', 'label': 'Pago Móvil (Bs)', 'icon': Icons.phone_android},
    {'id': 'zelle', 'label': 'Zelle (USD)', 'icon': Icons.payment},
    {'id': 'tarjeta_bs', 'label': 'Tarjeta (Bs)', 'icon': Icons.credit_card},
    {'id': 'tarjeta_usd', 'label': 'Tarjeta (USD)', 'icon': Icons.credit_card},
    {'id': 'mixto', 'label': 'Mixto', 'icon': Icons.swap_horiz},
    {'id': 'bio_pago', 'label': 'Bio Pago', 'icon': Icons.payment},
  ];

  // Los 9 métodos válidos del backend para pago mixto.
  final List<Map<String, dynamic>> _metodosMixto = [
    {'id': 'efectivo_bs', 'label': 'Efectivo Bs', 'moneda': 'BS'},
    {'id': 'efectivo_usd', 'label': 'Efectivo USD', 'moneda': 'USD'},
    {'id': 'pago_movil_bs', 'label': 'Pago Móvil Bs', 'moneda': 'BS'},
    {'id': 'transferencia_bs', 'label': 'Transferencia Bs', 'moneda': 'BS'},
    {'id': 'transferencia_usd', 'label': 'Transferencia USD', 'moneda': 'USD'},
    {'id': 'zelle', 'label': 'Zelle USD', 'moneda': 'USD'},
    {'id': 'tarjeta_bs', 'label': 'Tarjeta Bs', 'moneda': 'BS'},
    {'id': 'tarjeta_usd', 'label': 'Tarjeta USD', 'moneda': 'USD'},
    {'id': 'bio_pago', 'label': 'Bio Pago Bs', 'moneda': 'BS'},
  ];

  @override
  void initState() {
    super.initState();
    // Inicializar un controller por cada método del pago mixto.
    for (final m in _metodosMixto) {
      _mixtoControllers[m['id']] = TextEditingController();
    }
    // Fecha por defecto del plan: hoy.
    _planFechaInicio = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clienteProvider = context.read<ClienteProvider>();
      if (clienteProvider.clientes.isEmpty) {
        clienteProvider.cargarClientes(forceRefresh: false);
      }

      final carrito = context.read<CarritoProvider>();
      if (carrito.clienteSeleccionado != null) {
        setState(() {
          _clienteSeleccionado = carrito.clienteSeleccionado;
          _validarClienteRiesgoso(carrito.clienteSeleccionado!);
        });
      }
      if (carrito.metodoPago != null && carrito.metodoPago!.isNotEmpty) {
        setState(() {
          _metodoPago = carrito.metodoPago!;
          _tipoVenta = carrito.tipoVenta ?? 'contado';
          _referencia = carrito.referencia ?? '';
          _diasCredito = carrito.diasCredito ?? 15;
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _mixtoControllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    _planMontoInicialController.dispose();
    _planNumeroCuotasController.dispose();
    _planDiasEntreCuotasController.dispose();
    _planObservacionesController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS DE PAGO MIXTO
  // ============================================================
  double _parseMonto(String v) {
    if (v.isEmpty) return 0.0;
    final limpio = v.replaceAll(',', '.');
    return double.tryParse(limpio) ?? 0.0;
  }

  double _sumaMixtoUsd(double tasaParalelo) {
    double suma = 0.0;
    for (final m in _metodosMixto) {
      final ctrl = _mixtoControllers[m['id']]!;
      final v = _parseMonto(ctrl.text);
      if (v <= 0) continue;
      if (m['moneda'] == 'BS') {
        if (tasaParalelo > 0) suma += v / tasaParalelo;
      } else {
        suma += v;
      }
    }
    return suma;
  }

  Map<String, double> _construirPagoMixtoDetalle(double tasaParalelo) {
    final detalle = <String, double>{};
    for (final m in _metodosMixto) {
      final ctrl = _mixtoControllers[m['id']]!;
      final v = _parseMonto(ctrl.text);
      if (v <= 0) continue;
      double usd;
      if (m['moneda'] == 'BS') {
        if (tasaParalelo <= 0) continue;
        usd = v / tasaParalelo;
      } else {
        usd = v;
      }
      detalle[m['id']] = double.parse(usd.toStringAsFixed(2));
    }
    return detalle;
  }

  void _limpiarMixto() {
    for (final c in _mixtoControllers.values) {
      c.clear();
    }
    setState(() => _mixtoError = null);
  }

  bool _puedeConfirmar(CarritoProvider carrito, double tasaParalelo) {
    if (_tipoVenta == 'credito') return true;
    if (_metodoPago.isEmpty) return false;
    if (_metodoPago == 'mixto') {
      final detalle = _construirPagoMixtoDetalle(tasaParalelo);
      if (detalle.isEmpty) return false;
      final suma = detalle.values.fold<double>(0.0, (a, b) => a + b);
      return (suma - carrito.totalUsd).abs() < 0.01;
    }
    return true;
  }

  // ============================================================
  // HELPERS DE PLAN DE CUOTAS
  // ============================================================
  void _resetPlanCuotas() {
    _planCuotasActivo = false;
    _planMontoInicialController.clear();
    _planNumeroCuotasController.text = '3';
    _planDiasEntreCuotasController.text = '30';
    _planObservacionesController.clear();
    _planFechaInicio = DateTime.now();
    _planCuotasError = null;
    _planInicialEnBs = false;
  }

  String _formatFechaYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  String _formatFechaDmy(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$m/$y';
  }

  Future<void> _seleccionarFechaInicioPlan() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _planFechaInicio,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('es', 'VE'),
      helpText: 'Fecha de inicio del plan',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null && mounted) {
      setState(() => _planFechaInicio = picked);
    }
  }

  // Devuelve un Map listo para mandar al backend, o null si no está activo / no válido.
  // Si hay error de validación, deja el mensaje en `_planCuotasError` y devuelve null.
  Map<String, dynamic>? _construirPlanCuotas(double totalVentaUsd) {
    if (!_planCuotasActivo) return null;

    // Leer el monto crudo tal como lo escribio el usuario.
    final montoCrudo = _parseMonto(_planMontoInicialController.text);

    // Si el usuario eligio Bs, convertir a USD con la tasa paralelo.
    final tasaParalelo = context.read<TasasProvider>().tasaParalelo;
    final double montoInicial;
    if (_planInicialEnBs) {
      if (tasaParalelo <= 0) {
        _planCuotasError = 'No hay tasa paralelo disponible para convertir Bs';
        return null;
      }
      montoInicial = montoCrudo / tasaParalelo;
    } else {
      montoInicial = montoCrudo;
    }

    final nCuotas = int.tryParse(_planNumeroCuotasController.text.trim()) ?? 0;
    final dias = int.tryParse(_planDiasEntreCuotasController.text.trim()) ?? 0;

    if (montoInicial < 0) {
      _planCuotasError = 'El monto inicial no puede ser negativo';
      return null;
    }
    if (montoInicial >= totalVentaUsd) {
      _planCuotasError = 'El monto inicial no puede ser igual o mayor al total de la venta';
      return null;
    }
    if (nCuotas < 1) {
      _planCuotasError = 'Debe haber al menos 1 cuota';
      return null;
    }
    if (dias < 1) {
      _planCuotasError = 'Los días entre cuotas deben ser al menos 1';
      return null;
    }

    _planCuotasError = null;
    return {
      'activo': true,
      'monto_inicial': double.parse(montoInicial.toStringAsFixed(2)),
      'numero_cuotas': nCuotas,
      'dias_entre_cuotas': dias,
      'fecha_inicio': _formatFechaYmd(_planFechaInicio),
      'observaciones': _planObservacionesController.text.trim(),
    };
  }

  // ============================================================
  // VALIDACIONES Y CREACIÓN DE CLIENTE
  // ============================================================
  void _validarClienteRiesgoso(Cliente cliente) {
    final categoria = cliente.categoria ?? 'Nuevo';
    if (categoria == 'Riesgoso' && _tipoVenta == 'credito') {
      setState(() {
        _tipoVenta = 'contado';
        _metodoPago = '';
        _referencia = '';
        _resetPlanCuotas();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Este cliente es "Riesgoso". Solo puede comprar al contado.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      });
    }
  }

  Future<void> _buscarClientes(String query) async {
    if (query.isEmpty) {
      setState(() {
        _clientesEncontrados = [];
        _buscandoClientes = false;
      });
      return;
    }

    setState(() => _buscandoClientes = true);

    final clienteProvider = context.read<ClienteProvider>();

    if (clienteProvider.clientes.isEmpty) {
      await clienteProvider.cargarClientes(forceRefresh: false);
    }

    final resultadosLocal = clienteProvider.buscarClientesLocal(query);

    setState(() {
      _clientesEncontrados = resultadosLocal;
      _buscandoClientes = false;
    });

    try {
      final resultados = await _clienteService.buscarClientes(query);
      if (resultados.isNotEmpty && mounted) {
        setState(() {
          _clientesEncontrados = resultados;
        });
      }
    } catch (e) {
      // Silencioso
    }

    if (resultadosLocal.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin clientes locales o sin conexión'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _mostrarDialogCrearCliente() async {
    final nombreController = TextEditingController();
    final cedulaController = TextEditingController();
    final telefonoController = TextEditingController();
    final emailController = TextEditingController();
    final direccionController = TextEditingController();
    bool cargando = false;

    final clienteCreado = await showDialog<Cliente>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nuevo Cliente'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaController,
                    decoration: const InputDecoration(
                      labelText: 'Cédula/RIF *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: direccionController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: cargando
                    ? null
                    : () async {
                        if (nombreController.text.isEmpty || cedulaController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nombre y Cédula son obligatorios'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setStateDialog(() => cargando = true);
                        try {
                          final nuevoCliente = await _clienteService.crearCliente(
                            nombre: nombreController.text.trim(),
                            cedula: cedulaController.text.trim(),
                            telefono: telefonoController.text.trim(),
                            email: emailController.text.trim(),
                            direccion: direccionController.text.trim(),
                          );
                          Navigator.pop(context, nuevoCliente);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                          setStateDialog(() => cargando = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf0872d),
                  foregroundColor: Colors.white,
                ),
                child: cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Crear Cliente'),
              ),
            ],
          );
        },
      ),
    );

    if (clienteCreado != null && mounted) {
      setState(() {
        _clienteSeleccionado = clienteCreado;
        _clientesEncontrados = [];
        _searchController.clear();
        _mostrarBusquedaClientes = false;
        _validarClienteRiesgoso(clienteCreado);
      });
    }
  }

  // ============================================================
  // FINALIZAR VENTA
  // ============================================================
  Future<void> _finalizarVenta() async {
    final carrito = context.read<CarritoProvider>();
    final syncProvider = context.read<SyncProvider>();
    final tasas = context.read<TasasProvider>();

    if (carrito.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Bloqueo de crédito si el cliente es riesgoso.
    if (_clienteSeleccionado != null) {
      final categoria = _clienteSeleccionado!.categoria ?? 'Nuevo';
      if (categoria == 'Riesgoso' && _tipoVenta == 'credito') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Este cliente es categoría "Riesgoso". Solo puede comprar al contado.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (_tipoVenta == 'contado' && _metodoPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un método de pago'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Validación de referencia solo para métodos electrónicos distintos de mixto.
    if (_tipoVenta == 'contado' && _metodoPago != 'mixto') {
      final metodoData = _metodosPago.firstWhere((m) => m['id'] == _metodoPago);
      final esElectronico = metodoData['id'].contains('transferencia') ||
          metodoData['id'].contains('pago_movil') ||
          metodoData['id'] == 'zelle' ||
          metodoData['id'] == 'bio_pago';
      if (esElectronico && _referencia.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingresa el número de referencia'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Validación y armado del pago mixto.
    Map<String, double>? pagoMixtoDetalle;
    if (_tipoVenta == 'contado' && _metodoPago == 'mixto') {
      final detalle = _construirPagoMixtoDetalle(tasas.tasaParalelo);
      if (detalle.isEmpty) {
        setState(() => _mixtoError = 'Ingresa al menos un monto en la distribución');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingresa al menos un monto en la distribución'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final suma = detalle.values.fold<double>(0.0, (a, b) => a + b);
      final total = carrito.totalUsd;
      if ((suma - total).abs() > 0.01) {
        final msg = 'La suma (\$${suma.toStringAsFixed(2)}) no cuadra con el total (\$${total.toStringAsFixed(2)})';
        setState(() => _mixtoError = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() => _mixtoError = null);
      pagoMixtoDetalle = detalle;
    }

    // Validación y armado del plan de cuotas.
    Map<String, dynamic>? planCuotas;
    if (_tipoVenta == 'credito' && _planCuotasActivo) {
      planCuotas = _construirPlanCuotas(carrito.totalUsd);
      if (planCuotas == null) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_planCuotasError ?? 'Revisa la configuración del plan de cuotas'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    String usuarioNombre = 'Vendedor';
    try {
      final nombre = await _secureStorage.read(key: 'usuario_nombre');
      if (nombre != null && nombre.isNotEmpty) {
        usuarioNombre = nombre;
      }
    } catch (e) {
      // Silencioso
    }

    // Capturamos el total ANTES de vaciar el carrito (para el diálogo de éxito).
    final totalVentaParaMostrar = carrito.totalUsd;

    final idLocal = 'LOCAL-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'id_local': idLocal,
      'items': carrito.items.map((item) => {
        'id': item.productoId,
        'nombre': item.nombre,
        'cantidad': item.cantidad,
        'precio_venta': item.precioParaVenta,
        'costo_actual': 0,
      }).toList(),
      'cliente_id': _clienteSeleccionado!.id!,
      'tipo_venta': _tipoVenta,
      'dias_credito': _tipoVenta == 'credito' ? _diasCredito : 0,
      'metodo_pago': _tipoVenta == 'credito' ? 'credito' : _metodoPago,
      'referencia': _referencia,
      'usuario_nombre': usuarioNombre,
    };
    if (pagoMixtoDetalle != null && pagoMixtoDetalle.isNotEmpty) {
      payload['pago_mixto_detalle'] = pagoMixtoDetalle;
    }
    if (planCuotas != null && planCuotas['activo'] == true) {
      payload['plan_cuotas'] = planCuotas;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Procesando venta...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _ventaService.finalizarVenta(
        items: carrito.items,
        clienteId: _clienteSeleccionado!.id!,
        tipoVenta: _tipoVenta,
        metodoPago: _tipoVenta == 'credito' ? 'credito' : _metodoPago,
        diasCredito: _tipoVenta == 'credito' ? _diasCredito : 0,
        referencia: _referencia,
        usuarioNombre: usuarioNombre,
        pagoMixtoDetalle: pagoMixtoDetalle,
        planCuotas: planCuotas,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['ok'] == true) {
        final factura = result['numero_factura'];
        final planResp = result['plan_cuotas'];
        carrito.vaciarCarrito();
        context.read<VentaProvider>().sincronizarTodo();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('✅ Venta exitosa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.check_circle, size: 60, color: Colors.green),
                ),
                const SizedBox(height: 16),
                Text(
                  'Factura: $factura',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${_clienteSeleccionado?.nombre ?? '--'}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Total: \$${totalVentaParaMostrar.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (planResp != null && planResp is Map) ...[
                  const Divider(height: 20),
                  const Text(
                    '📋 Plan de cuotas creado',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plan #${planResp['plan_id'] ?? '--'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (planResp['monto_financiado'] != null)
                    Text(
                      'Financiado: \$${(planResp['monto_financiado'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (planResp['cuotas'] is List && (planResp['cuotas'] as List).isNotEmpty)
                    Text(
                      '${(planResp['cuotas'] as List).length} cuota(s)',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  PdfService.descargarYCompartirFactura(context, factura);
                },
                icon: const Icon(Icons.share),
                label: const Text('Compartir factura'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      } else if (result['offline'] == true) {
        await syncProvider.agregarVenta(payload);
        carrito.vaciarCarrito();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Venta guardada localmente. Se sincronizará cuando haya internet.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        Navigator.pop(context);
      } else {
        final productoAgotado = result['producto_agotado'];
        if (productoAgotado != null && productoAgotado is String && productoAgotado.isNotEmpty) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('🚫 Producto agotado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('El producto "$productoAgotado" no tiene stock suficiente para completar la venta.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['mensaje'] ?? 'Error al guardar venta'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await syncProvider.agregarVenta(payload);
      carrito.vaciarCarrito();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💾 Venta guardada localmente. Se sincronizará cuando haya internet.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context);
    }
  }

  // ============================================================
  // WIDGETS DEL BLOQUE MIXTO
  // ============================================================
  Widget _buildBloqueMixto(double totalUsd, double tasaParalelo) {
    final suma = _sumaMixtoUsd(tasaParalelo);
    final diff = totalUsd - suma;
    final cuadra = diff.abs() < 0.01;
    final excede = suma > totalUsd + 0.01;

    // Equivalentes en Bs para mostrar junto a los USD.
    final totalBs = totalUsd * tasaParalelo;
    final sumaBs = suma * tasaParalelo;
    final diffBs = diff.abs() * tasaParalelo;

    Color colorBadge;
    String textoBadge;
    IconData iconBadge;

    if (suma <= 0) {
      colorBadge = Colors.grey;
      textoBadge = 'Pendiente';
      iconBadge = Icons.info_outline;
    } else if (cuadra) {
      colorBadge = Colors.green;
      textoBadge = '✓ Cuadra';
      iconBadge = Icons.check_circle;
    } else if (excede) {
      colorBadge = Colors.red;
      textoBadge =
          'Excede \$${(suma - totalUsd).toStringAsFixed(2)} (Bs ${((suma - totalUsd) * tasaParalelo).toStringAsFixed(2)})';
      iconBadge = Icons.error;
    } else {
      colorBadge = Colors.orange;
      textoBadge =
          'Faltan \$${diff.toStringAsFixed(2)} (Bs ${diffBs.toStringAsFixed(2)})';
      iconBadge = Icons.warning;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Distribución del pago',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              TextButton.icon(
                onPressed: _limpiarMixto,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Limpiar'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Text(
            'Tasa paralelo: ${tasaParalelo.toStringAsFixed(2)} Bs/USD',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _buildGridMixto(tasaParalelo),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asignado: \$${suma.toStringAsFixed(2)} (Bs ${sumaBs.toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Total: \$${totalUsd.toStringAsFixed(2)} (Bs ${totalBs.toStringAsFixed(2)})',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorBadge.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorBadge),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconBadge, size: 14, color: colorBadge),
                          const SizedBox(width: 4),
                          Text(
                            textoBadge,
                            style: TextStyle(
                              color: colorBadge,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_mixtoError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _mixtoError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMixto(double tasaParalelo) {
    final cells = _metodosMixto.map((m) => _buildCeldaMixto(m, tasaParalelo)).toList();
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 2) {
      if (i + 1 < cells.length) {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 8),
            Expanded(child: cells[i + 1]),
          ],
        ));
      } else {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ));
      }
    }
    return Column(children: rows);
  }

  Widget _buildCeldaMixto(Map<String, dynamic> m, double tasaParalelo) {
    final ctrl = _mixtoControllers[m['id']]!;
    final esBs = m['moneda'] == 'BS';
    final valor = _parseMonto(ctrl.text);
    final usd = esBs
        ? (tasaParalelo > 0 ? valor / tasaParalelo : 0.0)
        : valor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m['label'],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: const OutlineInputBorder(),
              prefixText: esBs ? null : '\$ ',
              suffixText: esBs ? 'Bs' : null,
              hintText: '0.00',
              hintStyle: const TextStyle(fontSize: 13),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) {
              setState(() {
                _mixtoError = null;
              });
            },
          ),
          if (esBs) ...[
            const SizedBox(height: 2),
            Text(
              '≈ \$${usd.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // WIDGETS DEL BLOQUE PLAN DE CUOTAS
  // ============================================================
  Widget _buildBloquePlanCuotas(double totalUsd) {
    // Cálculos del preview.
    final montoCrudoPreview = _parseMonto(_planMontoInicialController.text);
    final tasaPreview = context.watch<TasasProvider>().tasaParalelo;
    final montoInicial = (_planInicialEnBs && tasaPreview > 0)
        ? montoCrudoPreview / tasaPreview
        : montoCrudoPreview;
    final nCuotas = int.tryParse(_planNumeroCuotasController.text.trim()) ?? 0;
    final dias = int.tryParse(_planDiasEntreCuotasController.text.trim()) ?? 0;

    final financiado = (totalUsd - montoInicial).clamp(0.0, double.infinity);
    final cuotaAprox = (nCuotas > 0 && financiado > 0)
        ? financiado / nCuotas
        : 0.0;

    DateTime? fechaPrimera;
    DateTime? fechaUltima;
    if (dias > 0 && nCuotas > 0) {
      fechaPrimera = _planFechaInicio.add(Duration(days: dias));
      fechaUltima = _planFechaInicio.add(Duration(days: dias * nCuotas));
    }

    final sinFinanciar = _planCuotasActivo && montoInicial >= totalUsd;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Plan de cuotas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Switch(
                value: _planCuotasActivo,
                onChanged: (v) {
                  setState(() {
                    _planCuotasActivo = v;
                    if (!v) _planCuotasError = null;
                  });
                },
                activeColor: Colors.green,
              ),
            ],
          ),
          if (!_planCuotasActivo)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Activa esta opción para generar cuotas fijas con vencimientos programados.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          if (_planCuotasActivo) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _planMontoInicialController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      labelText: _planInicialEnBs ? 'Inicial (Bs)' : 'Inicial (USD)',
                      border: const OutlineInputBorder(),
                      prefixText: _planInicialEnBs ? 'Bs ' : '\$ ',
                      suffixIcon: TextButton(
                        onPressed: () {
                          setState(() {
                            _planInicialEnBs = !_planInicialEnBs;
                            _planCuotasError = null;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _planInicialEnBs ? 'Bs' : 'USD',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setState(() => _planCuotasError = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _planNumeroCuotasController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      labelText: 'N° cuotas',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setState(() => _planCuotasError = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _planDiasEntreCuotasController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      labelText: 'Días entre cuotas',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setState(() => _planCuotasError = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _seleccionarFechaInicioPlan,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        labelText: 'Fecha inicio',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatFechaDmy(_planFechaInicio),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _planObservacionesController,
              maxLines: 2,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Financiado:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '\$${financiado.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  if (nCuotas > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuota aprox ($nCuotas):',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '\$${cuotaAprox.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  if (fechaPrimera != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '1ra cuota:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _formatFechaDmy(fechaPrimera),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  if (fechaUltima != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Última cuota:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _formatFechaDmy(fechaUltima),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (sinFinanciar) ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ El monto inicial cubre todo. No hay nada que financiar.',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ],
            if (_planCuotasError != null) ...[
              const SizedBox(height: 8),
              Text(
                _planCuotasError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();
    final tasas = context.watch<TasasProvider>();
    final config = context.watch<ConfiguracionProvider>();

    final colorPrimario = config.colorPrimario;
    final color = Color(int.parse('0xFF${colorPrimario.replaceAll('#', '')}'));

    if (carrito.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          backgroundColor: const Color(0xFF1e293b),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('El carrito está vacío', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('Agrega productos desde el catálogo', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final totalUsd = carrito.totalUsd;
    final totalBs = totalUsd * tasas.tasaParalelo;
    final totalEqBcv = totalUsd * tasas.tasaParalelo / (tasas.tasaBCV > 0 ? tasas.tasaBCV : 1);
    final puedeConfirmar = _puedeConfirmar(carrito, tasas.tasaParalelo);

    final clienteRiesgoso = _clienteSeleccionado != null &&
        (_clienteSeleccionado!.categoria ?? 'Nuevo') == 'Riesgoso';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (clienteRiesgoso)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Cliente categoría "Riesgoso". Solo puede comprar al contado.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productos',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...carrito.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.cantidad}x ${item.nombre}',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '\$${(item.cantidad * item.precio).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal USD:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('\$${totalUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                                if (_clienteSeleccionado!.telefono.isNotEmpty)
                                  Text(
                                    'Tel: ${_clienteSeleccionado!.telefono}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                if (_clienteSeleccionado!.categoria != null)
                                  Text(
                                    'Categoría: ${_clienteSeleccionado!.categoria}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _clienteSeleccionado!.categoria == 'Riesgoso'
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() => _clienteSeleccionado = null);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: _mostrarDialogCrearCliente,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ] else ...[
                      if (!_mostrarBusquedaClientes)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _mostrarBusquedaClientes = true);
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('Buscar cliente'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _mostrarDialogCrearCliente,
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFf0872d),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o cédula...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _mostrarBusquedaClientes = false;
                                  _clientesEncontrados = [];
                                  _searchController.clear();
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: _buscarClientes,
                        ),
                        const SizedBox(height: 8),
                        if (_buscandoClientes)
                          const Center(child: CircularProgressIndicator())
                        else if (_clientesEncontrados.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _clientesEncontrados.length,
                              itemBuilder: (context, index) {
                                final cliente = _clientesEncontrados[index];
                                final esRiesgoso = (cliente.categoria ?? 'Nuevo') == 'Riesgoso';
                                return ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(cliente.nombre),
                                      ),
                                      if (esRiesgoso)
                                        const Icon(Icons.warning, color: Colors.red, size: 16),
                                    ],
                                  ),
                                  subtitle: Text('Cédula: ${cliente.cedula}'),
                                  trailing: cliente.deudaUsd > 0
                                      ? Chip(
                                          label: Text(
                                            '\$${cliente.deudaUsd.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                          backgroundColor: Colors.red,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _clienteSeleccionado = cliente;
                                      _clientesEncontrados = [];
                                      _searchController.clear();
                                      _mostrarBusquedaClientes = false;
                                      _validarClienteRiesgoso(cliente);
                                    });
                                  },
                                );
                              },
                            ),
                          )
                        else if (_searchController.text.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No se encontraron clientes',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración de venta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: _tipoVenta == 'contado'
                                ? const Color(0xFFf0872d).withOpacity(0.2)
                                : Colors.grey.shade50,
                            child: ListTile(
                              title: const Text('Contado', textAlign: TextAlign.center),
                              leading: Radio<String>(
                                value: 'contado',
                                groupValue: _tipoVenta,
                                onChanged: clienteRiesgoso
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _tipoVenta = value!;
                                          _metodoPago = '';
                                          _referencia = '';
                                          _mixtoError = null;
                                          _resetPlanCuotas();
                                        });
                                      },
                                activeColor: const Color(0xFFf0872d),
                              ),
                              onTap: clienteRiesgoso
                                  ? null
                                  : () {
                                      setState(() {
                                        _tipoVenta = 'contado';
                                        _metodoPago = '';
                                        _referencia = '';
                                        _mixtoError = null;
                                        _resetPlanCuotas();
                                      });
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            color: _tipoVenta == 'credito'
                                ? const Color(0xFFf0872d).withOpacity(0.2)
                                : Colors.grey.shade50,
                            child: ListTile(
                              title: const Text('Crédito', textAlign: TextAlign.center),
                              leading: Radio<String>(
                                value: 'credito',
                                groupValue: _tipoVenta,
                                onChanged: clienteRiesgoso
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _tipoVenta = value!;
                                          _metodoPago = 'credito';
                                          _referencia = '';
                                          _mixtoError = null;
                                        });
                                      },
                                activeColor: const Color(0xFFf0872d),
                              ),
                              onTap: clienteRiesgoso
                                  ? null
                                  : () {
                                      setState(() {
                                        _tipoVenta = 'credito';
                                        _metodoPago = 'credito';
                                        _referencia = '';
                                        _mixtoError = null;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_tipoVenta == 'credito') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Días de crédito:'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _diasCredito.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0) {
                                  setState(() => _diasCredito = parsed);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      _buildBloquePlanCuotas(totalUsd),
                    ],
                    if (_tipoVenta == 'contado') ...[
                      const SizedBox(height: 8),
                      const Text('Método de pago', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _metodosPago.map((metodo) {
                          final isSelected = _metodoPago == metodo['id'];
                          return ChoiceChip(
                            label: Text(metodo['label']),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _metodoPago = selected ? metodo['id'] : '';
                                _referencia = '';
                                _mixtoError = null;
                              });
                            },
                            selectedColor: const Color(0xFFf0872d),
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          );
                        }).toList(),
                      ),
                      if (_metodoPago.isNotEmpty &&
                          _metodoPago != 'mixto' &&
                          (_metodosPago.firstWhere((m) => m['id'] == _metodoPago)['id'].contains('transferencia') ||
                           _metodosPago.firstWhere((m) => m['id'] == _metodoPago)['id'].contains('pago_movil') ||
                           _metodosPago.firstWhere((m) => m['id'] == _metodoPago)['id'] == 'zelle' ||
                           _metodosPago.firstWhere((m) => m['id'] == _metodoPago)['id'] == 'bio_pago'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextFormField(
                            initialValue: _referencia,
                            decoration: const InputDecoration(
                              labelText: 'N° de Referencia / Comprobante',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.receipt),
                            ),
                            onChanged: (value) {
                              setState(() => _referencia = value);
                            },
                          ),
                        ),
                      if (_metodoPago == 'mixto')
                        _buildBloqueMixto(totalUsd, tasas.tasaParalelo),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
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
                      const Text('Total USD:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '\$${totalUsd.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bs (Paralelo):', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text('${totalBs.toStringAsFixed(2)} Bs', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Eq BCV:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text('${totalEqBcv.toStringAsFixed(2)} Eq BCV', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: puedeConfirmar ? _finalizarVenta : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf0872d),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  puedeConfirmar
                      ? 'CONFIRMAR VENTA'
                      : (_metodoPago == 'mixto'
                          ? 'COMPLETA LA DISTRIBUCIÓN'
                          : 'CONFIRMAR VENTA'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}