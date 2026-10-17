/// Serie y código de verificación de la etiqueta de una cámara EZVIZ (2026-10-17).
///
/// Versión recortada del lector de la app del cliente (`CloudStickerQr`). El QR real de EZVIZ son
/// líneas sueltas: `<url o marcador>\n<serie>\n<código de 6 letras>\n<modelo>`; también se aceptan
/// pares con nombre (`SN:…;CODE:…`) y enlaces con `?sn=…&code=…`. Si no se reconoce nada devuelve
/// `null` y el instalador escribe los datos a mano. El código es un secreto de alta: no se registra.
class EtiquetaEzviz {
  const EtiquetaEzviz({required this.serie, this.codigo = '', this.modelo});

  final String serie;
  final String codigo;
  final String? modelo;

  @override
  String toString() => 'EtiquetaEzviz($serie, ***)';

  static final _serie = RegExp(r'^[A-Z0-9]{8,24}$');
  static final _codigoLetras = RegExp(r'^[A-Z]{6}$');
  static final _codigo = RegExp(r'^[A-Z0-9]{6}$');
  static const _marcadores = {'EZVIZ', 'EZVIZLIFE', 'YS7', 'HIKVISION'};
  static const _llavesSerie = {'sn', 'serial', 'serialno', 'serialnumber', 'deviceserial', 'devserial'};
  static const _llavesCodigo = {'code', 'vcode', 'verifycode', 'verificationcode', 'validatecode'};

  /// Una serie EZVIZ: 8–24 mayúsculas/dígitos con al menos un dígito (descarta palabras como «EZVIZLIFE»).
  static bool pareceSerie(String t) {
    final s = t.trim().toUpperCase();
    return _serie.hasMatch(s) && RegExp(r'\d').hasMatch(s) && !_marcadores.contains(s);
  }

  /// El código de verificación: 6 letras mayúsculas (algunas series traen dígitos).
  static bool pareceCodigo(String t) => _codigo.hasMatch(t.trim().toUpperCase());

  static EtiquetaEzviz? leer(String crudo) {
    final texto = crudo.trim();
    if (texto.isEmpty) return null;

    // 1) Pares con nombre o query de un enlace.
    final campos = <String, String>{};
    final uri = Uri.tryParse(texto);
    if (uri != null && uri.hasQuery) {
      uri.queryParameters.forEach((k, v) => campos[_llave(k)] = v.trim());
    }
    for (final parte in texto.split(RegExp(r'[;,&\r\n]+'))) {
      final m = RegExp(r'^\s*([A-Za-z _-]+)\s*[:=]\s*(.+?)\s*$').firstMatch(parte);
      if (m != null) campos[_llave(m.group(1)!)] = m.group(2)!;
    }
    final serieNombrada = _primero(campos, _llavesSerie);
    if (serieNombrada != null && pareceSerie(serieNombrada)) {
      final c = _primero(campos, _llavesCodigo) ?? '';
      return EtiquetaEzviz(serie: serieNombrada.toUpperCase(), codigo: pareceCodigo(c) ? c.toUpperCase() : '');
    }

    // 2) Líneas sueltas (la etiqueta real).
    final lineas = texto.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final i = lineas.indexWhere(pareceSerie);
    if (i >= 0) {
      final resto = [for (var j = i + 1; j < lineas.length; j++) lineas[j]];
      String codigo = resto.firstWhere((l) => _codigoLetras.hasMatch(l.toUpperCase()) && !_marcadores.contains(l.toUpperCase()), orElse: () => '');
      if (codigo.isEmpty) codigo = resto.firstWhere((l) => pareceCodigo(l) && !_marcadores.contains(l.toUpperCase()), orElse: () => '');
      final modelo = lineas.firstWhere((l) => l.toUpperCase().startsWith('CS-') || l.toUpperCase().startsWith('DS-'), orElse: () => '');
      return EtiquetaEzviz(serie: lineas[i].toUpperCase(), codigo: codigo.toUpperCase(), modelo: modelo.isEmpty ? null : modelo);
    }

    // 3) Dos campos en una línea («D12345678 ABCDEF») o sólo la serie.
    final trozos = texto.split(RegExp(r'[\s;,]+')).where((t) => t.isNotEmpty).toList();
    final k = trozos.indexWhere(pareceSerie);
    if (k < 0) return null;
    final codigo = trozos.skip(k + 1).firstWhere(pareceCodigo, orElse: () => '');
    return EtiquetaEzviz(serie: trozos[k].toUpperCase(), codigo: codigo.toUpperCase());
  }

  static String _llave(String k) => k.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

  static String? _primero(Map<String, String> campos, Set<String> llaves) {
    for (final l in llaves) {
      final v = campos[l];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}
