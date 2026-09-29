import 'package:flutter/material.dart';

class EstadoAsistencia {
  static const debe = 'Debe';
  static const pagado = 'Pagado';
}

class MetodoPago {
  static const qr = 'QR';
  static const efectivo = 'Efectivo';
  static const cajaChica = 'Caja Chica';

  /// Convierte el string que manda el backend ("qr"/"efectivo", elegido
  /// por el invitado en la web) al valor que usa la app acá adentro.
  /// Si no lo reconoce (o es null), devuelve null — la pantalla cae al
  /// default de siempre (QR).
  static String? desdeBackend(String? valor) {
    switch (valor) {
      case 'qr':
        return qr;
      case 'efectivo':
        return efectivo;
      default:
        return null;
    }
  }
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

