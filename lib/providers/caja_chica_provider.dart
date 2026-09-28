import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constantes.dart';
import '../models/evento_fecha.dart';
import 'asistencias_provider.dart';
import 'repository_providers.dart';

class CajaChicaResumen {
  final double recaudado;
  final double meta;
  final double excedente;
  final double deficit;

  const CajaChicaResumen({
    required this.recaudado,
    required this.meta,
    required this.excedente,
    required this.deficit,
  });
}

/// Carga el evento (para saber su meta_recaudacion). Es un FutureProvider
/// porque leer de SQLite es asíncrono.
final eventoFechaProvider = FutureProvider.family<EventoFecha?, int>((
  ref,
  eventoId,
) {
  final repo = ref.watch(eventoFechaRepositoryProvider);
  return repo.obtenerPorId(eventoId);
});

/// El cálculo en tiempo real: cada vez que `asistenciasProvider` cambia
/// (alguien marcó un pago), esto se recalcula solo — no hay que llamarlo
/// a mano desde ningún lado.
final cajaChicaProvider = Provider.family<CajaChicaResumen, int>((
  ref,
  eventoId,
) {
  final asistencias = ref.watch(asistenciasProvider(eventoId));

  final recaudado = asistencias
      .where((fila) => fila['estado'] == EstadoAsistencia.pagado)
      .fold<double>(
        0,
        (suma, fila) => suma + (fila['monto_pagado'] as num).toDouble(),
      );

  final eventoAsync = ref.watch(eventoFechaProvider(eventoId));
  final meta = eventoAsync.maybeWhen(
    data: (evento) => evento?.metaRecaudacion ?? 0.0,
    orElse: () => 0.0,
  );

  return CajaChicaResumen(
    recaudado: recaudado,
    meta: meta,
    excedente: recaudado > meta ? recaudado - meta : 0.0,
    deficit: recaudado < meta ? meta - recaudado : 0.0,
  );
});
