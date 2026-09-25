import 'package:sqflite/sqflite.dart';

import '../models/constantes.dart';
import '../models/evento_fecha.dart';
import 'db_helper.dart';

class EventoFechaRepository {
  Future<Database> get _db async => DBHelper.instance.database;

  Future<int> crear({
    required int ligaId,
    String? titulo,
    required DateTime fechaExacta,
    String? horaFin,
    required double costoReserva,
    double? cuotaPorPersona,
    double descuentoCajaChicaAplicado = 0,
    String? qrImagenPath,
  }) async {
    final db = await _db;
    final metaRecaudacion = costoReserva - descuentoCajaChicaAplicado;

    return db.transaction((txn) async {
      final id = await txn.insert('Eventos_Fechas', {
        'uuid': null,
        'liga_id': ligaId,
        'titulo': titulo,
        'fecha_exacta': fechaExacta.toIso8601String(),
        'hora_fin': horaFin,
        'costo_reserva': costoReserva,
        'cuota_por_persona': cuotaPorPersona,
        'descuento_caja_chica_aplicado': descuentoCajaChicaAplicado,
        'meta_recaudacion': metaRecaudacion,
        'excedente_generado': 0,
        'estado': EstadoEventoFecha.pendiente,
        'qr_imagen_path': qrImagenPath,
        'link_publico': null,
        'creado_en': DateTime.now().toIso8601String(),
      });

      if (descuentoCajaChicaAplicado > 0) {
        await txn.rawUpdate(
          'UPDATE Ligas_Categorias SET saldo_caja_chica = saldo_caja_chica - ? WHERE id = ?',
          [descuentoCajaChicaAplicado, ligaId],
        );

        final descripcionPartido = (titulo != null && titulo.isNotEmpty)
            ? titulo
            : '${fechaExacta.day}/${fechaExacta.month}/${fechaExacta.year}';
        await txn.insert('Movimientos_Caja_Chica', {
          'liga_id': ligaId,
          'evento_id': id,
          'monto': -descuentoCajaChicaAplicado,
          'descripcion': 'Usado para cubrir "$descripcionPartido"',
          'creado_en': DateTime.now().toIso8601String(),
        });
      }

      return id;
    });
  }

  Future<List<EventoFecha>> obtenerPorLiga(int ligaId) async {
    final db = await _db;
    final filas = await db.query(
      'Eventos_Fechas',
      where: 'liga_id = ?',
      whereArgs: [ligaId],
      orderBy: 'fecha_exacta DESC',
    );
    return filas.map(EventoFecha.fromMap).toList();
  }

  Future<EventoFecha?> obtenerPorId(int id) async {
    final db = await _db;
    final filas =
        await db.query('Eventos_Fechas', where: 'id = ?', whereArgs: [id]);
    if (filas.isEmpty) return null;
    return EventoFecha.fromMap(filas.first);
  }

  Future<void> finalizarConExcedente({
    required int eventoId,
    required int ligaId,
    required double excedente,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'Eventos_Fechas',
        {
          'estado': EstadoEventoFecha.finalizado,
          'excedente_generado': excedente,
        },
        where: 'id = ?',
        whereArgs: [eventoId],
      );

      if (excedente != 0) {
        await txn.rawUpdate(
          'UPDATE Ligas_Categorias SET saldo_caja_chica = saldo_caja_chica + ? WHERE id = ?',
          [excedente, ligaId],
        );

        final filasEvento = await txn.query('Eventos_Fechas',
            columns: ['titulo'], where: 'id = ?', whereArgs: [eventoId]);
        final titulo = filasEvento.isNotEmpty
            ? filasEvento.first['titulo'] as String?
            : null;
        await txn.insert('Movimientos_Caja_Chica', {
          'liga_id': ligaId,
          'evento_id': eventoId,
          'monto': excedente,
          'descripcion': excedente > 0
              ? 'Excedente de "${titulo?.isNotEmpty == true ? titulo : "partido cerrado"}"'
              : 'Ajuste al cerrar "${titulo?.isNotEmpty == true ? titulo : "partido cerrado"}"',
          'creado_en': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> guardarDatosBackend(
    int id, {
    required String uuid,
    required String linkPublico,
    required String adminToken,
  }) async {
    final db = await _db;
    await db.update(
      'Eventos_Fechas',
      {
        'uuid': uuid,
        'link_publico': linkPublico,
        'admin_token': adminToken,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> eliminar(int id) async {
    final db = await _db;

    await db.transaction((txn) async {
      final pagos = await txn.rawQuery('''
        SELECT COUNT(*) as total FROM Asistencias_Cobros
        WHERE evento_id = ? AND estado = ?
      ''', [id, EstadoAsistencia.pagado]);
      final tienePagos = (pagos.first['total'] as int) > 0;

      if (tienePagos) {
        throw Exception(
            'Este partido ya tiene pagos registrados. Cerralo en vez de borrarlo, así lo cobrado pasa a la caja chica.');
      }

      final filas =
          await txn.query('Eventos_Fechas', where: 'id = ?', whereArgs: [id]);
      if (filas.isEmpty) return;

      final evento = filas.first;
      final ligaId = evento['liga_id'] as int;
      final titulo = evento['titulo'] as String?;
      final descuentoAplicado =
          (evento['descuento_caja_chica_aplicado'] as num).toDouble();

      await txn.delete('Eventos_Fechas', where: 'id = ?', whereArgs: [id]);

      if (descuentoAplicado > 0) {
        await txn.rawUpdate(
          'UPDATE Ligas_Categorias SET saldo_caja_chica = saldo_caja_chica + ? WHERE id = ?',
          [descuentoAplicado, ligaId],
        );

        await txn.insert('Movimientos_Caja_Chica', {
          'liga_id': ligaId,
          'evento_id': null,
          'monto': descuentoAplicado,
          'descripcion':
              'Reembolso — se borró "${titulo?.isNotEmpty == true ? titulo : "un partido"}"',
          'creado_en': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPendientesConLiga() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT ef.*, lc.nombre AS nombre_liga,
        (SELECT COUNT(*) FROM Asistencias_Cobros WHERE evento_id = ef.id) AS confirmados
      FROM Eventos_Fechas ef
      JOIN Ligas_Categorias lc ON lc.id = ef.liga_id
      WHERE ef.estado = ?
      ORDER BY ef.fecha_exacta ASC
    ''', [EstadoEventoFecha.pendiente]);
  }

  Future<void> actualizarQr(int id, String qrImagenPath) async {
    final db = await _db;
    await db.update(
      'Eventos_Fechas',
      {'qr_imagen_path': qrImagenPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> actualizarTitulo(int id, String? titulo) async {
    final db = await _db;
    await db.update(
      'Eventos_Fechas',
      {'titulo': titulo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> actualizarCuota(int id, double? cuotaPorPersona) async {
    final db = await _db;
    await db.update(
      'Eventos_Fechas',
      {'cuota_por_persona': cuotaPorPersona},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}