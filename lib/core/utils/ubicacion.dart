import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Posición actual del teléfono para la llegada y el cierre. Devuelve null si
/// no hay permiso, GPS o señal a tiempo: NUNCA inventa una posición (antes el
/// cierre traía coordenadas falsas de CDMX cuando el GPS estaba apagado).
Future<Position?> ubicacionActual({Duration limite = const Duration(seconds: 6)}) async {
  // Tope duro: si el plugin no contesta (sin servicio, sin canal), se sigue sin ubicación.
  try {
    return await _ubicacion(limite).timeout(limite + const Duration(seconds: 2));
  } catch (_) {
    return null;
  }
}

Future<Position?> _ubicacion(Duration limite) async {
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

/// Dirección escrita de unas coordenadas con el geocodificador NATIVO del teléfono (iOS/Android):
/// sin servicio externo ni clave. Null si no hay red/servicio o no se resolvió.
Future<String?> direccionDeCoordenadas(double lat, double lng) async {
  try {
    final lugares = await Geocoding(locale: const Locale('es', 'MX'))
        .placemarkFromCoordinates(lat, lng)
        .timeout(const Duration(seconds: 6));
    if (lugares.isEmpty) return null;
    final p = lugares.first;
    final calle = [p.thoroughfare, p.subThoroughfare].where((s) => (s ?? '').trim().isNotEmpty).join(' ');
    final partes = [
      calle.isNotEmpty ? calle : (p.street ?? ''),
      p.subLocality ?? '',
      [p.postalCode ?? '', p.locality ?? ''].where((s) => s.trim().isNotEmpty).join(' '),
    ].where((s) => s.trim().isNotEmpty).toList();
    return partes.isEmpty ? null : partes.join(', ');
  } catch (_) {
    return null;
  }
}

/// Coordenadas de una dirección escrita (geocodificador nativo). Null si no se encontró.
Future<({double lat, double lng})?> coordenadasDeDireccion(String direccion) async {
  if (direccion.trim().isEmpty) return null;
  try {
    final r = await Geocoding(locale: const Locale('es', 'MX')).locationFromAddress(direccion).timeout(const Duration(seconds: 6));
    return r.isEmpty ? null : (lat: r.first.latitude, lng: r.first.longitude);
  } catch (_) {
    return null;
  }
}

/// Distancia legible en metros o km («350 m», «8.6 km»).
String distanciaLegible(double metros) => metros < 1000 ? '${metros.round()} m' : '${(metros / 1000).toStringAsFixed(1)} km';
