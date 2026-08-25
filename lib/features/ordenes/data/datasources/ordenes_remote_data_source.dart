import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/orden_model.dart';
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

  // ---- Escritura (POST según el contrato) ----
  @override
  Future<void> iniciarRuta(String id) async {
    await dioClient.post('/instalador/ordenes/$id/iniciar-ruta');
  }

  @override
  Future<void> marcarLlegada(String id) async {
    await dioClient.post('/instalador/ordenes/$id/marcar-llegada');
  }

  @override
  Future<void> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos}) async {
    await dioClient.post('/instalador/ordenes/$id/inspeccion-perimetro',
        body: {'sinObstaculos': sinObstaculos, 'obstaculos': obstaculos});
  }

  @override
  Future<void> guardarReparacion(String id, Map<String, dynamic> costeo) async {
    await dioClient.post('/instalador/ordenes/$id/reparacion', body: costeo);
  }

  @override
  Future<void> vincularEnergizador(String id, {required String codigo}) async {
    await dioClient.post('/instalador/ordenes/$id/vincular-energizador', body: {'codigo': codigo});
  }

  @override
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre) async {
    await dioClient.post('/instalador/ordenes/$id/cierre', body: cierre);
  }
}
