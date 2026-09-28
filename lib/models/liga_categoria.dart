class LigaCategoria {
  final int? id;
  final String nombre;
  final String? deporte;
  final double saldoCajaChica;
  final DateTime creadoEn;

  LigaCategoria({
    this.id,
    required this.nombre,
    this.deporte,
    this.saldoCajaChica = 0,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'deporte': deporte,
    'saldo_caja_chica': saldoCajaChica,
    'creado_en': creadoEn.toIso8601String(),
  };

  factory LigaCategoria.fromMap(Map<String, dynamic> map) {
    return LigaCategoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      deporte: map['deporte'] as String?,
      saldoCajaChica: (map['saldo_caja_chica'] as num).toDouble(),
      creadoEn: DateTime.parse(map['creado_en'] as String),
    );
  }

  LigaCategoria copyWith({double? saldoCajaChica}) => LigaCategoria(
    id: id,
    nombre: nombre,
    deporte: deporte,
    saldoCajaChica: saldoCajaChica ?? this.saldoCajaChica,
    creadoEn: creadoEn,
  );
}
