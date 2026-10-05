import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/jugador_repository.dart';
import '../models/jugador.dart';
import '../services/backend_api.dart';
import 'repository_providers.dart';

class JugadoresNotifier extends StateNotifier<List<Jugador>> {
  final JugadorRepository _repo;

  JugadoresNotifier(this._repo) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerTodos();
  }

  Future<void> crear({required String nombre, String? celular}) async {
    await _repo.crear(Jugador(nombre: nombre, celular: celular));
    await cargar();
  }

  Future<void> eliminar(int id) async {
    await _repo.eliminar(id);
    await cargar();
  }

  /// Renombra al jugador en el directorio (cambio global) y despues
  /// intenta propagar la correccion al backend, solo para los partidos
  /// que siguen abiertos donde esa persona ya confirmo por la web.
  /// Best-effort: si el envio a algun partido falla (sin internet, por
  /// ejemplo), el nombre local ya quedo corregido igual — no se pierde
  /// nada, simplemente ese partido puntual no se actualiza en la web.
  Future<void> renombrar(int id, String nuevoNombre) async {
    await _repo.actualizarNombre(id, nuevoNombre);
    await cargar();
    await _propagarNombre(id, nuevoNombre);
  }

  /// Corrige el celular a mano. A diferencia del nombre, esto no se
  /// propaga al backend (ver JugadorRepository.actualizarCelular).
  Future<void> actualizarCelular(int id, String? nuevoCelular) async {
    await _repo.actualizarCelular(id, nuevoCelular);
    await cargar();
  }

  /// Fusiona dos jugadores duplicados (ver JugadorRepository.fusionar) y
  /// despues propaga el nombre del que queda a los partidos abiertos que
  /// se le acaban de reasignar, para que la lista publica quede prolija.
  Future<void> fusionar({
    required int idOrigen,
    required int idDestino,
  }) async {
    await _repo.fusionar(idOrigen: idOrigen, idDestino: idDestino);
    await cargar();

    final destino = await _repo.obtenerPorId(idDestino);
    if (destino != null) {
      await _propagarNombre(idDestino, destino.nombre);
    }
  }

  /// Agrupa a los jugadores que comparten el mismo celular — señal de
  /// que son la misma persona con dos registros (ej. se registró por la
  /// web con un nombre distinto al que ya tenía en el directorio). Cada
  /// grupo devuelto tiene 2 o más jugadores con el mismo número.
  List<List<Jugador>> duplicadosPorCelular() {
    final porCelular = <String, List<Jugador>>{};
    for (final jugador in state) {
      final celular = jugador.celular?.trim();
      if (celular == null || celular.isEmpty) continue;
      porCelular.putIfAbsent(celular, () => []).add(jugador);
    }
    return porCelular.values.where((grupo) => grupo.length > 1).toList();
  }

  Future<void> _propagarNombre(int jugadorId, String nombre) async {
    final objetivos = await _repo.obtenerConfirmacionesAbiertasPara(jugadorId);
    for (final fila in objetivos) {
      try {
        await BackendApi().corregirNombreConfirmacion(
          eventoIdBackend: fila['evento_uuid'] as String,
          adminToken: fila['admin_token'] as String,
          confirmacionId: fila['confirmacion_uuid'] as String,
          nombreInvitado: nombre,
        );
      } catch (e) {
        debugPrint(
          'No se pudo corregir el nombre en el backend para el evento '
          '${fila['evento_uuid']}: $e',
        );
      }
    }
  }
}

final jugadoresProvider =
    StateNotifierProvider<JugadoresNotifier, List<Jugador>>((ref) {
      final repo = ref.watch(jugadorRepositoryProvider);
      return JugadoresNotifier(repo);
    });
