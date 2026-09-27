import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/config/env_config.dart';
import 'package:ohmsafe_app/core/error/exceptions.dart';
import 'package:ohmsafe_app/core/network/dio_client.dart';

const _env = EnvConfig(environment: Environment.development, apiBaseUrl: 'http://x', hubspotApiKey: '', useMock: false);

/// Transporte simulado: contesta 401 hasta que alguien "autoriza".
class _Dio extends DioClient {
  _Dio() : super(envConfig: _env);
  bool autorizado = false;
  final envios = <String>[];

  @override
  Future<Map<String, dynamic>> enviar(String method, String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    envios.add('$method $path');
    if (!autorizado) throw const UnauthorizedException('Token has been revoked');
    return {'success': true, 'data': {'ok': true}};
  }
}

void main() {
  test('un 401 dispara UN refresco y reintenta una vez', () async {
    final dio = _Dio();
    var refrescos = 0;
    dio.onUnauthorized = () async {
      refrescos++;
      dio.autorizado = true;
      return true;
    };
    final r = await dio.get('/instalador/ordenes');
    expect(r['data'], {'ok': true});
    expect(refrescos, 1);
    expect(dio.envios, ['GET /instalador/ordenes', 'GET /instalador/ordenes']);
  });

  test('si el refresco falla o lanza, el 401 se propaga sin segundo intento', () async {
    final dio = _Dio();
    dio.onUnauthorized = () async => false;
    await expectLater(dio.post('/x', body: {}), throwsA(isA<UnauthorizedException>()));
    expect(dio.envios.length, 1);

    dio.envios.clear();
    dio.onUnauthorized = () async => throw StateError('boom');
    await expectLater(dio.put('/x', body: {}), throwsA(isA<UnauthorizedException>()));
    expect(dio.envios.length, 1);
  });

  test('las rutas de auth (sinReintento) y un cliente sin refrescador propagan el 401 tal cual', () async {
    final dio = _Dio();
    var refrescos = 0;
    dio.onUnauthorized = () async {
      refrescos++;
      return true;
    };
    await expectLater(dio.post('/instalador/auth/login', body: {}, sinReintento: true), throwsA(isA<UnauthorizedException>()));
    expect(refrescos, 0);

    final sinRefrescador = _Dio();
    await expectLater(sinRefrescador.get('/x'), throwsA(isA<UnauthorizedException>()));
  });
}
