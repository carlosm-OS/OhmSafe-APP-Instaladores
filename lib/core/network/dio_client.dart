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

  DioClient({required this.envConfig});

  void addInterceptor(HttpClientInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse("${envConfig.apiBaseUrl}$path");
    
    Map<String, String> mergedHeaders = {
      'Authorization': 'Bearer ${envConfig.hubspotApiKey}',
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

  Map<String, dynamic> _handleResponse(int statusCode, String responseBody) {
    if (statusCode >= 200 && statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw ServerException("Respuesta fallida: $statusCode - $responseBody");
    }
  }
}
