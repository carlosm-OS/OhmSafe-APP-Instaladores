import '../../../../core/error/exceptions.dart';
import '../../domain/entities/acceso.dart';
import '../models/sesion_model.dart';
import 'auth_data_source.dart';

/// Variante Mock: acepta cualquier credencial no vacía y devuelve la sesión
/// del instalador de prueba (Juan Mora). Permite desarrollar el flujo de
/// login sin backend.
class AuthMockDataSource implements AuthDataSource {
  @override
  Future<SesionModel> login({required String email, required String password, String? deviceId, String? deviceName}) async {
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

  @override
  Future<void> logout() async {} // mock: nada que limpiar

  @override
  Future<AccesoSiguiente> solicitarAcceso({required String email, bool olvide = false}) async =>
      AccesoSiguiente(siguiente: olvide ? 'codigo' : 'password', esperaSegundos: 60);

  @override
  Future<CodigoVerificado> verificarCodigo({required String email, required String codigo}) async =>
      const CodigoVerificado(activacion: 'mock', primeraVez: true, nombre: 'Juan Mora', numeroInstalador: '65243');

  @override
  Future<SesionModel> activar({required String activacion, required String password, String? deviceId, String? deviceName}) =>
      login(email: 'juan@mock', password: password);
}
