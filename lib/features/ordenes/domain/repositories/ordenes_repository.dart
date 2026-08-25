import '../../../../core/network/result.dart';
import '../entities/orden.dart';

/// Contrato de acceso a órdenes de servicio del instalador.
/// Implementado por [OrdenesRepositoryImpl] sobre un datasource Mock o Api.
abstract class OrdenesRepository {
  /// Lista de órdenes filtradas por tipo (instalacion | reparacion | ...).
  Future<Result<List<Orden>>> getOrdenes({required String tipo});

  /// Detalle de una orden.
  Future<Result<Orden>> getOrden(String id);
}
