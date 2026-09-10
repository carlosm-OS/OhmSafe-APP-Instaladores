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
      plan: 'Reparación Cerca Eléctrica',
      monto: 1800,
      stripePaymentId: 'pi_mock_rep001',
      fechaAgendada: '2026-09-11 09:00:00',
      agendado: true,
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
      plan: 'Reparación Energizador',
      monto: 1200,
      stripePaymentId: 'pi_mock_rep002',
      fechaAgendada: '2026-09-12 11:30:00',
      agendado: true,
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
      plan: 'Fortress - Pago Anual',
      monto: 8990,
      stripePaymentId: 'pi_mock_ins001',
      fechaAgendada: '2026-09-08 10:00:00',
      agendado: true,
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
      plan: 'Hogar Seguro - Pago Mensual',
      monto: 499,
      stripePaymentId: 'pi_mock_ins002',
      // Sin agendar: demuestra el bloqueo del botón "Iniciar ruta".
      fechaAgendada: null,
      agendado: false,
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
      plan: 'Cerradura Inteligente',
      monto: 2490,
      stripePaymentId: 'pi_mock_ins003',
      fechaAgendada: '2026-09-08 16:00:00',
      agendado: true,
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
  Future<void> vincularEnergizador(String id, {required String codigo, String? serie}) => _ok();

  @override
  Future<Map<String, dynamic>> diagnosticoEnergizador(String serie) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return {
      'encontrado': true, 'serie': serie, 'mac': 'AA:BB:CC:00:CA:R1',
      'enLinea': true, 'conexionLinea': true, 'bateria': 'ok', 'bateriaVoltaje': 13.9,
      'cercaActiva': true, 'firmware': '2.7.1.0', 'ultimoReporte': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre) => _ok();
}
