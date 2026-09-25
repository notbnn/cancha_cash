import 'dart:convert';
import 'package:http/http.dart' as http;

/// Único lugar de la app que le habla por HTTP al backend. Nada de
/// lógica de negocio acá — solo arma el request, lo manda, y devuelve
/// el JSON ya decodificado para que el que lo llama decida qué hacer.
class BackendApi {
  // OJO: esta URL depende de dónde estés probando la app — la ajustamos
  // en el próximo paso según tu caso (emulador, celular físico o
  // escritorio).
  static const String _baseUrl = "https://cancha-semanal-backend.onrender.com";
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
  }) async {
    final respuesta = await http.post(
      Uri.parse("$_baseUrl/api/eventos"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "fecha": fecha.toUtc().toIso8601String(),
        if (nombreCancha != null) "nombreCancha": nombreCancha,
        if (horaFin != null) "horaFin": horaFin,
      }),
    );

    if (respuesta.statusCode != 201) {
      throw Exception("No se pudo crear el evento en el backend: ${respuesta.body}");
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
      throw Exception("No se pudieron traer las confirmaciones: ${respuesta.body}");
    }

    final lista = jsonDecode(respuesta.body) as List<dynamic>;
    return lista.cast<Map<String, dynamic>>();
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