import 'package:flutter/services.dart';

/// Familias de serie de Ohmbox en el inventario de Odoo: `OS-<familia>-<consecutivo>`.
const familiasSerie = ['OBV01', 'PRUEBA'];

/// Familia por defecto cuando el técnico escribe sólo el número (26 → OS-OBV01-0026).
const familiaPorDefecto = 'OBV01';

/// Pone los guiones de la serie mientras el técnico escribe, para que no tenga que buscar «-» en el
/// teclado (Carlos, 2026-10-09). Se escribe de corrido y se ve con guiones:
///   «OSOBV010026» → «OS-OBV01-0026»   ·   «osprueba1» → «OS-PRUEBA-1»
/// Al borrar no vuelve a poner el guion que el técnico acaba de quitar. Las series viejas (`OHM-…`)
/// y cualquier otro texto se respetan tal cual (en mayúsculas).
class SerieInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final borrando = newValue.text.length < oldValue.text.length;
    final texto = formatearSerie(newValue.text, guionFinal: !borrando);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

/// Formatea lo escrito con los guiones de `OS-<familia>-<número>`. `guionFinal` agrega el guion
/// en cuanto termina un tramo (al escribir «OS» queda «OS-»).
String formatearSerie(String crudo, {bool guionFinal = true}) {
  final mayus = crudo.toUpperCase();
  if (mayus.trimLeft().startsWith('OHM')) return mayus.trim();
  final limpio = mayus.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (limpio.isEmpty) return '';
  if (!limpio.startsWith('OS')) {
    // Empieza a escribir «O»: aún no hay tramo completo.
    return limpio == 'O' ? 'O' : limpio;
  }
  final resto = limpio.substring(2);
  if (resto.isEmpty) return guionFinal ? 'OS-' : 'OS';
  for (final fam in familiasSerie) {
    if (resto.startsWith(fam)) {
      final num = resto.substring(fam.length);
      if (num.isEmpty) return guionFinal ? 'OS-$fam-' : 'OS-$fam';
      return 'OS-$fam-$num';
    }
  }
  return 'OS-$resto';
}

/// Serie lista para validar: con guiones, y si el técnico escribió sólo el número (1 a 4 dígitos)
/// se completa con la familia por defecto y ceros a la izquierda (26 → OS-OBV01-0026).
String normalizarSerie(String crudo) {
  final t = crudo.trim();
  if (RegExp(r'^\d{1,4}$').hasMatch(t)) return 'OS-$familiaPorDefecto-${t.padLeft(4, '0')}';
  final f = formatearSerie(t, guionFinal: false);
  // «OS-OBV01-26» → «OS-OBV01-0026»: el consecutivo del inventario siempre tiene 4 dígitos.
  final m = RegExp(r'^(OS-[A-Z0-9]+-)(\d{1,3})$').firstMatch(f);
  return m == null ? f : '${m.group(1)}${m.group(2)!.padLeft(4, '0')}';
}
