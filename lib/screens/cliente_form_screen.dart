import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zentri_vendedor/models/cliente.dart';
import 'package:zentri_vendedor/providers/cliente_provider.dart';
import 'package:zentri_vendedor/services/usuario_service.dart';
import 'package:zentri_vendedor/services/ubicacion_service.dart';
import 'package:zentri_vendedor/utils/logger.dart';

class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;
  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _notasController = TextEditingController();
  final _ubicacionGpsController = TextEditingController();
  bool _activo = true;
  bool _cargando = false;
  bool _obteniendoUbicacion = false;

  List<Map<String, dynamic>> _vendedores = [];
  int? _vendedorIdSeleccionado;
  bool _esAdmin = false;
  bool _cargandoVendedores = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    if (widget.cliente != null) {
      _nombreController.text = widget.cliente!.nombre;
      _cedulaController.text = widget.cliente!.cedula;
      _telefonoController.text = widget.cliente!.telefono;
      _emailController.text = widget.cliente!.email;
      _direccionController.text = widget.cliente!.direccion;
      _notasController.text = widget.cliente!.notas;
      _ubicacionGpsController.text = widget.cliente!.ubicacionGps ?? '';
      _activo = widget.cliente!.activo == 1;
      _vendedorIdSeleccionado = widget.cliente!.vendedorId;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _notasController.dispose();
    _ubicacionGpsController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    final usuarioService = UsuarioService();
    final usuario = await usuarioService.obtenerUsuarioActual();
    if (usuario != null && usuario.rol == 'admin') {
      setState(() => _esAdmin = true);
      final vendedores = await usuarioService.listarVendedores();
      setState(() {
        _vendedores = vendedores;
        _cargandoVendedores = false;
      });
    } else {
      setState(() => _cargandoVendedores = false);
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Activa el GPS en tu dispositivo para obtener la ubicación'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _obteniendoUbicacion = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Permisos de ubicación denegados'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _obteniendoUbicacion = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Permisos de ubicación denegados permanentemente. Ve a ajustes de la app.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _obteniendoUbicacion = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String url = "https://maps.google.com/maps?q=${position.latitude},${position.longitude}";

      setState(() {
        _ubicacionGpsController.text = url;
        _obteniendoUbicacion = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ubicación obtenida correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      AppLogger.log('📍 Ubicación obtenida: $url');
    } catch (e) {
      AppLogger.log('❌ Error al obtener ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al obtener ubicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final provider = context.read<ClienteProvider>();

    // ✅ NUEVO: Resolver enlace corto de ubicación antes de guardar
    String ubicacionGpsFinal = _ubicacionGpsController.text.trim();
    if (UbicacionService.esEnlaceCorto(ubicacionGpsFinal)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔗 Resolviendo enlace de ubicación...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
      try {
        final urlResuelta = await UbicacionService.resolverEnlaceUbicacion(ubicacionGpsFinal);
        ubicacionGpsFinal = urlResuelta;
        _ubicacionGpsController.text = urlResuelta;
        AppLogger.log('📍 Enlace resuelto al guardar: $urlResuelta');
      } catch (e) {
        AppLogger.log('⚠️ No se pudo resolver el enlace corto: $e');
        // Se guardará el original (el enlace corto tal cual)
      }
    }

    try {
      if (widget.cliente == null) {
        await provider.crearCliente(
          nombre: _nombreController.text.trim(),
          cedula: _cedulaController.text.trim(),
          telefono: _telefonoController.text.trim(),
          email: _emailController.text.trim(),
          direccion: _direccionController.text.trim(),
          notas: _notasController.text.trim(),
          activo: _activo ? 1 : 0,
          vendedorId: _esAdmin ? _vendedorIdSeleccionado : null,
          ubicacionGps: ubicacionGpsFinal,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cliente creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        await provider.actualizarCliente(
          id: widget.cliente!.id!,
          nombre: _nombreController.text.trim(),
          cedula: _cedulaController.text.trim(),
          telefono: _telefonoController.text.trim(),
          email: _emailController.text.trim(),
          direccion: _direccionController.text.trim(),
          notas: _notasController.text.trim(),
          activo: _activo ? 1 : 0,
          vendedorId: _esAdmin ? _vendedorIdSeleccionado : null,
          ubicacionGps: ubicacionGpsFinal,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cliente actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('guardado localmente') || msg.contains('actualizado localmente')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $msg'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _cargando = false);
      }
    } finally {
      if (mounted && !_cargando) {
        // Si no hubo error de conexión que cerró la pantalla, desactivar loading
        if (!Navigator.canPop(context)) {
          setState(() => _cargando = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.cliente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
        backgroundColor: const Color(0xFF1e293b),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _cedulaController,
                decoration: const InputDecoration(
                  labelText: 'Cédula/RIF *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),

              // UBICACIÓN GPS
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ubicacionGpsController,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación GPS (Google Maps)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.map),
                      ),
                      keyboardType: TextInputType.url,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Obtener ubicación actual del dispositivo',
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e293b),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: _obteniendoUbicacion
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.gps_fixed, color: Colors.white),
                        onPressed: _obteniendoUbicacion ? null : _obtenerUbicacionActual,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Cliente activo'),
                value: _activo,
                onChanged: (value) => setState(() => _activo = value),
                activeColor: const Color(0xFFf0872d),
              ),

              if (_esAdmin) ...[
                const SizedBox(height: 16),
                if (_cargandoVendedores)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Asignar a vendedor (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    value: _vendedorIdSeleccionado,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('(Público - visible para todos)'),
                      ),
                      ..._vendedores.map((v) => DropdownMenuItem<int>(
                        value: v['id'],
                        child: Text(v['nombre'] ?? 'Vendedor #${v['id']}'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _vendedorIdSeleccionado = value);
                    },
                  ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf0872d),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          esEdicion ? 'Actualizar Cliente' : 'Crear Cliente',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}