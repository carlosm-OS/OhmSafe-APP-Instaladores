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
  Future<Result<bool>> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos, double? metrosReales});

  /// Guarda el registro de instalación (conteos de material, paso 3 de instalación).
  Future<Result<bool>> guardarInstalacion(String id, Map<String, dynamic> registro);

  /// Guarda el costeo de la reparación (paso 3 de reparación).
  Future<Result<bool>> guardarReparacion(String id, Map<String, dynamic> costeo);

  /// Vincula el energizador (por QR o número de serie).
  Future<Result<bool>> vincularEnergizador(String id, {required String codigo, String? serie, bool? tierraConfirmada});

  /// Diagnóstico real del energizador por número de serie (telemetría del device).
  Future<Result<Map<String, dynamic>>> diagnosticoEnergizador(String serie);

  /// Sube UNA foto de evidencia al ticket y devuelve su fileKey.
  ///
  /// Se sube en el momento de tomarla, no al cerrar: en campo la señal es mala
  /// y un solo envío con todas las fotos hace que un corte tire el cierre
  /// completo. Así cada foto es reintentable por separado.
  Future<Result<String>> subirEvidencia(String id, String categoria, String imagenBase64);

  /// Guarda el cierre del servicio (evidencias, entrega de equipo, firma).
  Future<Result<bool>> guardarCierre(String id, Map<String, dynamic> cierre);
}
