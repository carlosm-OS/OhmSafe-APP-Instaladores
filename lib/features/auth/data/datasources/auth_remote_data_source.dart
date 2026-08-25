import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/sesion_model.dart';
import 'auth_data_source.dart';

/// Variante Api: login contra el backend real (`/v1/instalador/auth/login`),
/// que valida contra usuario de Odoo. Lista para cuando exista el endpoint.
class AuthRemoteDataSource implements AuthDataSource {
  final DioClient dioClient;

  AuthRemoteDataSource({required this.dioClient});

  @override
  Future<SesionModel> login({required String email, required String password}) async {
    final response = await dioClient.post(
      '/instalador/auth/login',
      body: {'email': email, 'password': password},
    );
    if (response.isEmpty) throw const ServerException('Respuesta de login vacía');
    return SesionModel.fromJson(response);
  }
}
