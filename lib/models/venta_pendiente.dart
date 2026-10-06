class VentaPendiente {
  final int? id;
  final String payload;
  final String fechaCreacion;
  final int intentos;
  final String? ultimoError;
  final String estado; // 'pendiente', 'en_progreso', 'fallido', 'sincronizado'

  VentaPendiente({
    this.id,
    required this.payload,
    required this.fechaCreacion,
    this.intentos = 0,
    this.ultimoError,
    this.estado = 'pendiente',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payload': payload,
      'fecha_creacion': fechaCreacion,
      'intentos': intentos,
      'ultimo_error': ultimoError,
      'estado': estado,
    };
  }

  factory VentaPendiente.fromMap(Map<String, dynamic> map) {
    return VentaPendiente(
      id: map['id'],
      payload: map['payload'],
      fechaCreacion: map['fecha_creacion'],
      intentos: map['intentos'] ?? 0,
      ultimoError: map['ultimo_error'],
      estado: map['estado'] ?? 'pendiente',
    );
  }
}