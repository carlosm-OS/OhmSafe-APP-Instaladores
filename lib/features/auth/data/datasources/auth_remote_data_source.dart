import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/acceso.dart';
import '../models/sesion_model.dart';
import 'auth_data_source.dart';

/// Variante Api: login contra el backend real (`/v1/instalador/auth/login`),
/// que valida contra usuario de Odoo. Lista para cuando exista el endpoint.
class AuthRemoteDataSource implements AuthDataSource {
  final DioClient dioClient;

  AuthRemoteDataSource({required this.dioClient});

  @override
  Future<SesionModel> login({required String email, required String password, String? deviceId, String? deviceName}) async {
    final response = await dioClient.post(
      '/instalador/auth/login',
      body: {
        'email': email,
        'password': password,
        // Con deviceId el backend abre una sesión persistente (refresh rotado
        // ligado a este dispositivo); sin él, la de 15 minutos de antes.
        if (deviceId != null) 'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
      },
      sinReintento: true,
    );
    if (response.isEmpty) throw const ServerException('Respuesta de login vacía');
    // El backend responde { success, data: { accessToken, refreshToken, instalador } }.
    final data = (response['data'] ?? response) as Map<String, dynamic>;
    final sesion = SesionModel.fromJson(data);
    // Propaga el access token a las siguientes peticiones (Authorization: Bearer).
    if (sesion.accessToken.isNotEmpty) dioClient.setAuthToken(sesion.accessToken);
    return sesion;
  }

  @override
  Future<void> logout() async {
    // Limpia el Bearer para que las siguientes peticiones no usen el token viejo.
    dioClient.clearAuthToken();
  }

  Map<String, dynamic> _data(Map<String, dynamic> r) => (r['data'] ?? r) as Map<String, dynamic>;

  @override
  Future<AccesoSiguiente> solicitarAcceso({required String email, bool olvide = false}) async {
    final r = await dioClient.post('/instalador/auth/correo', body: {'email': email.trim(), if (olvide) 'olvide': true}, sinReintento: true);
    return AccesoSiguiente.fromJson(_data(r));
  }

  @override
  Future<CodigoVerificado> verificarCodigo({required String email, required String codigo}) async {
    final r = await dioClient.post('/instalador/auth/codigo', body: {'email': email.trim(), 'codigo': codigo.trim()}, sinReintento: true);
    return CodigoVerificado.fromJson(_data(r));
  }

  @override
  Future<SesionModel> activar({required String activacion, required String password, String? deviceId, String? deviceName}) async {
    final r = await dioClient.post('/instalador/auth/activar', body: {
      'activacion': activacion,
      'password': password,
      'deviceId': ?deviceId,
      'deviceName': ?deviceName,
    }, sinReintento: true);
    final sesion = SesionModel.fromJson(_data(r));
    if (sesion.accessToken.isNotEmpty) dioClient.setAuthToken(sesion.accessToken);
    return sesion;
  }
}
