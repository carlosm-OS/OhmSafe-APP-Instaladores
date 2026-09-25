/// Fechas que llegan del backend tal como las guarda Odoo: `"YYYY-MM-DD HH:MM:SS"`
/// en **UTC y sin indicador de zona**. Si se parsean tal cual, Dart las toma
/// como hora local y el instalador ve la hora corrida (p. ej. 16:00 en vez de
/// 10:00 en CDMX). Aquí se interpretan como UTC y se convierten a la zona del
/// dispositivo, sea cual sea: la app se usa desde donde esté el instalador.
///
/// También acepta ISO-8601 con zona (`...Z`, `...-06:00`), como lo devuelve la
/// telemetría; en ese caso respeta la zona que traiga.
class FechasOdoo {
  FechasOdoo._();

  static final RegExp _conZona = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');
  static final RegExp _soloFecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Instante en hora local del dispositivo, o null si no parsea.
  ///
  /// Una fecha sin hora (`2026-09-20`, como `invoice_date` o `date_order` de
  /// tipo Date en Odoo) es un día calendario, no un instante: se lee tal cual,
  /// sin pasarla por UTC, o en América amanecería como el día anterior.
  static DateTime? aLocal(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (_soloFecha.hasMatch(s)) {
      final d = DateTime.tryParse(s);
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }
    s = s.replaceFirst(' ', 'T');
    if (!_conZona.hasMatch(s)) s = '${s}Z';
    return DateTime.tryParse(s)?.toLocal();
  }

  /// Solo el día (a medianoche local); sirve para colocar la orden en el
  /// calendario del día correcto aunque la hora UTC cruce medianoche.
  static DateTime? soloDia(String? raw) {
    final d = aLocal(raw);
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  /// `"18/09/2026 10:00"` en hora local. Si no parsea devuelve el texto original.
  static String fechaHora(String? raw) {
    final d = aLocal(raw);
    if (d == null) return raw ?? '';
    return '${_dos(d.day)}/${_dos(d.month)}/${d.year} ${_dos(d.hour)}:${_dos(d.minute)}';
  }

  /// `"18/09/2026"` en hora local.
  static String fecha(String? raw) {
    final d = aLocal(raw);
    if (d == null) return raw ?? '';
    return '${_dos(d.day)}/${_dos(d.month)}/${d.year}';
  }

  /// `"10:00"` en hora local.
  static String hora(String? raw) {
    final d = aLocal(raw);
    if (d == null) return '';
    return '${_dos(d.hour)}:${_dos(d.minute)}';
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
}
