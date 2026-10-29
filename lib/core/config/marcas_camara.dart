/// Marcas de cámaras y sensores Wi‑Fi que la app de instaladores OFRECE (2026-10-20).
///
/// Decisión de Carlos (20-oct): la app de instaladores se queda **sólo con Tuya**. EZVIZ e Imou se
/// APAGAN, no se borran: el código de sus pantallas, puentes nativos y SDKs sigue en el repo detrás
/// de este interruptor, y lo que el backend diga (`wifi.emparejar`, `camaras.proveedores`) sólo
/// cuenta si la marca está aquí. Para volver a encender una marca basta compilar con
/// `--dart-define=MARCAS_CAMARA=tuya,ezviz,imou` (ver docs/WIFI-EZVIZ-TUYA.md, «Retirada de EZVIZ e
/// Imou»). Los equipos ya registrados de otra marca se siguen listando con su nombre.
abstract final class MarcasCamara {
  static const _define = String.fromEnvironment('MARCAS_CAMARA', defaultValue: 'tuya');

  /// Mutable sólo para las pruebas (p. ej. `MarcasCamara.habilitadas = MarcasCamara.todas`).
  static Set<String> habilitadas = desde(_define);

  static const todas = {'tuya', 'ezviz', 'imou'};

  static bool get tuya => habilitadas.contains('tuya');
  static bool get ezviz => habilitadas.contains('ezviz');
  static bool get imou => habilitadas.contains('imou');

  /// «Cámara ya conectada» (registrar por serie + código una cámara que ya está en internet) sólo
  /// tiene sentido con marcas que se registran así: EZVIZ e Imou.
  static bool get registroPorSerie => ezviz || imou;

  static Set<String> desde(String lista) => lista.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
}
