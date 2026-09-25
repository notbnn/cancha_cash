import 'package:cancha_cash/screens/evento_detalle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/eventos_pendientes_provider.dart';

class PanelCobrosScreen extends ConsumerWidget {
  const PanelCobrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientes = ref.watch(eventosPendientesProvider);

    if (pendientes.isEmpty) {
      return const Center(child: Text('No hay partidos pendientes todavía.'));
    }

    return ListView.builder(
      itemCount: pendientes.length,
      itemBuilder: (context, index) {
        final fila = pendientes[index];
        final fecha = DateTime.parse(fila['fecha_exacta'] as String);
                return ListTile(
          leading: const Icon(Icons.sports_soccer),
          title: Text((fila['titulo'] as String?)?.isNotEmpty == true
              ? '${fila['nombre_liga']} — ${fila['titulo']}'
              : '${fila['nombre_liga']} — ${fecha.day}/${fecha.month}/${fecha.year}'),
          subtitle: Text(
              '${fecha.day}/${fecha.month}/${fecha.year} · Meta: ${(fila['meta_recaudacion'] as num).toStringAsFixed(0)}'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EventoDetalleScreen(eventoId: fila['id'] as int)),
            );
          },
        );
      },
    );
  }
}