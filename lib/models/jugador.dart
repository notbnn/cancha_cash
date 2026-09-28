/// Jugadores — el directorio. Se alimenta solo (al sincronizar la web) o
/// a mano (walk-ins en cancha).
class Jugador {
  final int? id;
  final String nombre;
  final String? celular;
  final DateTime creadoEn;

  Jugador({this.id, required this.nombre, this.celular, DateTime? creadoEn})
    : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'celular': celular,
    'creado_en': creadoEn.toIso8601String(),
  };

  factory Jugador.fromMap(Map<String, dynamic> map) {
    return Jugador(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      celular: map['celular'] as String?,
      creadoEn: DateTime.parse(map['creado_en'] as String),
    );
  }
}
