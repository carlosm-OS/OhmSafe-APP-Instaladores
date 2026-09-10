/// Excepciones de la capa de datos (datasources / red).
///
/// Se lanzan en los datasources y las traduce a [Failure] el `RepositoryImpl`.
/// La distinción entre ellas es lo que permite a la UI mostrar el mensaje
/// correcto (p. ej. credenciales inválidas vs. falta de red).

/// Error del backend con respuesta HTTP (status >= 400, salvo 401).
/// [message] trae, si existe, el texto de error que devolvió el backend.
class ServerException implements Exception {
  final String message;
  const ServerException([this.message = "Error del servidor"]);
}

/// Credenciales inválidas o sesión no autorizada (HTTP 401).
/// Se separa de [ServerException] para que el login pueda mostrar
/// "correo o contraseña incorrectos" en vez de un error genérico.
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = "No autorizado"]);
}

/// Error de caché/almacenamiento local.
class CacheException implements Exception {
  final String message;
  const CacheException([this.message = "Error de caché"]);
}

/// Fallo real de conectividad: no se pudo establecer la conexión con el
/// backend (socket, DNS, timeout). NO se usa para respuestas HTTP de error.
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = "Sin conexión"]);
}
