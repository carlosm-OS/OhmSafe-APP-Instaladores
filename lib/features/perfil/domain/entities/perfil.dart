/// Perfil del instalador (proveedor en Odoo). Todos sus datos los carga el equipo
/// de OhmSafe en Odoo (2026-09-26); en la app sólo el RFC es editable. La
/// constancia fiscal es de uso interno: vive sólo en Odoo y no llega a la app. `estado` lo decide OhmSafe (activo /
/// no_disponible / suspendido; vacío = sin decidir).
class Perfil {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String rfc;
  final String curp;
  final String estado; // activo | no_disponible | suspendido | '' (lo decide OhmSafe)
  final bool perfilCompleto;
  final String numeroInstalador; // ID visible (aleatorio, único) — vacío si no asignado
  final String codigoVenta; // código de descuento/bono (OHMS-…)
  final String fotoBase64; // foto de perfil (Odoo image_256) en base64 — vacío si no hay
  final double? calificacion; // promedio 1-5 de las encuestas de satisfacción; null sin respuestas
  final int respuestasEncuesta;

  const Perfil({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rfc,
    required this.curp,
    required this.estado,
    required this.perfilCompleto,
    this.numeroInstalador = '',
    this.codigoVenta = '',
    this.fotoBase64 = '',
    this.calificacion,
    this.respuestasEncuesta = 0,
  });
}
