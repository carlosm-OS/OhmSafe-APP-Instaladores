/// Número de serie a partir de lo que trae el QR del energizador. El QR puede
/// traer la serie sola («OS-OBV01-0001», o las viejas «OHM-XXXX-XXXX») o dentro
/// de un texto o enlace (`...?serie=OS-...`); si no se reconoce, se usa el texto
/// completo y el backend dirá si está en el inventario de Odoo.
String serieDesdeQr(String crudo) {
  final t = crudo.trim();
  if (t.isEmpty) return '';
  // Formato del inventario de Ohmbox en Odoo (2026-10-02): OS-<modelo>-<consecutivo>.
  final os = RegExp(r'OS-[A-Z0-9]+-\d{3,}', caseSensitive: false).firstMatch(t);
  if (os != null) return os.group(0)!.toUpperCase();
  final ohm = RegExp(r'OHM-[A-Z0-9][A-Z0-9-]*', caseSensitive: false).firstMatch(t);
  if (ohm != null) return ohm.group(0)!.toUpperCase();
  final uri = Uri.tryParse(t);
  if (uri != null && uri.hasQuery) {
    for (final k in const ['serie', 'serial', 'sn']) {
      final v = uri.queryParameters[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
  }
  return t;
}
