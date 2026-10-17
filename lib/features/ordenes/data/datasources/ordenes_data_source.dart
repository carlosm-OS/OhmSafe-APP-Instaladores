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
  Future<Map<String, dynamic>> casasParaVincular(String id);

  /// Prueba en sitio del energizador (build 39): ventana temporal para encender/apagar la cerca.
  /// `GET/POST /instalador/ordenes/:id/prueba[/abrir|extender|accion|terminar]`.
  Future<Map<String, dynamic>> pruebaEstado(String id);
  Future<Map<String, dynamic>> pruebaAbrir(String id);
  Future<Map<String, dynamic>> pruebaExtender(String id);
  Future<Map<String, dynamic>> pruebaAccion(String id, String accion);
  Future<Map<String, dynamic>> pruebaTerminar(String id);

  /// «Agregar dispositivos» cableado con prueba en vivo (build 39): `GET/POST /instalador/ordenes/:id/cableado…`.
  Future<Map<String, dynamic>> cableadoEstado(String id);
  Future<Map<String, dynamic>> cableadoProbarEntrada(String id, int index);
  Future<Map<String, dynamic>> cableadoRegistrarEntrada(String id, int index, {required String nombre, String? icono});
  Future<Map<String, dynamic>> cableadoProbarSirena(String id);
  Future<Map<String, dynamic>> cableadoConfirmarSirena(String id, {required bool sono});
  Future<Map<String, dynamic>> cableadoProbarSalida(String id, int index);
  Future<Map<String, dynamic>> cableadoRegistrarSalida(String id, int index, {required String nombre, required String tipo, required String modo, int? pulsoSeg, required bool funciono});
  /// OhmBox adicional en la misma casa (2026-10-14): `GET/POST /instalador/ordenes/:id/ohmbox`.
  Future<Map<String, dynamic>> ohmboxEstado(String id);
  Future<Map<String, dynamic>> ohmboxAgregar(String id, {required String serie, String? mac});
  /// Sensores 433, Wi‑Fi y cámaras (2026-10-14): `/instalador/ordenes/:id/{dispositivos,rf/aprender…,sensores-wifi,camaras}`.
  Future<Map<String, dynamic>> dispositivosEstado(String id);
  Future<Map<String, dynamic>> rfAprender(String id, {required String tipo, String? nombre});
  Future<Map<String, dynamic>> rfSesion(String id, String sid);
  Future<Map<String, dynamic>> rfTerminar(String id, String sid, {required String nombre});
  Future<Map<String, dynamic>> rfCancelar(String id, String sid);
  Future<Map<String, dynamic>> sensorWifiAgregar(String id, {required String externalId, required String nombre, required String tipo});
  Future<Map<String, dynamic>> camaraAgregar(String id, {String? proveedor, required String serie, required String codigo, required String nombre});
  /// Emparejamiento Wi‑Fi desde el teléfono (2026-10-17): sesión del fabricante de la casa (`tuya`|`ezviz`),
  /// sondeo de una cámara EZVIZ y alta de lo emparejado con el nombre de la red (nunca la contraseña).
  Future<Map<String, dynamic>> wifiSesion(String id, String proveedor);
  Future<Map<String, dynamic>> ezvizSondeo(String id, String serie);
  /// Tuya (2026-10-17): token de emparejamiento de la casa (`modo` EZ|AP|BLE) y qué equipos entraron con él.
  Future<Map<String, dynamic>> tuyaToken(String id, {required String modo, String? zonaHoraria});
  Future<Map<String, dynamic>> tuyaTokenResultado(String id, String token);
  Future<Map<String, dynamic>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category});
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
