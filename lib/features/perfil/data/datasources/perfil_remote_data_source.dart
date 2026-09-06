import '../../../../core/network/dio_client.dart';
import '../models/perfil_model.dart';
import 'perfil_data_source.dart';

/// Variante Api: consume el backend real (`/v1/instalador/perfil`, etc.).
class PerfilRemoteDataSource implements PerfilDataSource {
  final DioClient dioClient;
  PerfilRemoteDataSource({required this.dioClient});

  PerfilModel _parse(Map<String, dynamic> response) {
    final data = (response['data'] ?? response) as Map<String, dynamic>;
    return PerfilModel.fromJson(data);
  }

  @override
  Future<PerfilModel> getPerfil() async {
    return _parse(await dioClient.get('/instalador/perfil'));
  }

  @override
  Future<PerfilModel> updatePerfil({String? nombre, String? telefono, String? rfc, String? curp}) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre;
    if (telefono != null) body['telefono'] = telefono;
    if (rfc != null) body['rfc'] = rfc;
    if (curp != null) body['curp'] = curp;
    return _parse(await dioClient.put('/instalador/perfil', body: body));
  }

  @override
  Future<PerfilModel> subirConstancia({required String nombreArchivo, required String contenidoBase64, String mimetype = 'application/pdf'}) async {
    return _parse(await dioClient.post('/instalador/perfil/constancia', body: {
      'nombreArchivo': nombreArchivo,
      'contenidoBase64': contenidoBase64,
      'mimetype': mimetype,
    }));
  }

  @override
  Future<void> cambiarPassword({required String passwordActual, required String passwordNueva}) async {
    await dioClient.post('/instalador/auth/cambiar-password', body: {
      'passwordActual': passwordActual,
      'passwordNueva': passwordNueva,
    });
  }
}
