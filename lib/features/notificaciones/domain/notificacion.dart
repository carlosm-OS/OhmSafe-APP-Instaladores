/// Aviso para el instalador (asignación, reagenda, cancelación o mensaje de
/// operaciones). Vive en el chatter de su tarea en Odoo; ver el backend.
class Notificacion {
  final String id;
  final String tipo; // asignacion | agenda | cancelacion | mensaje
  final String titulo;
  final String cuerpo;
  final String fecha; // "2026-09-17 20:11:05" (UTC, como lo entrega Odoo)
  final bool leida;
  final String? ordenId;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.fecha,
    required this.leida,
    this.ordenId,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return Notificacion(
      id: s(json['id']),
      tipo: s(json['tipo']).isEmpty ? 'mensaje' : s(json['tipo']),
      titulo: s(json['titulo']),
      cuerpo: s(json['cuerpo']),
      fecha: s(json['fecha']),
      leida: json['leida'] == true,
      ordenId: json['ordenId'] as String?,
    );
  }
}
