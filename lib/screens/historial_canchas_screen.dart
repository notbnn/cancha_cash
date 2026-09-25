import 'dart:io';

import 'package:cancha_cash/models/liga_categoria.dart';
import 'package:cancha_cash/screens/eventos_liga_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/constantes.dart';
import '../providers/eventos_pendientes_provider.dart';
import '../providers/ligas_provider.dart';
import 'evento_detalle_screen.dart';

// Dibuja una curva tipo "ola" en el borde inferior del contenedor.
class _RecortadorCurva extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 36);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 36,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HistorialCanchasScreen extends ConsumerWidget {
  const HistorialCanchasScreen({super.key});

  Future<void> _mostrarDialogoCrearLiga(
      BuildContext context, WidgetRef ref) async {
    final controlador = TextEditingController();
    String? deporteSeleccionado;

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controlador,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Ej: Fútbol Mañana, Wally Tarde...',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Deporte'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: Deporte.todos.map((deporte) {
                  return ChoiceChip(
                    label: Text(deporte),
                    selected: deporteSeleccionado == deporte,
                    onSelected: (_) {
                      setState(() => deporteSeleccionado = deporte);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controlador.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (nombre != null && nombre.isNotEmpty) {
      await ref
          .read(ligasProvider.notifier)
          .crear(nombre, deporte: deporteSeleccionado);
    }
  }

  Future<void> _mostrarDialogoEditarLiga(
      BuildContext context, WidgetRef ref, LigaCategoria liga) async {
    final controlador = TextEditingController(text: liga.nombre);
    String? deporteSeleccionado = liga.deporte;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controlador,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Ej: Fútbol Mañana, Wally Tarde...',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Deporte'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: Deporte.todos.map((deporte) {
                  return ChoiceChip(
                    label: Text(deporte),
                    selected: deporteSeleccionado == deporte,
                    onSelected: (_) {
                      setState(() => deporteSeleccionado = deporte);
                    },
                  );
                }).toList(),
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
      ),
    );

    final nombre = controlador.text.trim();
    if (confirmado == true && nombre.isNotEmpty) {
      await ref.read(ligasProvider.notifier).editar(
            liga.id!,
            nombre: nombre,
            deporte: deporteSeleccionado,
          );
    }
  }

  Future<void> _confirmarEliminar(
      BuildContext context, WidgetRef ref, LigaCategoria liga) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text(
            'Se va a borrar "${liga.nombre}" junto con todos sus partidos y confirmaciones. No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await ref.read(ligasProvider.notifier).eliminar(liga.id!);
    }
  }

  Future<void> _mostrarOpciones(
      BuildContext context, WidgetRef ref, LigaCategoria liga) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar nombre y deporte'),
              onTap: () => Navigator.pop(context, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'eliminar'),
            ),
          ],
        ),
      ),
    );

    if (opcion == 'editar') {
      await _mostrarDialogoEditarLiga(context, ref, liga);
    } else if (opcion == 'eliminar') {
      await _confirmarEliminar(context, ref, liga);
    }
  }

  Future<void> _exportarBackup(BuildContext context) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final origen = File(p.join(docsDir.path, 'cancha_semanal.db'));

      if (!await origen.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró la base de datos.')),
          );
        }
        return;
      }

      final ahora = DateTime.now();
      final nombreArchivo =
          'backup_cancha_semanal_${ahora.year}${ahora.month.toString().padLeft(2, '0')}${ahora.day.toString().padLeft(2, '0')}_${ahora.hour.toString().padLeft(2, '0')}${ahora.minute.toString().padLeft(2, '0')}.db';

      final tempDir = await getTemporaryDirectory();
      final destino = File(p.join(tempDir.path, nombreArchivo));
      await origen.copy(destino.path);

      await Share.shareXFiles(
        [XFile(destino.path)],
        text:
            'Backup de tus ligas ($nombreArchivo) — guardalo en un lugar seguro (Drive, WhatsApp a vos mismo, etc.)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }

  Widget _tarjetaProximoPartido(
      BuildContext context, Map<String, dynamic>? proximo) {
    if (proximo == null) return const SizedBox.shrink();

    final fecha = DateTime.parse(proximo['fecha_exacta'] as String);
    final horaTexto =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    final fechaTexto = '${fecha.day}/${fecha.month}/${fecha.year}';
    final tituloPartido = (proximo['titulo'] as String?)?.isNotEmpty == true
        ? proximo['titulo'] as String
        : fechaTexto;
    final confirmados = proximo['confirmados'] as int;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text('Próximo: $tituloPartido'),
        subtitle: Text(
            '${proximo['nombre_liga']} · $fechaTexto · $horaTexto · $confirmados confirmado(s)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EventoDetalleScreen(eventoId: proximo['id'] as int),
            ),
          );
        },
      ),
    );
  }

  // 👈 NUEVO — encabezado curvo que reemplaza a la AppBar propia de esta pantalla
  Widget _encabezadoCurvo(BuildContext context, WidgetRef ref) {
    return ClipPath(
      clipper: _RecortadorCurva(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 12,
          12,
          48,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.75),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Backup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.backup, color: Colors.white),
              tooltip: 'Exportar backup',
              onPressed: () => _exportarBackup(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligas = ref.watch(ligasProvider);
    final pendientes = ref.watch(eventosPendientesProvider);
    final proximo = pendientes.isNotEmpty ? pendientes.first : null;

    return Scaffold(
      body: Column(
        children: [
          _encabezadoCurvo(context, ref), // 👈 NUEVO — antes era appBar: AppBar(...)
          _tarjetaProximoPartido(context, proximo),
          Expanded(
            child: ligas.isEmpty
                ? const Center(
                    child: Text(
                      'Todavía no creaste ninguna categoría.\nTocá el botón + para empezar.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: ligas.length,
                    itemBuilder: (context, index) {
                      final liga = ligas[index];
                      return Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      EventosLigaScreen(liga: liga)),
                            );
                          },
                          onLongPress: () =>
                              _mostrarOpciones(context, ref, liga),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Deporte.icono(liga.deporte), size: 20),
                                const SizedBox(height: 4),
                                Hero(
                                  tag: 'liga-${liga.id}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(liga.nombre,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Fondo: ${liga.saldoCajaChica.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoCrearLiga(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}