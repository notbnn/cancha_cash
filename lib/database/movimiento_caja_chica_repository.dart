import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class MovimientoCajaChicaRepository {
  Future<Database> get _db async => DBHelper.instance.database;

  /// Todos los movimientos de una liga, más recientes primero.
  Future<List<Map<String, dynamic>>> obtenerPorLiga(int ligaId) async {
    final db = await _db;
    return db.query(
      'Movimientos_Caja_Chica',
      where: 'liga_id = ?',
      whereArgs: [ligaId],
      orderBy: 'creado_en DESC',
    );
  }

  /// Registra un movimiento manual de caja chica de la liga.
  /// [monto] con signo: positivo = ingreso, negativo = gasto.
  Future<void> registrarMovimiento({
    required int ligaId,
    required double monto,
    required String descripcion,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('Movimientos_Caja_Chica', {
        'liga_id': ligaId,
        'monto': monto,
        'descripcion': descripcion,
        'creado_en': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate(
        'UPDATE Ligas_Categorias SET saldo_caja_chica = saldo_caja_chica + ? WHERE id = ?',
        [monto, ligaId],
      );
    });
  }
}