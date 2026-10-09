/// Dónde va el energizador al vincular (decisión del instalador, 2026-10-06):
/// a una casa que el cliente ya tiene en el dashboard o a una casa nueva.
///
/// `casas` es lo que devuelve `GET /instalador/ordenes/:id/casas`. Sólo se
/// pregunta cuando hay al menos una casa; con cero, el backend crea la casa
/// como siempre.
class CasaCliente {
  const CasaCliente({required this.id, required this.nombre, this.direccion, this.energizadores = 0, this.equipos = 0});
  final String id;
  final String nombre;
  final String? direccion;
  final int energizadores;

  /// Todos los equipos de la casa (energizadores, cámaras, sensores…). El backend sólo manda
  /// casas con al menos uno (2026-10-09); con un backend anterior se cuentan los energizadores.
  final int equipos;

  static CasaCliente fromJson(Map<String, dynamic> j) {
    final energizadores = (j['energizadores'] as num?)?.toInt() ?? 0;
    return CasaCliente(
      id: (j['id'] ?? '').toString(),
      nombre: (j['nombre'] ?? '').toString(),
      direccion: j['direccion']?.toString(),
      energizadores: energizadores,
      equipos: (j['equipos'] as num?)?.toInt() ?? energizadores,
    );
  }
}

class OpcionesDestino {
  const OpcionesDestino({required this.casas, this.sugerida, required this.nombreNueva, required this.direccionNueva, this.ventaNueva, this.latNueva, this.lngNueva});
  final List<CasaCliente> casas;
  final String? sugerida;
  final String nombreNueva;

  /// Dirección de la COMPRA (entrega de la venta en Odoo); es la que lleva la casa nueva.
  final String direccionNueva;

  /// Venta de la que viene (S00…), para mostrarla junto a la dirección.
  final String? ventaNueva;

  /// Coordenadas de la dirección de la compra, si Odoo las tiene.
  final double? latNueva;
  final double? lngNueva;

  /// ¿Hay que preguntar? Sólo si el cliente ya tiene casas.
  bool get hayQuePreguntar => casas.isNotEmpty;

  /// Valor de «casa nueva» en el selector.
  static const nueva = '__nueva__';

  /// Preselección: la casa que coincide con la dirección de la orden; si ninguna
  /// coincide, «Casa nueva» (la primera opción), porque la dirección del ticket
  /// manda (Carlos, 2026-10-06).
  String get seleccionInicial {
    if (sugerida != null && casas.any((c) => c.id == sugerida)) return sugerida!;
    return nueva;
  }

  static OpcionesDestino fromJson(Map<String, dynamic> j) {
    final nueva = (j['nueva'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OpcionesDestino(
      casas: ((j['casas'] as List?) ?? const []).whereType<Map>().map((e) => CasaCliente.fromJson(e.cast<String, dynamic>())).toList(),
      sugerida: j['sugerida']?.toString(),
      nombreNueva: (nueva['nombre'] ?? 'Casa nueva').toString(),
      direccionNueva: (nueva['direccion'] ?? '').toString(),
      ventaNueva: nueva['venta']?.toString(),
      latNueva: ((nueva['coordenadas'] as Map?)?['lat'] as num?)?.toDouble(),
      lngNueva: ((nueva['coordenadas'] as Map?)?['lng'] as num?)?.toDouble(),
    );
  }
}

/// Cuerpo `destino` para `vincular-energizador`.
Map<String, dynamic> destinoCasaExistente(String casaId) => {'casaId': casaId};
Map<String, dynamic> destinoCasaNueva({required String nombre, String? direccion}) => {
      'nueva': {'nombre': nombre.trim(), if ((direccion ?? '').trim().isNotEmpty) 'direccion': direccion!.trim()},
    };
