/// Lee la etiqueta de una cámara Imou: el QR de la guía rápida o de la caja trae el número de serie
/// (S/N, 15 mayúsculas/dígitos, p. ej. «C3CE8CAPSFA2E62») y el código de seguridad («SAFETY CODE» /
/// SC, 8 caracteres que SÍ distinguen mayúsculas y minúsculas, p. ej. «L2VqC2QF»). 2026-10-19.
///
/// Acepta lo que suele venir en el QR: pares «SN:…» / «SC:…» (también `=`, JSON o query de un enlace),
/// líneas sueltas de la etiqueta («SAFETY CODE:L2VqC2QF», «S/N:C3CE8CAPSFA2E62») o los dos valores
/// pegados en una línea. El código nunca se pasa a mayúsculas.
class EtiquetaImou {
  const EtiquetaImou({required this.serie, this.codigo = '', this.modelo});
  final String serie;
  final String codigo;
  final String? modelo;

  @override
  String toString() => 'EtiquetaImou($serie, ***)';

  static final _serie = RegExp(r'^[A-Z0-9]{12,16}$');
  static final _codigo = RegExp(r'^[A-Za-z0-9]{6,12}$');
  static const _marcadores = {'IMOU', 'IMOULIFE', 'DAHUA', 'EASY4IP', 'LECHANGE'};
  static const _llavesSerie = {'sn', 'serial', 'serialno', 'serialnumber', 'deviceid', 'devicesn', 'did'};
  static const _llavesCodigo = {'sc', 'safetycode', 'safecode', 'securitycode', 'code', 'verifycode', 'regcode'};

  /// Una serie Imou: 12–16 mayúsculas/dígitos con al menos un dígito.
  static bool pareceSerie(String t) {
    final s = t.trim().toUpperCase();
    return _serie.hasMatch(s) && RegExp(r'\d').hasMatch(s) && !_marcadores.contains(s);
  }

  /// El código SC: 6–12 letras/dígitos, tal cual (no se cambia a mayúsculas).
  static bool pareceCodigo(String t) => _codigo.hasMatch(t.trim());

  static EtiquetaImou? leer(String crudo) {
    final texto = crudo.trim();
    if (texto.isEmpty) return null;

    // 1) Pares con nombre: «SN:…», «sc=…», JSON {"SN":"…"} o la query de un enlace.
    final campos = <String, String>{};
    final uri = Uri.tryParse(texto);
    if (uri != null && uri.hasQuery) {
      uri.queryParameters.forEach((k, v) => campos[_llave(k)] = v.trim());
    }
    for (final m in RegExp(r'"([A-Za-z _/-]+)"\s*:\s*"([^"]*)"').allMatches(texto)) {
      campos[_llave(m.group(1)!)] = m.group(2)!.trim();
    }
    for (final parte in texto.split(RegExp(r'[;,&{}\r\n]+'))) {
      final m = RegExp(r'^\s*"?([A-Za-z _/-]+?)"?\s*[:=]\s*"?([^"\s]+)"?\s*$').firstMatch(parte);
      if (m != null) campos[_llave(m.group(1)!)] = m.group(2)!;
    }
    final serieNombrada = _primero(campos, _llavesSerie);
    if (serieNombrada != null && pareceSerie(serieNombrada)) {
      final c = _primero(campos, _llavesCodigo) ?? '';
      return EtiquetaImou(serie: serieNombrada.toUpperCase(), codigo: pareceCodigo(c) ? c.trim() : '', modelo: _modelo(texto));
    }

    // 2) Valores sueltos: la serie es el trozo de 12–16 mayúsculas/dígitos; el código, el siguiente
    //    trozo de 6–12 caracteres que no sea una palabra de la marca ni otra serie.
    final trozos = texto.split(RegExp(r'[\s;,:=]+')).where((t) => t.isNotEmpty).toList();
    final k = trozos.indexWhere(pareceSerie);
    if (k < 0) return null;
    final codigo = trozos.skip(k + 1).firstWhere((t) => pareceCodigo(t) && !pareceSerie(t) && !_marcadores.contains(t.toUpperCase()), orElse: () => '');
    return EtiquetaImou(serie: trozos[k].toUpperCase(), codigo: codigo, modelo: _modelo(texto));
  }

  /// Modelo si viene en el texto («Model:IPC-DK2N-4H1W»).
  static String? _modelo(String texto) {
    final m = RegExp(r'\b(IPC-[A-Z0-9-]+)\b', caseSensitive: false).firstMatch(texto);
    return m?.group(1)?.toUpperCase();
  }

  static String _llave(String k) => k.toLowerCase().replaceAll(RegExp(r'[\s_/-]'), '');

  static String? _primero(Map<String, String> campos, Set<String> llaves) {
    for (final l in llaves) {
      final v = campos[l];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}
