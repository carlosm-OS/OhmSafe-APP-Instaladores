/// Número de serie a partir de lo que trae el QR del energizador. El QR puede
/// traer la serie sola («OHM-XXXX-XXXX») o dentro de un texto o enlace
/// (`...?serie=OHM-...`); si no se reconoce, se usa el texto completo y el
/// diagnóstico dirá si existe.
String serieDesdeQr(String crudo) {
  final t = crudo.trim();
  if (t.isEmpty) return '';
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
