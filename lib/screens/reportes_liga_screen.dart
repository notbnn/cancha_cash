import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constantes.dart';
import '../models/liga_categoria.dart';
import '../providers/eventos_provider.dart';
import 'movimientos_caja_chica_screen.dart'; // 👈 NUEVO
import 'reporte_evento_screen.dart';

class ReportesLigaScreen extends ConsumerWidget {
  final LigaCategoria liga;

  const ReportesLigaScreen({super.key, required this.liga});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventos = ref.watch(eventosPorLigaProvider(liga.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('Reportes · ${liga.nombre}'),
        actions: [
          // 👈 NUEVO
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Movimientos de caja chica',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovimientosCajaChicaScreen(liga: liga),
                ),
              );
            },
          ),
        ],
      ),
      body: eventos.isEmpty
          ? const Center(
              child: Text('Todavía no hay partidos en esta categoría.'),
            )
          : ListView.builder(
              itemCount: eventos.length,
              itemBuilder: (context, index) {
                final evento = eventos[index];
                final cerrado = evento.estado == EstadoEventoFecha.finalizado;
                final horaTexto =
                    '${evento.fechaExacta.hour.toString().padLeft(2, '0')}:${evento.fechaExacta.minute.toString().padLeft(2, '0')}';
                return ListTile(
                  leading: Icon(
                    cerrado ? Icons.lock : Icons.lock_open,
                    color: cerrado ? Colors.grey : Colors.green,
                  ),
                  title: Text(
                    evento.titulo?.isNotEmpty == true
                        ? evento.titulo!
                        : '${evento.fechaExacta.day}/${evento.fechaExacta.month}/${evento.fechaExacta.year}',
                  ),
                  subtitle: Text(
                    '${evento.fechaExacta.day}/${evento.fechaExacta.month}/${evento.fechaExacta.year} · $horaTexto · ${cerrado ? "Cerrado" : "Abierto"}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ReporteEventoScreen(eventoId: evento.id!),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
