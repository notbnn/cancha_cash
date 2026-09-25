import 'dart:io';

import 'package:cancha_cash/screens/reporte_evento_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/constantes.dart';
import '../providers/asistencias_provider.dart';
import '../providers/caja_chica_provider.dart';
import '../providers/eventos_pendientes_provider.dart';
import '../providers/ligas_provider.dart';
import '../providers/repository_providers.dart';
import '../models/evento_fecha.dart';
import 'dart:convert';

import '../services/backend_api.dart';
import '../providers/eventos_provider.dart';
import '../providers/reportes_provider.dart';

class EventoDetalleScreen extends ConsumerWidget {
  final int eventoId;

  const EventoDetalleScreen({super.key, required this.eventoId});

  Future<void> _subirQr(BuildContext context, WidgetRef ref) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Sacar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;

    final archivo = await ImagePicker().pickImage(source: origen, imageQuality: 85);
    if (archivo == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final destino = p.join(docsDir.path, 'qr_evento_$eventoId.jpg');
    await File(archivo.path).copy(destino);

    await ref.read(eventoFechaRepositoryProvider).actualizarQr(eventoId, destino);
    ref.invalidate(eventoFechaProvider(eventoId));

    try {
      final evento = await ref.read(eventoFechaRepositoryProvider).obtenerPorId(eventoId);
      if (evento?.uuid != null && evento?.adminToken != null) {
        final bytes = await File(archivo.path).readAsBytes();
        final mime = _mimeDesdeRuta(archivo.path);
        final datos = base64Encode(bytes);
        await BackendApi().subirQr(
          eventoIdBackend: evento!.uuid!,
          adminToken: evento.adminToken!,
          qrBase64: 'data:$mime;base64,$datos',
        );
      }
    } catch (e) {
      debugPrint('No se pudo subir el QR al backend: $e');
    }
  }

  String _mimeDesdeRuta(String ruta) {
    final ext = ruta.toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _verQrCompleto(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(child: Image.file(File(path))),
    );
  }

  Widget _tarjetaQr(BuildContext context, WidgetRef ref, String? qrPath) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: qrPath == null
            ? OutlinedButton.icon(
                onPressed: () => _subirQr(context, ref),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Subir QR de cobro'),
              )
            : Column(
                children: [
                  GestureDetector(
                    onTap: () => _verQrCompleto(context, qrPath),
                    child: Image.file(File(qrPath), height: 160),
                  ),
                  TextButton(
                    onPressed: () => _subirQr(context, ref),
                    child: const Text('Cambiar QR'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _mostrarDialogoAgregarJugador(
      BuildContext context, WidgetRef ref) async {
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir jugador en cancha'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre del jugador'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controlador.text.trim()),
              child: const Text('Añadir')),
        ],
      ),
    );

    if (nombre != null && nombre.isNotEmpty) {
      await ref.read(asistenciasProvider(eventoId).notifier).agregarJugador(nombre);
    }
  }

  Future<void> _mostrarDialogoEditarTitulo(
      BuildContext context, WidgetRef ref, EventoFecha? evento) async {
    if (evento == null) return;
    final controlador = TextEditingController(text: evento.titulo ?? '');

    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nombre del partido'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Bajo Llojeta'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controlador.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (nuevoTitulo != null) {
      await ref
          .read(eventoFechaRepositoryProvider)
          .actualizarTitulo(eventoId, nuevoTitulo.isEmpty ? null : nuevoTitulo);
      ref.invalidate(eventoFechaProvider(eventoId));
    }
  }

  Future<void> _mostrarDialogoEditarCuota(
      BuildContext context, WidgetRef ref, EventoFecha? evento) async {
    if (evento == null) return;
    final controlador = TextEditingController(
      text: evento.cuotaPorPersona != null
          ? evento.cuotaPorPersona!.toStringAsFixed(0)
          : '',
    );

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuota por persona'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Vacío = sin cuota fija (carga el monto a mano)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controlador.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (resultado != null) {
      final nuevaCuota = resultado.isEmpty ? null : double.tryParse(resultado);
      await ref
          .read(eventoFechaRepositoryProvider)
          .actualizarCuota(eventoId, nuevaCuota);
      ref.invalidate(eventoFechaProvider(eventoId));
      await ref.read(morososProvider.notifier).cargar(); 
    }
  }

  Future<void> _mostrarDialogoPago(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> fila, {
    double? cuotaPorPersona,
  }) async {
    final montoPagadoActual = (fila['monto_pagado'] as num).toDouble();
    final montoSugerido =
        montoPagadoActual > 0 ? montoPagadoActual : (cuotaPorPersona ?? 0);
    final montoControlador = TextEditingController(
      text: montoSugerido > 0 ? montoSugerido.toStringAsFixed(0) : '',
    );
    String metodo = MetodoPago.qr;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Pago de ${fila['nombre_jugador']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      value: MetodoPago.efectivo, label: Text('Efectivo')),
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
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar')),
          ],
        ),
      ),
    );

    final monto = double.tryParse(montoControlador.text);
    if (confirmado == true && monto != null) {
      await ref.read(asistenciasProvider(eventoId).notifier).marcarPagado(
            fila['id'] as int,
            monto: monto,
            metodo: metodo,
          );
    }
  }

  Future<bool> _confirmarEliminarAsistencia(
      BuildContext context, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar inscripción?'),
        content: Text('Se va a borrar a "$nombre" de este partido.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Borrar')),
        ],
      ),
    );
    return confirmado ?? false;
  }

  void _compartir(BuildContext context, EventoFecha? evento) {
    final link = evento?.linkPublico;
    if (link == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Este partido todavía no tiene link generado.')),
      );
      return;
    }
    Share.share('¡Vengan a jugar! Confirma tu asistencia acá: $link');
  }

  // Animación corta de "listo" antes de ir al reporte al cerrar
  Future<void> _mostrarAnimacionListo(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, valor, child) => Transform.scale(
            scale: valor,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 48),
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 700));
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _cerrarPartido(BuildContext context, WidgetRef ref) async {
    final resumen = ref.read(cajaChicaProvider(eventoId));
    final evento = await ref.read(eventoFechaRepositoryProvider).obtenerPorId(eventoId);
    if (evento == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar partido?'),
        content: Text(
          resumen.excedente > 0
              ? 'Se va a sumar ${resumen.excedente.toStringAsFixed(0)} al fondo de la liga.'
              : 'No hubo excedente esta vez.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar')),
        ],
      ),
    );

    if (confirmar == true) {
      await ref.read(eventoFechaRepositoryProvider).finalizarConExcedente(
            eventoId: eventoId,
            ligaId: evento.ligaId,
            excedente: resumen.excedente,
          );
      ref.invalidate(eventoFechaProvider(eventoId));
      await ref.read(ligasProvider.notifier).cargar();
      await ref.read(eventosPendientesProvider.notifier).cargar();
      await ref.read(eventosPorLigaProvider(evento.ligaId).notifier).cargar();
      if (context.mounted) {
        await _mostrarAnimacionListo(context);
      }
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReporteEventoScreen(eventoId: eventoId))
        );
      }
    }
  }

  Future<void> _sincronizar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(asistenciasProvider(eventoId).notifier).sincronizar();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sincronizado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al sincronizar: $e')));
      }
    }
  }

  Widget _dato(String etiqueta, double valor) {
    return Column(
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 12)),
        Text(valor.toStringAsFixed(0),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asistencias = ref.watch(asistenciasProvider(eventoId));
    final resumen = ref.watch(cajaChicaProvider(eventoId));
    final eventoAsync = ref.watch(eventoFechaProvider(eventoId));
    final cerrado = eventoAsync.value?.estado == EstadoEventoFecha.finalizado;
    final cuotaPorPersona = eventoAsync.value?.cuotaPorPersona;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de cobros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir link',
            onPressed: () => _compartir(context, eventoAsync.value),
          ),
          PopupMenuButton<String>(
            onSelected: (valor) {
              switch (valor) {
                case 'cerrar':
                  _cerrarPartido(context, ref);
                  break;
                case 'editar_titulo':
                  _mostrarDialogoEditarTitulo(context, ref, eventoAsync.value);
                  break;
                case 'editar_cuota':
                  _mostrarDialogoEditarCuota(context, ref, eventoAsync.value);
                  break;
                case 'reporte':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (
                        (context) => ReporteEventoScreen(eventoId: eventoId)),
                    )
                  );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'editar_titulo',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Editar nombre'),
                ),
              ),
              const PopupMenuItem(
                value: 'editar_cuota',
                child: ListTile(
                  leading: Icon(Icons.payments),
                  title: Text('Editar cuota'),
                ),
              ),
              const PopupMenuItem(
                value: 'reporte',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Ver reporte'),
                ),
              ),
              if (!cerrado)
                const PopupMenuItem(
                  value: 'cerrar',
                  child: ListTile(
                    leading: Icon(Icons.flag),
                    title: Text('Cerrar partido'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (cerrado)
            Container(
              width: double.infinity,
              color: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Partido cerrado',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          eventoAsync.when(
            data: (evento) => _tarjetaQr(context, ref, evento?.qrImagenPath),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Card(
            margin: const EdgeInsets.all(12),
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
                        resumen.excedente > 0 ? resumen.excedente : resumen.deficit,
                      ),
                    ],
                  ),
                  if (cuotaPorPersona != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Cuota por persona: ${cuotaPorPersona.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _sincronizar(context, ref),
              child: asistencias.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(
                          child: Text(
                              'Nadie registrado todavía. Usa el botón + para agregar.'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: asistencias.length,
                      itemBuilder: (context, index) {
                        final fila = asistencias[index];
                        final pagado = fila['estado'] == EstadoAsistencia.pagado;
                        return Dismissible(
                          key: ValueKey(fila['id']),
                          direction: cerrado
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) => _confirmarEliminarAsistencia(
                              context, fila['nombre_jugador'] as String),
                          onDismissed: (_) => ref
                              .read(asistenciasProvider(eventoId).notifier)
                              .eliminar(fila['id'] as int),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            color: pagado
                                ? Colors.green.withOpacity(0.15)
                                : Colors.transparent,
                            child: CheckboxListTile(
                              value: pagado,
                              title: Text(fila['nombre_jugador'] as String),
                              subtitle: Text(pagado
                                  ? '${fila['metodo_pago']} · ${fila['monto_pagado']}'
                                  : 'Debe'),
                              onChanged: cerrado
                                ? null
                                : (marcado) async {
                                if (marcado == true) {
                                  await _mostrarDialogoPago(
                                    context, ref, fila,
                                    cuotaPorPersona: cuotaPorPersona,
                                  );
                                } else {
                                  await ref
                                      .read(asistenciasProvider(eventoId).notifier)
                                      .desmarcar(fila['id'] as int);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: cerrado
        ? null
        : FloatingActionButton(
        onPressed: () => _mostrarDialogoAgregarJugador(context, ref),
        tooltip: 'Añadir Jugador en Cancha',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}