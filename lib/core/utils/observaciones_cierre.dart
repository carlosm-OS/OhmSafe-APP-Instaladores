/// Observaciones del cierre que viajan al backend (`comentariosGenerales`) y
/// acaban en la hoja de trabajo («Observaciones» del reporte PDF).
///
/// Sólo los pasos con texto: antes se mandaba «Paso 1:  | Paso 2: » aunque el
/// instalador no escribiera nada, y así salía impreso en el reporte al cliente.
String observacionesCierre({required String paso1, required String paso2}) {
  final partes = <String>[
    if (paso1.trim().isNotEmpty) 'Paso 1: ${paso1.trim()}',
    if (paso2.trim().isNotEmpty) 'Paso 2: ${paso2.trim()}',
  ];
  return partes.join(' | ');
}
