import 'dart:async';

import 'package:flutter/foundation.dart';

/// Esperas que el instalador debe VER (Carlos, 2026-10-15: «hay tiempos de espera donde parece que
/// la app se trabó»). Cada petición al backend cuenta aquí (lo hace [DioClient]) y también la lectura
/// del GPS; la barra de progreso global (`BarraProgresoGlobal`) se pinta mientras haya algo pendiente.
///
/// Lo que corre solo en segundo plano (sondeos, renovar la ventana de prueba, avisos push) va dentro de
/// [enSilencio] y no cuenta: la barra sólo responde a lo que el instalador tocó.
abstract final class Actividad {
  /// Trabajos en curso que el instalador está esperando.
  static final ValueNotifier<int> pendientes = ValueNotifier<int>(0);

  static const Symbol _silencio = #ohmsafeActividadSilenciosa;

  /// True si el código corre dentro de [enSilencio] (la zona se hereda por los `await`).
  static bool get silenciosa => Zone.current[_silencio] == true;

  /// Corre [trabajo] contando como espera visible (salvo dentro de [enSilencio]).
  static Future<T> seguir<T>(Future<T> Function() trabajo) async {
    if (silenciosa) return trabajo();
    pendientes.value++;
    try {
      return await trabajo();
    } finally {
      pendientes.value--;
    }
  }

  /// Corre [cuerpo] sin mover la barra: para sondeos y tareas de fondo.
  static R enSilencio<R>(R Function() cuerpo) => runZoned(cuerpo, zoneValues: {_silencio: true});
}
