import '../models/perfil_model.dart';

/// Fuente de datos del perfil del instalador. Variante Mock (local) y Api
/// (backend `/v1/instalador/perfil`), según `EnvConfig.useMock`.
abstract class PerfilDataSource {
  Future<PerfilModel> getPerfil();
  Future<PerfilModel> updatePerfil({String? nombre, String? telefono, String? rfc, String? curp});
  Future<PerfilModel> subirConstancia({required String nombreArchivo, required String contenidoBase64, String mimetype});
  Future<void> cambiarPassword({required String passwordActual, required String passwordNueva});
}
