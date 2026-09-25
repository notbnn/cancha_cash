import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/liga_categoria.dart';
import '../providers/ligas_provider.dart';
import '../providers/movimientos_caja_chica_provider.dart';
import '../providers/repository_providers.dart';

class _TarjetaResumenCajaChica extends StatelessWidget {
  final String nombreLiga;
  final double saldoActual;
  final double totalIngresos;
  final double totalGastos;
  final List<Map<String, dynamic>> movimientos;

  const _TarjetaResumenCajaChica({
    required this.nombreLiga,
    required this.saldoActual,
    required this.totalIngresos,
    required this.totalGastos,
    required this.movimientos,
  });

  Widget _fila(String etiqueta, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: const TextStyle(fontSize: 15, color: Colors.black54)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Caja chica',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    nombreLiga,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _fila('Saldo actual', 'Bs ${saldoActual.toStringAsFixed(0)}',
                color: const Color(0xFF2E7D32)),
            _fila('Total ingresos', '+ Bs ${totalIngresos.toStringAsFixed(0)}',
                color: Colors.green),
            _fila('Total gastos', '- Bs ${totalGastos.toStringAsFixed(0)}',
                color: Colors.red),
            const Divider(height: 28),
            const Text('Movimientos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...movimientos.map((mov) {
              final monto = (mov['monto'] as num).toDouble();
              final entrada = monto >= 0;
              final fecha = DateTime.parse(mov['creado_en'] as String);
              final fechaTexto =
                  '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${mov['descripcion']} · $fechaTexto',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),
                    ),
                    Text(
                      '${entrada ? '+' : ''}${monto.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: entrada ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Center(
              child: Text('Generado con Cancha Cash',
                  style: TextStyle(fontSize: 11, color: Colors.black38)),
            ),
          ],
        ),
      ),
    );
  }
}

class MovimientosCajaChicaScreen extends ConsumerWidget {
  final LigaCategoria liga;

  const MovimientosCajaChicaScreen({super.key, required this.liga});

  Future<void> _mostrarDialogoRegistrarMovimiento(
      BuildContext context, WidgetRef ref) async {
    final descripcionControlador = TextEditingController();
    final montoControlador = TextEditingController();
    String tipo = 'gasto';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Registrar movimiento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'gasto', label: Text('Gasto')),
                  ButtonSegment(value: 'ingreso', label: Text('Ingreso')),
                ],
                selected: {tipo},
                onSelectionChanged: (nuevo) =>
                    setState(() => tipo = nuevo.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionControlador,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Hora extra de cancha',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoControlador,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto'),
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

    final montoIngresado = double.tryParse(montoControlador.text);
    final descripcion = descripcionControlador.text.trim();

    if (confirmado == true &&
        montoIngresado != null &&
        montoIngresado > 0 &&
        descripcion.isNotEmpty) {
      final montoConSigno = tipo == 'gasto' ? -montoIngresado : montoIngresado;

      await ref
          .read(movimientoCajaChicaRepositoryProvider)
          .registrarMovimiento(
            ligaId: liga.id!,
            monto: montoConSigno,
            descripcion: descripcion,
          );

      ref.invalidate(movimientosCajaChicaProvider(liga.id!));
      await ref.read(ligasProvider.notifier).cargar();
    }
  }

  void _compartirMovimiento(Map<String, dynamic> mov) {
    final monto = (mov['monto'] as num).toDouble();
    final entrada = monto >= 0;
    final fecha = DateTime.parse(mov['creado_en'] as String);
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    final texto = '${entrada ? '💰 Ingreso' : '💸 Gasto'} de caja chica · ${liga.nombre}\n'
        '${mov['descripcion']}\n'
        'Monto: ${entrada ? '+' : '-'}Bs ${monto.abs().toStringAsFixed(0)}\n'
        'Fecha: $fechaTexto';

    Share.share(texto);
  }

  Future<void> _compartirResumenComoImagen(
    BuildContext context,
    GlobalKey tarjetaKey,
    String textoResumen,
  ) async {
    try {
      final boundary = tarjetaKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final imagen = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await imagen.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final archivo = File(p.join(tempDir.path, 'caja_chica_${liga.id}.png'));
      await archivo.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(archivo.path)], text: textoResumen);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientosAsync = ref.watch(movimientosCajaChicaProvider(liga.id!));
    final tarjetaKey = GlobalKey();

    final movimientosParaTarjeta = movimientosAsync.value ?? [];
    final totalIngresos = movimientosParaTarjeta
        .where((m) => (m['monto'] as num) >= 0)
        .fold<double>(0, (s, m) => s + (m['monto'] as num).toDouble());
    final totalGastos = movimientosParaTarjeta
        .where((m) => (m['monto'] as num) < 0)
        .fold<double>(0, (s, m) => s + (m['monto'] as num).abs());
    final saldoActual = totalIngresos - totalGastos;

    return Scaffold(
      appBar: AppBar(
        title: Text('Caja chica · ${liga.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Compartir resumen',
            onPressed: movimientosParaTarjeta.isEmpty
                ? null
                : () => _compartirResumenComoImagen(
                      context,
                      tarjetaKey,
                      'Caja chica de ${liga.nombre}: saldo actual Bs ${saldoActual.toStringAsFixed(0)}',
                    ),
          ),
        ],
      ),
      body: Stack(
        children: [
          movimientosAsync.when(
            data: (lista) {
              if (lista.isEmpty) {
                return const Center(child: Text('Todavía no hay movimientos.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (context, index) {
                  final mov = lista[index];
                  final monto = (mov['monto'] as num).toDouble();
                  final entrada = monto >= 0;
                  final fecha = DateTime.parse(mov['creado_en'] as String);
                  final fechaTexto =
                      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        entrada ? Icons.add_circle : Icons.remove_circle,
                        color: entrada ? Colors.green : Colors.red,
                      ),
                      title: Text(mov['descripcion'] as String),
                      subtitle: Text(fechaTexto),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${entrada ? '+' : ''}${monto.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: entrada ? Colors.green : Colors.red,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 18),
                            tooltip: 'Compartir',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _compartirMovimiento(mov),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          Positioned(
            left: -9999,
            top: 0,
            child: RepaintBoundary(
              key: tarjetaKey,
              child: _TarjetaResumenCajaChica(
                nombreLiga: liga.nombre,
                saldoActual: saldoActual,
                totalIngresos: totalIngresos,
                totalGastos: totalGastos,
                movimientos: movimientosParaTarjeta,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoRegistrarMovimiento(context, ref),
        tooltip: 'Registrar movimiento',
        child: const Icon(Icons.add),
      ),
    );
  }
}