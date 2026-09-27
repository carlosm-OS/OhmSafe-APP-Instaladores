import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/perfil.dart';

/// Caché local del perfil del instalador (nombre, número, código de venta y
/// foto). Existe para que al abrir la app la foto y el nombre se pinten al
/// instante en vez de esperar a `/instalador/perfil` (~2.3 s en dev): se pinta
/// lo cacheado y la red refresca por detrás.
///
/// Se guarda **por instalador** para que, si en el mismo teléfono entra otra
/// cuadrilla, no se le muestre la foto del anterior.
class PerfilCache {
  static const _prefix = 'perfil_cache_v1_';

  static String _keyFor(String instaladorId) => '$_prefix$instaladorId';

  /// Datos cacheados del instalador, o null si nunca se guardaron / no parsean.
  static Future<PerfilCacheData?> leer(String instaladorId) async {
    if (instaladorId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(instaladorId));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PerfilCacheData(
        nombre: (map['nombre'] ?? '') as String,
        numeroInstalador: (map['numeroInstalador'] ?? '') as String,
        codigoVenta: (map['codigoVenta'] ?? '') as String,
        fotoBase64: (map['fotoBase64'] ?? '') as String,
      );
    } catch (_) {
      // Caché corrupta o storage no disponible: se ignora y se usa la red.
      return null;
    }
  }

  /// Guarda el perfil recién traído de la red. Silencioso ante fallos: la
  /// caché es una optimización, nunca debe romper el flujo.
  static Future<void> guardar(String instaladorId, Perfil p) async {
    if (instaladorId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyFor(instaladorId),
        jsonEncode({
          'nombre': p.nombre,
          'numeroInstalador': p.numeroInstalador,
          'codigoVenta': p.codigoVenta,
          'fotoBase64': p.fotoBase64,
        }),
      );
    } catch (_) {
      // Ignorado a propósito.
    }
  }

  /// Borra la caché de un instalador (al cerrar sesión).
  static Future<void> limpiar(String instaladorId) async {
    if (instaladorId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(instaladorId));
    } catch (_) {
      // Ignorado a propósito.
    }
  }
}

/// Contenido plano de la caché (no es el `Perfil` completo: sólo lo que se
/// pinta en el home / cabecera de perfil).
class PerfilCacheData {
  final String nombre;
  final String numeroInstalador;
  final String codigoVenta;
  final String fotoBase64;

  const PerfilCacheData({
    required this.nombre,
    required this.numeroInstalador,
    required this.codigoVenta,
    required this.fotoBase64,
  });
}
