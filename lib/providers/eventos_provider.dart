import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/evento_fecha_repository.dart';
import '../models/evento_fecha.dart';
import '../services/backend_api.dart';
import 'eventos_pendientes_provider.dart';
import 'ligas_provider.dart'; // 👈 NUEVO
import 'reportes_provider.dart'; // 👈 NUEVO
import 'repository_providers.dart';

class EventosNotifier extends StateNotifier<List<EventoFecha>> {
  final EventoFechaRepository _repo;
  final Ref _ref;
  final int ligaId;

  EventosNotifier(this._repo, this._ref, this.ligaId) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerPorLiga(ligaId);
  }

  Future<void> crear({
    String? titulo,
    required DateTime fechaExacta,
    String? horaFin,
    required double costoReserva,
    double? cuotaPorPersona,
    double descuentoCajaChicaAplicado = 0,
  }) async {
    final id = await _repo.crear(
      ligaId: ligaId,
      titulo: titulo,
      fechaExacta: fechaExacta,
      horaFin: horaFin,
      costoReserva: costoReserva,
      cuotaPorPersona: cuotaPorPersona,
      descuentoCajaChicaAplicado: descuentoCajaChicaAplicado,
    );

    try {
      final respuesta = await BackendApi().crearEvento(
        fecha: fechaExacta,
        horaFin: horaFin,
        titulo: titulo,
      );
      final linkPublico = BackendApi.urlPublica(respuesta['slug'] as String);

      await _repo.guardarDatosBackend(
        id,
        uuid: respuesta['id'] as String,
        linkPublico: linkPublico,
        adminToken: respuesta['adminToken'] as String,
      );

      debugPrint('Evento creado en el backend — link: $linkPublico');
    } catch (e) {
      debugPrint('No se pudo crear el evento en el backend: $e');
    }

    await cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
  }

  // 👈 NUEVO
  Future<void> eliminar(int id) async {
    await _repo.eliminar(id); // tira una excepción si ya tiene pagos
    await cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref
        .read(ligasProvider.notifier)
        .cargar(); // por si se devolvió el descuento
  }
}

final eventosPorLigaProvider =
    StateNotifierProvider.family<EventosNotifier, List<EventoFecha>, int>((
      ref,
      ligaId,
    ) {
      final repo = ref.watch(eventoFechaRepositoryProvider);
      return EventosNotifier(repo, ref, ligaId);
    });
