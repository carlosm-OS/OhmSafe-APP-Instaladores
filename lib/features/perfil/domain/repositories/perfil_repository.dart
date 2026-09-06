import '../../../../core/network/result.dart';
import '../entities/perfil.dart';

/// Contrato del perfil del instalador (onboarding). Implementado sobre un
/// datasource Mock o Api según `EnvConfig.useMock`.
abstract class PerfilRepository {
  /// Perfil actual del instalador autenticado.
  Future<Result<Perfil>> getPerfil();

  /// Actualiza datos generales/fiscales. Recalcula el estado (activo si completo).
  Future<Result<Perfil>> updatePerfil({String? nombre, String? telefono, String? rfc, String? curp});

  /// Sube la constancia de situación fiscal (archivo en base64).
  Future<Result<Perfil>> subirConstancia({required String nombreArchivo, required String contenidoBase64, String mimetype});

  /// Cambia la contraseña (primer ingreso con temporal, o posterior).
  Future<Result<bool>> cambiarPassword({required String passwordActual, required String passwordNueva});
}
