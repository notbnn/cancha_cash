import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/asistencia_cobro_repository.dart';
import '../database/evento_fecha_repository.dart';
import '../database/jugador_repository.dart';
import '../database/liga_categoria_repository.dart';
import '../database/movimiento_caja_chica_repository.dart'; // 👈 NUEVO

final ligaCategoriaRepositoryProvider = Provider(
  (ref) => LigaCategoriaRepository(),
);
final eventoFechaRepositoryProvider = Provider(
  (ref) => EventoFechaRepository(),
);
final jugadorRepositoryProvider = Provider((ref) => JugadorRepository());
final asistenciaCobroRepositoryProvider = Provider(
  (ref) => AsistenciaCobroRepository(),
);
final movimientoCajaChicaRepositoryProvider = // 👈 NUEVO
Provider(
  (ref) => MovimientoCajaChicaRepository(),
);
