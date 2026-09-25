import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/liga_categoria_repository.dart';
import '../models/liga_categoria.dart';
import 'eventos_pendientes_provider.dart';
import 'reportes_provider.dart';
import 'repository_providers.dart';

class LigasNotifier extends StateNotifier<List<LigaCategoria>> {
  final LigaCategoriaRepository _repo;
  final Ref _ref;

  LigasNotifier(this._repo, this._ref) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerTodas();
  }

  Future<void> crear(String nombre, {String? deporte}) async {
    await _repo.crear(LigaCategoria(nombre: nombre, deporte: deporte));
    await cargar();
  }

  // 👈 NUEVO
  Future<void> editar(int id, {required String nombre, String? deporte}) async {
    await _repo.actualizar(id, nombre: nombre, deporte: deporte);
    await cargar();
  }

  Future<void> eliminar(int id) async {
    await _repo.eliminar(id);
    await cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
    await _ref.read(morososProvider.notifier).cargar();
  }
}

final ligasProvider =
    StateNotifierProvider<LigasNotifier, List<LigaCategoria>>((ref) {
  final repo = ref.watch(ligaCategoriaRepositoryProvider);
  return LigasNotifier(repo, ref);
});