import 'dart:io' show Platform;

import '../../../../core/auth/session_manager.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/result.dart';
import '../../domain/entities/acceso.dart';
import '../../domain/entities/sesion.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;
  final SessionManager sessionManager;

  AuthRepositoryImpl({required this.dataSource, required this.sessionManager});

  Sesion? _sesion;

  @override
  Sesion? get sesionActual => _sesion ?? sessionManager.actual;

  @override
  Future<Result<Sesion>> login({required String email, required String password}) async {
    try {
      final sesion = await dataSource.login(
        email: email,
        password: password,
        deviceId: await sessionManager.deviceId(),
        deviceName: nombreDispositivo(),
      );
      _sesion = sesion;
      await sessionManager.guardarLogin(sesion, email: email.trim().toLowerCase());
      return Success(sesion);
    } on UnauthorizedException {
      // 401 del backend = credenciales inválidas (mensaje claro para el login).
      return const FailureResult(AuthFailure());
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AccesoSiguiente>> solicitarAcceso({required String email, bool olvide = false}) =>
      _run(() => dataSource.solicitarAcceso(email: email, olvide: olvide));

  @override
  Future<Result<CodigoVerificado>> verificarCodigo({required String email, required String codigo}) =>
      _run(() => dataSource.verificarCodigo(email: email, codigo: codigo));

  @override
  Future<Result<Sesion>> activar({required String email, required String activacion, required String password}) => _run(() async {
        final sesion = await dataSource.activar(
          activacion: activacion,
          password: password,
          deviceId: await sessionManager.deviceId(),
          deviceName: nombreDispositivo(),
        );
        _sesion = sesion;
        await sessionManager.guardarLogin(sesion, email: email.trim().toLowerCase());
        return sesion;
      });

  /// Traduce errores de transporte a fallos con el código del backend (p. ej. CODIGO_INCORRECTO).
  Future<Result<T>> _run<T>(Future<T> Function() fn) async {
    try {
      return Success(await fn());
    } on UnauthorizedException {
      return const FailureResult(AuthFailure());
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> logout() async {
    await sessionManager.cerrar(); // revoca la familia en el servidor y limpia el almacén
    await dataSource.logout(); // limpia el token en la variante Api
    _sesion = null;
  }

  @override
  Future<Sesion?> restaurar() async {
    try {
      final s = await sessionManager.refrescar();
      _sesion = s;
      return s;
    } on SesionExpiradaException {
      _sesion = null;
      return null;
    }
  }
}

/// Nombre corto del dispositivo para «Dispositivos con sesión» (sin datos personales).
String nombreDispositivo() {
  if (Platform.isIOS) return 'iPhone';
  if (Platform.isAndroid) return 'Android';
  return Platform.operatingSystem;
}
