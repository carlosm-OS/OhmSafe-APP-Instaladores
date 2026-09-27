import 'package:flutter/material.dart';

/// Cierra un flujo (cierre o cancelación de un servicio) y abre el listado
/// conservando el Inicio debajo. Con `(route) => false` la pila quedaba sólo
/// con el listado y el chevron de regresar dejaba la app en negro.
void volverAListado(BuildContext context, Widget listado) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => listado),
    (route) => route.isFirst,
  );
}
