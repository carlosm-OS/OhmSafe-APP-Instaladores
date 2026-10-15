import 'package:flutter/widgets.dart';

/// Diálogo (u hoja) dueño de sus controladores de texto: los crea al abrir y los libera en
/// `dispose()`, cuando la ruta YA terminó de cerrarse.
///
/// Build 43 (2026-10-15): «Agregar dispositivos» tronaba al guardar el nombre de una puerta
/// ('_dependents.isEmpty': is not true). Los controladores se liberaban justo después de
/// `await showDialog(...)`, pero la animación de salida del diálogo todavía dibujaba los campos.
/// Con este widget el diálogo devuelve los valores en `Navigator.pop` y nadie libera nada antes de tiempo.
class ConTextos extends StatefulWidget {
  const ConTextos({super.key, required this.iniciales, required this.builder});

  /// Texto inicial de cada controlador (uno por campo).
  final List<String> iniciales;
  final Widget Function(BuildContext context, List<TextEditingController> controladores) builder;

  @override
  State<ConTextos> createState() => _ConTextosState();
}

class _ConTextosState extends State<ConTextos> {
  late final List<TextEditingController> _c = [for (final t in widget.iniciales) TextEditingController(text: t)];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}
