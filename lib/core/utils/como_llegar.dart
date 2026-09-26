import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apps de navegación que ofrece «Cómo llegar».
enum AppMapas { google, waze, apple }

/// Destino de un servicio: la dirección de Odoo y, si el contacto está
/// geolocalizado, sus coordenadas (más precisas que el texto).
class DestinoServicio {
  final String direccion;
  final double? lat;
  final double? lng;
  const DestinoServicio({required this.direccion, this.lat, this.lng});

  /// Desde el `details` del ticket. Con backends viejos (sin `direccionCompleta`)
  /// arma el texto con calle, CP y ciudad.
  factory DestinoServicio.deDetalles(Map<dynamic, dynamic> d) {
    String t(String k) => (d[k] ?? '').toString().trim();
    var direccion = t('direccionCompleta');
    if (direccion.isEmpty) {
      direccion = [t('direccion'), [t('cp'), t('ciudad')].where((x) => x.isNotEmpty).join(' ')].where((x) => x.isNotEmpty).join(', ');
      if (direccion.isNotEmpty) direccion = '$direccion, México';
    }
    double? n(String k) => d[k] is num ? (d[k] as num).toDouble() : double.tryParse(t(k));
    return DestinoServicio(direccion: direccion, lat: n('lat'), lng: n('lng'));
  }

  bool get tieneCoordenadas => lat != null && lng != null && !(lat == 0 && lng == 0);
  bool get vacio => direccion.isEmpty && !tieneCoordenadas;

  /// Lo que se manda al mapa: coordenadas si las hay, si no la dirección.
  String get consulta => tieneCoordenadas ? '$lat,$lng' : direccion;
}

/// Enlace universal de cada app. Son https: abren la app instalada o, si no
/// está, el mapa en el navegador (no requieren esquemas en Info.plist).
Uri rutaEn(AppMapas app, DestinoServicio d) {
  switch (app) {
    case AppMapas.google:
      return Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': d.consulta, 'travelmode': 'driving'});
    case AppMapas.waze:
      return Uri.https('waze.com', '/ul', {if (d.tieneCoordenadas) 'll': d.consulta else 'q': d.direccion, 'navigate': 'yes'});
    case AppMapas.apple:
      return Uri.https('maps.apple.com', '/', {'daddr': d.consulta, 'dirflg': 'd'});
  }
}

/// Hoja para elegir con qué app navegar al servicio, o copiar la dirección.
Future<void> mostrarComoLlegar(BuildContext context, DestinoServicio destino) {
  final esIOS = defaultTargetPlatform == TargetPlatform.iOS;
  Future<void> abrir(BuildContext hoja, AppMapas app) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(hoja).pop();
    final ok = await launchUrl(rutaEn(app, destino), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) messenger?.showSnackBar(const SnackBar(content: Text('No se pudo abrir el mapa. Copia la dirección y pégala en tu app de mapas.')));
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (hoja) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Cómo llegar', style: Theme.of(hoja).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (destino.direccion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(destino.direccion, style: Theme.of(hoja).textTheme.bodyMedium),
            ),
          ListTile(leading: const Icon(Icons.map_outlined), title: const Text('Google Maps'), onTap: () => abrir(hoja, AppMapas.google)),
          ListTile(leading: const Icon(Icons.navigation_outlined), title: const Text('Waze'), onTap: () => abrir(hoja, AppMapas.waze)),
          if (esIOS) ListTile(leading: const Icon(Icons.explore_outlined), title: const Text('Apple Maps'), onTap: () => abrir(hoja, AppMapas.apple)),
          if (destino.direccion.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar dirección'),
              onTap: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                Navigator.of(hoja).pop();
                await Clipboard.setData(ClipboardData(text: destino.direccion));
                messenger?.showSnackBar(const SnackBar(content: Text('Dirección copiada')));
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Botón «Cómo llegar» para las tarjetas del servicio; no se pinta sin destino.
class BotonComoLlegar extends StatelessWidget {
  final DestinoServicio destino;
  const BotonComoLlegar({super.key, required this.destino});

  @override
  Widget build(BuildContext context) {
    if (destino.vacio) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => mostrarComoLlegar(context, destino),
          icon: const Icon(Icons.directions_rounded, size: 20),
          label: const Text('Cómo llegar'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
