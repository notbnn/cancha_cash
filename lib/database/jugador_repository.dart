import 'package:sqflite/sqflite.dart';

import '../models/constantes.dart';
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
    final filas = await db.query('Jugadores', where: 'id = ?', whereArgs: [id]);
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
    if (existente != null) {
      // Si ya lo teniamos sin celular y ahora llega uno (ej. confirmo por
      // la web con su telefono), lo completamos en vez de perderlo.
      if ((existente.celular == null || existente.celular!.isEmpty) &&
          celular != null &&
          celular.isNotEmpty) {
        final db = await _db;
        await db.update(
          'Jugadores',
          {'celular': celular},
          where: 'id = ?',
          whereArgs: [existente.id],
        );
      }
      return existente.id!;
    }
    return crear(Jugador(nombre: nombre, celular: celular));
  }

  Future<void> actualizar(Jugador jugador) async {
    final db = await _db;
    await db.update(
      'Jugadores',
      jugador.toMap(),
      where: 'id = ?',
      whereArgs: [jugador.id],
    );
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('Jugadores', where: 'id = ?', whereArgs: [id]);
  }

  /// Corrige el nombre del jugador en el directorio (cambio global — es
  /// la misma persona en todos los partidos, no algo por evento).
  Future<void> actualizarNombre(int id, String nuevoNombre) async {
    final db = await _db;
    await db.update(
      'Jugadores',
      {'nombre': nuevoNombre},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Corrige el celular del jugador a mano — para cuando quedo sin
  /// numero (ej. por el bug viejo del sync) o simplemente cambio de
  /// telefono. Es solo local: el celular no se propaga al backend, cada
  /// confirmacion de la web ya trae el suyo propio por separado.
  Future<void> actualizarCelular(int id, String? nuevoCelular) async {
    final db = await _db;
    await db.update(
      'Jugadores',
      {'celular': nuevoCelular},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fusiona dos jugadores duplicados: todo el historial de `idOrigen`
  /// pasa a `idDestino` y `idOrigen` se borra. Si en algun evento puntual
  /// los dos ya tenian una asistencia por separado (raro, pero puede
  /// pasar si ambos duplicados jugaron el mismo partido), se conserva la
  /// del destino y se descarta la del origen para no duplicar filas.
  Future<void> fusionar({
    required int idOrigen,
    required int idDestino,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final asistenciasOrigen = await txn.query(
        'Asistencias_Cobros',
        where: 'jugador_id = ?',
        whereArgs: [idOrigen],
      );

      for (final fila in asistenciasOrigen) {
        final eventoId = fila['evento_id'] as int;
        final yaExiste = await txn.query(
          'Asistencias_Cobros',
          where: 'jugador_id = ? AND evento_id = ?',
          whereArgs: [idDestino, eventoId],
        );
        if (yaExiste.isNotEmpty) {
          await txn.delete(
            'Asistencias_Cobros',
            where: 'id = ?',
            whereArgs: [fila['id']],
          );
        } else {
          await txn.update(
            'Asistencias_Cobros',
            {'jugador_id': idDestino},
            where: 'id = ?',
            whereArgs: [fila['id']],
          );
        }
      }

      // Si al destino le faltaba celular, aprovechamos el del origen.
      final destino = await txn.query(
        'Jugadores',
        where: 'id = ?',
        whereArgs: [idDestino],
      );
      final origen = await txn.query(
        'Jugadores',
        where: 'id = ?',
        whereArgs: [idOrigen],
      );
      if (destino.isNotEmpty && origen.isNotEmpty) {
        final celularDestino = destino.first['celular'] as String?;
        final celularOrigen = origen.first['celular'] as String?;
        if ((celularDestino == null || celularDestino.isEmpty) &&
            celularOrigen != null &&
            celularOrigen.isNotEmpty) {
          await txn.update(
            'Jugadores',
            {'celular': celularOrigen},
            where: 'id = ?',
            whereArgs: [idDestino],
          );
        }
      }

      await txn.delete('Jugadores', where: 'id = ?', whereArgs: [idOrigen]);
    });
  }

  /// Confirmaciones de este jugador que todavia hay que corregir en el
  /// backend: solo las que vinieron de la web publica (tienen uuid —
  /// un jugador agregado a mano en cancha no tiene nada que corregir
  /// alla) y solo de partidos que siguen abiertos (uno ya cerrado no
  /// tiene sentido tocarlo).
  Future<List<Map<String, dynamic>>> obtenerConfirmacionesAbiertasPara(
    int jugadorId,
  ) async {
    final db = await _db;
    return db.rawQuery(
      '''
      SELECT ac.uuid AS confirmacion_uuid, ef.uuid AS evento_uuid, ef.admin_token AS admin_token
      FROM Asistencias_Cobros ac
      JOIN Eventos_Fechas ef ON ef.id = ac.evento_id
      WHERE ac.jugador_id = ?
        AND ac.uuid IS NOT NULL
        AND ef.estado = ?
        AND ef.uuid IS NOT NULL
        AND ef.admin_token IS NOT NULL
    ''',
      [jugadorId, EstadoEventoFecha.pendiente],
    );
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
