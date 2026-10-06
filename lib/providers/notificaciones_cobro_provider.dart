import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zentri_vendedor/services/notificaciones_cobro_service.dart';
import 'package:zentri_vendedor/utils/logger.dart';

/// Provider que mantiene el estado de las notificaciones de cobro.
/// Hace polling cada 5 minutos (igual que el panel web).
class NotificacionesCobroProvider extends ChangeNotifier {
  final NotificacionesCobroService _service = NotificacionesCobroService();

  // Resumen (contadores + totales)
  Map<String, dynamic> _resumen = {};
  double _tasaParalelo = 0;
  DateTime? _ultimaActualizacion;

  // Listas
  List<Map<String, dynamic>> _cuotasVencidas = [];
  List<Map<String, dynamic>> _cuotasPorVencer = [];
  List<Map<String, dynamic>> _creditosVencidos = [];
  List<Map<String, dynamic>> _creditosPorVencer = [];

  int _diasAviso = 3;

  bool _cargando = false;
  bool _fetchEnCurso = false;
  String? _error;

  Timer? _timer;

  // ============ Getters ============
  Map<String, dynamic> get resumen => _resumen;
  double get tasaParalelo => _tasaParalelo;
  DateTime? get ultimaActualizacion => _ultimaActualizacion;

  List<Map<String, dynamic>> get cuotasVencidas => _cuotasVencidas;
  List<Map<String, dynamic>> get cuotasPorVencer => _cuotasPorVencer;
  List<Map<String, dynamic>> get creditosVencidos => _creditosVencidos;
  List<Map<String, dynamic>> get creditosPorVencer => _creditosPorVencer;

  int get diasAviso => _diasAviso;
  bool get cargando => _cargando;
  String? get error => _error;

  int get totalNotificaciones =>
      (_resumen['total_notificaciones'] as num?)?.toInt() ?? 0;
  int get totalVencidas =>
      (_resumen['total_vencidas'] as num?)?.toInt() ?? 0;
  int get totalPorVencer =>
      (_resumen['total_por_vencer'] as num?)?.toInt() ?? 0;

  NotificacionesCobroProvider() {
    _iniciar();
  }

  void _iniciar() {
    // Primera carga
    cargar(silencioso: true);
    // Polling cada 5 minutos
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      cargar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> setDiasAviso(int dias) async {
    if (dias < 0) dias = 0;
    if (dias > 30) dias = 30;
    if (dias == _diasAviso) return;
    _diasAviso = dias;
    await cargar(silencioso: false);
  }

  Future<void> cargar({bool silencioso = false}) async {
    if (_fetchEnCurso) return;
    _fetchEnCurso = true;

    if (!silencioso) {
      _cargando = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _service.obtenerCobrosPendientes(diasAviso: _diasAviso);

      if (data['ok'] != true) {
        if (!silencioso) {
          _error = data['mensaje']?.toString() ?? 'Error al cargar';
        }
        return;
      }

      // Extraer resumen
      _resumen = Map<String, dynamic>.from(data['resumen'] ?? {});
      _tasaParalelo = (data['tasa_paralelo'] as num?)?.toDouble() ?? 0;

      // Extraer cuotas
      final cuotas = data['cuotas'] ?? {};
      _cuotasVencidas = List<Map<String, dynamic>>.from(
          cuotas['vencidas'] ?? []);
      _cuotasPorVencer = List<Map<String, dynamic>>.from(
          cuotas['por_vencer'] ?? []);

      // Extraer créditos directos
      final creditos = data['creditos_libres'] ?? {};
      _creditosVencidos = List<Map<String, dynamic>>.from(
          creditos['vencidas'] ?? []);
      _creditosPorVencer = List<Map<String, dynamic>>.from(
          creditos['por_vencer'] ?? []);

      _ultimaActualizacion = DateTime.now();
      _error = null;

      if (silencioso) {
        // En modo silencioso, no disparamos notifyListeners si no cambió
        // el contador principal, para evitar parpadeo.
        AppLogger.log(
            '💵 [NotificacionesCobro] Cargado silencioso: $totalNotificaciones notificaciones');
      } else {
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log('❌ [NotificacionesCobro] Error: $e');
      if (!silencioso) _error = 'Error: $e';
    } finally {
      _fetchEnCurso = false;
      if (!silencioso && _cargando) {
        _cargando = false;
        notifyListeners();
      }
    }
  }

  Future<void> refrescar() async {
    await cargar(silencioso: false);
  }
}