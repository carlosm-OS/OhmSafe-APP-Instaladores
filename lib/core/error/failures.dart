import 'package:flutter/foundation.dart';

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
  /// Código del backend (vacío si no viene), p. ej. FUERA_DE_SITIO.
  final String code;
  final Map<String, dynamic> details;
  const ServerFailure([super.message = "Ocurrió un error en el servidor", this.code = '', this.details = const {}]);
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

/// Mensaje único cuando algo truena del lado de la app o del servidor (auditoría 2026-10-23): el
/// instalador nunca ve el texto técnico («type 'Null' is not a subtype…»); el detalle va al registro.
const mensajeFallaInesperada = 'Algo falló de nuestro lado. Vuelve a intentar; si sigue, avisa a soporte.';

/// Sesión vencida, con las mismas palabras en toda la app (glosario 2026-10-23).
const mensajeSesionVencida = 'Tu sesión venció. Entra de nuevo con tu contraseña.';

ServerFailure fallaInesperada(Object e) {
  debugPrint('Falla inesperada: $e');
  return const ServerFailure(mensajeFallaInesperada);
}
