import '../../domain/entities/perfil.dart';

/// Mapea el JSON de `/v1/instalador/perfil` a la entidad [Perfil].
class PerfilModel extends Perfil {
  const PerfilModel({
    required super.id,
    required super.nombre,
    required super.email,
    required super.telefono,
    required super.rfc,
    required super.curp,
    required super.constanciaUrl,
    required super.estado,
    required super.perfilCompleto,
    super.numeroInstalador,
    super.codigoVenta,
  });

  factory PerfilModel.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return PerfilModel(
      id: s(json['id']),
      nombre: s(json['nombre']),
      email: s(json['email']),
      telefono: s(json['telefono']),
      rfc: s(json['rfc']),
      curp: s(json['curp']),
      constanciaUrl: s(json['constanciaUrl']),
      estado: s(json['estado']).isEmpty ? 'pendiente_perfil' : s(json['estado']),
      perfilCompleto: json['perfilCompleto'] == true,
      numeroInstalador: s(json['numeroInstalador']),
      codigoVenta: s(json['codigoVenta']),
    );
  }
}
