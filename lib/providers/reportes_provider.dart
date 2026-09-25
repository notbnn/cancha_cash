import 'package:flutter_riverpod/legacy.dart';

import '../database/asistencia_cobro_repository.dart';
import 'repository_providers.dart';

class MorososNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final AsistenciaCobroRepository _repo;

  MorososNotifier(this._repo) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerMorosos();
  }
}

final morososProvider =
    StateNotifierProvider<MorososNotifier, List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(asistenciaCobroRepositoryProvider);
  return MorososNotifier(repo);
});