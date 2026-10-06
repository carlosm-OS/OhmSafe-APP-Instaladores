/// Dónde va el energizador al vincular (decisión del instalador, 2026-10-06):
/// a una casa que el cliente ya tiene en el dashboard o a una casa nueva.
///
/// `casas` es lo que devuelve `GET /instalador/ordenes/:id/casas`. Sólo se
/// pregunta cuando hay al menos una casa; con cero, el backend crea la casa
/// como siempre.
class CasaCliente {
  const CasaCliente({required this.id, required this.nombre, this.direccion, this.energizadores = 0});
  final String id;
  final String nombre;
  final String? direccion;
  final int energizadores;

  static CasaCliente fromJson(Map<String, dynamic> j) => CasaCliente(
        id: (j['id'] ?? '').toString(),
        nombre: (j['nombre'] ?? '').toString(),
        direccion: j['direccion']?.toString(),
        energizadores: (j['energizadores'] as num?)?.toInt() ?? 0,
      );
}

class OpcionesDestino {
  const OpcionesDestino({required this.casas, this.sugerida, required this.nombreNueva, required this.direccionNueva});
  final List<CasaCliente> casas;
  final String? sugerida;
  final String nombreNueva;
  final String direccionNueva;

  /// ¿Hay que preguntar? Sólo si el cliente ya tiene casas.
  bool get hayQuePreguntar => casas.isNotEmpty;

  /// Casa preseleccionada: la sugerida por dirección; si no hay, la única cuando
  /// sólo tiene una; si tiene varias sin sugerencia, ninguna (que elija).
  String? get seleccionInicial {
    if (sugerida != null && casas.any((c) => c.id == sugerida)) return sugerida;
    return casas.length == 1 ? casas.first.id : null;
  }

  static OpcionesDestino fromJson(Map<String, dynamic> j) {
    final nueva = (j['nueva'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OpcionesDestino(
      casas: ((j['casas'] as List?) ?? const []).whereType<Map>().map((e) => CasaCliente.fromJson(e.cast<String, dynamic>())).toList(),
      sugerida: j['sugerida']?.toString(),
      nombreNueva: (nueva['nombre'] ?? 'Casa nueva').toString(),
      direccionNueva: (nueva['direccion'] ?? '').toString(),
    );
  }
}

/// Cuerpo `destino` para `vincular-energizador`.
Map<String, dynamic> destinoCasaExistente(String casaId) => {'casaId': casaId};
Map<String, dynamic> destinoCasaNueva({required String nombre, String? direccion}) => {
      'nueva': {'nombre': nombre.trim(), if ((direccion ?? '').trim().isNotEmpty) 'direccion': direccion!.trim()},
    };
