import 'package:flutter/material.dart';

class EstadoAsistencia {
  static const debe = 'Debe';
  static const pagado = 'Pagado';
}

class MetodoPago {
  static const qr = 'QR';
  static const efectivo = 'Efectivo';
  static const cajaChica = 'Caja Chica';
}

class EstadoEventoFecha {
  static const pendiente = 'pendiente';
  static const finalizado = 'finalizado';
}

class Deporte {
  static const futbol = 'Fútbol';
  static const volley = 'Vóley';
  static const basket = 'Básket';
  static const wally = 'Wally';
  static const raquet = 'Ráquet';
  static const tenis = 'Tenis';
  static const padel = 'Pádel';
  static const otros = 'Otros';

  static const todos = [
    futbol,
    volley,
    basket,
    wally,
    raquet,
    tenis,
    padel,
    otros,
  ];

  static IconData icono(String? deporte) {
    switch (deporte) {
      case futbol:
        return Icons.sports_soccer;
      case volley:
        return Icons.sports_volleyball;
      case basket:
        return Icons.sports_basketball;
      case wally:
        return Icons.sports_handball;
      case raquet:
      case tenis:
      case padel:
        return Icons.sports_tennis;
      case otros:
        return Icons.sports;
      default:
        return Icons.sports;
    }
  }
}
