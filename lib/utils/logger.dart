import 'package:flutter/foundation.dart' show kReleaseMode;

class AppLogger {
  static final List<String> _logs = [];
  static const int _maxLogs = 500;

  static void log(String message) {
    // En release (APK de producción) no imprimimos nada.
    // Solo funciona en debug (flutter run), donde sirve para diagnosticar.
    if (kReleaseMode) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    print(logEntry);
  }

  static List<String> getLogs() => List.from(_logs);

  static void clearLogs() => _logs.clear();

  static String getLogsAsString() {
    if (_logs.isEmpty) return 'No hay logs.';
    return _logs.join('\n');
  }
}