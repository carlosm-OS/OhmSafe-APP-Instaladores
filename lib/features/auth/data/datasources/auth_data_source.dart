import '../models/sesion_model.dart';

abstract class AuthDataSource {
  Future<SesionModel> login({required String email, required String password});

  /// Cierra sesión. En la variante Api limpia el token del [DioClient].
  Future<void> logout();
}
