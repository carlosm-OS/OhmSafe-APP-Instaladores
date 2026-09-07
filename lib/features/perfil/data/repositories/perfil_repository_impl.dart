import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/result.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/repositories/perfil_repository.dart';
import '../datasources/perfil_data_source.dart';

class PerfilRepositoryImpl implements PerfilRepository {
  final PerfilDataSource dataSource;
  PerfilRepositoryImpl({required this.dataSource});

  /// Ejecuta y traduce excepciones de datos a [Failure] de dominio.
  Future<Result<T>> _run<T>(Future<T> Function() run) async {
    try {
      return Success(await run());
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

  @override
  Future<Result<Perfil>> getPerfil() => _run(() => dataSource.getPerfil());

  @override
  Future<Result<Perfil>> updatePerfil({String? nombre, String? telefono, String? rfc, String? curp}) =>
      _run(() => dataSource.updatePerfil(nombre: nombre, telefono: telefono, rfc: rfc, curp: curp));

  @override
  Future<Result<Perfil>> subirConstancia({required String nombreArchivo, required String contenidoBase64, String mimetype = 'application/pdf'}) =>
      _run(() => dataSource.subirConstancia(nombreArchivo: nombreArchivo, contenidoBase64: contenidoBase64, mimetype: mimetype));

  @override
  Future<Result<Perfil>> subirAvatar({required String contenidoBase64}) =>
      _run(() => dataSource.subirAvatar(contenidoBase64: contenidoBase64));

  @override
  Future<Result<bool>> cambiarPassword({required String passwordActual, required String passwordNueva}) =>
      _run(() async {
        await dataSource.cambiarPassword(passwordActual: passwordActual, passwordNueva: passwordNueva);
        return true;
      });
}
