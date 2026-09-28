import 'constantes.dart';

/// Asistencias_Cobros — la transaccional. Une un Jugador con un
/// EventoFecha y registra cuánto y cómo pagó.
class AsistenciaCobro {
  final int? id;
  final String? uuid; // null salvo que vino sincronizado de la web
  final int eventoId;
  final int jugadorId;
  final double montoPagado;
  final String? metodoPago; // QR | Efectivo | Caja Chica — null si aún debe
  final String estado; // Debe | Pagado
  final DateTime creadoEn;

  AsistenciaCobro({
    this.id,
    this.uuid,
    required this.eventoId,
    required this.jugadorId,
    this.montoPagado = 0,
    this.metodoPago,
    this.estado = EstadoAsistencia.debe,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  bool get pagado => estado == EstadoAsistencia.pagado;

  Map<String, dynamic> toMap() => {
    'id': id,
    'uuid': uuid,
    'evento_id': eventoId,
    'jugador_id': jugadorId,
    'monto_pagado': montoPagado,
    'metodo_pago': metodoPago,
    'estado': estado,
    'creado_en': creadoEn.toIso8601String(),
  };

  factory AsistenciaCobro.fromMap(Map<String, dynamic> map) {
    return AsistenciaCobro(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      eventoId: map['evento_id'] as int,
      jugadorId: map['jugador_id'] as int,
      montoPagado: (map['monto_pagado'] as num).toDouble(),
      metodoPago: map['metodo_pago'] as String?,
      estado: map['estado'] as String,
      creadoEn: DateTime.parse(map['creado_en'] as String),
    );
  }

  /// El toggle del checkbox en la pantalla en vivo usa esto.
  AsistenciaCobro copyWith({
    double? montoPagado,
    String? metodoPago,
    String? estado,
  }) {
    return AsistenciaCobro(
      id: id,
      uuid: uuid,
      eventoId: eventoId,
      jugadorId: jugadorId,
      montoPagado: montoPagado ?? this.montoPagado,
      metodoPago: metodoPago ?? this.metodoPago,
      estado: estado ?? this.estado,
      creadoEn: creadoEn,
    );
  }
}
