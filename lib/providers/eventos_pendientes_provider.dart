import 'package:flutter_riverpod/legacy.dart';

import '../database/evento_fecha_repository.dart';
import 'repository_providers.dart';

class EventosPendientesNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  final EventoFechaRepository _repo;

  EventosPendientesNotifier(this._repo) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerPendientesConLiga();
  }
}

final eventosPendientesProvider =
    StateNotifierProvider<
      EventosPendientesNotifier,
      List<Map<String, dynamic>>
    >((ref) {
      final repo = ref.watch(eventoFechaRepositoryProvider);
      return EventosPendientesNotifier(repo);
    });
