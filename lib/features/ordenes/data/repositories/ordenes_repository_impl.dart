import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/result.dart';
import '../../domain/entities/orden.dart';
import '../../domain/entities/tarifas.dart';
import '../../domain/repositories/ordenes_repository.dart';
import '../datasources/ordenes_data_source.dart';

class OrdenesRepositoryImpl implements OrdenesRepository {
  final OrdenesDataSource dataSource;

  OrdenesRepositoryImpl({required this.dataSource});

  @override
  Future<Result<List<Orden>>> getOrdenes({required String tipo}) async {
    try {
      final ordenes = await dataSource.getOrdenes(tipo: tipo);
      return Success(ordenes);
    } on UnauthorizedException {
      // 401 en una lectura/acción = sesión expirada.
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Orden>> getOrden(String id) async {
    try {
      final orden = await dataSource.getOrden(id);
      return Success(orden);
    } on UnauthorizedException {
      // 401 en una lectura/acción = sesión expirada.
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Tarifas>> getTarifas() async {
    try {
      final tarifas = await dataSource.getTarifas();
      return Success(tarifas);
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  // ---- Acciones de escritura ----

  /// Envuelve una acción de escritura en Result<bool> con manejo de errores.
  Future<Result<bool>> _accion(Future<void> Function() run) async {
    try {
      await run();
      return const Success(true);
    } on UnauthorizedException {
      // 401 en una lectura/acción = sesión expirada.
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> iniciarRuta(String id) => _accion(() => dataSource.iniciarRuta(id));

  @override
  Future<Result<bool>> marcarLlegada(String id, {Map<String, dynamic>? ubicacion}) =>
      _accion(() => dataSource.marcarLlegada(id, ubicacion: ubicacion));

  @override
  Future<Result<bool>> guardarInspeccion(String id, {required bool sinObstaculos, required List<String> obstaculos, double? metrosReales}) =>
      _accion(() => dataSource.guardarInspeccion(id, sinObstaculos: sinObstaculos, obstaculos: obstaculos, metrosReales: metrosReales));

  @override
  Future<Result<bool>> guardarInstalacion(String id, Map<String, dynamic> registro) =>
      _accion(() => dataSource.guardarInstalacion(id, registro));

  @override
  Future<Result<bool>> guardarReparacion(String id, Map<String, dynamic> costeo) =>
      _accion(() => dataSource.guardarReparacion(id, costeo));

  @override
  Future<Result<Map<String, dynamic>>> cancelar(String id, {required String motivo, String? notas, String? fotoBase64, Map<String, dynamic>? ubicacion}) async {
    try {
      return Success(await dataSource.cancelar(id, motivo: motivo, notas: notas, fotoBase64: fotoBase64, ubicacion: ubicacion));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> historial({String rango = 'todo'}) async {
    try {
      return Success(await dataSource.historial(rango: rango));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> casasParaVincular(String id) async {
    try {
      return Success(await dataSource.casasParaVincular(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> pruebaEstado(String id) async {
    try {
      return Success(await dataSource.pruebaEstado(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> pruebaAbrir(String id) async {
    try {
      return Success(await dataSource.pruebaAbrir(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> pruebaExtender(String id) async {
    try {
      return Success(await dataSource.pruebaExtender(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> pruebaAccion(String id, String accion) async {
    try {
      return Success(await dataSource.pruebaAccion(id, accion));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> pruebaTerminar(String id) async {
    try {
      return Success(await dataSource.pruebaTerminar(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> dispositivosEstado(String id) async {
    try {
      return Success(await dataSource.dispositivosEstado(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> rfAprender(String id, {required String tipo, String? nombre}) async {
    try {
      return Success(await dataSource.rfAprender(id, tipo: tipo, nombre: nombre));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> rfSesion(String id, String sid) async {
    try {
      return Success(await dataSource.rfSesion(id, sid));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> rfTerminar(String id, String sid, {required String nombre}) async {
    try {
      return Success(await dataSource.rfTerminar(id, sid, nombre: nombre));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> rfCancelar(String id, String sid) async {
    try {
      return Success(await dataSource.rfCancelar(id, sid));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> sensorWifiAgregar(String id, {required String externalId, required String nombre, required String tipo}) async {
    try {
      return Success(await dataSource.sensorWifiAgregar(id, externalId: externalId, nombre: nombre, tipo: tipo));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> camaraAgregar(String id, {String? proveedor, required String serie, required String codigo, required String nombre}) async {
    try {
      return Success(await dataSource.camaraAgregar(id, proveedor: proveedor, serie: serie, codigo: codigo, nombre: nombre));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> wifiSesion(String id, String proveedor) async {
    try {
      return Success(await dataSource.wifiSesion(id, proveedor));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> ezvizSondeo(String id, String serie) async {
    try {
      return Success(await dataSource.ezvizSondeo(id, serie));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> imouSesion(String id) async {
    try {
      return Success(await dataSource.imouSesion(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> imouSondeo(String id, String serie) async {
    try {
      return Success(await dataSource.imouSondeo(id, serie));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> tuyaToken(String id, {required String modo, String? zonaHoraria}) async {
    try {
      return Success(await dataSource.tuyaToken(id, modo: modo, zonaHoraria: zonaHoraria));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> tuyaTokenResultado(String id, String token) async {
    try {
      return Success(await dataSource.tuyaTokenResultado(id, token));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category}) async {
    try {
      return Success(await dataSource.dispositivoWifiAgregar(id, proveedor: proveedor, clase: clase, externalId: externalId, nombre: nombre, codigo: codigo, red: red, tipo: tipo, productId: productId, category: category));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> ohmboxEstado(String id) async {
    try {
      return Success(await dataSource.ohmboxEstado(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> ohmboxAgregar(String id, {required String serie, String? mac}) async {
    try {
      return Success(await dataSource.ohmboxAgregar(id, serie: serie, mac: mac));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoEstado(String id) async {
    try {
      return Success(await dataSource.cableadoEstado(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoProbarEntrada(String id, int index) async {
    try {
      return Success(await dataSource.cableadoProbarEntrada(id, index));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoRegistrarEntrada(String id, int index, {required String nombre, String? icono}) async {
    try {
      return Success(await dataSource.cableadoRegistrarEntrada(id, index, nombre: nombre, icono: icono));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoProbarSirena(String id) async {
    try {
      return Success(await dataSource.cableadoProbarSirena(id));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoConfirmarSirena(String id, {required bool sono}) async {
    try {
      return Success(await dataSource.cableadoConfirmarSirena(id, sono: sono));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoProbarSalida(String id, int index) async {
    try {
      return Success(await dataSource.cableadoProbarSalida(id, index));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> cableadoRegistrarSalida(String id, int index, {required String nombre, required String tipo, required String modo, int? pulsoSeg, required bool funciono}) async {
    try {
      return Success(await dataSource.cableadoRegistrarSalida(id, index, nombre: nombre, tipo: tipo, modo: modo, pulsoSeg: pulsoSeg, funciono: funciono));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> vincularEnergizador(String id, {required String codigo, String? serie, bool? tierraConfirmada}) async {
    try {
      return Success(await dataSource.vincularEnergizador(id, codigo: codigo, serie: serie, tierraConfirmada: tierraConfirmada));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> diagnosticoEnergizador(String serie, {String ordenId = ''}) async {
    try {
      return Success(await dataSource.diagnosticoEnergizador(serie, ordenId: ordenId));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> subirEvidencia(String id, String categoria, String imagenBase64) async {
    try {
      return Success(await dataSource.subirEvidencia(id, categoria, imagenBase64));
    } on UnauthorizedException {
      return const FailureResult(AuthFailure("Sesión expirada, vuelve a iniciar sesión"));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, e.code, e.details));
    } on NetworkException {
      return const FailureResult(NetworkFailure());
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> guardarCierre(String id, Map<String, dynamic> cierre) =>
      _accion(() => dataSource.guardarCierre(id, cierre));
}
