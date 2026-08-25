import '../../../../core/error/exceptions.dart';
import '../models/orden_model.dart';
import 'ordenes_data_source.dart';

/// Variante Mock: datos de prueba locales con la forma del contrato.
/// Permite desarrollar toda la app sin backend. En producción se sustituye
/// por [OrdenesRemoteDataSource] cambiando el flag `EnvConfig.useMock`.
class OrdenesMockDataSource implements OrdenesDataSource {
  static const List<OrdenModel> _ordenes = [
    OrdenModel(
      id: 'REP-001',
      tipo: 'reparacion',
      titulo: 'Reparación de Cerca Eléctrica',
      estado: 'por_hacer',
      urgente: true,
      cliente: 'Mariana Ríos',
      direccion: 'Cerrada de Puebla 45 Col. Roma Norte, Cuauhtémoc',
      ciudad: 'CDMX',
      cp: '06700',
      telefono: '55 2233 4455',
      metraje: '65m',
      fechaCreacion: '21/07/2026',
      diasAbierto: '1',
    ),
    OrdenModel(
      id: 'REP-002',
      tipo: 'reparacion',
      titulo: 'Reparación por daño de energizador',
      estado: 'por_hacer',
      urgente: false,
      cliente: 'Ernesto Padilla',
      direccion: 'Av. Coyoacán 1500 Col. Del Valle, Benito Juárez',
      ciudad: 'CDMX',
      cp: '03100',
      telefono: '55 7788 9900',
      metraje: '40m',
      fechaCreacion: '20/07/2026',
      diasAbierto: '2',
    ),
  ];

  @override
  Future<List<OrdenModel>> getOrdenes({required String tipo}) async {
    // Simula latencia de red para probar estados de carga.
    await Future.delayed(const Duration(milliseconds: 400));
    return _ordenes.where((o) => o.tipo == tipo).toList();
  }

  @override
  Future<OrdenModel> getOrden(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _ordenes.firstWhere(
      (o) => o.id == id,
      orElse: () => throw const ServerException('Orden no encontrada'),
    );
  }
}
