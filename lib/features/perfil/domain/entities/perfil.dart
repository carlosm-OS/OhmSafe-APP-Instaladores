/// Perfil del instalador (proveedor en Odoo). RFC y CURP son campos fiscales
/// nativos; la constancia se sube como adjunto en Odoo. `perfilCompleto` = true
/// cuando hay RFC + CURP + constancia, y entonces `estado` pasa a "activo".
class Perfil {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String rfc;
  final String curp;
  final String constanciaUrl;
  final String estado; // pendiente_perfil | activo | suspendido
  final bool perfilCompleto;
  final String numeroInstalador; // ID visible (aleatorio, único) — vacío si no asignado
  final String codigoVenta; // código de descuento/bono (OHMS-…)

  const Perfil({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rfc,
    required this.curp,
    required this.constanciaUrl,
    required this.estado,
    required this.perfilCompleto,
    this.numeroInstalador = '',
    this.codigoVenta = '',
  });

  bool get tieneConstancia => constanciaUrl.isNotEmpty;
}
