/// Incidencia reportada desde la app: en Odoo es un ticket de Helpdesk del
/// equipo «Incidencias de campo» (contrato `/v1/instalador/incidencias`).
class Incidencia {
  final String id;
  final String referencia; // "#77"
  final String tipo; // equipo_danado | cliente_ausente | riesgo_en_sitio | falta_material | acceso_al_sitio | otro
  final String titulo;
  final String descripcion;
  final String estado; // etapa del ticket en Odoo
  final String fecha; // UTC de Odoo
  final String? ordenId;

  const Incidencia({
    required this.id,
    required this.referencia,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.fecha,
    this.ordenId,
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return Incidencia(
      id: s(json['id']),
      referencia: s(json['referencia']),
      tipo: s(json['tipo']),
      titulo: s(json['titulo']),
      descripcion: s(json['descripcion']),
      estado: s(json['estado']),
      fecha: s(json['fecha']),
      ordenId: json['ordenId'] == null ? null : s(json['ordenId']),
    );
  }
}

/// Catálogo de tipos (mismo orden y claves que el backend).
const tiposIncidencia = <String, String>{
  'equipo_danado': 'Equipo dañado',
  'cliente_ausente': 'Cliente ausente',
  'riesgo_en_sitio': 'Riesgo en sitio',
  'falta_material': 'Falta material',
  'acceso_al_sitio': 'Acceso al sitio',
  'otro': 'Otro',
};
