import 'dart:convert';
import 'package:http/http.dart' as http;

/// Único lugar de la app que le habla por HTTP al backend. Nada de
/// lógica de negocio acá — solo arma el request, lo manda, y devuelve
/// el JSON ya decodificado para que el que lo llama decida qué hacer.
class BackendApi {
  // OJO: esta URL depende de dónde estés probando la app — la ajustamos
  // en el próximo paso según tu caso (emulador, celular físico o
  // escritorio).
  static const String _baseUrl = "https://canchacash.up.railway.app";

  /// Arma la URL pública completa a partir del slug que devuelve el
  /// backend — es la que la app va a guardar como `linkPublico`.
  static String urlPublica(String slug) => "$_baseUrl/e/$slug";

  /// Crea el evento en el backend — se llama justo después de crearlo
  /// local. Devuelve el JSON completo de la respuesta (id, slug,
  /// adminToken, etc.) tal cual lo manda el servidor.
  Future<Map<String, dynamic>> crearEvento({
    required DateTime fecha,
    String? nombreCancha,
    String? horaFin,
    String? titulo,
  }) async {
    final respuesta = await http.post(
      Uri.parse("$_baseUrl/api/eventos"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "fecha": fecha.toUtc().toIso8601String(),
        // ignore: use_null_aware_elements
        if (nombreCancha != null) "nombreCancha": nombreCancha,
        // ignore: use_null_aware_elements
        if (horaFin != null) "horaFin": horaFin,
        // ignore: use_null_aware_elements
        if (titulo != null) "titulo": titulo,
      }),
    );

    if (respuesta.statusCode != 201) {
      throw Exception(
        "No se pudo crear el evento en el backend: ${respuesta.body}",
      );
    }

    return jsonDecode(respuesta.body) as Map<String, dynamic>;
  }

  /// Trae las confirmaciones del evento, para sincronizar localmente.
  Future<List<Map<String, dynamic>>> obtenerConfirmaciones({
    required String eventoIdBackend,
    required String adminToken,
  }) async {
    final respuesta = await http.get(
      Uri.parse("$_baseUrl/api/eventos/$eventoIdBackend/confirmaciones"),
      headers: {"x-admin-token": adminToken},
    );

    if (respuesta.statusCode != 200) {
      throw Exception(
        "No se pudieron traer las confirmaciones: ${respuesta.body}",
      );
    }

    final lista = jsonDecode(respuesta.body) as List<dynamic>;
    return lista.cast<Map<String, dynamic>>();
  }

  /// Corrige el nombre de una confirmacion puntual — se usa cuando el
  /// organizador renombra un jugador en la app y ese jugador ya habia
  /// confirmado por la web para este partido (todavia abierto).
  Future<void> corregirNombreConfirmacion({
    required String eventoIdBackend,
    required String adminToken,
    required String confirmacionId,
    required String nombreInvitado,
  }) async {
    final respuesta = await http.patch(
      Uri.parse(
        "$_baseUrl/api/eventos/$eventoIdBackend/confirmaciones/$confirmacionId",
      ),
      headers: {
        "Content-Type": "application/json",
        "x-admin-token": adminToken,
      },
      body: jsonEncode({"nombreInvitado": nombreInvitado}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(
        "No se pudo corregir el nombre en el backend: ${respuesta.body}",
      );
    }
  }

  /// Actualiza el link de ubicacion (Google Maps) del evento. Es texto
  /// libre tal cual lo comparte la app de Maps — no se valida formato
  /// del lado de la app, el backend tampoco lo valida como URL real.
  Future<void> actualizarUbicacion({
    required String eventoIdBackend,
    required String adminToken,
    required String ubicacionUrl,
  }) async {
    final respuesta = await http.patch(
      Uri.parse("$_baseUrl/api/eventos/$eventoIdBackend"),
      headers: {
        "Content-Type": "application/json",
        "x-admin-token": adminToken,
      },
      body: jsonEncode({"ubicacionUrl": ubicacionUrl}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(
        "No se pudo actualizar la ubicacion en el backend: ${respuesta.body}",
      );
    }
  }

  /// Actualiza el nombre que el organizador le puso al partido (ej.
  /// "Bajo Llojeta") — la pagina publica lo muestra como titulo arriba
  /// de todo en vez de "Partido semanal".
  Future<void> actualizarTitulo({
    required String eventoIdBackend,
    required String adminToken,
    required String titulo,
  }) async {
    final respuesta = await http.patch(
      Uri.parse("$_baseUrl/api/eventos/$eventoIdBackend"),
      headers: {
        "Content-Type": "application/json",
        "x-admin-token": adminToken,
      },
      body: jsonEncode({"titulo": titulo}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(
        "No se pudo actualizar el titulo en el backend: ${respuesta.body}",
      );
    }
  }

  /// Le avisa al backend que el partido se cerro, para que la pagina
  /// publica deje de aceptar confirmaciones nuevas de inmediato.
  Future<void> cerrarEvento({
    required String eventoIdBackend,
    required String adminToken,
  }) async {
    final respuesta = await http.patch(
      Uri.parse("$_baseUrl/api/eventos/$eventoIdBackend"),
      headers: {
        "Content-Type": "application/json",
        "x-admin-token": adminToken,
      },
      body: jsonEncode({"estado": "cerrado"}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(
        "No se pudo cerrar el evento en el backend: ${respuesta.body}",
      );
    }
  }

  /// Sube el QR de cobro al backend, como base64 (no hace falta ningún
  /// servicio de hosting de imágenes — el string se guarda tal cual en
  /// el campo `qrUrl`, y la página pública lo puede mostrar directo en
  /// un `<img src="...">`).
  Future<void> subirQr({
    required String eventoIdBackend,
    required String adminToken,
    required String qrBase64,
  }) async {
    final respuesta = await http.post(
      Uri.parse("$_baseUrl/api/eventos/$eventoIdBackend/qr"),
      headers: {
        "Content-Type": "application/json",
        "x-admin-token": adminToken,
      },
      body: jsonEncode({"qrUrl": qrBase64}),
    );

    if (respuesta.statusCode != 200) {
      throw Exception("No se pudo subir el QR al backend: ${respuesta.body}");
    }
  }
}
