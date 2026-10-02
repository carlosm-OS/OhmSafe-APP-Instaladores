import '../models/orden_model.dart';
import '../../domain/entities/tarifas.dart';

/// Fuente de datos de órdenes. Implementada por la variante Api (backend real)
/// y la variante Mock (datos de prueba locales). El repositorio depende de
/// esta abstracción; el contenedor de DI decide cuál inyectar según el flag
/// `EnvConfig.useMock`.
abstract class OrdenesDataSource {
  Future<List<OrdenModel>> getOrdenes({required String tipo});
  Future<OrdenModel> getOrden(String id);

  /// Tarifas del motor de costeo (precios de Odoo). Ver [Tarifas].
  Future<Tarifas> getTarifas();

  // Acciones de escritura
  Future<void> iniciarRuta(String id);
  Future<void> marcarLlegada(String id, {Map<String, dynamic>? ubicacion});
  Future<void> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos, double? metrosReales});
  Future<void> guardarInstalacion(String id, Map<String, dynamic> registro);
  Future<void> guardarReparacion(String id, Map<String, dynamic> costeo);
  /// Devuelve el resultado del ligado a la cuenta del cliente (`dashboard`:
  /// `ligado`, y si no, `motivo` CLIENTE_SIN_CUENTA | EQUIPO_DE_OTRO_TITULAR | SIN_SERIE).
  Future<Map<String, dynamic>> vincularEnergizador(String id, {required String codigo, String? serie, bool? tierraConfirmada});
  Future<Map<String, dynamic>> cancelar(String id, {required String motivo, String? notas, String? fotoBase64, Map<String, dynamic>? ubicacion});

  /// Historial del instalador: intervenciones completadas y canceladas en sitio
  /// (`GET /instalador/historial`). Cada fila trae `estado` (completado | cancelado),
  /// `fecha` del evento y, si aplica, `motivo`.
  Future<List<Map<String, dynamic>>> historial({String rango = 'todo'});
  /// Diagnóstico real del energizador por número de serie (telemetría del device).
  Future<Map<String, dynamic>> diagnosticoEnergizador(String serie, {String ordenId = ''});
  /// Sube UNA foto de evidencia y devuelve su fileKey en Odoo.
  Future<String> subirEvidencia(String id, String categoria, String imagenBase64);
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre);
}
