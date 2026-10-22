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
  Future<void> marcarLlegada(String id, {Map<String, dynamic>? ubicacion}) => _ok();

  @override
  Future<void> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos, double? metrosReales}) => _ok();

  @override
  Future<void> guardarInstalacion(String id, Map<String, dynamic> registro) => _ok();

  @override
  Future<void> guardarReparacion(String id, Map<String, dynamic> costeo) => _ok();

  @override
  Future<Map<String, dynamic>> vincularEnergizador(String id, {required String codigo, String? serie, bool? tierraConfirmada}) async {
    await _ok();
    return {'ligado': true};
  }
  @override
  Future<Map<String, dynamic>> casasParaVincular(String id) async {
    await _ok();
    return {
      'clienteConCuenta': true,
      'casas': [],
      'sugerida': null,
      'nueva': {'nombre': 'Av. Insurgentes Sur 1234', 'direccion': 'Av. Insurgentes Sur 1234, CDMX'},
      'venta': {'nombre': 'S00170', 'esServicioNuevo': true, 'plan': 'Plan Hogar Seguro - Mensual', 'equipos': [{'nombre': 'Ohmbox/Energizador', 'cantidad': 1}]},
      'destino': {'tipo': 'nueva', 'nombre': 'Av. Insurgentes Sur 1234', 'direccion': 'Av. Insurgentes Sur 1234, CDMX', 'motivo': 'S00170 es un plan nuevo: va a una casa nueva con la dirección de la compra.', 'aviso': null},
    };
  }
  final List<Map<String, dynamic>> _mockRf = [];
  final List<Map<String, dynamic>> _mockWifi = [];
  final List<Map<String, dynamic>> _mockCams = [];
  int _mockPaso = 0;
  @override
  Future<Map<String, dynamic>> dispositivosEstado(String id) async {
    await _ok();
    return {
      // Energizador opcional (2026-10-20): null cuando la casa aún no tiene energizador vinculado.
      'energizador': {'id': 'dev-1', 'serie': 'OS-PRUEBA-0005'},
     
      'equipo': {'id': 'dev-mock', 'serie': 'OS-PRUEBA-0001', 'firmware': '2.11.0.14'},
      'rf': {'soportado': true, 'dispositivos': _mockRf, 'limites': {}, 'aprendizaje': null},
      'wifi': {'sensores': _mockWifi, 'limites': {}, 'usados': {}},
      'camaras': {'habilitadas': true, 'proveedores': {'ezviz': true, 'imou': true}, 'lista': _mockCams, 'max': 32},
    };
  }
  Map<String, dynamic> _sesion(String tipo, {String status = 'listening'}) => {'sid': 'mock1', 'kind': tipo, 'status': status, 'phase': tipo == 'door' ? (_mockPaso == 0 ? 'open' : 'close') : 'btn', 'step': _mockPaso + 1, 'steps': tipo == 'door' ? 2 : tipo == 'fob' ? 3 : 1, 'frames': 0, 'need': 2, 'addr': status == 'listening' ? null : 'A1B2C3', 'captured': []};
  String _mockTipo = 'door';
  @override
  Future<Map<String, dynamic>> rfAprender(String id, {required String tipo, String? nombre, int? botones}) async { await _ok(); _mockTipo = tipo; _mockPaso = 0; return {'sesion': _sesion(tipo)}; }
  @override
  Future<Map<String, dynamic>> rfSesion(String id, String sid) async { await _ok(); _mockPaso++; return {'sesion': _sesion(_mockTipo, status: _mockPaso >= 2 ? 'done' : 'listening')}; }
  @override
  Future<Map<String, dynamic>> rfTerminar(String id, String sid, {required String nombre}) async { await _ok(); _mockRf.add({'id': 'rf${_mockRf.length}', 'tipo': _mockTipo, 'nombre': nombre}); return {'device': {'name': nombre}}; }
  @override
  Future<Map<String, dynamic>> rfCancelar(String id, String sid) async { await _ok(); return {'sesion': _sesion(_mockTipo, status: 'cancelled')}; }
  @override
  Future<Map<String, dynamic>> sensorWifiAgregar(String id, {required String externalId, required String nombre, required String tipo}) async { await _ok(); _mockWifi.add({'id': externalId, 'tipo': tipo, 'nombre': nombre, 'externalId': externalId}); return {'sensor': {'name': nombre}}; }
  @override
  Future<Map<String, dynamic>> camaraAgregar(String id, {String? proveedor, required String serie, required String codigo, required String nombre}) async { await _ok(); _mockCams.add({'id': serie, 'proveedor': proveedor ?? 'cam', 'nombre': nombre, 'serie': serie, 'estado': 'online'}); return {'camara': {'name': nombre}}; }
  @override
  Future<Map<String, dynamic>> wifiSesion(String id, String proveedor) async { await _ok(); return {'provider': proveedor, 'appKey': 'mock', 'areaDomain': 'https://iusopen.ezvizlife.com', 'region': 'na', 'accountName': 'mock', 'accessToken': 'mock', 'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String()}; }
  @override
  Future<Map<String, dynamic>> ezvizSondeo(String id, String serie) async { await _ok(); return {'state': 'online_unbound'}; }
  @override
  Future<Map<String, dynamic>> tuyaToken(String id, {required String modo, String? zonaHoraria}) async { await _ok(); return {'provider': 'tuya', 'authToken': 'AZmocktokmocksec', 'region': 'AZ', 'token': 'mocktok', 'secret': 'mocksec', 'expiresAt': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(), 'homeId': '1'}; }
  @override
  Future<Map<String, dynamic>> tuyaTokenResultado(String id, String token) async { await _ok(); return {'successDevices': [{'id': 'ebmock1', 'name': 'Sensor', 'category': 'mcs'}], 'errorDevices': []}; }
  @override
  Future<Map<String, dynamic>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category, String? serie}) async { await _ok(); _mockCams.add({'id': externalId, 'proveedor': proveedor, 'nombre': nombre, 'serie': serie ?? externalId, 'estado': 'online', 'red': red}); return {'dispositivo': {'name': nombre, 'pairing': {'ssid': red, 'serial': serie}}}; }
  final List<Map<String, dynamic>> _mockOhmbox = [
    {'id': 'dev-mock', 'serie': 'OS-PRUEBA-0001', 'nombre': 'Cerca', 'enLinea': true, 'principal': true},
  ];
  @override
  Future<Map<String, dynamic>> ohmboxEstado(String id) async { await _ok(); return {'casa': {'id': 'casa-1', 'nombre': 'Casa Mock'}, 'energizadores': _mockOhmbox}; }
  @override
  Future<Map<String, dynamic>> ohmboxAgregar(String id, {required String serie, String? mac}) async {
    await _ok();
    _mockOhmbox.add({'id': 'dev-${_mockOhmbox.length + 1}', 'serie': serie, 'nombre': 'Cerca', 'enLinea': false, 'principal': false});
    return {'casa': {'id': 'casa-1', 'nombre': 'Casa Mock'}, 'energizadores': _mockOhmbox};
  }
  Map<String, dynamic> _prueba({bool abierta = true, bool cerca = false}) => {
        'intervencion': 'i1',
        'ventana': {'abierta': abierta, 'vence': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(), 'segundosRestantes': abierta ? 1800 : 0, 'propia': abierta},
        'equipo': {'id': 'dev-mock', 'serie': 'OS-PRUEBA-0001', 'nombre': 'Cerca', 'enLinea': true, 'ultimoReporte': DateTime.now().toIso8601String(), 'cercaEncendida': cerca, 'alarmaActiva': false, 'sirenaSonando': false},
      };
  bool _mockCerca = false;
  @override
  Future<Map<String, dynamic>> pruebaEstado(String id) async { await _ok(); return _prueba(cerca: _mockCerca); }
  @override
  Future<Map<String, dynamic>> pruebaAbrir(String id) async { await _ok(); return _prueba(cerca: _mockCerca); }
  @override
  Future<Map<String, dynamic>> pruebaExtender(String id) async { await _ok(); return _prueba(cerca: _mockCerca); }
  @override
  Future<Map<String, dynamic>> pruebaAccion(String id, String accion) async { await _ok(); _mockCerca = accion == 'cerca_on'; return {..._prueba(cerca: _mockCerca), 'resultado': 'sent'}; }
  /// Como el equipo real: tras «Probar», la salida queda marcada como probada.
  final Set<int> _salidasProbadas = {};
  Map<String, dynamic> _cableado() => {
        'intervencion': 'i1',
        'equipo': {'id': 'dev-mock', 'serie': 'OS-PRUEBA-0001', 'firmware': '2.11.0.14', 'firmwareOk': true, 'firmwareMinimo': '2.10.0.0', 'enLinea': true, 'alarmaArmada': false, 'estadoEntradasEn': null},
        'entradas': [
          {'index': 1, 'nombre': 'Puerta 1', 'dadaDeAlta': false, 'enUso': true, 'abierta': true, 'prueba': null},
          {'index': 2, 'nombre': 'Puerta 2', 'dadaDeAlta': false, 'enUso': true, 'abierta': true, 'prueba': null},
        ],
        'sirena': {'sonando': false, 'probada': false, 'sono': null},
        'salidas': [
          for (final i in [1, 2]) {'index': i, 'nombre': null, 'dadaDeAlta': false, 'encendida': false, 'tipo': null, 'modo': null, 'probada': _salidasProbadas.contains(i), 'cerro': null},
        ],
      };
  @override
  Future<Map<String, dynamic>> cableadoEstado(String id) async { await _ok(); return _cableado(); }
  @override
  Future<Map<String, dynamic>> cableadoProbarEntrada(String id, int index) async { await _ok(); return _cableado(); }
  @override
  Future<Map<String, dynamic>> cableadoRegistrarEntrada(String id, int index, {required String nombre, String? icono}) async { await _ok(); return _cableado(); }
  @override
  Future<Map<String, dynamic>> cableadoProbarSirena(String id) async { await _ok(); return _cableado(); }
  @override
  Future<Map<String, dynamic>> cableadoConfirmarSirena(String id, {required bool sono}) async { await _ok(); return _cableado(); }
  @override
  Future<Map<String, dynamic>> cableadoSirena(String id, {required bool encender}) async {
    await _ok();
    final c = _cableado();
    return {...c, 'sirena': {'sonando': encender, 'probada': true, 'sono': null}};
  }
  @override
  Future<Map<String, dynamic>> cableadoProbarSalida(String id, int index) async { await _ok(); _salidasProbadas.add(index); return _cableado(); }
  @override
  Future<Map<String, dynamic>> cableadoRegistrarSalida(String id, int index, {required String nombre, required String tipo, required String modo, int? pulsoSeg, required bool funciono}) async { await _ok(); return _cableado(); }
  @override
  Future<Map<String, dynamic>> pruebaTerminar(String id) async { await _ok(); return _prueba(abierta: false, cerca: _mockCerca); }
  @override
  Future<Map<String, dynamic>> cancelar(String id, {required String motivo, String? notas, String? fotoBase64, Map<String, dynamic>? ubicacion}) async => {'estado': 'cancelado'};

  @override
  Future<List<Map<String, dynamic>>> historial({String rango = 'todo'}) async => const [];

  @override
  Future<Map<String, dynamic>> diagnosticoEnergizador(String serie, {String ordenId = ''}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return {
      'encontrado': true, 'serie': serie, 'mac': 'AA:BB:CC:00:CA:R1',
      'enLinea': true, 'conexionLinea': true, 'bateria': 'ok', 'bateriaVoltaje': 13.9,
      'cercaActiva': true, 'firmware': '2.7.1.0', 'ultimoReporte': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<String> subirEvidencia(String id, String categoria, String imagenBase64) async =>
      '/web/content/0';

  @override
  Future<void> guardarCierre(String id, Map<String, dynamic> cierre) => _ok();
  @override
  Future<Map<String, dynamic>> wifiCasaGuardar(String id, {String? red, bool omitir = false}) async {
    await _ok();
    return omitir ? {'estado': 'omitida', 'red': null} : {'estado': 'lista', 'red': red};
  }
  @override
  Future<Map<String, dynamic>> ohmboxWifi(String id, {required String red, String? contrasena}) async {
    await _ok();
    return {'ok': true, 'red': red, 'ip': '192.168.1.40'};
  }
}
