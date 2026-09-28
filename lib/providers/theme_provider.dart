import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Arranca en 'system' (sigue el tema del celular). El botón del AppBar
/// lo fuerza a claro u oscuro.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
