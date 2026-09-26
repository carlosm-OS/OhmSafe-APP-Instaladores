/// ============================================================
/// OHMSAFE ARMY — Configuración del motor de costeo de reparaciones
/// ------------------------------------------------------------
/// Todas las tarifas del modelo en un solo lugar.
/// Las que están en 0 aún no se definen (pendientes de validar
/// con instaladores externos). Edita aquí y toda la app recalcula.
/// ============================================================
library repair_pricing;

class RepairPricing {
  // ---------- MANO DE OBRA (pago al instalador externo, sin carga social) ----------
  /// Cuota fija por ir y diagnosticar (se paga siempre)
  static const double visita = 0;

  /// Tarifa por metro de hilo reparado (1 hilo × 1 metro = 1 unidad)
  static const double metroHilo = 0;

  /// Cambio de poste esquina (mano de obra)
  static const double posteEsquina = 0;

  /// Cambio de poste de paso (mano de obra)
  static const double postePaso = 0;

  /// Cambio de abanico (mano de obra)
  static const double abanico = 0;

  /// Cambio de aislador suelto — sin cambiar el poste
  static const double aisladorSuelto = 0;

  /// Cambio de tensor
  static const double tensor = 0;

  /// Cambio de energizador (mano de obra) — dato firme Yonusa
  static const double energizadorSimple = 950;
  static const double energizadorBateria = 1500;

  /// Mantenimiento preventivo anual — definido por OhmSafe
  static const double mantenimientoPreventivo = 1800;

  // ---------- FACTOR DE DIFICULTAD POR HILO (% extra sobre mano de obra) ----------
  /// Nivel Medio: vegetación, árboles, desniveles, herrería, arcos, malla
  static const double difMedioPct = 10;

  /// Nivel Alto: altura superior (>7 m), concertina, cableado
  static const double difAltoPct = 25;

  // ---------- MATERIAL (costo OhmSafe — no se paga al instalador) ----------
  static const double rolloAlambre3kg = 0;

  /// Rendimiento del rollo cal. 16 de 3 kg (~65 m/kg → ~195 m)
  static const double metrosPorRollo = 195;

  static const double matPosteEsquina = 0;
  static const double matPostePaso = 0;
  static const double matAbanico = 0;
  static const double matAislador = 0;
  static const double matTensor = 0;
  static const double matEnergizadorSimple = 0;
  static const double matEnergizadorBateria = 0;

  // ---------- VALIDACIÓN DE PLAUSIBILIDAD (vida útil mínima, años) ----------
  /// Aislador: 4–5 años en calor, 15 en clima controlado (matriz Yonusa)
  static const int vidaMinAisladorAnios = 4;

  /// Cable galvanizado: ~8 años de buena conductividad (matriz Yonusa)
  static const int vidaMinCableAnios = 8;

  /// Buena práctica: tramos de hasta 6 m entre postes
  static const double tramoMaxMetros = 6;
}

/// Niveles de dificultad por hilo.
/// Derivables de los obstáculos de la inspección (verificables con foto),
/// pero asignables por hilo: el hilo 4 puede estar a 10 m (alto)
/// y el hilo 2 a 2 m (normal).
enum DificultadHilo { normal, medio, alto }

extension DificultadHiloX on DificultadHilo {
  String get etiqueta => switch (this) {
        DificultadHilo.normal => 'Normal',
        DificultadHilo.medio => 'Medio',
        DificultadHilo.alto => 'Alto',
      };

  double get pctExtra => switch (this) {
        DificultadHilo.normal => 0,
        DificultadHilo.medio => RepairPricing.difMedioPct,
        DificultadHilo.alto => RepairPricing.difAltoPct,
      };
}
