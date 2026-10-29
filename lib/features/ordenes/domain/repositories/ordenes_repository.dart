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
  /// [ubicacion] = `{lat, lng, precision}` del teléfono; el backend la usa como referencia del cierre.
  Future<Result<bool>> marcarLlegada(String id, {Map<String, dynamic>? ubicacion});

  /// Guarda la inspección del perímetro.
  Future<Result<bool>> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos, double? metrosReales});

  /// Guarda el registro de instalación (conteos de material, paso 3 de instalación).
  Future<Result<bool>> guardarInstalacion(String id, Map<String, dynamic> registro);

  /// Guarda el costeo de la reparación (paso 3 de reparación).
  Future<Result<bool>> guardarReparacion(String id, Map<String, dynamic> costeo);

  /// Vincula el energizador (por QR o número de serie).
  /// Devuelve el resultado del ligado a la cuenta del cliente (`ligado`, `motivo`).
  /// La casa la decide la venta en el backend (2026-10-14); la app ya no manda `destino`.
  Future<Result<Map<String, dynamic>>> vincularEnergizador(String id, {required String codigo, String? serie, bool? tierraConfirmada});

  /// A dónde va el equipo (`destino`, decidido por la venta) y qué se vendió; ya no hay casas que elegir.
  Future<Result<Map<String, dynamic>>> casasParaVincular(String id);

  /// Prueba en sitio del energizador (ventana temporal para encender/apagar la cerca).
  Future<Result<Map<String, dynamic>>> pruebaEstado(String id);
  Future<Result<Map<String, dynamic>>> pruebaAbrir(String id);
  Future<Result<Map<String, dynamic>>> pruebaExtender(String id);
  Future<Result<Map<String, dynamic>>> pruebaAccion(String id, String accion);
  Future<Result<Map<String, dynamic>>> pruebaTerminar(String id);

  /// «Agregar dispositivos» cableado con prueba en vivo.
  Future<Result<Map<String, dynamic>>> cableadoEstado(String id);
  Future<Result<Map<String, dynamic>>> cableadoProbarEntrada(String id, int index);
  Future<Result<Map<String, dynamic>>> cableadoRegistrarEntrada(String id, int index, {required String nombre, String? icono});
  Future<Result<Map<String, dynamic>>> cableadoProbarSirena(String id);
  Future<Result<Map<String, dynamic>>> cableadoConfirmarSirena(String id, {required bool sono});
  Future<Result<Map<String, dynamic>>> cableadoProbarSalida(String id, int index);
  Future<Result<Map<String, dynamic>>> cableadoRegistrarSalida(String id, int index, {required String nombre, required String tipo, required String modo, int? pulsoSeg, required bool funciono});
  /// OhmBox adicional en la misma casa (add-on de su suscripción, 2026-10-14).
  Future<Result<Map<String, dynamic>>> ohmboxEstado(String id);
  Future<Result<Map<String, dynamic>>> ohmboxAgregar(String id, {required String serie, String? mac});
  /// Sensores 433, Wi‑Fi y cámaras desde «Agregar dispositivos» (2026-10-14).
  Future<Result<Map<String, dynamic>>> dispositivosEstado(String id);
  Future<Result<Map<String, dynamic>>> rfAprender(String id, {required String tipo, String? nombre});
  Future<Result<Map<String, dynamic>>> rfSesion(String id, String sid);
  Future<Result<Map<String, dynamic>>> rfTerminar(String id, String sid, {required String nombre});
  Future<Result<Map<String, dynamic>>> rfCancelar(String id, String sid);
  Future<Result<Map<String, dynamic>>> sensorWifiAgregar(String id, {required String externalId, required String nombre, required String tipo});
  Future<Result<Map<String, dynamic>>> camaraAgregar(String id, {String? proveedor, required String serie, required String codigo, required String nombre});
  /// Emparejamiento Wi‑Fi desde el teléfono (2026-10-17): ver [OrdenesDataSource.wifiSesion].
  Future<Result<Map<String, dynamic>>> wifiSesion(String id, String proveedor);
  Future<Result<Map<String, dynamic>>> ezvizSondeo(String id, String serie);
  /// Imou (2026-10-20): sesión del SDK (host + accessToken de la cuenta) y sondeo de llegada a la nube.
  Future<Result<Map<String, dynamic>>> imouSesion(String id);
  Future<Result<Map<String, dynamic>>> imouSondeo(String id, String serie);
  Future<Result<Map<String, dynamic>>> tuyaToken(String id, {required String modo, String? zonaHoraria});
  Future<Result<Map<String, dynamic>>> tuyaTokenResultado(String id, String token);
  Future<Result<Map<String, dynamic>>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category});
  /// Cancelación en sitio: motivo tipado (mismo catálogo que el backend), notas, foto y ubicación opcionales.
  Future<Result<Map<String, dynamic>>> cancelar(String id, {required String motivo, String? notas, String? fotoBase64, Map<String, dynamic>? ubicacion});

  /// Historial del instalador (completadas y canceladas en sitio), del backend.
  Future<Result<List<Map<String, dynamic>>>> historial({String rango = 'todo'});

  /// Diagnóstico real del energizador por número de serie (telemetría del device).
  Future<Result<Map<String, dynamic>>> diagnosticoEnergizador(String serie, {String ordenId = ''});

  /// Sube UNA foto de evidencia al ticket y devuelve su fileKey.
  ///
  /// Se sube en el momento de tomarla, no al cerrar: en campo la señal es mala
  /// y un solo envío con todas las fotos hace que un corte tire el cierre
  /// completo. Así cada foto es reintentable por separado.
  Future<Result<String>> subirEvidencia(String id, String categoria, String imagenBase64);

  /// Guarda el cierre del servicio (evidencias, entrega de equipo, firma).
  Future<Result<bool>> guardarCierre(String id, Map<String, dynamic> cierre);
}
