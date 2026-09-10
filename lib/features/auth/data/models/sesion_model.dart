import '../../domain/entities/sesion.dart';

class SesionModel extends Sesion {
  const SesionModel({
    required super.accessToken,
    required super.refreshToken,
    required super.instaladorId,
    required super.nombre,
    required super.numeroInstalador,
    required super.rol,
    super.debeCambiarPassword,
  });

  factory SesionModel.fromJson(Map<String, dynamic> json) {
    final inst = (json['instalador'] ?? {}) as Map<String, dynamic>;
    String s(dynamic v) => v?.toString() ?? '';
    return SesionModel(
      accessToken: s(json['accessToken']),
      refreshToken: s(json['refreshToken']),
      instaladorId: s(inst['id']),
      nombre: s(inst['nombre']),
      numeroInstalador: s(inst['numeroInstalador']),
      rol: s(inst['rol']),
      debeCambiarPassword: json['debeCambiarPassword'] == true,
    );
  }
}
