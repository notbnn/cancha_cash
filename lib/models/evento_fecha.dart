import 'constantes.dart';

class EventoFecha {
  final int? id;
  final String? uuid;
  final int ligaId;
  final String? titulo;
  final DateTime fechaExacta;
  final String? horaFin;
  final double costoReserva;
  final double?
  cuotaPorPersona; // 👈 NUEVO — null = sin cuota fija (como antes)
  final double descuentoCajaChicaAplicado;
  final double metaRecaudacion;
  final double excedenteGenerado;
  final String estado;
  final String? qrImagenPath;
  final String? ubicacionUrl;
  final String? linkPublico;
  final String? adminToken;
  final DateTime creadoEn;

  EventoFecha({
    this.id,
    this.uuid,
    required this.ligaId,
    this.titulo,
    required this.fechaExacta,
    this.horaFin,
    required this.costoReserva,
    this.cuotaPorPersona, // 👈 NUEVO
    this.descuentoCajaChicaAplicado = 0,
    required this.metaRecaudacion,
    this.excedenteGenerado = 0,
    this.estado = EstadoEventoFecha.pendiente,
    this.qrImagenPath,
    this.ubicacionUrl,
    this.linkPublico,
    this.adminToken,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'uuid': uuid,
    'liga_id': ligaId,
    'titulo': titulo,
    'fecha_exacta': fechaExacta.toIso8601String(),
    'hora_fin': horaFin,
    'costo_reserva': costoReserva,
    'cuota_por_persona': cuotaPorPersona, // 👈 NUEVO
    'descuento_caja_chica_aplicado': descuentoCajaChicaAplicado,
    'meta_recaudacion': metaRecaudacion,
    'excedente_generado': excedenteGenerado,
    'estado': estado,
    'qr_imagen_path': qrImagenPath,
    'ubicacion_url': ubicacionUrl,
    'link_publico': linkPublico,
    'admin_token': adminToken,
    'creado_en': creadoEn.toIso8601String(),
  };

  factory EventoFecha.fromMap(Map<String, dynamic> map) {
    return EventoFecha(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      ligaId: map['liga_id'] as int,
      titulo: map['titulo'] as String?,
      fechaExacta: DateTime.parse(map['fecha_exacta'] as String),
      horaFin: map['hora_fin'] as String?,
      costoReserva: (map['costo_reserva'] as num).toDouble(),
      cuotaPorPersona: (map['cuota_por_persona'] as num?)
          ?.toDouble(), // 👈 NUEVO
      descuentoCajaChicaAplicado: (map['descuento_caja_chica_aplicado'] as num)
          .toDouble(),
      metaRecaudacion: (map['meta_recaudacion'] as num).toDouble(),
      excedenteGenerado: (map['excedente_generado'] as num).toDouble(),
      estado: map['estado'] as String,
      qrImagenPath: map['qr_imagen_path'] as String?,
      ubicacionUrl: map['ubicacion_url'] as String?,
      linkPublico: map['link_publico'] as String?,
      adminToken: map['admin_token'] as String?,
      creadoEn: DateTime.parse(map['creado_en'] as String),
    );
  }

  EventoFecha copyWith({
    String? uuid,
    String? estado,
    double? excedenteGenerado,
    String? qrImagenPath,
    String? ubicacionUrl,
    String? linkPublico,
    String? adminToken,
    String? horaFin,
    double? cuotaPorPersona, // 👈 NUEVO
  }) {
    return EventoFecha(
      id: id,
      uuid: uuid ?? this.uuid,
      ligaId: ligaId,
      titulo: titulo,
      fechaExacta: fechaExacta,
      horaFin: horaFin ?? this.horaFin,
      costoReserva: costoReserva,
      cuotaPorPersona: cuotaPorPersona ?? this.cuotaPorPersona, // 👈 NUEVO
      descuentoCajaChicaAplicado: descuentoCajaChicaAplicado,
      metaRecaudacion: metaRecaudacion,
      excedenteGenerado: excedenteGenerado ?? this.excedenteGenerado,
      estado: estado ?? this.estado,
      qrImagenPath: qrImagenPath ?? this.qrImagenPath,
      ubicacionUrl: ubicacionUrl ?? this.ubicacionUrl,
      linkPublico: linkPublico ?? this.linkPublico,
      adminToken: adminToken ?? this.adminToken,
      creadoEn: creadoEn,
    );
  }
}
