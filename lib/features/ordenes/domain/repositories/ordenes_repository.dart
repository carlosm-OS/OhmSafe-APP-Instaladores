import '../../../../core/network/result.dart';
import '../entities/orden.dart';
import '../entities/tarifas.dart';

/// Contrato de acceso a órdenes de servicio del instalador.
/// Implementado por [OrdenesRepositoryImpl] sobre un datasource Mock o Api.
abstract class OrdenesRepository {
  /// Lista de órdenes filtradas por tipo (instalacion | reparacion | ...).
  Future<Result<List<Orden>>> getOrdenes({required String tipo});

  /// Detalle de una orden.
  Future<Result<Orden>> getOrden(String id);

  /// Tarifas del motor de costeo (precios vivos de Odoo). Ver [Tarifas].
  Future<Result<Tarifas>> getTarifas();

  // ---- Acciones de escritura (reportan avance/cierre al backend) ----

  /// Inicia la ruta de servicio (pasa la orden a "en curso"; notifica cliente).
  Future<Result<bool>> iniciarRuta(String id);

  /// Marca la llegada del técnico al domicilio (completa el paso 1).
  Future<Result<bool>> marcarLlegada(String id);

  /// Guarda la inspección del perímetro.
  Future<Result<bool>> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos});

  /// Guarda el registro de instalación (conteos de material, paso 3 de instalación).
  Future<Result<bool>> guardarInstalacion(String id, Map<String, dynamic> registro);

  /// Guarda el costeo de la reparación (paso 3 de reparación).
  Future<Result<bool>> guardarReparacion(String id, Map<String, dynamic> costeo);

  /// Vincula el energizador (por QR o número de serie).
  Future<Result<bool>> vincularEnergizador(String id, {required String codigo});

  /// Guarda el cierre del servicio (evidencias, entrega de equipo, firma).
  Future<Result<bool>> guardarCierre(String id, Map<String, dynamic> cierre);
}
