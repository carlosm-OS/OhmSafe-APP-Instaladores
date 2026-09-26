import '../../../../config/repair_pricing.dart';

/// Tarifas del motor de costeo de reparaciones.
///
/// Reemplaza el uso directo de las constantes fijas de [RepairPricing] en la
/// calculadora: la pantalla de reparación baja estos valores del backend
/// (`GET /instalador/tarifas-reparacion`, que a su vez los lee de los productos
/// de Odoo). Así, cambiar un precio en Odoo cambia el costeo en la app.
///
/// [Tarifas.defaults] usa los valores de [RepairPricing] como respaldo cuando
/// el backend no responde o un precio viene en 0.
class Tarifas {
  // Mano de obra (pago al instalador)
  final double visita;
  final double metroHilo;
  final double posteEsquina;
  final double postePaso;
  final double abanico;
  final double aisladorSuelto;
  final double tensor;
  final double energizadorSimple;
  final double energizadorBateria;
  final double mantenimientoPreventivo;

  // Factores de dificultad por hilo (% extra sobre mano de obra)
  final double difMedioPct;
  final double difAltoPct;

  // Material (costo OhmSafe)
  final double rolloAlambre3kg;
  final double metrosPorRollo; // rendimiento (constante del modelo, no precio)
  final double matPosteEsquina;
  final double matPostePaso;
  final double matAbanico;
  final double matAislador;
  final double matTensor;
  final double matEnergizadorSimple;
  final double matEnergizadorBateria;

  // Validación de plausibilidad
  final double tramoMaxMetros;
  final int vidaMinAisladorAnios;
  final int vidaMinCableAnios;

  const Tarifas({
    required this.visita,
    required this.metroHilo,
    required this.posteEsquina,
    required this.postePaso,
    required this.abanico,
    required this.aisladorSuelto,
    required this.tensor,
    required this.energizadorSimple,
    required this.energizadorBateria,
    required this.mantenimientoPreventivo,
    required this.difMedioPct,
    required this.difAltoPct,
    required this.rolloAlambre3kg,
    required this.metrosPorRollo,
    required this.matPosteEsquina,
    required this.matPostePaso,
    required this.matAbanico,
    required this.matAislador,
    required this.matTensor,
    required this.matEnergizadorSimple,
    required this.matEnergizadorBateria,
    required this.tramoMaxMetros,
    required this.vidaMinAisladorAnios,
    required this.vidaMinCableAnios,
  });

  /// Valores de respaldo (los firmes de [RepairPricing]).
  factory Tarifas.defaults() => const Tarifas(
        visita: RepairPricing.visita,
        metroHilo: RepairPricing.metroHilo,
        posteEsquina: RepairPricing.posteEsquina,
        postePaso: RepairPricing.postePaso,
        abanico: RepairPricing.abanico,
        aisladorSuelto: RepairPricing.aisladorSuelto,
        tensor: RepairPricing.tensor,
        energizadorSimple: RepairPricing.energizadorSimple,
        energizadorBateria: RepairPricing.energizadorBateria,
        mantenimientoPreventivo: RepairPricing.mantenimientoPreventivo,
        difMedioPct: RepairPricing.difMedioPct,
        difAltoPct: RepairPricing.difAltoPct,
        rolloAlambre3kg: RepairPricing.rolloAlambre3kg,
        metrosPorRollo: RepairPricing.metrosPorRollo,
        matPosteEsquina: RepairPricing.matPosteEsquina,
        matPostePaso: RepairPricing.matPostePaso,
        matAbanico: RepairPricing.matAbanico,
        matAislador: RepairPricing.matAislador,
        matTensor: RepairPricing.matTensor,
        matEnergizadorSimple: RepairPricing.matEnergizadorSimple,
        matEnergizadorBateria: RepairPricing.matEnergizadorBateria,
        tramoMaxMetros: RepairPricing.tramoMaxMetros,
        vidaMinAisladorAnios: RepairPricing.vidaMinAisladorAnios,
        vidaMinCableAnios: RepairPricing.vidaMinCableAnios,
      );

  /// Construye desde la respuesta del backend (`data` de /tarifas-reparacion).
  /// Cualquier campo ausente cae al respaldo de [RepairPricing].
  factory Tarifas.fromJson(Map<String, dynamic> json) {
    double d(dynamic v, double fallback) => (v is num) ? v.toDouble() : fallback;
    int i(dynamic v, int fallback) => (v is num) ? v.toInt() : fallback;
    final mat = (json['materiales'] ?? const {}) as Map;
    final fac = (json['factoresDificultad'] ?? const {}) as Map;
    return Tarifas(
      visita: d(json['visita'], RepairPricing.visita),
      metroHilo: d(json['metroHilo'], RepairPricing.metroHilo),
      posteEsquina: d(json['posteEsquina'], RepairPricing.posteEsquina),
      postePaso: d(json['postePaso'], RepairPricing.postePaso),
      abanico: d(json['abanico'], RepairPricing.abanico),
      aisladorSuelto: d(json['aisladorSuelto'], RepairPricing.aisladorSuelto),
      tensor: d(json['tensor'], RepairPricing.tensor),
      energizadorSimple: d(json['energizadorSimple'], RepairPricing.energizadorSimple),
      energizadorBateria: d(json['energizadorBateria'], RepairPricing.energizadorBateria),
      mantenimientoPreventivo: d(json['mantenimientoPreventivo'], RepairPricing.mantenimientoPreventivo),
      difMedioPct: d(fac['medio'], RepairPricing.difMedioPct),
      difAltoPct: d(fac['alto'], RepairPricing.difAltoPct),
      rolloAlambre3kg: d(mat['rolloAlambre'], RepairPricing.rolloAlambre3kg),
      // metrosPorRollo es rendimiento del modelo, no un precio de Odoo.
      metrosPorRollo: RepairPricing.metrosPorRollo,
      matPosteEsquina: d(mat['posteEsquina'], RepairPricing.matPosteEsquina),
      matPostePaso: d(mat['postePaso'], RepairPricing.matPostePaso),
      matAbanico: d(mat['abanico'], RepairPricing.matAbanico),
      matAislador: d(mat['aislador'], RepairPricing.matAislador),
      matTensor: d(mat['tensor'], RepairPricing.matTensor),
      matEnergizadorSimple: d(mat['energizadorSimple'], RepairPricing.matEnergizadorSimple),
      matEnergizadorBateria: d(mat['energizadorBateria'], RepairPricing.matEnergizadorBateria),
      tramoMaxMetros: d(json['tramoMaxMetros'], RepairPricing.tramoMaxMetros),
      vidaMinAisladorAnios: i(json['vidaMinAisladorAnios'], RepairPricing.vidaMinAisladorAnios),
      vidaMinCableAnios: i(json['vidaMinCableAnios'], RepairPricing.vidaMinCableAnios),
    );
  }
}
