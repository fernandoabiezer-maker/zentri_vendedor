import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:zentri_vendedor/providers/sync_provider.dart';
import 'package:zentri_vendedor/database/sync_database_helper.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Vigila la conexión a internet y dispara una sincronización
/// automática cuando:
///   1. Se recupera la señal (cambio wifi ↔ datos ↔ nada).
///   2. Pasa un tiempo prudencial sin sincronizar (por si el server
///      se cayó pero el wifi sigue conectado — Connectivity no lo
///      detecta).
class ConnectionWatcher {
  ConnectionWatcher._();
  static final ConnectionWatcher instance = ConnectionWatcher._();

  StreamSubscription<ConnectivityResult>? _sub;
  Timer? _debounce;
  Timer? _periodico;

  SyncProvider? _syncProvider;
  bool _sincronizando = false;

  /// Cada cuánto reintentamos aunque no cambie la red.
  static const Duration _intervaloReintento = Duration(seconds: 30);

  /// Espera entre un cambio de red y la sync (por si va y viene).
  static const Duration _debounceDelay = Duration(seconds: 3);

  void iniciar(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
    _sub?.cancel();
    _periodico?.cancel();

    // 1) Escucha cambios de red
    _sub = Connectivity().onConnectivityChanged.listen(_onCambio);
    Connectivity().checkConnectivity().then(_onCambio);

    // 2) Reintento periódico (aunque la red no cambie)
    _periodico = Timer.periodic(_intervaloReintento, (_) => _intentarSync());

    AppLogger.log('👁️ [ConnectionWatcher] Vigilante iniciado (reintento cada ${_intervaloReintento.inSeconds}s)');
  }

  void detener() {
    _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    _debounce = null;
    _periodico?.cancel();
    _periodico = null;
  }

  void _onCambio(ConnectivityResult resultado) {
    final hayRed = resultado == ConnectivityResult.wifi ||
        resultado == ConnectivityResult.mobile ||
        resultado == ConnectivityResult.ethernet;

    if (!hayRed) {
      AppLogger.log('📴 [ConnectionWatcher] Sin conexión');
      return;
    }

    // Debounce: esperar 3 segundos antes de sincronizar
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _intentarSync);
  }

  Future<void> _intentarSync() async {
    if (_sincronizando) return;
    if (_syncProvider == null) return;

    _sincronizando = true;
    try {
      // Chequeo SILENCIOSO: leemos la BD directamente en vez de llamar
      // a SyncProvider.cargarPendientes(), que dispara notifyListeners()
      // múltiples veces y hace parpadear la UI cada 30 segundos.
      final dbHelper = SyncDatabaseHelper();
      final ventas = await dbHelper.obtenerPendientes();
      final cotizaciones = await dbHelper.obtenerCotizacionesPendientes();
      final abonos = await dbHelper.obtenerAbonosPendientes();
      final clientes = await dbHelper.obtenerClientesPendientes();
      final total = ventas.length +
          cotizaciones.length +
          abonos.length +
          clientes.length;

      if (total == 0) {
        // Nada que subir. No tocamos la UI, no parpadea.
        return;
      }

      AppLogger.log('🌐 [ConnectionWatcher] Detectados $total pendientes. Sincronizando...');
      final sincronizados = await _syncProvider!.sincronizarTodo();

      if (sincronizados > 0) {
        AppLogger.log('🎉 [ConnectionWatcher] Sincronizados: $sincronizados');
      } else {
        AppLogger.log('⏳ [ConnectionWatcher] No se pudo sincronizar todavía (server caído o lento)');
      }
    } catch (e) {
      AppLogger.log('❌ [ConnectionWatcher] Error sincronizando: $e');
    } finally {
      _sincronizando = false;
    }
  }
}