import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/result.dart';
import '../../domain/entities/orden.dart';
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
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
