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
  // Agendamiento / pago (contrato `/v1/instalador/ordenes`).
  final String plan; // plan contratado, p.ej. "Hogar Seguro - Mensual"
  final double monto; // monto pagado
  final String stripePaymentId; // referencia de pago Stripe
  final String? fechaAgendada; // ISO "2026-09-15 10:00:00" o null si no agendada
  final bool agendado; // true cuando el equipo de servicio ya agendó día/hora
  // Capturado por operaciones en la llamada de agendamiento.
  final String? fechaPagoConfirmado;
  final bool contratoFirmado;
  final List<String> condicionesTerreno; // malla, vegetación, mascotas, acceso...
  /// Paso del flujo en el que está la orden, calculado por el backend a
  /// partir de lo ya guardado en Odoo: iniciar_ruta | marcar_llegada |
  /// inspeccion | instalacion | vinculacion | cierre | completo | ...
  final String pasoActual;

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
    this.plan = '',
    this.monto = 0,
    this.stripePaymentId = '',
    this.fechaAgendada,
    this.agendado = false,
    this.fechaPagoConfirmado,
    this.contratoFirmado = false,
    this.condicionesTerreno = const [],
    this.pasoActual = 'iniciar_ruta',
  });

  /// true cuando el servicio ya arrancó: la acción de la tarjeta debe
  /// retomar el paso pendiente, no volver a "iniciar ruta".
  bool get enCurso => const {
        'marcar_llegada', 'inspeccion', 'instalacion', 'vinculacion', 'cierre',
      }.contains(pasoActual);

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
          'condicionesTerreno': condicionesTerreno.join(', '),
        },
      };
}
