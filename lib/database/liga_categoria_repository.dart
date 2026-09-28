import 'package:sqflite/sqflite.dart';

import '../models/liga_categoria.dart';
import 'db_helper.dart';

class LigaCategoriaRepository {
  Future<Database> get _db async => DBHelper.instance.database;

  /// Crea una categoría nueva (ej. "Fútbol Mañana"). Devuelve el id que
  /// le asignó SQLite.
  Future<int> crear(LigaCategoria liga) async {
    final db = await _db;
    return db.insert('Ligas_Categorias', liga.toMap());
  }

  /// Para el menú lateral / selector de categoría (Fase 4).
  Future<List<LigaCategoria>> obtenerTodas() async {
    final db = await _db;
    final filas = await db.query('Ligas_Categorias', orderBy: 'nombre ASC');
    return filas.map(LigaCategoria.fromMap).toList();
  }

  Future<LigaCategoria?> obtenerPorId(int id) async {
    final db = await _db;
    final filas = await db.query(
      'Ligas_Categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (filas.isEmpty) return null;
    return LigaCategoria.fromMap(filas.first);
  }

  /// Suma (o resta, si le pasás un número negativo) al fondo de esta
  /// categoría. La usamos en dos momentos de la Fase 3: al liquidar un
  /// evento (suma el excedente) y al aplicar el fondo a un evento nuevo
  /// (resta lo que se aplicó).
  Future<void> ajustarSaldo(int ligaId, double delta) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE Ligas_Categorias SET saldo_caja_chica = saldo_caja_chica + ? WHERE id = ?',
      [delta, ligaId],
    );
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('Ligas_Categorias', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> actualizar(
    int id, {
    required String nombre,
    String? deporte,
  }) async {
    final db = await _db;
    await db.update(
      'Ligas_Categorias',
      {'nombre': nombre, 'deporte': deporte},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
