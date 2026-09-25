import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constantes.dart';
import '../providers/ligas_provider.dart';
import '../providers/reportes_provider.dart';
import 'reportes_liga_screen.dart';

class ReportesScreen extends ConsumerWidget {
  const ReportesScreen({super.key});

  Future<void> _actualizar(WidgetRef ref) async {
    await ref.read(ligasProvider.notifier).cargar();
    await ref.read(morososProvider.notifier).cargar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligas = ref.watch(ligasProvider);
    final morosos = ref.watch(morososProvider);

    // 👈 NUEVO — agrupa la lista plana que llega del repo por nombre de
    // liga; como la query ya viene ordenada por liga, el Map preserva
    // los bloques en orden.
    final Map<String, List<Map<String, dynamic>>> morososPorLiga = {};
    for (final fila in morosos) {
      final nombreLiga = fila['nombre_liga'] as String;
      morososPorLiga.putIfAbsent(nombreLiga, () => []).add(fila);
    }

    return RefreshIndicator(
      onRefresh: () => _actualizar(ref),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Reportes por liga',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (ligas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Todavía no creaste ninguna categoría.'),
            )
          else
            ...ligas.map((liga) => Card(
                  child: ListTile(
                    leading: Icon(Deporte.icono(liga.deporte)),
                    title: Text(liga.nombre),
                    subtitle: Text(
                        'Caja chica: ${liga.saldoCajaChica.toStringAsFixed(0)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportesLigaScreen(liga: liga),
                        ),
                      );
                    },
                  ),
                )),
          const SizedBox(height: 16),
          Text('Jugadores morosos',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (morosos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nadie debe plata — todo al día.'),
            )
          else
            // 👈 NUEVO — antes era ...morosos.map(...) plano, ahora arma
            // un subtítulo por liga y debajo sus deudores.
            ...morososPorLiga.entries.expand((entry) => [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...entry.value.map((fila) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber,
                              color: Colors.orange),
                          title: Text(fila['nombre'] as String),
                          subtitle: Text(
                              '${fila['partidos_debe']} partido(s) pendiente(s)'),
                          trailing: Text(
                              (fila['deuda_total'] as num).toStringAsFixed(0)),
                        ),
                      )),
                ]),
        ],
      ),
    );
  }
}