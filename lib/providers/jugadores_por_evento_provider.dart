import 'package:flutter_riverpod/legacy.dart';

import '../database/jugador_repository.dart';
import '../models/jugador.dart';
import 'repository_providers.dart';

class JugadoresPorEventoNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  final JugadorRepository _repo;

  JugadoresPorEventoNotifier(this._repo) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerAgrupadosPorLiga();
  }
}

final jugadoresPorEventoProvider =
    StateNotifierProvider<
      JugadoresPorEventoNotifier,
      List<Map<String, dynamic>>
    >((ref) {
      final repo = ref.watch(jugadorRepositoryProvider);
      return JugadoresPorEventoNotifier(repo);
    });

class JugadoresSinPartidosNotifier extends StateNotifier<List<Jugador>> {
  final JugadorRepository _repo;

  JugadoresSinPartidosNotifier(this._repo) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerSinPartidos();
  }
}

final jugadoresSinPartidosProvider =
    StateNotifierProvider<JugadoresSinPartidosNotifier, List<Jugador>>((ref) {
      final repo = ref.watch(jugadorRepositoryProvider);
      return JugadoresSinPartidosNotifier(repo);
    });
