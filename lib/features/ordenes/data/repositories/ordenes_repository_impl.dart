import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/result.dart';
import '../../domain/entities/orden.dart';
import '../../domain/entities/tarifas.dart';
import '../../domain/repositories/ordenes_repository.dart';
import '../datasources/ordenes_data_source.dart';

class OrdenesRepositoryImpl implements OrdenesRepository {
  final OrdenesDataSource dataSource;

  OrdenesRepositoryImpl({required this.dataSource});

  @override
  Future<Result<List<Orden>>> getOrdenes({required String tipo}) async {
    try {
      final ordenes = await dataSource.getOrdenes(tipo: tipo);
      return Success(ordenes);
    } on UnauthorizedException {
      // 401 en una lectura/acción = sesión expirada.
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
  Future<Result<Orden>> getOrden(String id) async {
    try {
      final orden = await dataSource.getOrden(id);
      return Success(orden);
    } on UnauthorizedException {
      // 401 en una lectura/acción = sesión expirada.
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
  Future<Result<Tarifas>> getTarifas() async {
    try {
      final tarifas = await dataSource.getTarifas();
      return Success(tarifas);
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

  // ---- Acciones de escritura ----

  /// Envuelve una acción de escritura en Result<bool> con manejo de errores.
  Future<Result<bool>> _accion(Future<void> Function() run) async {
    try {
      await run();
      return const Success(true);
    } on UnauthorizedException {
      // 401 en una lectura/acción = sesión expirada.
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
  Future<Result<bool>> iniciarRuta(String id) => _accion(() => dataSource.iniciarRuta(id));

  @override
  Future<Result<bool>> marcarLlegada(String id) => _accion(() => dataSource.marcarLlegada(id));

  @override
  Future<Result<bool>> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos}) =>
      _accion(() => dataSource.guardarInspeccion(id, sinObstaculos: sinObstaculos, obstaculos: obstaculos));

  @override
  Future<Result<bool>> guardarInstalacion(String id, Map<String, dynamic> registro) =>
      _accion(() => dataSource.guardarInstalacion(id, registro));

  @override
  Future<Result<bool>> guardarReparacion(String id, Map<String, dynamic> costeo) =>
      _accion(() => dataSource.guardarReparacion(id, costeo));

  @override
  Future<Result<bool>> vincularEnergizador(String id, {required String codigo, String? serie}) =>
      _accion(() => dataSource.vincularEnergizador(id, codigo: codigo, serie: serie));

  @override
  Future<Result<Map<String, dynamic>>> diagnosticoEnergizador(String serie) async {
    try {
      return Success(await dataSource.diagnosticoEnergizador(serie));
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
  Future<Result<bool>> guardarCierre(String id, Map<String, dynamic> cierre) =>
      _accion(() => dataSource.guardarCierre(id, cierre));
}
