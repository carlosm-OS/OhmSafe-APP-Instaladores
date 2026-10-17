/// A dónde va el energizador al vincular (2026-10-14, una vivienda = una suscripción).
///
/// Ya no lo elige el instalador: lo decide la venta en el backend (`destino` de
/// `GET /instalador/ordenes/:id/casas`) y la app sólo lo muestra para confirmar.
///   · plan nuevo → casa nueva con la dirección de la compra;
///   · equipo adicional → la casa del contrato;
///   · `indeterminada` → no se puede vincular hasta que operaciones ligue la venta.
/// Un segundo energizador en la misma casa se instala desde «Agregar dispositivos → OhmBox».
library;

/// Qué se vendió en la venta de la intervención (backend `venta` de `GET /ordenes/:id/casas`, 2026-10-09):
/// un servicio nuevo (plan) va normalmente en una casa nueva; el equipo adicional se suma a una casa.
class VentaResumen {
  const VentaResumen({required this.nombre, required this.esServicioNuevo, this.plan, this.equipos = const []});
  final String nombre;
  final bool esServicioNuevo;
  final String? plan;
  final List<({String nombre, int cantidad})> equipos;

  /// «Servicio nuevo: Plan Hogar Seguro - Mensual · 1 Ohmbox» / «Equipo adicional · 2 Ohmbox».
  String get resumen {
    final cabeza = esServicioNuevo ? 'Servicio nuevo${plan != null ? ': $plan' : ''}' : 'Equipo adicional';
    final lista = equipos.map((e) => '${e.cantidad} ${e.nombre}').join(', ');
    return lista.isEmpty ? cabeza : '$cabeza · $lista';
  }

  static VentaResumen? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = j.cast<String, dynamic>();
    return VentaResumen(
      nombre: (m['nombre'] ?? '').toString(),
      esServicioNuevo: m['esServicioNuevo'] == true,
      plan: m['plan']?.toString(),
      equipos: ((m['equipos'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (nombre: (e['nombre'] ?? '').toString(), cantidad: (e['cantidad'] as num?)?.toInt() ?? 0))
          .toList(),
    );
  }
}

class DestinoDecidido {
  const DestinoDecidido({required this.tipo, required this.motivo, this.casaNombre, this.direccion, this.aviso, this.venta});

  /// 'nueva' | 'existente' | 'sin_cuenta' | 'indeterminada'.
  final String tipo;

  /// Nombre de la casa (la nueva o la existente).
  final String? casaNombre;
  final String? direccion;

  /// Por qué va ahí (texto del backend, listo para mostrar).
  final String motivo;

  /// Aviso para operaciones (p. ej. «dirección parecida a otra casa»), si lo hay.
  final String? aviso;
  final VentaResumen? venta;

  bool get esNueva => tipo == 'nueva';
  bool get esExistente => tipo == 'existente';

  /// No se puede vincular: la venta no dice a qué casa va.
  bool get bloquea => tipo == 'indeterminada';

  /// `null` con un backend anterior (sin `destino`): se vincula sin confirmar y el backend decide.
  static DestinoDecidido? fromCasas(Map<String, dynamic> j) {
    final d = j['destino'];
    if (d is! Map) return null;
    final m = d.cast<String, dynamic>();
    final casa = (m['casa'] as Map?)?.cast<String, dynamic>();
    return DestinoDecidido(
      tipo: (m['tipo'] ?? '').toString(),
      motivo: (m['motivo'] ?? '').toString(),
      casaNombre: (casa?['nombre'] ?? m['nombre'])?.toString(),
      direccion: (casa?['direccion'] ?? m['direccion'])?.toString(),
      aviso: (m['aviso'] as String?)?.trim().isEmpty ?? true ? null : m['aviso'] as String,
      venta: VentaResumen.fromJson(j['venta']),
    );
  }
}
