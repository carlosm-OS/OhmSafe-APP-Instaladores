/// Orden de servicio del instalador (instalación / reparación / mantenimiento).
/// Forma alineada con el contrato del backend (`/v1/instalador/ordenes`).
class Orden {
  final String id;
  final String tipo; // instalacion | reparacion | mantenimiento
  final String titulo;
  final String estado; // por_hacer | en_curso | completo | cancelado
  final bool urgente;
  final String cliente;
  final String direccion;
  final String ciudad;
  final String cp;
  final String telefono;
  final String metraje;
  final String fechaCreacion;
  final String diasAbierto;

  const Orden({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.estado,
    required this.urgente,
    required this.cliente,
    required this.direccion,
    required this.ciudad,
    required this.cp,
    required this.telefono,
    required this.metraje,
    required this.fechaCreacion,
    required this.diasAbierto,
  });

  bool get esReparacion {
    final t = tipo.toLowerCase();
    return t.contains('reparacion') || t.contains('reparación');
  }

  /// Adaptador de compatibilidad: los flujos actuales (service_steps, cierre,
  /// route_details, etc.) consumen un `Map<String,dynamic> ticket`. Mientras
  /// migramos esas pantallas, la Orden se entrega con esa misma forma.
  Map<String, dynamic> toTicketMap() => {
        'id': id,
        'title': titulo,
        'type': tipo,
        'status': estado,
        'isUrgent': urgente,
        'user': cliente,
        'details': {
          'openDays': diasAbierto,
          'createdDate': fechaCreacion,
          'metraje': metraje,
          'direccion': direccion,
          'ciudad': ciudad,
          'cp': cp,
          'telefono': telefono,
        },
      };
}
