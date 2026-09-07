import '../models/perfil_model.dart';
import 'perfil_data_source.dart';

/// Variante Mock: perfil de prueba local, sin backend.
class PerfilMockDataSource implements PerfilDataSource {
  PerfilModel _perfil = const PerfilModel(
    id: '65243',
    nombre: 'Juan Mora',
    email: 'cuadrilla1@ohmsafe.com',
    telefono: '55 8888 1122',
    rfc: '',
    curp: '',
    constanciaUrl: '',
    estado: 'pendiente_perfil',
    perfilCompleto: false,
    numeroInstalador: '14336',
    codigoVenta: 'OHMS-JUAN19',
  );

  @override
  Future<PerfilModel> getPerfil() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _perfil;
  }

  @override
  Future<PerfilModel> updatePerfil({String? nombre, String? telefono, String? rfc, String? curp}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _perfil = PerfilModel(
      id: _perfil.id,
      nombre: nombre ?? _perfil.nombre,
      email: _perfil.email,
      telefono: telefono ?? _perfil.telefono,
      rfc: rfc ?? _perfil.rfc,
      curp: curp ?? _perfil.curp,
      constanciaUrl: _perfil.constanciaUrl,
      estado: _perfil.estado,
      perfilCompleto: _perfil.perfilCompleto,
      numeroInstalador: _perfil.numeroInstalador,
      codigoVenta: _perfil.codigoVenta,
    );
    return _perfil;
  }

  @override
  Future<PerfilModel> subirConstancia({required String nombreArchivo, required String contenidoBase64, String mimetype = 'application/pdf'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _perfil = PerfilModel(
      id: _perfil.id, nombre: _perfil.nombre, email: _perfil.email, telefono: _perfil.telefono,
      rfc: _perfil.rfc, curp: _perfil.curp, constanciaUrl: 'mock://constancia.pdf',
      estado: _perfil.estado, perfilCompleto: _perfil.perfilCompleto,
      numeroInstalador: _perfil.numeroInstalador, codigoVenta: _perfil.codigoVenta,
    );
    return _perfil;
  }

  @override
  Future<PerfilModel> subirAvatar({required String contenidoBase64}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _perfil; // mock: no persiste imagen
  }

  @override
  Future<void> cambiarPassword({required String passwordActual, required String passwordNueva}) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
