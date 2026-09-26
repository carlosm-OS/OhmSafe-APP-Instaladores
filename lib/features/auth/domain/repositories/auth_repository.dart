import '../../../../core/network/result.dart';
import '../entities/acceso.dart';
import '../entities/sesion.dart';

abstract class AuthRepository {
  /// Inicia sesión (credenciales de usuario Odoo). Guarda la sesión activa.
  Future<Result<Sesion>> login({required String email, required String password});

  /// Cierra la sesión activa.
  Future<void> logout();

  /// Sesión activa en memoria (null si no hay).
  Sesion? get sesionActual;

  /// Reconstruye la sesión guardada rotando el refresh; null si no hay o murió.
  /// Un fallo de RED lanza [NetworkException]: la sesión sigue viva.
  Future<Sesion?> restaurar();

  /// Primer ingreso: con el correo decide si sigue contraseña o código.
  Future<Result<AccesoSiguiente>> solicitarAcceso({required String email, bool olvide = false});

  /// Valida el código de 6 dígitos del correo.
  Future<Result<CodigoVerificado>> verificarCodigo({required String email, required String codigo});

  /// Crea la contraseña con el token del código y deja la sesión abierta y guardada.
  Future<Result<Sesion>> activar({required String email, required String activacion, required String password});
}
