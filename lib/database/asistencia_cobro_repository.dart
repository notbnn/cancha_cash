import 'package:sqflite/sqflite.dart';
import '../models/constantes.dart';
import 'db_helper.dart';

class AsistenciaCobroRepository {
  Future<Database> get _db async => DBHelper.instance.database;

  Future<int> inscribir({
    required int eventoId,
    required int jugadorId,
    String? uuid,
    double montoPagado = 0,
    String? metodoPagoSugerido,
  }) async {
    final db = await _db;
    return db.insert('Asistencias_Cobros', {
      'uuid': uuid,
      'evento_id': eventoId,
      'jugador_id': jugadorId,
      'monto_pagado': montoPagado,
      'metodo_pago': null,
      'metodo_pago_sugerido': metodoPagoSugerido,
      'estado': EstadoAsistencia.debe,
      'creado_en': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> existePorUuid(String uuid) async {
    final db = await _db;
    final filas = await db.query(
      'Asistencias_Cobros',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return filas.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> obtenerPorEventoConNombre(
    int eventoId,
  ) async {
    final db = await _db;
    return db.rawQuery(
      '''
      SELECT ac.*, j.nombre AS nombre_jugador, j.celular AS celular_jugador
      FROM Asistencias_Cobros ac
      JOIN Jugadores j ON j.id = ac.jugador_id
      WHERE ac.evento_id = ? AND ac.eliminado_manualmente = 0
      ORDER BY j.nombre ASC
    ''',
      [eventoId],
    );
  }

  Future<void> marcarPagado(
    int id, {
    required double montoPagado,
    required String metodoPago,
  }) async {
    final db = await _db;
    await db.update(
      'Asistencias_Cobros',
      {
        'estado': EstadoAsistencia.pagado,
        'monto_pagado': montoPagado,
        'metodo_pago': metodoPago,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> desmarcarPago(int id) async {
    final db = await _db;
    await db.update(
      'Asistencias_Cobros',
      {'estado': EstadoAsistencia.debe, 'metodo_pago': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> pagarDeudaTardia({
    required int asistenciaId,
    required int ligaId,
    required double monto,
    required String metodo,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'Asistencias_Cobros',
        {
          'estado': EstadoAsistencia.pagado,
          'monto_pagado': monto,
          'metodo_pago': metodo,
        },
        where: 'id = ?',
        whereArgs: [asistenciaId],
      );

      await txn.rawUpdate(
        'UPDATE Ligas_Categorias SET saldo_caja_chica = saldo_caja_chica + ? WHERE id = ?',
        [monto, ligaId],
      );

      final filas = await txn.rawQuery(
        '''
        SELECT ac.evento_id, j.nombre
        FROM Asistencias_Cobros ac
        JOIN Jugadores j ON j.id = ac.jugador_id
        WHERE ac.id = ?
      ''',
        [asistenciaId],
      );
      final nombre = filas.isNotEmpty ? filas.first['nombre'] as String? : null;
      final eventoId = filas.isNotEmpty
          ? filas.first['evento_id'] as int?
          : null;

      await txn.insert('Movimientos_Caja_Chica', {
        'liga_id': ligaId,
        'evento_id': eventoId,
        'monto': monto,
        'descripcion': 'Pago tardío de ${nombre ?? "jugador"}',
        'creado_en': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<double> totalRecaudado(int eventoId) async {
    final db = await _db;
    final resultado = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(monto_pagado), 0) AS total
      FROM Asistencias_Cobros
      WHERE evento_id = ? AND estado = ? AND eliminado_manualmente = 0
    ''',
      [eventoId, EstadoAsistencia.pagado],
    );
    return (resultado.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> obtenerMorosos() async {
    final db = await _db;
    return db.rawQuery(
      '''
      SELECT
        lc.id AS liga_id,
        lc.nombre AS nombre_liga,
        j.id AS jugador_id,
        j.nombre,
        COUNT(*) AS partidos_debe,
        SUM(COALESCE(ef.cuota_por_persona, 0) - ac.monto_pagado) AS deuda_total
      FROM Asistencias_Cobros ac
      JOIN Jugadores j ON j.id = ac.jugador_id
      JOIN Eventos_Fechas ef ON ef.id = ac.evento_id
      JOIN Ligas_Categorias lc ON lc.id = ef.liga_id
      WHERE ac.estado = ? AND ac.eliminado_manualmente = 0
      GROUP BY lc.id, lc.nombre, j.id, j.nombre
      ORDER BY lc.nombre ASC, deuda_total DESC
    ''',
      [EstadoAsistencia.debe],
    );
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.update(
      'Asistencias_Cobros',
      {'eliminado_manualmente': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> existeParaEventoYJugador(int eventoId, int jugadorId) async {
    final db = await _db;
    final filas = await db.query(
      'Asistencias_Cobros',
      where: 'evento_id = ? AND jugador_id = ?',
      whereArgs: [eventoId, jugadorId],
    );
    return filas.isNotEmpty;
  }
}
