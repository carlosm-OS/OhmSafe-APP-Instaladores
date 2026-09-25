import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import '../error/exceptions.dart';
import '../config/env_config.dart';

abstract class HttpClientRequest {
  String get method;
  Uri get uri;
  Map<String, String> get headers;
}

class _HttpClientRequestImpl implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final Map<String, String> headers;

  _HttpClientRequestImpl(this.method, this.uri, this.headers);
}

abstract class HttpClientInterceptor {
  Future<HttpClientRequest> onRequest(HttpClientRequest request);
}

class DioClient {
  final EnvConfig envConfig;
  final HttpClient _client = HttpClient();
  final List<HttpClientInterceptor> _interceptors = [];

  /// Token de la sesión del instalador (se fija tras login). Cuando existe,
  /// se usa como `Authorization: Bearer` en vez de la API key por defecto.
  String? _authToken;

  DioClient({required this.envConfig});

  void addInterceptor(HttpClientInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  /// Fija el access token de la sesión (llamado por el login).
  void setAuthToken(String token) => _authToken = token;

  /// Limpia el token (logout).
  void clearAuthToken() => _authToken = null;

  /// Quien sabe refrescar la sesión (SessionManager). Devuelve true si dejó
  /// un access token nuevo; la petición original se reintenta UNA vez.
  Future<bool> Function()? onUnauthorized;

  /// Reintenta una vez si el backend contestó 401 y hay quien refresque. Las
  /// rutas de auth (`sinReintento`) nunca entran aquí: un 401 en el login son
  /// credenciales malas y en el refresh es una sesión muerta.
  Future<Map<String, dynamic>> _conReintento(Future<Map<String, dynamic>> Function() intento, {required bool sinReintento}) async {
    try {
      return await intento();
    } on UnauthorizedException {
      final refrescar = onUnauthorized;
      if (sinReintento || refrescar == null) rethrow;
      bool ok;
      try {
        ok = await refrescar();
      } catch (_) {
        ok = false;
      }
      if (!ok) rethrow;
      return await intento();
    }
  }

  String get _bearer => _authToken ?? envConfig.hubspotApiKey;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers, bool sinReintento = false}) =>
      _conReintento(() => enviar('GET', path, headers: headers), sinReintento: sinReintento);

  /// Transporte real (una petición, sin reintento). Las pruebas lo sustituyen.
  @visibleForTesting
  Future<Map<String, dynamic>> enviar(String method, String path, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      method == 'GET' ? _getOnce(path, headers: headers) : _sendBody(method, path, body: body, headers: headers);

  Future<Map<String, dynamic>> _getOnce(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse("${envConfig.apiBaseUrl}$path");
    
    Map<String, String> mergedHeaders = {
      'Authorization': 'Bearer $_bearer',
      'Content-Type': 'application/json',
    };
    if (headers != null) {
      mergedHeaders.addAll(headers);
    }

    HttpClientRequest request = _HttpClientRequestImpl('GET', uri, mergedHeaders);

    // Apply interceptors
    for (var interceptor in _interceptors) {
      request = await interceptor.onRequest(request);
    }

    try {
      final ioRequest = await _client.openUrl(request.method, request.uri);
      
      // Set headers
      request.headers.forEach((key, value) {
        ioRequest.headers.set(key, value);
      });

      final ioResponse = await ioRequest.close();
      final body = await ioResponse.transform(utf8.decoder).join();

      return _handleResponse(ioResponse.statusCode, body);
    } on ServerException {
      rethrow; // error HTTP del backend (>=400): no es falta de red
    } on UnauthorizedException {
      rethrow; // 401: credenciales/sesión inválida
    } catch (_) {
      // Cualquier otra excepción (socket, DNS, timeout) sí es falta de conexión.
      throw const NetworkException();
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers, bool sinReintento = false}) =>
      _conReintento(() => enviar('POST', path, body: body, headers: headers), sinReintento: sinReintento);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, Map<String, String>? headers, bool sinReintento = false}) =>
      _conReintento(() => enviar('PUT', path, body: body, headers: headers), sinReintento: sinReintento);

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? body, Map<String, String>? headers, bool sinReintento = false}) =>
      _conReintento(() => enviar('DELETE', path, body: body, headers: headers), sinReintento: sinReintento);

  /// Envío con cuerpo JSON (POST/PUT), con el mismo manejo de errores que get().
  Future<Map<String, dynamic>> _sendBody(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = Uri.parse("${envConfig.apiBaseUrl}$path");

    Map<String, String> mergedHeaders = {
      'Authorization': 'Bearer $_bearer',
      'Content-Type': 'application/json',
    };
    if (headers != null) {
      mergedHeaders.addAll(headers);
    }

    HttpClientRequest request = _HttpClientRequestImpl(method, uri, mergedHeaders);
    for (var interceptor in _interceptors) {
      request = await interceptor.onRequest(request);
    }

    try {
      final ioRequest = await _client.openUrl(request.method, request.uri);
      request.headers.forEach((key, value) {
        ioRequest.headers.set(key, value);
      });
      if (body != null) {
        ioRequest.add(utf8.encode(jsonEncode(body)));
      }
      final ioResponse = await ioRequest.close();
      final responseBody = await ioResponse.transform(utf8.decoder).join();
      return _handleResponse(ioResponse.statusCode, responseBody);
    } on ServerException {
      rethrow; // error HTTP del backend (>=400): no es falta de red
    } on UnauthorizedException {
      rethrow; // 401: credenciales/sesión inválida
    } catch (_) {
      // Cualquier otra excepción (socket, DNS, timeout) sí es falta de conexión.
      throw const NetworkException();
    }
  }

  /// Procesa la respuesta HTTP:
  /// - 2xx → decodifica el JSON (`{success, data, ...}`).
  /// - 401 → [UnauthorizedException] (credenciales/sesión).
  /// - resto (>=400) → [ServerException].
  /// En 401/>=400 intenta extraer el `message` que devuelve el backend
  /// (`{ success:false, error, message }`) para mostrar algo útil.
  Map<String, dynamic> _handleResponse(int statusCode, String responseBody) {
    if (statusCode >= 200 && statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    }
    String msg = "Respuesta fallida: $statusCode";
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map && decoded['message'] is String) {
        msg = decoded['message'] as String;
      }
    } catch (_) {
      // cuerpo no-JSON: se queda el mensaje por defecto
    }
    if (statusCode == 401) throw UnauthorizedException(msg);
    throw ServerException(msg);
  }
}
