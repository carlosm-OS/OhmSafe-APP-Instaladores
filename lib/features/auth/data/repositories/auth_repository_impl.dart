import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/result.dart';
import '../../domain/entities/sesion.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;

  AuthRepositoryImpl({required this.dataSource});

  Sesion? _sesion;

  @override
  Sesion? get sesionActual => _sesion;

  @override
  Future<Result<Sesion>> login({required String email, required String password}) async {
    try {
      final sesion = await dataSource.login(email: email, password: password);
      _sesion = sesion;
      return Success(sesion);
    } on UnauthorizedException {
      // 401 del backend = credenciales inválidas (mensaje claro para el login).
      return const FailureResult(AuthFailure());
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> logout() async {
    await dataSource.logout(); // limpia el token en la variante Api
    _sesion = null;
  }
}
