import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';

final movimientosCajaChicaProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, ligaId) {
  final repo = ref.watch(movimientoCajaChicaRepositoryProvider);
  return repo.obtenerPorLiga(ligaId);
});