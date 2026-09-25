import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'historial_canchas_screen.dart';
import 'lista_amigos_screen.dart';
import 'panel_cobros_screen.dart';
import 'reportes_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _indiceSeleccionado = 0;

  List<Widget> get _pantallas => [
        HistorialCanchasScreen(),
        PanelCobrosScreen(),
        ListaAmigosScreen(),
        ReportesScreen(),
      ];

  static const _titulos = [
    'Eventos programados',
    'Panel de cobros',
    'Lista de amigos',
    'Reportes',
  ];

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_indiceSeleccionado]),
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pantallas[_indiceSeleccionado],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceSeleccionado,
        onDestinationSelected: (indice) =>
            setState(() => _indiceSeleccionado = indice),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Eventos',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Cobros',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Amigos',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}