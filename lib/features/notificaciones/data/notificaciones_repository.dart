import '../../../core/network/dio_client.dart';
import '../../../core/network/result.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../domain/notificacion.dart';

/// Centro de notificaciones: feed y marca de leído.
class NotificacionesRepository {
  final DioClient dioClient;
  const NotificacionesRepository({required this.dioClient});

  Future<Result<({List<Notificacion> items, int noLeidas})>> listar() async {
    try {
      final res = await dioClient.get('/instalador/notificaciones');
      final data = (res['data'] as Map<String, dynamic>?) ?? const {};
      final items = ((data['items'] as List?) ?? const [])
          .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success((items: items, noLeidas: (data['noLeidas'] as num?)?.toInt() ?? 0));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  /// Mueve la marca de agua: todo lo anterior queda leído.
  Future<Result<bool>> marcarLeidas() async {
    try {
      await dioClient.post('/instalador/notificaciones/leidas');
      return const Success(true);
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
