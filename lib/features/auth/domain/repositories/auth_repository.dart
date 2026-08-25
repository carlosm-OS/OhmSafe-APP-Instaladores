import '../../../../core/network/result.dart';
import '../entities/sesion.dart';

abstract class AuthRepository {
  /// Inicia sesión (credenciales de usuario Odoo). Guarda la sesión activa.
  Future<Result<Sesion>> login({required String email, required String password});

  /// Cierra la sesión activa.
  Future<void> logout();

  /// Sesión activa en memoria (null si no hay).
  Sesion? get sesionActual;
}
