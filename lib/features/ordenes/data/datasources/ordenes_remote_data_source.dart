import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/orden_model.dart';
import '../../domain/entities/tarifas.dart';
import 'ordenes_data_source.dart';

/// Variante Api: consume el backend real (`/v1/instalador/ordenes`).
/// Aún sin backend; queda lista para cuando exista el dominio field-service.
class OrdenesRemoteDataSource implements OrdenesDataSource {
  final DioClient dioClient;

  OrdenesRemoteDataSource({required this.dioClient});

  @override
  Future<List<OrdenModel>> getOrdenes({required String tipo}) async {
    final response = await dioClient.get('/instalador/ordenes?tipo=$tipo');
    final items = (response['data'] ?? response['ordenes'] ?? []) as List<dynamic>;
    return items
        .map((e) => OrdenModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrdenModel> getOrden(String id) async {
    final response = await dioClient.get('/instalador/ordenes/$id');
    final data = (response['data'] ?? response) as Map<String, dynamic>;
    if (data.isEmpty) throw const ServerException('Orden no encontrada');
    return OrdenModel.fromJson(data);
  }

  @override
  Future<Tarifas> getTarifas() async {
    final response = await dioClient.get('/instalador/tarifas-reparacion');
    final data = (response['data'] ?? response) as Map<String, dynamic>;
    return Tarifas.fromJson(data);
  }

  // ---- Escritura (POST según el contrato) ----
  @override
  Future<void> iniciarRuta(String id) async {
    await dioClient.post('/instalador/ordenes/$id/iniciar-ruta');
  }

  @override
  Future<void> marcarLlegada(String id, {Map<String, dynamic>? ubicacion}) async {
    await dioClient.post('/instalador/ordenes/$id/marcar-llegada', body: {'ubicacion': ?ubicacion});
  }

  @override
  Future<void> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos, double? metrosReales}) async {
    await dioClient.post('/instalador/ordenes/$id/inspeccion-perimetro',
        body: {
          'sinObstaculos': sinObstaculos,
          'obstaculos': obstaculos,
          if (metrosReales != null) 'metrosReales': metrosReales,
        });
  }

  @override
  Future<void> guardarInstalacion(String id, Map<String, dynamic> registro) async {
    await dioClient.post('/instalador/ordenes/$id/instalacion', body: registro);
  }

  @override
  Future<void> guardarReparacion(String id, Map<String, dynamic> costeo) async {
    await dioClient.post('/instalador/ordenes/$id/reparacion', body: costeo);
  }

  @override
  Future<Map<String, dynamic>> cancelar(String id, {required String motivo, String? notas, String? fotoBase64, Map<String, dynamic>? ubicacion}) async {
    final res = await dioClient.post('/instalador/ordenes/$id/cancelar', body: {
      'motivo': motivo,
      if (notas != null && notas.isNotEmpty) 'notas': notas,
      if (fotoBase64 != null) 'fotoBase64': fotoBase64,
      if (ubicacion != null) 'ubicacion': ubicacion,
    });
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<List<Map<String, dynamic>>> historial({String rango = 'todo'}) async {
    final res = await dioClient.get('/instalador/historial?rango=${Uri.encodeQueryComponent(rango)}');
    final data = res['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  @override
  Future<Map<String, dynamic>> casasParaVincular(String id) async {
    final res = await dioClient.get('/instalador/ordenes/$id/casas');
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<Map<String, dynamic>> pruebaEstado(String id) async {
    final res = await dioClient.get('/instalador/ordenes/$id/prueba');
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<Map<String, dynamic>> pruebaAbrir(String id) async {
    final res = await dioClient.post('/instalador/ordenes/$id/prueba/abrir', body: const {});
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<Map<String, dynamic>> pruebaExtender(String id) async {
    final res = await dioClient.post('/instalador/ordenes/$id/prueba/extender', body: const {});
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<Map<String, dynamic>> pruebaAccion(String id, String accion) async {
    final res = await dioClient.post('/instalador/ordenes/$id/prueba/accion', body: {'accion': accion});
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<Map<String, dynamic>> pruebaTerminar(String id) async {
    final res = await dioClient.post('/instalador/ordenes/$id/prueba/terminar', body: const {});
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  Map<String, dynamic> _data(Map<String, dynamic> res) => (res['data'] as Map<String, dynamic>?) ?? const {};

  @override
  Future<Map<String, dynamic>> cableadoEstado(String id) async => _data(await dioClient.get('/instalador/ordenes/$id/cableado'));
  @override
  Future<Map<String, dynamic>> cableadoProbarEntrada(String id, int index) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/entradas/$index/probar', body: const {}));
  @override
  Future<Map<String, dynamic>> cableadoRegistrarEntrada(String id, int index, {required String nombre, String? icono}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/entradas/$index/registrar', body: {'nombre': nombre, if (icono != null) 'icono': icono}));
  @override
  Future<Map<String, dynamic>> cableadoProbarSirena(String id) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/sirena/probar', body: const {}));
  @override
  Future<Map<String, dynamic>> cableadoConfirmarSirena(String id, {required bool sono}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/sirena/confirmar', body: {'sono': sono}));
  @override
  Future<Map<String, dynamic>> cableadoSirena(String id, {required bool encender}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/sirena/${encender ? 'encender' : 'apagar'}', body: const {}));
  @override
  Future<Map<String, dynamic>> cableadoProbarSalida(String id, int index) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/salidas/$index/probar', body: const {}));
  @override
  Future<Map<String, dynamic>> cableadoRegistrarSalida(String id, int index, {required String nombre, required String tipo, required String modo, int? pulsoSeg, required bool funciono}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/cableado/salidas/$index/registrar', body: {'nombre': nombre, 'tipo': tipo, 'modo': modo, if (pulsoSeg != null) 'pulsoSeg': pulsoSeg, 'funciono': funciono}));

  @override
  Future<Map<String, dynamic>> dispositivosEstado(String id) async => _data(await dioClient.get('/instalador/ordenes/$id/dispositivos'));
  @override
  Future<Map<String, dynamic>> rfAprender(String id, {required String tipo, String? nombre, int? botones}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/rf/aprender', body: {'tipo': tipo, if (nombre != null && nombre.isNotEmpty) 'nombre': nombre, if (botones != null) 'botones': botones}));
  @override
  Future<Map<String, dynamic>> rfSesion(String id, String sid) async => _data(await dioClient.get('/instalador/ordenes/$id/rf/aprender/$sid'));
  @override
  Future<Map<String, dynamic>> rfTerminar(String id, String sid, {required String nombre}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/rf/aprender/$sid/terminar', body: {'nombre': nombre}));
  @override
  Future<Map<String, dynamic>> rfCancelar(String id, String sid) async => _data(await dioClient.post('/instalador/ordenes/$id/rf/aprender/$sid/cancelar', body: const {}));
  @override
  Future<Map<String, dynamic>> sensorWifiAgregar(String id, {required String externalId, required String nombre, required String tipo}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/sensores-wifi', body: {'externalId': externalId, 'nombre': nombre, 'tipo': tipo}));
  @override
  Future<Map<String, dynamic>> camaraAgregar(String id, {String? proveedor, required String serie, required String codigo, required String nombre}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/camaras', body: {if (proveedor != null) 'proveedor': proveedor, 'serie': serie, 'codigo': codigo, 'nombre': nombre}));

  @override
  Future<Map<String, dynamic>> wifiSesion(String id, String proveedor) async =>
      _data(await dioClient.get('/instalador/ordenes/$id/wifi/sesion?proveedor=$proveedor', sinReintento: true));
  @override
  Future<Map<String, dynamic>> ezvizSondeo(String id, String serie) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/wifi/ezviz/sondeo', body: {'serie': serie}, sinReintento: true));
  @override
  Future<Map<String, dynamic>> tuyaToken(String id, {required String modo, String? zonaHoraria}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/wifi/tuya/token', body: {'modo': modo, if (zonaHoraria != null && zonaHoraria.isNotEmpty) 'zonaHoraria': zonaHoraria}, sinReintento: true));
  @override
  Future<Map<String, dynamic>> tuyaTokenResultado(String id, String token) async =>
      _data(await dioClient.get('/instalador/ordenes/$id/wifi/tuya/token/${Uri.encodeComponent(token)}', sinReintento: true));
  @override
  Future<Map<String, dynamic>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category, String? serie}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/dispositivos-wifi', body: {
        'proveedor': proveedor,
        'clase': clase,
        'externalId': externalId,
        'nombre': nombre,
        if (codigo != null && codigo.isNotEmpty) 'codigo': codigo,
        if (red != null && red.isNotEmpty) 'red': red,
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        if (category != null && category.isNotEmpty) 'category': category,
        // Serie de la etiqueta (opcional, 2026-10-22). Sólo si la hay: un backend viejo rechaza campos que no conoce.
        if (serie != null && serie.isNotEmpty) 'serie': serie,
      }));
  @override
  Future<Map<String, dynamic>> ohmboxEstado(String id) async => _data(await dioClient.get('/instalador/ordenes/$id/ohmbox'));
  @override
  Future<Map<String, dynamic>> ohmboxAgregar(String id, {required String serie, String? mac}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/ohmbox', body: {'serie': serie, if (mac != null && mac.isNotEmpty) 'mac': mac}));

  @override
  Future<Map<String, dynamic>> vincularEnergizador(String id, {required String codigo, String? serie, bool? tierraConfirmada}) async {
    // `codigo` = MAC del energizador (Odoo x_mac_address). `serie` = número de
    // serie del inventario de Ohmbox en Odoo (OS-OBV01-####).
    final res = await dioClient.post('/instalador/ordenes/$id/vincular-energizador',
        body: {
          'qr': serie ?? codigo,
          'mac': codigo,
          if (serie != null) 'serial': serie,
          if (tierraConfirmada != null) 'tierraConfirmada': tierraConfirmada,
        });
    final data = (res['data'] as Map<String, dynamic>?) ?? const {};
    return (data['dashboard'] as Map<String, dynamic>?) ?? const {'ligado': true};
  }

  @override
  Future<Map<String, dynamic>> diagnosticoEnergizador(String serie, {String ordenId = ''}) async {
    final res = await dioClient.post('/instalador/energizador/diagnostico', body: {'serie': serie, if (ordenId.isNotEmpty) 'ordenId': ordenId});
    return (res['data'] as Map<String, dynamic>?) ?? const {};
  }

  @override
  Future<String> subirEvidencia(String id, String categoria, String imagenBase64) async {
    final res = await dioClient.post(
      '/instalador/ordenes/$id/evidencias',
      body: {'categoria': categoria, 'imagenBase64': imagenBase64},
    );
    final data = (res['data'] as Map<String, dynamic>?) ?? const {};
    return (data['fileKey'] ?? '').toString();
  }

  @override
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre) async {
    await dioClient.post('/instalador/ordenes/$id/cierre', body: cierre);
  }
  @override
  Future<Map<String, dynamic>> wifiCasaGuardar(String id, {String? red, bool omitir = false}) async =>
      _data(await dioClient.put('/instalador/ordenes/$id/wifi-casa', body: omitir ? {'omitir': true} : {'red': red ?? ''}));
  @override
  Future<Map<String, dynamic>> ohmboxWifi(String id, {required String red, String? contrasena}) async =>
      _data(await dioClient.post('/instalador/ordenes/$id/ohmbox/wifi', body: {'red': red, if (contrasena != null && contrasena.isNotEmpty) 'contrasena': contrasena}));
}
