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
    super.direccionCompleta,
    super.lat,
    super.lng,
    required super.metraje,
    required super.fechaCreacion,
    required super.diasAbierto,
    super.plan,
    super.monto,
    super.stripePaymentId,
    super.fechaAgendada,
    super.fechaFin,
    super.agendado,
    super.fechaPagoConfirmado,
    super.contratoFirmado,
    super.condicionesTerreno,
    super.pasoActual,
    super.origen,
    super.ordenVenta,
    super.hojaTrabajo,
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
      direccionCompleta: s(json['direccionCompleta']),
      lat: ((json['coordenadas'] as Map?)?['lat'] as num?)?.toDouble(),
      lng: ((json['coordenadas'] as Map?)?['lng'] as num?)?.toDouble(),
      metraje: s(json['metraje']),
      fechaCreacion: s(json['fechaCreacion']),
      diasAbierto: s(json['diasAbierto']),
      plan: s(json['plan']),
      monto: (json['monto'] as num?)?.toDouble() ?? 0,
      stripePaymentId: s(json['stripePaymentId']),
      fechaAgendada: json['fechaAgendada'] as String?,
      fechaFin: json['fechaFin'] as String?,
      agendado: json['agendado'] == true,
      fechaPagoConfirmado: json['fechaPagoConfirmado'] as String?,
      contratoFirmado: json['contratoFirmado'] == true,
      condicionesTerreno: (json['condicionesTerreno'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      pasoActual: s(json['pasoActual']).isEmpty ? 'iniciar_ruta' : s(json['pasoActual']),
      origen: s(json['origen']),
      ordenVenta: s(json['ordenVenta']),
      hojaTrabajo: (json['hojaTrabajo'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
    );
  }
}
