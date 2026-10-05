import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constantes.dart';
import '../models/jugador.dart';
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

  /// Edita nombre y celular juntos. El nombre se propaga al backend
  /// (ver JugadoresNotifier.renombrar); el celular queda solo local.
  Future<void> _mostrarDialogoEditarJugador(
    BuildContext context,
    WidgetRef ref,
    int jugadorId,
    String nombreActual,
    String? celularActual,
  ) async {
    final nombreControlador = TextEditingController(text: nombreActual);
    final celularControlador = TextEditingController(
      text: celularActual ?? '',
    );

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar jugador'),
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

    if (guardar != true) return;

    final nuevoNombre = nombreControlador.text.trim();
    final nuevoCelular = celularControlador.text.trim();

    if (nuevoNombre.isNotEmpty && nuevoNombre != nombreActual) {
      await ref
          .read(jugadoresProvider.notifier)
          .renombrar(jugadorId, nuevoNombre);
    }
    if (nuevoCelular != (celularActual ?? '')) {
      await ref
          .read(jugadoresProvider.notifier)
          .actualizarCelular(jugadorId, nuevoCelular.isEmpty ? null : nuevoCelular);

      if (nuevoCelular.isNotEmpty) {
        final duplicados = ref
            .read(jugadoresProvider.notifier)
            .duplicadosPorCelular();
        if (duplicados.isNotEmpty && context.mounted) {
          await _resolverDuplicadosCelular(context, ref, duplicados);
        }
      }
    }

    // El listado agrupado por categoria usa otro provider — lo
    // refrescamos tambien para que se vea lo nuevo ahi.
    await ref.read(jugadoresPorEventoProvider.notifier).cargar();
  }

  /// Candidatos para fusionar con un jugador de una liga puntual: solo
  /// los demas de esa misma liga (no tiene sentido mezclar gente de
  /// grupos distintos aunque compartan nombre) mas los que todavia no
  /// tienen ningun partido (esos no pertenecen a ninguna liga todavia,
  /// asi que fusionarlos nunca genera un cruce indebido).
  List<({int id, String nombre})> _candidatosDeLiga(
    List<Map<String, dynamic>> jugadoresDeLaLiga,
    List<Jugador> sinPartidos,
    int idExcluir,
  ) {
    return [
      for (final otro in jugadoresDeLaLiga)
        if (otro['jugador_id'] != idExcluir)
          (
            id: otro['jugador_id'] as int,
            nombre: otro['jugador_nombre'] as String,
          ),
      for (final otro in sinPartidos)
        if (otro.id != idExcluir) (id: otro.id!, nombre: otro.nombre),
    ];
  }

  /// Candidatos para fusionar con un jugador que todavia no tiene ningun
  /// partido: como no pertenece a ninguna liga, no hay restriccion — se
  /// ofrece cualquier otro jugador de cualquier liga (deduplicado, por
  /// si esa persona ya jugo en mas de una).
  List<({int id, String nombre})> _candidatosGlobales(
    Map<int, Map<String, dynamic>> grupos,
    List<Jugador> sinPartidos,
    int idExcluir,
  ) {
    final vistos = <int, String>{};
    for (final grupo in grupos.values) {
      for (final otro in grupo['jugadores'] as List<Map<String, dynamic>>) {
        final id = otro['jugador_id'] as int;
        if (id != idExcluir) vistos[id] = otro['jugador_nombre'] as String;
      }
    }
    for (final otro in sinPartidos) {
      if (otro.id != idExcluir && otro.id != null) {
        vistos[otro.id!] = otro.nombre;
      }
    }
    return vistos.entries.map((e) => (id: e.key, nombre: e.value)).toList();
  }

  /// Fusiona a un jugador duplicado con otro — pensado para cuando la
  /// misma persona quedo registrada varias veces con nombres distintos
  /// (ej. confirmo por la web como "Juan" una semana y "Juanito" otra).
  /// `candidatos` ya viene filtrado por liga (ver los dos metodos de
  /// arriba) — este dialogo solo busca y confirma.
  /// Pregunta uno por uno, con cual nombre nos quedamos cuando dos
  /// jugadores terminan con el mismo celular, y fusiona con
  /// [JugadoresNotifier.fusionar].
  Future<void> _resolverDuplicadosCelular(
    BuildContext context,
    WidgetRef ref,
    List<List<Jugador>> grupos,
  ) async {
    for (final grupo in grupos) {
      if (!context.mounted) return;

      final elegidoId = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Posible jugador duplicado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El número ${grupo.first.celular} está anotado con '
                '${grupo.length} nombres distintos. ¿Con cuál nos quedamos?',
              ),
              const SizedBox(height: 12),
              for (final jugador in grupo)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person),
                  title: Text(jugador.nombre),
                  onTap: () => Navigator.pop(context, jugador.id),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      );

      if (elegidoId == null || !context.mounted) continue;

      for (final jugador in grupo) {
        if (jugador.id == elegidoId) continue;
        await ref
            .read(jugadoresProvider.notifier)
            .fusionar(idOrigen: jugador.id!, idDestino: elegidoId);
      }

      if (context.mounted) {
        final nombreElegido = grupo
            .firstWhere((j) => j.id == elegidoId)
            .nombre;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jugadores fusionados en "$nombreElegido"')),
        );
      }
    }
  }

  Future<void> _mostrarDialogoFusionar(
    BuildContext context,
    WidgetRef ref,
    int idOrigen,
    String nombreOrigen,
    List<({int id, String nombre})> candidatos,
  ) async {
    if (candidatos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay otro jugador de esta liga con quien fusionar todavía.',
            ),
          ),
        );
      }
      return;
    }

    final busquedaControlador = TextEditingController();

    final destinoId = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtro = busquedaControlador.text.trim().toLowerCase();
          final filtrados = filtro.isEmpty
              ? candidatos
              : candidatos
                    .where((c) => c.nombre.toLowerCase().contains(filtro))
                    .toList();

          return AlertDialog(
            title: Text('Fusionar "$nombreOrigen" con...'),
            content: SizedBox(
              width: double.maxFinite,
              height: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: busquedaControlador,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nombre',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtrados.length,
                            itemBuilder: (context, i) => ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(filtrados[i].nombre),
                              onTap: () =>
                                  Navigator.pop(context, filtrados[i].id),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );

    if (destinoId == null || !context.mounted) return;

    final nombreDestino = candidatos
        .firstWhere((c) => c.id == destinoId)
        .nombre;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar fusión'),
        content: Text(
          'Todos los partidos de "$nombreOrigen" van a quedar a nombre de '
          '"$nombreDestino", y "$nombreOrigen" se borra del directorio. '
          'Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fusionar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    await ref
        .read(jugadoresProvider.notifier)
        .fusionar(idOrigen: idOrigen, idDestino: destinoId);
    await ref.read(jugadoresPorEventoProvider.notifier).cargar();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$nombreOrigen" se fusionó con "$nombreDestino"'),
        ),
      );
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
                'Todavía no agregaste ningún amigo.\nToca + para empezar.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
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
                        trailing: const Icon(Icons.edit, size: 18),
                        onTap: () => _mostrarDialogoEditarJugador(
                          context,
                          ref,
                          jugador['jugador_id'] as int,
                          jugador['jugador_nombre'] as String,
                          jugador['jugador_celular'] as String?,
                        ),
                        onLongPress: () => _mostrarDialogoFusionar(
                          context,
                          ref,
                          jugador['jugador_id'] as int,
                          jugador['jugador_nombre'] as String,
                          _candidatosDeLiga(
                            grupo['jugadores'] as List<Map<String, dynamic>>,
                            sinPartidos,
                            jugador['jugador_id'] as int,
                          ),
                        ),
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
                        trailing: const Icon(Icons.edit, size: 18),
                        onTap: () => _mostrarDialogoEditarJugador(
                          context,
                          ref,
                          jugador.id!,
                          jugador.nombre,
                          jugador.celular,
                        ),
                        onLongPress: () => _mostrarDialogoFusionar(
                          context,
                          ref,
                          jugador.id!,
                          jugador.nombre,
                          _candidatosGlobales(grupos, sinPartidos, jugador.id!),
                        ),
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
