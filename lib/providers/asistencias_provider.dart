import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/asistencia_cobro_repository.dart';
import '../database/evento_fecha_repository.dart';
import '../database/jugador_repository.dart';
import '../models/constantes.dart';
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
    _sincronizarAlAbrir();
  }

  /// Sincroniza con el backend automáticamente apenas se abre la pantalla
  /// de este partido — así el organizador ya no tiene que acordarse de
  /// tocar "Sincronizar" cada vez. Best-effort: si no hay internet o el
  /// partido todavía no tiene link generado, falla en silencio y se queda
  /// con lo que ya había localmente.
  Future<void> _sincronizarAlAbrir() async {
    try {
      await sincronizar();
    } catch (_) {
      // best-effort: sin link generado o sin internet, no interrumpe nada.
    }
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
    await _sincronizarPagoConBackend(asistenciaId, pagado: true);
  }

  Future<void> desmarcar(int asistenciaId) async {
    await _repo.desmarcarPago(asistenciaId);
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _sincronizarPagoConBackend(asistenciaId, pagado: false);
  }

  /// Si esta asistencia vino de una confirmación de la web (tiene uuid),
  /// le avisa al backend que cambió el estado de pago — best-effort,
  /// igual que el resto de llamadas al backend: si falla (sin internet,
  /// etc.), el cambio local ya quedó guardado, solo no se refleja en el
  /// link público hasta que vuelva a sincronizar.
  Future<void> _sincronizarPagoConBackend(
    int asistenciaId, {
    required bool pagado,
  }) async {
    try {
      final uuid = await _repo.obtenerUuid(asistenciaId);
      if (uuid == null) return;

      final evento = await _eventoRepo.obtenerPorId(eventoId);
      if (evento?.uuid == null || evento?.adminToken == null) return;

      await BackendApi().actualizarPagoConfirmacion(
        eventoIdBackend: evento!.uuid!,
        adminToken: evento.adminToken!,
        confirmacionId: uuid,
        pagado: pagado,
      );
    } catch (_) {
      // best-effort: no interrumpe el flujo local si falla.
    }
  }

  Future<void> agregarJugador(String nombre) async {
    final jugadorId = await _jugadorRepo.obtenerOCrear(nombre: nombre);
    await _repo.inscribir(eventoId: eventoId, jugadorId: jugadorId);
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
  }

  /// Añade a un jugador que ya existe en el directorio (walk-in que ya
  /// habia jugado antes) — a diferencia de [agregarJugador], no crea un
  /// registro nuevo. Devuelve false sin hacer nada si esa persona ya
  /// estaba anotada en este partido.
  Future<bool> agregarJugadorExistente(int jugadorId) async {
    if (await _repo.existeParaEventoYJugador(eventoId, jugadorId)) {
      return false;
    }
    await _repo.inscribir(eventoId: eventoId, jugadorId: jugadorId);
    await cargar();
    await _ref.read(morososProvider.notifier).cargar();
    await _ref.read(eventosPendientesProvider.notifier).cargar();
    return true;
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
        metodoPagoSugerido: MetodoPago.desdeBackend(
          confirmacion['metodoPago'] as String?,
        ),
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
