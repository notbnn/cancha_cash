import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'cancha_semanal.db');

    return openDatabase(
      path,
      version: 8,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Ligas_Categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        deporte TEXT,
        saldo_caja_chica REAL NOT NULL DEFAULT 0,
        creado_en TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Eventos_Fechas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        liga_id INTEGER NOT NULL,
        fecha_exacta TEXT NOT NULL,
        hora_fin TEXT,
        costo_reserva REAL NOT NULL,
        cuota_por_persona REAL,
        descuento_caja_chica_aplicado REAL NOT NULL DEFAULT 0,
        meta_recaudacion REAL NOT NULL,
        excedente_generado REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        qr_imagen_path TEXT,
        link_publico TEXT,
        admin_token TEXT,
        titulo TEXT,
        creado_en TEXT NOT NULL,
        FOREIGN KEY (liga_id) REFERENCES Ligas_Categorias (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Jugadores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        celular TEXT,
        creado_en TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Asistencias_Cobros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        evento_id INTEGER NOT NULL,
        jugador_id INTEGER NOT NULL,
        monto_pagado REAL NOT NULL DEFAULT 0,
        metodo_pago TEXT,
        estado TEXT NOT NULL DEFAULT 'Debe',
        eliminado_manualmente INTEGER NOT NULL DEFAULT 0,
        creado_en TEXT NOT NULL,
        FOREIGN KEY (evento_id) REFERENCES Eventos_Fechas (id) ON DELETE CASCADE,
        FOREIGN KEY (jugador_id) REFERENCES Jugadores (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE Movimientos_Caja_Chica (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        liga_id INTEGER NOT NULL,
        evento_id INTEGER,
        monto REAL NOT NULL,
        descripcion TEXT NOT NULL,
        creado_en TEXT NOT NULL,
        FOREIGN KEY (liga_id) REFERENCES Ligas_Categorias (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_eventos_liga ON Eventos_Fechas (liga_id)');
    await db.execute(
        'CREATE INDEX idx_asistencias_evento ON Asistencias_Cobros (evento_id)');
    await db.execute(
        'CREATE INDEX idx_asistencias_jugador ON Asistencias_Cobros (jugador_id)');
    await db.execute(
        'CREATE INDEX idx_movimientos_liga ON Movimientos_Caja_Chica (liga_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE Eventos_Fechas ADD COLUMN admin_token TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE Eventos_Fechas ADD COLUMN titulo TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE Ligas_Categorias ADD COLUMN deporte TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE Eventos_Fechas ADD COLUMN hora_fin TEXT');
    }
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE Eventos_Fechas ADD COLUMN cuota_por_persona REAL');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE Movimientos_Caja_Chica (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          liga_id INTEGER NOT NULL,
          evento_id INTEGER,
          monto REAL NOT NULL,
          descripcion TEXT NOT NULL,
          creado_en TEXT NOT NULL,
          FOREIGN KEY (liga_id) REFERENCES Ligas_Categorias (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_movimientos_liga ON Movimientos_Caja_Chica (liga_id)');
    }
    if (oldVersion < 8) {
      await db.execute(
          'ALTER TABLE Asistencias_Cobros ADD COLUMN eliminado_manualmente INTEGER NOT NULL DEFAULT 0');
    }
  }
}