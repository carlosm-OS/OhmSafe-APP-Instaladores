abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = "Ocurrió un error en el servidor"]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = "Sin conexión a internet"]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = "Error de caché local"]);
}
