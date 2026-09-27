import 'package:geolocator/geolocator.dart';

/// Posición actual del teléfono para la llegada y el cierre. Devuelve null si
/// no hay permiso, GPS o señal a tiempo: NUNCA inventa una posición (antes el
/// cierre traía coordenadas falsas de CDMX cuando el GPS estaba apagado).
Future<Position?> ubicacionActual({Duration limite = const Duration(seconds: 6)}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: limite),
    );
  } catch (_) {
    return null;
  }
}

/// Forma que espera el backend en `marcar-llegada` y `cierre`.
Map<String, dynamic>? ubicacionJson(Position? p) => p == null
    ? null
    : {'lat': p.latitude, 'lng': p.longitude, 'precision': p.accuracy};
