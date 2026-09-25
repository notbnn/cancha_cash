import 'package:sqflite/sqflite.dart';

import '../models/jugador.dart';
import 'db_helper.dart';

class JugadorRepository {
  Future<Database> get _db async => DBHelper.instance.database;

  Future<int> crear(Jugador jugador) async {
    final db = await _db;
    return db.insert('Jugadores', jugador.toMap());
  }

  /// Para el listado de "Lista de amigos" (Fase 4).
  Future<List<Jugador>> obtenerTodos() async {
    final db = await _db;
    final filas = await db.query('Jugadores', orderBy: 'nombre ASC');
    return filas.map(Jugador.fromMap).toList();
  }

  Future<Jugador?> obtenerPorId(int id) async {
    final db = await _db;
    final filas =
        await db.query('Jugadores', where: 'id = ?', whereArgs: [id]);
    if (filas.isEmpty) return null;
    return Jugador.fromMap(filas.first);
  }

  /// Busca por nombre sin importar mayúsculas/minúsculas.
  Future<Jugador?> buscarPorNombre(String nombre) async {
    final db = await _db;
    final filas = await db.query(
      'Jugadores',
      where: 'LOWER(nombre) = ?',
      whereArgs: [nombre.trim().toLowerCase()],
    );
    if (filas.isEmpty) return null;
    return Jugador.fromMap(filas.first);
  }

  /// Si ya existe un jugador con ese nombre, devuelve su id. Si no,
  /// lo crea. Este es el método que van a usar tanto el sync de la web
  /// (punto 1 — "se alimenta automáticamente") como el botón de
  /// walk-ins en cancha (punto 4) para nunca duplicar a la misma
  /// persona en el directorio.
  Future<int> obtenerOCrear({required String nombre, String? celular}) async {
    final existente = await buscarPorNombre(nombre);
    if (existente != null) return existente.id!;
    return crear(Jugador(nombre: nombre, celular: celular));
  }

  Future<void> actualizar(Jugador jugador) async {
    final db = await _db;
    await db.update('Jugadores', jugador.toMap(),
        where: 'id = ?', whereArgs: [jugador.id]);
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('Jugadores', where: 'id = ?', whereArgs: [id]);
  }
    /// Jugadores agrupados por evento (categoría) — un jugador aparece en
  /// cada categoría donde ya jugó al menos un partido (según su historial
  /// en Asistencias_Cobros). Si jugó fútbol y wally, sale en las dos —
  /// es automático, no hay que asignarlo a mano.
  Future<List<Map<String, dynamic>>> obtenerAgrupadosPorLiga() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT DISTINCT
        j.id AS jugador_id,
        j.nombre AS jugador_nombre,
        j.celular AS jugador_celular,
        lc.id AS liga_id,
        lc.nombre AS liga_nombre,
        lc.deporte AS liga_deporte
      FROM Jugadores j
      JOIN Asistencias_Cobros ac ON ac.jugador_id = j.id
      JOIN Eventos_Fechas ef ON ef.id = ac.evento_id
      JOIN Ligas_Categorias lc ON lc.id = ef.liga_id
      ORDER BY lc.nombre ASC, j.nombre ASC
    ''');
  }

  /// Jugadores que todavía no tienen ningún partido registrado en ninguna
  /// categoría (recién agregados, o que nunca fueron marcados presentes).
  Future<List<Jugador>> obtenerSinPartidos() async {
    final db = await _db;
    final filas = await db.rawQuery('''
      SELECT * FROM Jugadores
      WHERE id NOT IN (SELECT DISTINCT jugador_id FROM Asistencias_Cobros)
      ORDER BY nombre ASC
    ''');
    return filas.map(Jugador.fromMap).toList();
  }
}