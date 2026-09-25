import 'package:flutter_riverpod/legacy.dart';

import '../database/jugador_repository.dart';
import '../models/jugador.dart';
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
}

final jugadoresProvider =
    StateNotifierProvider<JugadoresNotifier, List<Jugador>>((ref) {
  final repo = ref.watch(jugadorRepositoryProvider);
  return JugadoresNotifier(repo);
});