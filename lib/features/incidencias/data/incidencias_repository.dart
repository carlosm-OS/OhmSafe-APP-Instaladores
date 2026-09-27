import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../domain/incidencia.dart';

/// Incidencias del instalador (Helpdesk de Odoo vía backend).
class IncidenciasRepository {
  final DioClient dioClient;
  const IncidenciasRepository({required this.dioClient});

  Future<Result<List<Incidencia>>> listar() => _run(() async {
        final res = await dioClient.get('/instalador/incidencias');
        return ((res['data'] as List?) ?? const []).map((e) => Incidencia.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<Result<Incidencia>> reportar({
    required String tipo,
    required String descripcion,
    String? ordenId,
    String? fotoBase64,
    Map<String, dynamic>? ubicacion,
  }) =>
      _run(() async {
        final res = await dioClient.post('/instalador/incidencias', body: {
          'tipo': tipo,
          'descripcion': descripcion,
          'ordenId': ?ordenId,
          'fotoBase64': ?fotoBase64,
          'ubicacion': ?ubicacion,
        });
        return Incidencia.fromJson((res['data'] as Map<String, dynamic>?) ?? const {});
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
