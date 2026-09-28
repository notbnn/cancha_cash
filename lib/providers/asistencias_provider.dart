import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/asistencia_cobro_repository.dart';
import '../database/evento_fecha_repository.dart';
import '../database/jugador_repository.dart';
import '../services/backend_api.dart';
import 'eventos_pendientes_provider.dart';
import 'ligas_provider.dart';
import 'reportes_provider.dart';
import 'repository_providers.dart';

class AsistenciasNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final AsistenciaCobroRepository _repo;
  final JugadorRepository _jugadorRepo;
  final EventoFechaRepository _eventoRepo;
  final Ref _ref;
  final int eventoId;

  AsistenciasNotifier(
    this._repo,
    this._jugadorRepo,
    this._eventoRepo,
    this._ref,
    this.eventoId,
  ) : super([]) {
    cargar();
  }

  Future<void> cargar() async {
    state = await _repo.obtenerPorEventoConNombre(eventoId);
  }

  Future<void> marcarPagado(
    int asistenciaId, {
    required double monto,
    required String metodo,
  }) async {
    await _repo.marcarPagado(
      asistenciaId,
      montoPagado: monto,
      metodoPago: metodo,
    );
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
  }

  Future<void> desmarcar(int asistenciaId) async {
    await _repo.desmarcarPago(asistenciaId);
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
  }

  Future<void> agregarJugador(String nombre) async {
    final jugadorId = await _jugadorRepo.obtenerOCrear(nombre: nombre);
    await _repo.inscribir(eventoId: eventoId, jugadorId: jugadorId);
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
  }

  Future<void> eliminar(int asistenciaId) async {
    await _repo.eliminar(asistenciaId);
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
  }

  Future<void> pagarDeudaTardia({
    required int asistenciaId,
    required int ligaID,
    required double monto,
    required String metodo,
  }) async {
    await _repo.pagarDeudaTardia(
      asistenciaId: asistenciaId,
      ligaId: ligaID,
      monto: monto,
      metodo: metodo,
    );
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref.read(ligasProvider.notifier).cargar();
  }

  Future<void> sincronizar() async {
    final evento = await _eventoRepo.obtenerPorId(eventoId);
    if (evento?.uuid == null || evento?.adminToken == null) {
      throw Exception('Este partido todavía no tiene link generado.');
    }

    final confirmaciones = await BackendApi().obtenerConfirmaciones(
      eventoIdBackend: evento!.uuid!,
      adminToken: evento.adminToken!,
    );

    for (final confirmacion in confirmaciones) {
      final uuid = confirmacion['id'] as String;
      if (await _repo.existePorUuid(uuid)) continue;

      final jugadorId = await _jugadorRepo.obtenerOCrear(
        nombre: confirmacion['nombreInvitado'] as String,
        celular: confirmacion['telefono'] as String?,
      );

      if (await _repo.existeParaEventoYJugador(eventoId, jugadorId)) continue;

      await _repo.inscribir(
        eventoId: eventoId,
        jugadorId: jugadorId,
        uuid: uuid,
      );
    }

    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
  }
}

final asistenciasProvider =
    StateNotifierProvider.family<
      AsistenciasNotifier,
      List<Map<String, dynamic>>,
      int
    >((ref, eventoId) {
      final repo = ref.watch(asistenciaCobroRepositoryProvider);
      final jugadorRepo = ref.watch(jugadorRepositoryProvider);
      final eventoRepo = ref.watch(eventoFechaRepositoryProvider);
      return AsistenciasNotifier(repo, jugadorRepo, eventoRepo, ref, eventoId);
    });
