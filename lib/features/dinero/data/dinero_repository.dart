import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../domain/dinero.dart';

/// Pagos, catálogo y cotizaciones del instalador (Odoo vía backend).
class DineroRepository {
  final DioClient dioClient;
  const DineroRepository({required this.dioClient});

  Future<Result<ResumenPagos>> pagos() => _run(() async {
        final res = await dioClient.get('/instalador/pagos');
        return ResumenPagos.fromJson((res['data'] as Map<String, dynamic>?) ?? const {});
      });

  Future<Result<List<ProductoCatalogo>>> catalogo() => _run(() async {
        final res = await dioClient.get('/instalador/catalogo');
        return ((res['data'] as List?) ?? const []).map((e) => ProductoCatalogo.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<Result<List<Cotizacion>>> cotizaciones() => _run(() async {
        final res = await dioClient.get('/instalador/cotizaciones');
        return ((res['data'] as List?) ?? const []).map((e) => Cotizacion.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<Result<Cotizacion>> cotizar({
    required String nombre,
    required String email,
    String? telefono,
    String? direccion,
    String? ciudad,
    String? cp,
    required Map<int, double> lineas,
    String? nota,
  }) =>
      _run(() async {
        final res = await dioClient.post('/instalador/cotizaciones', body: {
          'cliente': {
            'nombre': nombre,
            'email': email,
            if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
            if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
            if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
            if (cp != null && cp.isNotEmpty) 'cp': cp,
          },
          'lineas': [for (final e in lineas.entries) if (e.value > 0) {'productoId': e.key, 'cantidad': e.value}],
          if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        });
        return Cotizacion.fromJson((res['data'] as Map<String, dynamic>?) ?? const {});
      });

  Future<Result<T>> _run<T>(Future<T> Function() fn) async {
    try {
      return Success(await fn());
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
