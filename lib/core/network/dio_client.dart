import 'dart:convert';
import 'dart:io';
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

  String get _bearer => _authToken ?? envConfig.hubspotApiKey;

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
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
    } catch (e) {
      throw const NetworkException();
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = Uri.parse("${envConfig.apiBaseUrl}$path");

    Map<String, String> mergedHeaders = {
      'Authorization': 'Bearer $_bearer',
      'Content-Type': 'application/json',
    };
    if (headers != null) {
      mergedHeaders.addAll(headers);
    }

    HttpClientRequest request = _HttpClientRequestImpl('POST', uri, mergedHeaders);
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
    } catch (e) {
      throw const NetworkException();
    }
  }

  Map<String, dynamic> _handleResponse(int statusCode, String responseBody) {
    if (statusCode >= 200 && statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw ServerException("Respuesta fallida: $statusCode - $responseBody");
    }
  }
}
