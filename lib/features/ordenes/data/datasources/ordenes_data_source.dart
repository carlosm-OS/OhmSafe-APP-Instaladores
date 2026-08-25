import '../models/orden_model.dart';

/// Fuente de datos de órdenes. Implementada por la variante Api (backend real)
/// y la variante Mock (datos de prueba locales). El repositorio depende de
/// esta abstracción; el contenedor de DI decide cuál inyectar según el flag
/// `EnvConfig.useMock`.
abstract class OrdenesDataSource {
  Future<List<OrdenModel>> getOrdenes({required String tipo});
  Future<OrdenModel> getOrden(String id);

  // Acciones de escritura
  Future<void> iniciarRuta(String id);
  Future<void> marcarLlegada(String id);
  Future<void> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos});
  Future<void> guardarReparacion(String id, Map<String, dynamic> costeo);
  Future<void> vincularEnergizador(String id, {required String codigo});
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre);
}
