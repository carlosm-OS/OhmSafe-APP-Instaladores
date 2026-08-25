import '../../domain/entities/orden.dart';

/// Mapea el JSON del contrato (`/v1/instalador/ordenes`) a la entidad [Orden].
class OrdenModel extends Orden {
  const OrdenModel({
    required super.id,
    required super.tipo,
    required super.titulo,
    required super.estado,
    required super.urgente,
    required super.cliente,
    required super.direccion,
    required super.ciudad,
    required super.cp,
    required super.telefono,
    required super.metraje,
    required super.fechaCreacion,
    required super.diasAbierto,
  });

  factory OrdenModel.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return OrdenModel(
      id: s(json['id']),
      tipo: s(json['tipo']),
      titulo: s(json['titulo']),
      estado: s(json['estado']),
      urgente: json['urgente'] == true,
      cliente: s(json['cliente']),
      direccion: s(json['direccion']),
      ciudad: s(json['ciudad']),
      cp: s(json['cp']),
      telefono: s(json['telefono']),
      metraje: s(json['metraje']),
      fechaCreacion: s(json['fechaCreacion']),
      diasAbierto: s(json['diasAbierto']),
    );
  }
}
