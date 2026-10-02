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
}
