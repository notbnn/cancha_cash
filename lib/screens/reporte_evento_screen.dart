import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/constantes.dart';
import '../providers/asistencias_provider.dart';
import '../providers/caja_chica_provider.dart';
import '../providers/eventos_pendientes_provider.dart';
import '../providers/ligas_provider.dart';

class _TarjetaInforme extends StatelessWidget {
  final String titulo;
  final String fecha;
  final double reserva;
  final double descuentoCajaChica;
  final double recaudado;
  final double excedente;
  final double deficit;
  final List<Map<String, dynamic>> deudores;

  const _TarjetaInforme({
    required this.titulo,
    required this.fecha,
    required this.reserva,
    required this.descuentoCajaChica,
    required this.recaudado,
    required this.excedente,
    required this.deficit,
    required this.deudores,
  });

  Widget _fila(String etiqueta, double valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          Text(
            valor.toStringAsFixed(0),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sobro = excedente > 0;

    return Container(
      width: 720,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22C55E), Color(0xFF15803D)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CANCHA CASH',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fila('Reserva', reserva),
                if (descuentoCajaChica > 0)
                  _fila('Cubierto por caja chica', descuentoCajaChica),
                _fila('Recaudado', recaudado),
                const Divider(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sobro
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sobro ? Icons.check_circle : Icons.error_outline,
                        color: sobro
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sobro
                              ? 'Sobraron ${excedente.toStringAsFixed(0)} → van a la caja chica'
                              : 'Faltaron ${deficit.toStringAsFixed(0)} → se cobran la próxima semana',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sobro
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Deudores',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (deudores.isEmpty)
                  const Text(
                    'Nadie debe — todos al día.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ...deudores.map(
                    (d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d['nombre'] as String,
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            (d['deuda'] as double).toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Generado con Cancha Cash',
                    style: TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReporteEventoScreen extends ConsumerWidget {
  final int eventoId;

  const ReporteEventoScreen({super.key, required this.eventoId});

  Future<void> _mostrarDialogoPagoTardio(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> fila,
    int ligaId,
  ) async {
    final montoControlador = TextEditingController(
      text: fila['monto_pagado'].toString(),
    );
    String metodo = MetodoPago.qr;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Pago tardío de ${fila['nombre_jugador']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Este monto se suma directo a la caja chica de la liga (el partido ya está cerrado).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoControlador,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: MetodoPago.qr, label: Text('QR')),
                  ButtonSegment(
                    value: MetodoPago.efectivo,
                    label: Text('Efectivo'),
                  ),
                ],
                selected: {metodo},
                onSelectionChanged: (nuevo) =>
                    setState(() => metodo = nuevo.first),
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
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    final monto = double.tryParse(montoControlador.text);
    if (confirmado == true && monto != null) {
      await ref
          .read(asistenciasProvider(eventoId).notifier)
          .pagarDeudaTardia(
            asistenciaId: fila['id'] as int,
            ligaID: ligaId,
            monto: monto,
            metodo: metodo,
          );
      await ref.read(ligasProvider.notifier).cargar();
      await ref.read(eventosPendientesProvider.notifier).cargar();
    }
  }

  double _deudaDe(Map<String, dynamic> fila, double? cuotaPorPersona) {
    final pagado = (fila['monto_pagado'] as num).toDouble();
    final cuota = cuotaPorPersona ?? 0;
    final deuda = cuota - pagado;
    return deuda > 0 ? deuda : 0;
  }

  String _construirInforme(
    dynamic evento,
    dynamic resumen,
    List<Map<String, dynamic>> deben,
  ) {
    final fecha =
        '${evento.fechaExacta.day.toString().padLeft(2, '0')}/${evento.fechaExacta.month.toString().padLeft(2, '0')}/${evento.fechaExacta.year}';
    final titulo =
        (evento.titulo != null && (evento.titulo as String).isNotEmpty)
        ? evento.titulo as String
        : fecha;

    final buffer = StringBuffer()
      ..writeln('📋 Informe — $titulo')
      ..writeln('📅 $fecha')
      ..writeln()
      ..writeln(
        'Reserva: ${(evento.costoReserva as double).toStringAsFixed(0)}',
      );

    final descuento = evento.descuentoCajaChicaAplicado as double;
    if (descuento > 0) {
      buffer.writeln(
        'Cubierto por caja chica: ${descuento.toStringAsFixed(0)}',
      );
    }

    buffer
      ..writeln(
        'Recaudado: ${(resumen.recaudado as double).toStringAsFixed(0)}',
      )
      ..writeln();

    if ((resumen.excedente as double) > 0) {
      buffer.writeln(
        '✅ Sobraron ${(resumen.excedente as double).toStringAsFixed(0)} → van a la caja chica',
      );
    } else {
      buffer.writeln(
        '⚠️ Faltaron ${(resumen.deficit as double).toStringAsFixed(0)} → se cobran la próxima semana junto con la cuota',
      );
    }

    buffer
      ..writeln()
      ..writeln('Deudores:');

    if (deben.isEmpty) {
      buffer.writeln('Nadie debe — todos al día.');
    } else {
      for (final fila in deben) {
        final deuda = _deudaDe(fila, evento.cuotaPorPersona as double?);
        buffer.writeln(
          '- ${fila['nombre_jugador']} (${deuda.toStringAsFixed(0)})',
        );
      }
    }

    return buffer.toString().trim();
  }

  Future<void> _compartirComoImagen(
    BuildContext context,
    GlobalKey tarjetaKey,
    String textoInforme,
  ) async {
    try {
      final boundary =
          tarjetaKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final imagen = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await imagen.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final archivo = File(p.join(tempDir.path, 'informe_partido.png'));
      await archivo.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(archivo.path)], text: textoInforme);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar la imagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asistencias = ref.watch(asistenciasProvider(eventoId));
    final resumen = ref.watch(cajaChicaProvider(eventoId));
    final eventoAsync = ref.watch(eventoFechaProvider(eventoId));
    final ligas = ref.watch(ligasProvider);

    final evento = eventoAsync.value;
    final ligaId = evento?.ligaId;

    final pagaron = asistencias
        .where((f) => f['estado'] == EstadoAsistencia.pagado)
        .length;
    final deben = asistencias
        .where((f) => f['estado'] == EstadoAsistencia.debe)
        .toList();

    final tarjetaKey = GlobalKey();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte del partido'),
        actions: [
          if (evento != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Compartir informe',
              onPressed: () {
                final texto = _construirInforme(evento, resumen, deben);
                _compartirComoImagen(context, tarjetaKey, texto);
              },
            ),
        ],
      ),
      body: ligaId == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _dato('Recaudado', resumen.recaudado),
                                _dato('Meta', resumen.meta),
                                _dato(
                                  resumen.excedente > 0 ? 'Excedente' : 'Falta',
                                  resumen.excedente > 0
                                      ? resumen.excedente
                                      : resumen.deficit,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 160,
                              child: (pagaron == 0 && deben.isEmpty)
                                  ? const Center(child: Text('Nadie inscripto'))
                                  : PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 30,
                                        sections: [
                                          PieChartSectionData(
                                            value: pagaron.toDouble(),
                                            color: Colors.green,
                                            title: '$pagaron pagó',
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: deben.length.toDouble(),
                                            color: Colors.red,
                                            title: '${deben.length} debe',
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Caja chica de la liga (actual)'),
                            Text(
                              _saldoLiga(ligas, ligaId).toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Deudores (${deben.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (deben.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Nadie debe — quedó todo cobrado.'),
                      )
                    else
                      ...deben.map(
                        (fila) => Card(
                          child: ListTile(
                            title: Text(fila['nombre_jugador'] as String),
                            subtitle: Text(
                              'Debe ${_deudaDe(fila, evento?.cuotaPorPersona).toStringAsFixed(0)}',
                            ),
                            trailing: TextButton(
                              onPressed: () => _mostrarDialogoPagoTardio(
                                context,
                                ref,
                                fila,
                                ligaId,
                              ),
                              child: const Text('Marcar pagado'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (evento != null)
                  Positioned(
                    left: -9999,
                    top: 0,
                    child: RepaintBoundary(
                      key: tarjetaKey,
                      child: _TarjetaInforme(
                        titulo:
                            (evento.titulo != null && evento.titulo!.isNotEmpty)
                            ? evento.titulo!
                            : '${evento.fechaExacta.day.toString().padLeft(2, '0')}/${evento.fechaExacta.month.toString().padLeft(2, '0')}/${evento.fechaExacta.year}',
                        fecha:
                            '${evento.fechaExacta.day.toString().padLeft(2, '0')}/${evento.fechaExacta.month.toString().padLeft(2, '0')}/${evento.fechaExacta.year}',
                        reserva: evento.costoReserva,
                        descuentoCajaChica: evento.descuentoCajaChicaAplicado,
                        recaudado: resumen.recaudado,
                        excedente: resumen.excedente,
                        deficit: resumen.deficit,
                        deudores: deben
                            .map(
                              (fila) => {
                                'nombre': fila['nombre_jugador'] as String,
                                'deuda': _deudaDe(fila, evento.cuotaPorPersona),
                              },
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _dato(String etiqueta, double valor) {
    return Column(
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 12)),
        Text(
          valor.toStringAsFixed(0),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  double _saldoLiga(List ligas, int ligaId) {
    final liga = ligas.firstWhere((l) => l.id == ligaId);
    return liga.saldoCajaChica as double;
  }
}
