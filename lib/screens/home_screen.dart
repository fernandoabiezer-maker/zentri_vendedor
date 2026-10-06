import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zentri_vendedor/main.dart';
import 'package:zentri_vendedor/screens/catalogo_screen.dart';
import 'package:zentri_vendedor/screens/clientes_screen.dart';
import 'package:zentri_vendedor/screens/historial_ventas_screen.dart';
import 'package:zentri_vendedor/screens/cotizaciones_screen.dart';
import 'package:zentri_vendedor/screens/cuentas_por_cobrar_screen.dart';
import 'package:zentri_vendedor/screens/sync_queue_screen.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/providers/auth_provider.dart';
import 'package:zentri_vendedor/providers/producto_provider.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/providers/tasas_provider.dart';
import 'package:zentri_vendedor/providers/configuracion_provider.dart';
import 'package:zentri_vendedor/providers/venta_provider.dart';
import 'package:zentri_vendedor/providers/cotizacion_provider.dart';
import 'package:zentri_vendedor/providers/cuentas_por_cobrar_provider.dart';
import 'package:zentri_vendedor/providers/notificaciones_cobro_provider.dart';
import 'package:zentri_vendedor/screens/notificaciones_cobro_screen.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _precargaIniciada = false;

  @override
  void initState() {
    super.initState();
    // ✅ Refrescar conteo de pendientes al abrir el Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SyncProvider>().cargarPendientes();
        _precargarDatosCliente();
      }
    });
  }

  Future<void> _sincronizarTodo(BuildContext context) async {
    final syncProvider = context.read<SyncProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sincronizadas = await syncProvider.sincronizarTodo();
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ Sincronizados $sincronizadas pendientes (ventas, cotizaciones, abonos, clientes)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error al sincronizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recargarDatos(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ProductoProvider>().sincronizar();
      await context.read<ClienteProvider>().sincronizar();
      await context.read<TasasProvider>().sincronizar();
      await context.read<ConfiguracionProvider>().sincronizar();
      await context.read<VentaProvider>().sincronizarTodo();
      await context.read<CotizacionProvider>().sincronizarTodo();
      await context.read<CuentasPorCobrarProvider>().sincronizarTodo();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Datos sincronizados con el servidor'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error al sincronizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDiagnostico(BuildContext context) {
    final clienteProvider = context.read<ClienteProvider>();
    final productoProvider = context.read<ProductoProvider>();
    final tasasProvider = context.read<TasasProvider>();
    final configProvider = context.read<ConfiguracionProvider>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔍 Diagnóstico Offline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clientes en memoria: ${clienteProvider.clientes.length}'),
            Text('Productos en memoria: ${productoProvider.productos.length}'),
            Text('Tasa BCV: ${tasasProvider.tasaBCV}'),
            Text('Tasa Paralelo: ${tasasProvider.tasaParalelo}'),
            Text('Color primario: ${configProvider.colorPrimario}'),
            const Divider(),
            Text(
              'Estado: ${clienteProvider.clientes.isEmpty && productoProvider.productos.isEmpty ? "⚠️ SIN DATOS OFFLINE" : "✅ DATOS OFFLINE DISPONIBLES"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: clienteProvider.clientes.isEmpty && productoProvider.productos.isEmpty
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarLogs(BuildContext context) {
    final logs = AppLogger.getLogsAsString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('📋 Logs de la App'),
            IconButton(
              icon: const Icon(Icons.copy, size: 20, color: Colors.blue),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: logs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Logs copiados al portapapeles'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copiar logs',
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: SelectableText(
              logs.isEmpty ? 'No hay logs.' : logs,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogger.clearLogs();
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ✅ PRECARGA EN SEGUNDO PLANO (solo una vez)
  Future<void> _precargarDatosCliente() async {
    if (_precargaIniciada) return;
    _precargaIniciada = true;

    final clienteProvider = context.read<ClienteProvider>();
    if (clienteProvider.clientes.isNotEmpty) {
      AppLogger.log('🔄 Iniciando precarga de datos de clientes en segundo plano...');
      await clienteProvider.precargarComportamientoClientes(limite: 30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zentri Vendedor'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _mostrarLogs(context),
            tooltip: 'Ver logs',
          ),
          IconButton(
            icon: const Icon(Icons.medical_services),
            onPressed: () => _mostrarDiagnostico(context),
            tooltip: 'Diagnóstico offline',
          ),
          // ============================================================
          // ÍCONO DE NOTIFICACIONES DE COBRO CON BADGE
          // ============================================================
          Consumer<NotificacionesCobroProvider>(
            builder: (context, notifProv, _) {
              final total = notifProv.totalNotificaciones;
              final hayVencidas = notifProv.totalVencidas > 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_active),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificacionesCobroScreen(),
                        ),
                      ).then((_) {
                        if (mounted) {
                          context
                              .read<NotificacionesCobroProvider>()
                              .refrescar();
                        }
                      });
                    },
                    tooltip: 'Notificaciones de cobro',
                  ),
                  if (total > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: hayVencidas ? Colors.red : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          total > 99 ? '99+' : '$total',
                          style: TextStyle(
                            color: hayVencidas ? Colors.white : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // ============================================================
          // ÍCONO DE PENDIENTES POR SINCRONIZAR
          // ============================================================
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.cloud_upload),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SyncQueueScreen()),
                  ).then((_) {
                    if (mounted) {
                      context.read<SyncProvider>().cargarPendientes();
                    }
                  });
                },
                tooltip: 'Pendientes (ventas/cotizaciones/abonos/clientes)',
              ),
              if (syncProvider.pendingCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${syncProvider.pendingCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _recargarDatos(context),
            tooltip: 'Sincronizar todos los datos',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              await ApiClient().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (authProvider.fotoBase64 != null && authProvider.fotoBase64!.isNotEmpty)
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: MemoryImage(
                  base64Decode(authProvider.fotoBase64!),
                ),
              )
            else
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
            const SizedBox(height: 20),
            const Text(
              '¡Bienvenido!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              authProvider.nombre != null ? 'Hola, ${authProvider.nombre}' : 'Has iniciado sesión correctamente.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CatalogoScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf0872d),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ver Catálogo', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientesScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563eb),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clientes', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistorialVentasScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10b981),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Historial de Ventas', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CotizacionesScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8b5cf6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cotizaciones', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CuentasPorCobrarScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFdc3545),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cuentas por Cobrar', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            if (syncProvider.pendingCount > 0)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SyncQueueScreen()),
                    ).then((_) {
                      if (mounted) {
                        context.read<SyncProvider>().cargarPendientes();
                      }
                    });
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(
                    'Pendientes (${syncProvider.pendingCount})',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}