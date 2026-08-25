import '../../../../core/error/exceptions.dart';
import '../models/sesion_model.dart';
import 'auth_data_source.dart';

/// Variante Mock: acepta cualquier credencial no vacía y devuelve la sesión
/// del instalador de prueba (Juan Mora). Permite desarrollar el flujo de
/// login sin backend.
class AuthMockDataSource implements AuthDataSource {
  @override
  Future<SesionModel> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw const ServerException('Ingresa correo y contraseña');
    }
    return const SesionModel(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      instaladorId: '65243',
      nombre: 'Juan Mora',
      numeroInstalador: '65243',
      rol: 'Instalador',
    );
  }
}
