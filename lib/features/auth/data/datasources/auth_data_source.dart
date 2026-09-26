import '../../domain/entities/acceso.dart';
import '../models/sesion_model.dart';

abstract class AuthDataSource {
  Future<SesionModel> login({required String email, required String password, String? deviceId, String? deviceName});

  /// Cierra sesión. En la variante Api limpia el token del [DioClient].
  Future<void> logout();

  /// Paso 1 del primer ingreso: el correo decide si pide contraseña o código.
  Future<AccesoSiguiente> solicitarAcceso({required String email, bool olvide = false});

  /// Paso 2: valida el código de 6 dígitos que llegó al correo.
  Future<CodigoVerificado> verificarCodigo({required String email, required String codigo});

  /// Paso 3: crea la contraseña y abre la sesión (misma forma que el login).
  Future<SesionModel> activar({required String activacion, required String password, String? deviceId, String? deviceName});
}
