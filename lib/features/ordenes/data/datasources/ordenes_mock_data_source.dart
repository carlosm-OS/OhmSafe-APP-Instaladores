import '../../../../core/error/exceptions.dart';
import '../models/orden_model.dart';
import '../../domain/entities/tarifas.dart';
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
    // --- Instalaciones ---
    OrdenModel(
      id: 'INS-001',
      tipo: 'instalacion',
      titulo: 'Ticket de Instalación Fortress + Pago Anual',
      estado: 'por_hacer',
      urgente: false,
      cliente: 'Alfredo López',
      direccion: 'Nellie Campobello 129 Col. Sn Pedro, Alcaldía A.Obregón',
      ciudad: 'CDMX',
      cp: '10820',
      telefono: '55 1455 6678',
      metraje: '70m',
      fechaCreacion: '7/02/2026',
      diasAbierto: '1',
    ),
    OrdenModel(
      id: 'INS-002',
      tipo: 'instalacion',
      titulo: 'Ticket de Instalación Hogar Seguro Pago Mensual',
      estado: 'por_hacer',
      urgente: false,
      cliente: 'Sonia Morales',
      direccion: 'Av. Universidad 1200 Col. Xoco, Benito Juárez',
      ciudad: 'CDMX',
      cp: '03330',
      telefono: '55 9876 5432',
      metraje: '35m',
      fechaCreacion: '22/05/2026',
      diasAbierto: '3',
    ),
    OrdenModel(
      id: 'INS-003',
      tipo: 'instalacion',
      titulo: 'Ticket de Instalación Cerradura Inteligente',
      estado: 'en_curso',
      urgente: true,
      cliente: 'Sonia Morales',
      direccion: 'Temístocles 89, Miguel Hidalgo, CDMX',
      ciudad: 'CDMX',
      cp: '11560',
      telefono: '55 6677 8899',
      metraje: '15m',
      fechaCreacion: '20/05/2026',
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

  @override
  Future<Tarifas> getTarifas() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return Tarifas.defaults(); // mock: usa los valores firmes locales
  }

  // ---- Escritura (mock: simula latencia y confirma OK) ----
  Future<void> _ok() => Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<void> iniciarRuta(String id) => _ok();

  @override
  Future<void> marcarLlegada(String id) => _ok();

  @override
  Future<void> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos}) => _ok();

  @override
  Future<void> guardarInstalacion(String id, Map<String, dynamic> registro) => _ok();

  @override
  Future<void> guardarReparacion(String id, Map<String, dynamic> costeo) => _ok();

  @override
  Future<void> vincularEnergizador(String id, {required String codigo}) => _ok();

  @override
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre) => _ok();
}
