// eventos_liga_screen.dart — único cambio: el título del AppBar ahora está envuelto en el mismo Hero
import 'package:cancha_cash/models/evento_fecha.dart';
import 'package:cancha_cash/screens/evento_detalle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constantes.dart';
import '../models/liga_categoria.dart';
import '../providers/eventos_provider.dart';
import '../providers/ligas_provider.dart';

class EventosLigaScreen extends ConsumerWidget {
  final LigaCategoria liga;

  const EventosLigaScreen({super.key, required this.liga});

  String _formatoHora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  Future<void> _mostrarDialogoCrearEvento(
      BuildContext context, WidgetRef ref) async {
    DateTime fechaElegida = DateTime.now().add(const Duration(days: 7));
    TimeOfDay horaInicioElegida = const TimeOfDay(hour: 20, minute: 0);
    TimeOfDay horaFinElegida = const TimeOfDay(hour: 22, minute: 0);
    final tituloControlador = TextEditingController();
    final costoControlador = TextEditingController();
    final cuotaControlador = TextEditingController();
    bool usarCajaChica = false;
    final cajaChicaControlador = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo partido'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: tituloControlador,
                  decoration: const InputDecoration(
                    labelText: 'Título (opcional)',
                    hintText: 'Ej: Bajo Llojeta',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Fecha: ${fechaElegida.day}/${fechaElegida.month}/${fechaElegida.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final elegida = await showDatePicker(
                      context: context,
                      initialDate: fechaElegida,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (elegida != null) setState(() => fechaElegida = elegida);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Desde: ${horaInicioElegida.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final elegida = await showTimePicker(
                      context: context,
                      initialTime: horaInicioElegida,
                    );
                    if (elegida != null) {
                      setState(() => horaInicioElegida = elegida);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Hasta: ${horaFinElegida.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final elegida = await showTimePicker(
                      context: context,
                      initialTime: horaFinElegida,
                    );
                    if (elegida != null) {
                      setState(() => horaFinElegida = elegida);
                    }
                  },
                ),
                TextField(
                  controller: costoControlador,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Costo de la reserva'),
                ),
                TextField(
                  controller: cuotaControlador,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cuota por persona (opcional)',
                    hintText: 'Si la dejás vacía, cargás el monto a mano',
                  ),
                ),
                if (liga.saldoCajaChica > 0) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: usarCajaChica,
                    title: Text(
                        'Usar caja chica (disponible: ${liga.saldoCajaChica.toStringAsFixed(0)})'),
                    onChanged: (valor) =>
                        setState(() => usarCajaChica = valor ?? false),
                  ),
                  if (usarCajaChica)
                    TextField(
                      controller: cajaChicaControlador,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '¿Cuánto usar? (máx. ${liga.saldoCajaChica.toStringAsFixed(0)})',
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    final costo = double.tryParse(costoControlador.text);
    if (confirmado == true && costo != null && costo > 0) {
      double descuento = 0;
      if (usarCajaChica) {
        final ingresado = double.tryParse(cajaChicaControlador.text) ?? 0;
        descuento = ingresado.clamp(0, liga.saldoCajaChica);
      }

      final titulo = tituloControlador.text.trim();

      final cuotaIngresada = double.tryParse(cuotaControlador.text);
      final cuotaPorPersona =
          (cuotaIngresada != null && cuotaIngresada > 0) ? cuotaIngresada : null;

      final fechaConHora = DateTime(
        fechaElegida.year,
        fechaElegida.month,
        fechaElegida.day,
        horaInicioElegida.hour,
        horaInicioElegida.minute,
      );

      await ref.read(eventosPorLigaProvider(liga.id!).notifier).crear(
            titulo: titulo.isEmpty ? null : titulo,
            fechaExacta: fechaConHora,
            horaFin: _formatoHora(horaFinElegida),
            costoReserva: costo,
            cuotaPorPersona: cuotaPorPersona,
            descuentoCajaChicaAplicado: descuento,
          );

      await ref.read(ligasProvider.notifier).cargar();
    }
  }

  Future<void> _confirmarEliminarEvento(
      BuildContext context, WidgetRef ref, EventoFecha evento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar partido?'),
        content: const Text(
            'Se va a borrar este partido y sus inscripciones. Solo se puede si todavía no se registró ningún pago.'),
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

    if (confirmar != true) return;

    try {
      await ref.read(eventosPorLigaProvider(liga.id!).notifier).eliminar(evento.id!);
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No se puede borrar'),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventos = ref.watch(eventosPorLigaProvider(liga.id!));

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'liga-${liga.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(liga.nombre),
          ),
        ),
      ),
      body: eventos.isEmpty
          ? const Center(
              child: Text('Todavía no hay partidos en esta categoría.'))
          : ListView.builder(
              itemCount: eventos.length,
              itemBuilder: (context, index) {
                final evento = eventos[index];
                final horaTexto =
                    '${evento.fechaExacta.hour.toString().padLeft(2, '0')}:${evento.fechaExacta.minute.toString().padLeft(2, '0')}';
                final cuotaTexto = evento.cuotaPorPersona != null
                    ? ' · Cuota: ${evento.cuotaPorPersona!.toStringAsFixed(0)}'
                    : '';
                return ListTile(
                  title: Text(evento.titulo?.isNotEmpty == true
                      ? evento.titulo!
                      : '${evento.fechaExacta.day}/${evento.fechaExacta.month}/${evento.fechaExacta.year}'),
                  subtitle: Text(
                      '${evento.fechaExacta.day}/${evento.fechaExacta.month}/${evento.fechaExacta.year} · $horaTexto · Meta: ${evento.metaRecaudacion.toStringAsFixed(0)}$cuotaTexto · ${evento.estado}'),
                  trailing: evento.estado == EstadoEventoFecha.finalizado
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.pending_outlined),
                  onLongPress: () => _confirmarEliminarEvento(context, ref, evento),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EventoDetalleScreen(eventoId: evento.id!)),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoCrearEvento(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}