import '../models/sesion_model.dart';

abstract class AuthDataSource {
  Future<SesionModel> login({required String email, required String password});
}
