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

/// Serie de la etiqueta de un sensor o cámara Wi‑Fi (2026-10-22). Cada fabricante pone otra cosa en
/// el QR: la serie sola, un enlace con `?sn=`/`serial=`/`serie=`/`uuid=`, o un enlace cuyo último
/// tramo es la serie. Se queda con eso, sin espacios y en mayúsculas (máx. 64); '' si no hay nada.
String serieDeEtiqueta(String crudo) {
  final t = crudo.trim();
  if (t.isEmpty) return '';
  var v = t;
  final uri = Uri.tryParse(t);
  if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
    String? q;
    for (final k in const ['sn', 'serial', 'serie', 'uuid', 'id']) {
      final x = uri.queryParameters[k];
      if (x != null && x.trim().isNotEmpty) {
        q = x;
        break;
      }
    }
    final tramos = uri.pathSegments.where((p) => p.trim().isNotEmpty).toList();
    v = q ?? (tramos.isNotEmpty ? tramos.last : t);
  }
  v = v.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return v.length > 64 ? v.substring(0, 64) : v;
}
