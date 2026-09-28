import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constantes.dart';
import '../providers/jugadores_por_evento_provider.dart';
import '../providers/jugadores_provider.dart';

class ListaAmigosScreen extends ConsumerWidget {
  const ListaAmigosScreen({super.key});

  Future<void> _mostrarDialogoCrearJugador(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nombreControlador = TextEditingController();
    final celularControlador = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo amigo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreControlador,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: celularControlador,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final nombre = nombreControlador.text.trim();
    if (confirmado == true && nombre.isNotEmpty) {
      await ref
          .read(jugadoresProvider.notifier)
          .crear(
            nombre: nombre,
            celular: celularControlador.text.trim().isEmpty
                ? null
                : celularControlador.text.trim(),
          );
      // El jugador recién creado todavía no jugó nada, así que cae en
      // "Sin partidos todavía" — refrescamos esa lista para que aparezca.
      await ref.read(jugadoresSinPartidosProvider.notifier).cargar();
    }
  }

  Future<bool> _eliminarJugador(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    try {
      await ref.read(jugadoresProvider.notifier).eliminar(id);
      // No sabemos de antemano si estaba agrupado en una categoría o en
      // "sin partidos", así que refrescamos las dos listas.
      await ref.read(jugadoresPorEventoProvider.notifier).cargar();
      await ref.read(jugadoresSinPartidosProvider.notifier).cargar();
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede borrar: tiene pagos registrados.'),
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filasAgrupadas = ref.watch(jugadoresPorEventoProvider);
    final sinPartidos = ref.watch(jugadoresSinPartidosProvider);

    // Las filas vienen planas (una por jugador+categoría); acá las
    // juntamos por liga_id para poder armar una sección por evento.
    final grupos = <int, Map<String, dynamic>>{};
    for (final fila in filasAgrupadas) {
      final ligaId = fila['liga_id'] as int;
      grupos.putIfAbsent(
        ligaId,
        () => {
          'liga_nombre': fila['liga_nombre'],
          'liga_deporte': fila['liga_deporte'],
          'jugadores': <Map<String, dynamic>>[],
        },
      );
      (grupos[ligaId]!['jugadores'] as List<Map<String, dynamic>>).add(fila);
    }

    final hayAlgo = grupos.isNotEmpty || sinPartidos.isNotEmpty;

    return Scaffold(
      body: !hayAlgo
          ? const Center(
              child: Text(
                'Todavía no agregaste ningún amigo.\nTocá + para empezar.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                for (final grupo in grupos.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        Icon(
                          Deporte.icono(grupo['liga_deporte'] as String?),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          grupo['liga_nombre'] as String,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  for (final jugador
                      in grupo['jugadores'] as List<Map<String, dynamic>>)
                    Dismissible(
                      key: ValueKey(
                        '${grupo['liga_nombre']}-${jugador['jugador_id']}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _eliminarJugador(
                        context,
                        ref,
                        jugador['jugador_id'] as int,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(jugador['jugador_nombre'] as String),
                        subtitle: jugador['jugador_celular'] != null
                            ? Text(jugador['jugador_celular'] as String)
                            : null,
                      ),
                    ),
                ],
                if (sinPartidos.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Sin partidos todavía',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final jugador in sinPartidos)
                    Dismissible(
                      key: ValueKey('sin-partidos-${jugador.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) =>
                          _eliminarJugador(context, ref, jugador.id!),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(jugador.nombre),
                        subtitle: jugador.celular != null
                            ? Text(jugador.celular!)
                            : null,
                      ),
                    ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoCrearJugador(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
