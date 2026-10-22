import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// La Wi‑Fi de la casa de UNA visita, guardada sólo en este teléfono (Carlos, 2026-10-22, opción A).
///
/// El cliente escribe la contraseña una vez en el paso «Wi‑Fi de la casa» y la reutilizan los
/// sensores y cámaras Wi‑Fi y el OhmBox de esa misma intervención. Vive en el llavero del teléfono
/// (si la app se cierra no se pierde), ligada a la intervención, y se borra al terminar la
/// instalación o a las [vigencia] horas. El servidor sólo conoce el nombre de la red.
class WifiCasa {
  const WifiCasa({required this.red, required this.contrasena});
  final String red;
  final String contrasena;
}

/// Almacén de llave/valor que usa [WifiCasaLocal]; las pruebas lo cambian por uno en memoria.
abstract class AlmacenSeguro {
  Future<String?> leer(String llave);
  Future<void> escribir(String llave, String valor);
  Future<void> borrar(String llave);
}

class AlmacenLlavero implements AlmacenSeguro {
  AlmacenLlavero([FlutterSecureStorage? s])
    : _s =
          s ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );
  final FlutterSecureStorage _s;
  @override
  Future<String?> leer(String llave) => _s.read(key: llave);
  @override
  Future<void> escribir(String llave, String valor) => _s.write(key: llave, value: valor);
  @override
  Future<void> borrar(String llave) => _s.delete(key: llave);
}

class WifiCasaLocal {
  WifiCasaLocal({AlmacenSeguro? almacen, DateTime Function()? ahora, this.vigencia = const Duration(hours: 24)})
    : _almacen = almacen ?? AlmacenLlavero(),
      _ahora = ahora ?? DateTime.now;

  /// Una sola instancia para toda la app (las pantallas la comparten).
  static WifiCasaLocal instancia = WifiCasaLocal();

  final AlmacenSeguro _almacen;
  final DateTime Function() _ahora;
  final Duration vigencia;

  String _llave(String ordenId) => 'wifi_casa_$ordenId';

  Future<void> guardar(String ordenId, WifiCasa w) =>
      _almacen.escribir(_llave(ordenId), jsonEncode({'red': w.red, 'pw': w.contrasena, 'en': _ahora().toUtc().toIso8601String()}));

  /// La Wi‑Fi de esa intervención, o null si no hay o ya venció (entonces la borra).
  Future<WifiCasa?> leer(String ordenId) async {
    try {
      final crudo = await _almacen.leer(_llave(ordenId)).timeout(const Duration(seconds: 3));
      if (crudo == null || crudo.isEmpty) return null;
      final m = jsonDecode(crudo) as Map<String, dynamic>;
      final en = DateTime.tryParse((m['en'] ?? '').toString());
      if (en == null || _ahora().toUtc().difference(en) > vigencia) {
        await borrar(ordenId);
        return null;
      }
      final red = (m['red'] ?? '').toString();
      if (red.isEmpty) return null;
      return WifiCasa(red: red, contrasena: (m['pw'] ?? '').toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> borrar(String ordenId) async {
    try {
      await _almacen.borrar(_llave(ordenId));
    } catch (_) {}
  }
}
