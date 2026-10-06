import 'package:app_badge_plus/app_badge_plus.dart';

/// Badge del ícono de la app = avisos no leídos de la campana (decisión de
/// Carlos, 2026-10-06). El backend manda ese mismo número en cada push; aquí
/// lo fijamos cuando la app lo conoce y lo bajamos a 0 al leer. Antes nadie
/// lo tocaba y el «1» del primer push se quedaba para siempre.
///
/// Best-effort: en escritorio, en el simulador sin permiso o si el launcher
/// Android no soporta badges, simplemente no pasa nada.
class BadgeIcono {
  BadgeIcono._();

  static int? _ultimo;

  static Future<void> fijar(int noLeidas) async {
    final n = noLeidas < 0 ? 0 : noLeidas;
    if (_ultimo == n) return;
    _ultimo = n;
    try {
      if (!await AppBadgePlus.isSupported()) return;
      await AppBadgePlus.updateBadge(n);
    } catch (_) {
      _ultimo = null; // que el siguiente intento vuelva a probar
    }
  }
}
