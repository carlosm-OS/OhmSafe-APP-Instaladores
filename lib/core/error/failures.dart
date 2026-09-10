/// Fallos de dominio que la UI consume (a través de [Result]).
///
/// Son la contraparte "de negocio" de las excepciones de datos: el
/// `RepositoryImpl` traduce cada excepción a uno de estos [Failure] y la UI
/// decide qué mensaje mostrar según el tipo concreto.
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Error genérico del servidor (HTTP >= 400 distinto de 401).
class ServerFailure extends Failure {
  const ServerFailure([super.message = "Ocurrió un error en el servidor"]);
}

/// Credenciales inválidas / sesión no autorizada (HTTP 401).
class AuthFailure extends Failure {
  const AuthFailure([super.message = "Correo o contraseña incorrectos"]);
}

/// No hay conexión con el backend (socket/DNS/timeout).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = "Sin conexión a internet"]);
}

/// Error de caché/almacenamiento local.
class CacheFailure extends Failure {
  const CacheFailure([super.message = "Error de caché local"]);
}
